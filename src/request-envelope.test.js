import assert from 'node:assert/strict';
import { test } from 'node:test';

import { decodeExportRequest, encodeExportRequest } from '../public/lib/request-envelope.js';

function envelopeWith(metadata, audioBytes = new Uint8Array()) {
  const json = new TextEncoder().encode(JSON.stringify(metadata));
  const bytes = new Uint8Array(4 + json.length + audioBytes.length);
  new DataView(bytes.buffer).setUint32(0, json.length, false);
  bytes.set(json, 4);
  bytes.set(audioBytes, 4 + json.length);
  return bytes;
}

test('round-trips Unicode metadata and arbitrary binary audio', () => {
  const metadata = {
    filename: '口播 你好.wav',
    cues: [{ start: 0, end: 0.5, state: 'open' }],
    scale: 0.72,
  };
  const audioBytes = Uint8Array.from([0, 255, 128, 1, 13, 10]);

  const decoded = decodeExportRequest(encodeExportRequest(metadata, audioBytes));

  assert.deepEqual(decoded.metadata, metadata);
  assert.deepEqual(decoded.audioBytes, audioBytes);
});

test('rejects a missing JSON-length prefix', () => {
  assert.throws(() => decodeExportRequest(Uint8Array.from([0, 0, 0])), /invalid export request/i);
});

test('rejects a JSON-length prefix larger than the remaining payload', () => {
  const bytes = Uint8Array.from([0, 0, 0, 20, 123, 125, 1]);
  assert.throws(() => decodeExportRequest(bytes), /invalid export request/i);
});

test('rejects an empty audio payload', () => {
  assert.throws(
    () => decodeExportRequest(envelopeWith({ filename: 'voice.wav' })),
    /audio payload is empty/i,
  );
});
