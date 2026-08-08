import { describe, expect, it } from 'vitest';
import { buildMouthTimeline, mouthAtTime } from './lipsync';

describe('buildMouthTimeline', () => {
  it('keeps silence closed', () => {
    expect(buildMouthTimeline([0, 0, 0], {
      frameSeconds: 0.1, threshold: 0.2, minOpenSeconds: 0.1,
    })).toEqual([{ start: 0, end: 0.3, state: 'closed' }]);
  });

  it('opens above the threshold and merges adjacent frames', () => {
    expect(buildMouthTimeline([0, 0.4, 0.5, 0], {
      frameSeconds: 0.1, threshold: 0.2, minOpenSeconds: 0.1,
    })).toEqual([
      { start: 0, end: 0.1, state: 'closed' },
      { start: 0.1, end: 0.3, state: 'open' },
      { start: 0.3, end: 0.4, state: 'closed' },
    ]);
  });

  it('extends short open bursts to the configured minimum without exceeding duration', () => {
    expect(buildMouthTimeline([0, 0.5, 0, 0], {
      frameSeconds: 0.1, threshold: 0.2, minOpenSeconds: 0.2,
    })).toEqual([
      { start: 0, end: 0.1, state: 'closed' },
      { start: 0.1, end: 0.3, state: 'open' },
      { start: 0.3, end: 0.4, state: 'closed' },
    ]);
  });
});

it('uses a closed final boundary', () => {
  const cues = [{ start: 0, end: 0.2, state: 'open' as const }];
  expect(mouthAtTime(cues, 0.2)).toBe('closed');
});
