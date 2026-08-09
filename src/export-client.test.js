import assert from 'node:assert/strict';
import { test } from 'node:test';

import { createExportController } from '../public/lib/export-client.js';
import { decodeExportRequest } from '../public/lib/request-envelope.js';

function deferred() {
  let resolve;
  let reject;
  const promise = new Promise((resolvePromise, rejectPromise) => {
    resolve = resolvePromise;
    reject = rejectPromise;
  });
  return { promise, resolve, reject };
}

function makeButton() {
  return { disabled: false, textContent: '导出剪映透明 MOV' };
}

function makeDownloadLink() {
  return {
    hidden: true,
    textContent: '导出完成，点击保存 MOV',
    removeAttribute(name) {
      delete this[name];
    },
  };
}

function makeInput() {
  const file = new Blob([Uint8Array.from([0, 255, 7])], { type: 'audio/wav' });
  Object.defineProperties(file, {
    name: { value: '访谈.WAV' },
    arrayBuffer: {
      value: async () => { throw new Error('export must not copy the whole File'); },
    },
  });
  return {
    file,
    cues: [
      { start: 0, end: 0.5, state: 'closed' },
      { start: 0.5, end: 1, state: 'open' },
    ],
  };
}

test('disables controls and derives the final button state from current loaded state', async () => {
  const request = deferred();
  const button = makeButton();
  const downloadLink = makeDownloadLink();
  const controls = [{ disabled: false }, { disabled: true }];
  const input = makeInput();
  const revoked = [];
  const fetchCalls = [];
  const busyStates = [];
  let canExport = true;
  const controller = createExportController({
    button,
    downloadLink,
    controls,
    getExportInput: () => input,
    fetchImpl: async (...args) => {
      fetchCalls.push(args);
      return request.promise;
    },
    createObjectURL: () => 'blob:export-result',
    revokeObjectURL: (url) => revoked.push(url),
    showError: () => {},
    setExporting: (isExporting) => busyStates.push(isExporting),
    canExport: () => canExport,
  });

  const exporting = controller.exportVideo();
  assert.equal(button.textContent, '正在导出…');
  assert.equal(button.disabled, true);
  assert.deepEqual(controls.map(({ disabled }) => disabled), [true, true]);

  canExport = false;
  request.resolve(new Response(Uint8Array.from([26, 69, 223, 163]), {
    status: 200,
    headers: { 'Content-Type': 'video/quicktime' },
  }));
  await exporting;

  assert.equal(fetchCalls.length, 1);
  assert.equal(fetchCalls[0][0], '/api/export');
  assert.equal(fetchCalls[0][1].method, 'POST');
  assert.equal(fetchCalls[0][1].headers['Content-Type'], 'application/octet-stream');
  assert.ok(fetchCalls[0][1].body instanceof Blob);
  const decoded = decodeExportRequest(await fetchCalls[0][1].body.arrayBuffer());
  assert.deepEqual(decoded.metadata, {
    filename: '访谈.WAV',
    cues: input.cues,
  });
  assert.deepEqual(decoded.audioBytes, Uint8Array.from([0, 255, 7]));
  assert.equal(downloadLink.hidden, false);
  assert.equal(downloadLink.textContent, '导出完成，点击保存 MOV');
  assert.equal(downloadLink.href, 'blob:export-result');
  assert.equal(downloadLink.download, '访谈-OC口播.mov');
  assert.deepEqual(revoked, []);
  assert.equal(button.textContent, '导出剪映透明 MOV');
  assert.equal(button.disabled, true);
  assert.deepEqual(controls.map(({ disabled }) => disabled), [false, true]);
  assert.deepEqual(busyStates, [true, false]);
});

test('shows a retry error and preserves loaded audio and settings after failure', async () => {
  const button = makeButton();
  const downloadLink = makeDownloadLink();
  const controls = [{ disabled: false }, { disabled: false }];
  const input = makeInput();
  const originalInput = structuredClone({
    fileName: input.file.name,
    cues: input.cues,
  });
  const errors = [];
  const controller = createExportController({
    button,
    downloadLink,
    controls,
    getExportInput: () => input,
    fetchImpl: async () => new Response(JSON.stringify({ error: 'encoder failed' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    }),
    createObjectURL: () => 'blob:unused',
    revokeObjectURL: () => {},
    showError: (message) => errors.push(message),
    setExporting: () => {},
    canExport: () => true,
  });

  await controller.exportVideo();

  assert.equal(errors.at(-1), '导出失败，请重试');
  assert.equal(downloadLink.hidden, true);
  assert.equal(downloadLink.href, undefined);
  assert.equal(downloadLink.download, undefined);
  assert.deepEqual({
    fileName: input.file.name,
    cues: input.cues,
  }, originalInput);
  assert.equal(button.textContent, '导出剪映透明 MOV');
  assert.equal(button.disabled, false);
  assert.deepEqual(controls.map(({ disabled }) => disabled), [false, false]);
});

test('revokes a retained result only when it is replaced or disposed on unload', async () => {
  const downloadLink = makeDownloadLink();
  const urls = ['blob:first-result', 'blob:replacement-result'];
  const revoked = [];
  const replacement = deferred();
  let requestCount = 0;
  const controller = createExportController({
    button: makeButton(),
    downloadLink,
    getExportInput: makeInput,
    fetchImpl: async () => {
      requestCount += 1;
      return requestCount === 1
        ? new Response(Uint8Array.from([1]), { status: 200 })
        : replacement.promise;
    },
    createObjectURL: () => urls.shift(),
    revokeObjectURL: (url) => revoked.push(url),
    showError: () => {},
    setExporting: () => {},
    canExport: () => true,
  });

  await controller.exportVideo();
  assert.equal(downloadLink.href, 'blob:first-result');
  assert.deepEqual(revoked, []);

  const replacing = controller.exportVideo();
  assert.equal(downloadLink.href, 'blob:first-result');
  assert.deepEqual(revoked, []);

  replacement.resolve(new Response(Uint8Array.from([2]), { status: 200 }));
  await replacing;
  assert.equal(downloadLink.hidden, false);
  assert.equal(downloadLink.href, 'blob:replacement-result');
  assert.equal(downloadLink.download, '访谈-OC口播.mov');
  assert.deepEqual(revoked, ['blob:first-result']);

  controller.dispose();
  assert.equal(downloadLink.hidden, true);
  assert.equal(downloadLink.href, undefined);
  assert.equal(downloadLink.download, undefined);
  assert.deepEqual(revoked, ['blob:first-result', 'blob:replacement-result']);
});

test('keeps the last successful save link when a replacement export fails', async () => {
  const downloadLink = makeDownloadLink();
  const errors = [];
  const revoked = [];
  let requestCount = 0;
  const controller = createExportController({
    button: makeButton(),
    downloadLink,
    getExportInput: makeInput,
    fetchImpl: async () => {
      requestCount += 1;
      return new Response(Uint8Array.from([1]), { status: requestCount === 1 ? 200 : 500 });
    },
    createObjectURL: () => 'blob:last-success',
    revokeObjectURL: (url) => revoked.push(url),
    showError: (message) => errors.push(message),
    setExporting: () => {},
    canExport: () => true,
  });

  await controller.exportVideo();
  await controller.exportVideo();

  assert.equal(downloadLink.hidden, false);
  assert.equal(downloadLink.href, 'blob:last-success');
  assert.equal(downloadLink.download, '访谈-OC口播.mov');
  assert.deepEqual(revoked, []);
  assert.equal(errors.at(-1), '本次导出失败，上次完成的 MOV 仍可保存');
});
