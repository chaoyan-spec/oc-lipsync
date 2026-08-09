import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { buildMouthTimeline, mouthAtTime } from '../public/lib/lipsync.js';

describe('buildMouthTimeline', () => {
  it('keeps silence closed', () => {
    assert.deepEqual(buildMouthTimeline([0, 0, 0], {
      frameSeconds: 0.1, threshold: 0.2, minOpenSeconds: 0.1,
    }), [{ start: 0, end: 0.3, state: 'closed' }]);
  });

  it('opens above the threshold and merges adjacent frames', () => {
    assert.deepEqual(buildMouthTimeline([0, 0.4, 0.5, 0], {
      frameSeconds: 0.1, threshold: 0.2, minOpenSeconds: 0.1,
    }), [
      { start: 0, end: 0.1, state: 'closed' },
      { start: 0.1, end: 0.3, state: 'open' },
      { start: 0.3, end: 0.4, state: 'closed' },
    ]);
  });

  it('extends short open bursts to the configured minimum without exceeding duration', () => {
    assert.deepEqual(buildMouthTimeline([0, 0.5, 0, 0], {
      frameSeconds: 0.1, threshold: 0.2, minOpenSeconds: 0.2,
    }), [
      { start: 0, end: 0.1, state: 'closed' },
      { start: 0.1, end: 0.3, state: 'open' },
      { start: 0.3, end: 0.4, state: 'closed' },
    ]);
  });

  it('does not cascade a one-frame burst opened with the 30 fps and 120 ms defaults', () => {
    const energies = Array(20).fill(0);
    energies[1] = 0.5;

    assert.deepEqual(buildMouthTimeline(energies, {
      frameSeconds: 1 / 30, threshold: 0.2, minOpenSeconds: 0.12,
    }), [
      { start: 0, end: 0.033333, state: 'closed' },
      { start: 0.033333, end: 0.166667, state: 'open' },
      { start: 0.166667, end: 0.666667, state: 'closed' },
    ]);
  });

  it('does not cascade a two-frame burst opened with the 30 fps and 120 ms defaults', () => {
    const energies = Array(20).fill(0);
    energies[1] = 0.5;
    energies[2] = 0.5;

    assert.deepEqual(buildMouthTimeline(energies, {
      frameSeconds: 1 / 30, threshold: 0.2, minOpenSeconds: 0.12,
    }), [
      { start: 0, end: 0.033333, state: 'closed' },
      { start: 0.033333, end: 0.166667, state: 'open' },
      { start: 0.166667, end: 0.666667, state: 'closed' },
    ]);
  });
});

it('uses a closed final boundary', () => {
  const cues = [{ start: 0, end: 0.2, state: 'open' }];
  assert.equal(mouthAtTime(cues, 0.2), 'closed');
});
