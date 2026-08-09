import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  buildMouthTimeline,
  buildTalkingTimeline,
  calculateSpeechThreshold,
  frameAtTime,
  mouthAtTime,
} from '../public/lib/lipsync.js';

it('derives speech activity from the energy distribution instead of one peak', () => {
  const energies = [0.006, 0.011, 0.019, 0.026, 0.032, 0.060];
  const threshold = calculateSpeechThreshold(energies, 35);

  assert.ok(threshold > 0.006);
  assert.ok(threshold < 0.032);
});

it('recognizes a steady loud signal but keeps a steady quiet signal closed', () => {
  assert.ok(calculateSpeechThreshold(Array(12).fill(0.5), 35) < 0.5);
  assert.ok(calculateSpeechThreshold(Array(12).fill(0.001), 35) > 0.001);
});

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

  it('alternates open and closed while a continuous speech region stays active', () => {
    assert.deepEqual(buildMouthTimeline(Array(18).fill(0.5), {
      frameSeconds: 1 / 30,
      threshold: 0.2,
      minOpenSeconds: 0.12,
      minClosedSeconds: 2 / 30,
    }), [
      { start: 0, end: 0.133333, state: 'open' },
      { start: 0.133333, end: 0.2, state: 'closed' },
      { start: 0.2, end: 0.333333, state: 'open' },
      { start: 0.333333, end: 0.4, state: 'closed' },
      { start: 0.4, end: 0.533333, state: 'open' },
      { start: 0.533333, end: 0.6, state: 'closed' },
    ]);
  });

  it('resets the cadence and stays closed across silence', () => {
    assert.deepEqual(buildMouthTimeline([0.5, 0.5, 0, 0, 0.5, 0.5], {
      frameSeconds: 0.1,
      threshold: 0.2,
      minOpenSeconds: 0.1,
      minClosedSeconds: 0.1,
    }), [
      { start: 0, end: 0.1, state: 'open' },
      { start: 0.1, end: 0.4, state: 'closed' },
      { start: 0.4, end: 0.5, state: 'open' },
      { start: 0.5, end: 0.6, state: 'closed' },
    ]);
  });
});

it('uses a closed final boundary', () => {
  const cues = [{ start: 0, end: 0.2, state: 'open' }];
  assert.equal(mouthAtTime(cues, 0.2), 'closed');
});

describe('buildTalkingTimeline', () => {
  it('keeps silence on the closed sprite frame', () => {
    assert.deepEqual(buildTalkingTimeline([0, 0, 0], {
      frameSeconds: 0.1,
      threshold: 0.2,
      minOpenSeconds: 0.1,
    }), [{ start: 0, end: 0.3, frame: 0 }]);
  });

  it('uses small, medium, and near-closed frames during speech', () => {
    assert.deepEqual(buildTalkingTimeline([0, 0.3, 0.8, 0.3, 0.8, 0], {
      frameSeconds: 0.1,
      threshold: 0.2,
      minOpenSeconds: 0.1,
    }), [
      { start: 0, end: 0.1, frame: 0 },
      { start: 0.1, end: 0.2, frame: 1 },
      { start: 0.2, end: 0.3, frame: 2 },
      { start: 0.3, end: 0.4, frame: 3 },
      { start: 0.4, end: 0.5, frame: 4 },
      { start: 0.5, end: 0.6, frame: 0 },
    ]);
  });

  it('holds each talking pose at the source animation rate during 30 fps analysis', () => {
    const cues = buildTalkingTimeline(Array(12).fill(0.8), {
      frameSeconds: 1 / 30,
      threshold: 0.2,
      minOpenSeconds: 0.12,
    });

    assert.equal(frameAtTime(cues, 0.03), 1);
    assert.equal(frameAtTime(cues, 0.1), 1);
    assert.equal(frameAtTime(cues, 0.14), 2);
    assert.equal(frameAtTime(cues, 0.27), 3);
  });

  it('locks the selected mouth level for the complete pose hold', () => {
    const cues = buildTalkingTimeline([
      0.8, 0.3, 0.8, 0.3,
      0.8, 0.3, 0.8, 0.3,
    ], {
      frameSeconds: 1 / 30,
      threshold: 0.2,
      minOpenSeconds: 0.12,
    });

    assert.equal(frameAtTime(cues, 0.14), 2);
    assert.equal(frameAtTime(cues, 0.17), 2);
    assert.equal(frameAtTime(cues, 0.21), 2);
    assert.equal(frameAtTime(cues, 0.24), 2);
  });

  it('inserts the supplied blink frame without stopping speech cadence', () => {
    const cues = buildTalkingTimeline(Array(7).fill(0.5), {
      frameSeconds: 0.1,
      threshold: 0.2,
      minOpenSeconds: 0.1,
      blinkIntervalSeconds: 0.4,
    });

    assert.equal(frameAtTime(cues, 0.4), 5);
    assert.equal(frameAtTime(cues, 0.5), 2);
  });

  it('handles a long decoded recording without spreading every sample as arguments', () => {
    const cues = buildTalkingTimeline(Array(200_000).fill(0.5), {
      frameSeconds: 1 / 30,
      threshold: 0.2,
      minOpenSeconds: 0.12,
    });

    assert.equal(cues[0].start, 0);
    assert.equal(cues.at(-1).end, 6666.666667);
  });
});

it('uses the closed sprite frame outside a talking timeline', () => {
  assert.equal(frameAtTime([{ start: 0, end: 0.2, frame: 2 }], 0.2), 0);
});
