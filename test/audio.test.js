import assert from 'node:assert/strict';
import { it } from 'node:test';
import { calculateWindowRms } from '../public/lib/audio.js';

it('calculates one RMS value per complete or partial window', () => {
  const values = calculateWindowRms(new Float32Array([1, -1, 0, 0]), 4, 0.5);
  assert.deepEqual(values, [1, 0]);
});

it('returns zeros for silent samples', () => {
  assert.deepEqual(calculateWindowRms(new Float32Array(6), 6, 0.5), [0, 0]);
});
