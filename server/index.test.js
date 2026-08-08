import assert from 'node:assert/strict';
import { mkdir, mkdtemp, readFile, readdir, rm, stat, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, test } from 'node:test';

import { encodeExportRequest } from '../public/lib/request-envelope.js';
import { createAppServer } from './index.js';

const HOST = '127.0.0.1';
const MISSING_AUDIO_ERROR = '请先选择口播音频';
const UNSUPPORTED_AUDIO_ERROR = '暂不支持该音频，请换用 MP3、WAV 或 M4A';
const INVALID_SETTINGS_ERROR = '导出参数无效';
const servers = [];
const temporaryRoots = [];

afterEach(async () => {
  await Promise.all(servers.splice(0).map((server) => new Promise((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
  })));
  await Promise.all(temporaryRoots.splice(0).map((root) => (
    rm(root, { recursive: true, force: true })
  )));
});

async function startServer(options = {}) {
  const server = createAppServer(options);
  servers.push(server);
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, HOST, resolve);
  });
  const { port } = server.address();
  return `http://${HOST}:${port}`;
}

function rawEnvelope(metadata, audioBytes = new Uint8Array()) {
  const json = new TextEncoder().encode(JSON.stringify(metadata));
  const bytes = new Uint8Array(4 + json.length + audioBytes.length);
  new DataView(bytes.buffer).setUint32(0, json.length, false);
  bytes.set(json, 4);
  bytes.set(audioBytes, 4 + json.length);
  return bytes;
}

const validMetadata = {
  filename: 'sample.wav',
  scale: 0.72,
  cues: [
    { start: 0, end: 0.5, state: 'closed' },
    { start: 0.5, end: 1, state: 'open' },
  ],
};

async function post(baseUrl, body) {
  return fetch(`${baseUrl}/api/export`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/octet-stream' },
    body,
  });
}

async function waitForRemoval(targetPath) {
  for (let attempt = 0; attempt < 50; attempt += 1) {
    try {
      await stat(targetPath);
      await new Promise((resolve) => setTimeout(resolve, 5));
    } catch (error) {
      if (error?.code === 'ENOENT') return;
      throw error;
    }
  }
  assert.fail(`Temporary path was not removed: ${targetPath}`);
}

test('returns the agreed error when audio is missing', async () => {
  const baseUrl = await startServer();
  const response = await post(baseUrl, rawEnvelope(validMetadata));

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { error: MISSING_AUDIO_ERROR });
});

test('rejects malformed streamed prefixes and metadata', async () => {
  const baseUrl = await startServer();
  const malformedBodies = [
    Uint8Array.from([0, 0, 0]),
    Uint8Array.from([0, 0, 0, 20, 123, 125, 1]),
    Uint8Array.from([0, 0, 0, 1, 255, 1]),
  ];

  for (const body of malformedBodies) {
    const response = await post(baseUrl, body);
    assert.equal(response.status, 400);
    assert.deepEqual(await response.json(), { error: INVALID_SETTINGS_ERROR });
  }
});

test('rejects unsupported audio extensions', async () => {
  const baseUrl = await startServer();
  const response = await post(baseUrl, encodeExportRequest(
    { ...validMetadata, filename: 'sample.aac' },
    Uint8Array.from([1]),
  ));

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { error: UNSUPPORTED_AUDIO_ERROR });
});

test('rejects scales outside 0.4 through 1', async () => {
  const baseUrl = await startServer();
  const response = await post(baseUrl, encodeExportRequest(
    { ...validMetadata, scale: 0.39 },
    Uint8Array.from([1]),
  ));

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { error: INVALID_SETTINGS_ERROR });
});

test('rejects invalid or non-contiguous mouth cues', async () => {
  const baseUrl = await startServer();
  const invalidCueSets = [
    [],
    [{ start: 0, end: 0.5, state: 'talking' }],
    [
      { start: 0, end: 0.4, state: 'closed' },
      { start: 0.5, end: 1, state: 'open' },
    ],
  ];

  for (const cues of invalidCueSets) {
    const response = await post(baseUrl, encodeExportRequest(
      { ...validMetadata, cues },
      Uint8Array.from([1]),
    ));
    assert.equal(response.status, 400);
    assert.deepEqual(await response.json(), { error: INVALID_SETTINGS_ERROR });
  }
});

