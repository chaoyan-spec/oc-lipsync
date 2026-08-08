import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createInitialUiState, isSupportedAudio } from './ui-state.js';

test('starts with playback and export disabled', () => {
  assert.deepEqual(createInitialUiState(), {
    file: null,
    sensitivity: 35,
    minOpenMs: 120,
    characterScale: 72,
    canPlay: false,
    canExport: false,
    error: '',
  });
});

test('accepts only the three agreed audio extensions case-insensitively', () => {
  assert.equal(isSupportedAudio('讲解.M4A'), true);
  assert.equal(isSupportedAudio('讲解.mp3'), true);
  assert.equal(isSupportedAudio('讲解.wav'), true);
  assert.equal(isSupportedAudio('讲解.aac'), false);
});
