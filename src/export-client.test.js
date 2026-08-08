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
  return { disabled: false, textContent: '导出透明 WebM' };
}

function makeInput() {
  return {
    file: {
      name: '访谈.WAV',
      arrayBuffer: async () => Uint8Array.from([0, 255, 7]).buffer,
    },
    cues: [
      { start: 0, end: 0.5, state: 'closed' },
      { start: 0.5, end: 1, state: 'open' },
    ],
    characterScale: 72,
  };
}

test('disables controls immediately and restores their prior state after downloading', async () => {
  const request = deferred();
  const button = makeButton();
  const controls = [{ disabled: false }, { disabled: true }];
  const input = makeInput();
  const downloads = [];
  const revoked = [];
  const fetchCalls = [];
  const controller = createExportController({
    button,
    controls,
    getExportInput: () => input,
    fetchImpl: async (...args) => {
      fetchCalls.push(args);
      return request.promise;
    },
    createObjectURL: () => 'blob:export-result',
    revokeObjectURL: (url) => revoked.push(url),
    download: (url, filename) => downloads.push({ url, filename }),
    showError: () => {},
  });

  const exporting = controller.exportVideo();
  assert.equal(button.textContent, '正在导出…');
  assert.equal(button.disabled, true);
  assert.deepEqual(controls.map(({ disabled }) => disabled), [true, true]);

  request.resolve(new Response(Uint8Array.from([26, 69, 223, 163]), {
    status: 200,
    headers: { 'Content-Type': 'video/webm' },
  }));
  await exporting;

  assert.equal(fetchCalls.length, 1);
  assert.equal(fetchCalls[0][0], '/api/export');
  assert.equal(fetchCalls[0][1].method, 'POST');
  assert.equal(fetchCalls[0][1].headers['Content-Type'], 'application/octet-stream');
  const decoded = decodeExportRequest(fetchCalls[0][1].body);
  assert.deepEqual(decoded.metadata, {
    filename: '访谈.WAV',
    cues: input.cues,
    scale: 0.72,
  });
  assert.deepEqual(decoded.audioBytes, Uint8Array.from([0, 255, 7]));
  assert.deepEqual(downloads, [{
    url: 'blob:export-result',
    filename: '访谈-oc-lipsync.webm',
  }]);
  assert.deepEqual(revoked, ['blob:export-result']);
  assert.equal(button.textContent, '导出透明 WebM');
  assert.equal(button.disabled, false);
  assert.deepEqual(controls.map(({ disabled }) => disabled), [false, true]);
});

test('shows a retry error and preserves loaded audio and settings after failure', async () => {
  const button = makeButton();
  const controls = [{ disabled: false }, { disabled: false }];
  const input = makeInput();
  const originalInput = structuredClone({
    fileName: input.file.name,
    cues: input.cues,
    characterScale: input.characterScale,
  });
  const errors = [];
  let downloadCount = 0;
  const controller = createExportController({
    button,
    controls,
    getExportInput: () => input,
    fetchImpl: async () => new Response(JSON.stringify({ error: 'encoder failed' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    }),
    createObjectURL: () => 'blob:unused',
    revokeObjectURL: () => {},
    download: () => { downloadCount += 1; },
    showError: (message) => errors.push(message),
  });

  await controller.exportVideo();

  assert.equal(errors.at(-1), '导出失败，请重试');
  assert.equal(downloadCount, 0);
  assert.deepEqual({
    fileName: input.file.name,
    cues: input.cues,
    characterScale: input.characterScale,
  }, originalInput);
  assert.equal(button.textContent, '导出透明 WebM');
  assert.equal(button.disabled, false);
  assert.deepEqual(controls.map(({ disabled }) => disabled), [false, false]);
});