test('returns a WebM attachment for a valid request and cleans temporary files', async () => {
  let receivedInput;
  let receivedAudio;
  let temporaryRoot;
  const exportVideo = async (input) => {
    receivedInput = input;
    receivedAudio = await readFile(input.audioPath);
    temporaryRoot = input.temporaryRoot;
    const outputDirectory = join(input.temporaryRoot, 'fake-export');
    const outputPath = join(outputDirectory, 'transparent.webm');
    await mkdir(outputDirectory);
    await writeFile(outputPath, Uint8Array.from([26, 69, 223, 163]));
    return { path: outputPath };
  };
  const baseUrl = await startServer({ exportVideo });
  const fixtureAudio = await readFile(new URL('../test/fixtures/tone-silence.wav', import.meta.url));

  const specialMetadata = { ...validMetadata, filename: "a'b(c)*.wav", scale: 0.4 };
  const response = await post(baseUrl, encodeExportRequest(specialMetadata, fixtureAudio));

  assert.equal(response.status, 200);
  assert.match(response.headers.get('content-type'), /^video\/webm\b/);
  assert.match(
    response.headers.get('content-disposition'),
    /filename\*=UTF-8''a%27b%28c%29%2A-oc-lipsync\.webm/,
  );
  assert.deepEqual(new Uint8Array(await response.arrayBuffer()), Uint8Array.from([26, 69, 223, 163]));
  assert.equal(receivedInput.characterScale, 0.4);
  assert.deepEqual(receivedInput.mouthCues, validMetadata.cues);
  assert.deepEqual(receivedAudio, fixtureAudio);
  await waitForRemoval(temporaryRoot);
});

test('streams framed audio into the temporary file before the request finishes', async () => {
  const requestParent = await mkdtemp(join(tmpdir(), 'oc-lipsync-stream-test-'));
  temporaryRoots.push(requestParent);
  const firstAudio = Uint8Array.from([1, 2, 3]);
  const restAudio = Uint8Array.from([4, 5]);
  const firstEnvelope = rawEnvelope(validMetadata, firstAudio);
  let streamController;
  const body = new ReadableStream({
    start(controller) {
      streamController = controller;
      controller.enqueue(firstEnvelope.subarray(0, 2));
      controller.enqueue(firstEnvelope.subarray(2, 7));
      controller.enqueue(firstEnvelope.subarray(7));
    },
  });
  const exportVideo = async (input) => {
    const outputDirectory = join(input.temporaryRoot, 'fake-export');
    const outputPath = join(outputDirectory, 'transparent.webm');
    await mkdir(outputDirectory);
    await writeFile(outputPath, Uint8Array.from([26, 69, 223, 163]));
    return { path: outputPath };
  };
  const baseUrl = await startServer({ exportVideo, temporaryRoot: requestParent });
  const responsePromise = fetch(`${baseUrl}/api/export`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/octet-stream' },
    body,
    duplex: 'half',
  });

  let audioPath;
  let streamedAudio;
  for (let attempt = 0; attempt < 100; attempt += 1) {
    const requests = await readdir(requestParent);
    if (requests.length > 0) {
      audioPath = join(requestParent, requests[0], 'audio.wav');
      try {
        if ((await stat(audioPath)).size === firstAudio.length) {
          streamedAudio = await readFile(audioPath);
          break;
        }
      } catch (error) {
        if (error?.code !== 'ENOENT') throw error;
      }
    }
    await new Promise((resolve) => setTimeout(resolve, 5));
  }
  streamController.enqueue(restAudio);
  streamController.close();
  const response = await responsePromise;
  assert.equal(response.status, 200);
  await response.arrayBuffer();
  assert.ok(audioPath, 'request temp directory must exist before upload completion');
  assert.deepEqual(Uint8Array.from(streamedAudio), firstAudio);
});

test('cleans the request directory when the exporter fails', async () => {
  let temporaryRoot;
  const baseUrl = await startServer({
    exportVideo: async (input) => {
      temporaryRoot = input.temporaryRoot;
      throw new Error('encoder failed');
    },
  });
  const response = await post(baseUrl, encodeExportRequest(
    validMetadata,
    Uint8Array.from([1, 2, 3]),
  ));

  assert.equal(response.status, 500);
  assert.deepEqual(await response.json(), { error: '导出失败，请重试' });
  await waitForRemoval(temporaryRoot);
});

test('rejects a request body over the configured limit before exporting', async () => {
  let exportCount = 0;
  const baseUrl = await startServer({
    maxBodyBytes: 8,
    exportVideo: async () => { exportCount += 1; },
  });
  const response = await fetch(`${baseUrl}/api/export`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/octet-stream' },
    body: new ReadableStream({
      start(controller) {
        controller.enqueue(Uint8Array.from({ length: 5 }, () => 1));
        controller.enqueue(Uint8Array.from({ length: 4 }, () => 1));
        controller.close();
      },
    }),
    duplex: 'half',
  });

  assert.equal(response.status, 413);
  assert.deepEqual(await response.json(), { error: '音频文件过大' });
  assert.equal(exportCount, 0);
});

test('keeps static traversal protections while serving public files', async () => {
  const baseUrl = await startServer();
  const indexResponse = await fetch(`${baseUrl}/`);
  const traversalResponse = await fetch(`${baseUrl}/%2e%2e%5cpackage.json`);

  assert.equal(indexResponse.status, 200);
  assert.match(await indexResponse.text(), /OC 口播机/);
  assert.equal(traversalResponse.status, 403);
});
