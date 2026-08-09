import assert from 'node:assert/strict';
import { test } from 'node:test';

import { createMouthPreview } from '../public/lib/playback-mouth.js';

test('refreshes mouth state on animation frames while audio plays', () => {
  const callbacks = [];
  const rendered = [];
  const audio = { currentTime: 0.05, paused: false, ended: false };
  const preview = createMouthPreview({
    audio,
    getCues: () => [
      { start: 0, end: 0.1, state: 'open' },
      { start: 0.1, end: 0.2, state: 'closed' },
    ],
    render: (state) => rendered.push(state),
    requestFrame: (callback) => (callbacks.push(callback), callbacks.length),
    cancelFrame: () => {},
  });

  preview.start();
  assert.equal(rendered.at(-1), 'open');
  audio.currentTime = 0.15;
  callbacks.shift()();
  assert.equal(rendered.at(-1), 'closed');
});

test('stops scheduling and closes the mouth when playback stops', () => {
  const callbacks = [];
  const cancelled = [];
  const rendered = [];
  const audio = { currentTime: 0, paused: false, ended: false };
  const preview = createMouthPreview({
    audio,
    getCues: () => [{ start: 0, end: 1, state: 'open' }],
    render: (state) => rendered.push(state),
    requestFrame: (callback) => (callbacks.push(callback), 7),
    cancelFrame: (id) => cancelled.push(id),
  });

  preview.start();
  preview.stop();
  assert.deepEqual(cancelled, [7]);
  assert.equal(rendered.at(-1), 'closed');
});
