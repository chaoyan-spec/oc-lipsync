import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { buildMouthTimeline, mouthAtTime } from './lipsync.ts';

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
});

it('uses a closed final boundary', () => {
  const cues = [{ start: 0, end: 0.2, state: 'open' as const }];
  assert.equal(mouthAtTime(cues, 0.2), 'closed');
});
