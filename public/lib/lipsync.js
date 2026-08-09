/** @typedef {'open' | 'closed'} MouthState */

/**
 * @typedef {object} MouthCue
 * @property {number} start
 * @property {number} end
 * @property {MouthState} state
 */

/**
 * @typedef {object} TimelineOptions
 * @property {number} frameSeconds
 * @property {number} threshold
 * @property {number} minOpenSeconds
 * @property {number} [minClosedSeconds]
 */

const roundTime = (seconds) => Number(seconds.toFixed(6));

/** @param {TimelineOptions} options */
function validateOptions({
  frameSeconds,
  threshold,
  minOpenSeconds,
  minClosedSeconds = 0,
}) {
  if (!Number.isFinite(frameSeconds) || frameSeconds <= 0) {
    throw new Error('frameSeconds must be a positive finite number');
  }

  if (!Number.isFinite(threshold) || threshold < 0) {
    throw new Error('threshold must be a non-negative finite number');
  }

  if (!Number.isFinite(minOpenSeconds) || minOpenSeconds < 0) {
    throw new Error('minOpenSeconds must be a non-negative finite number');
  }

  if (!Number.isFinite(minClosedSeconds) || minClosedSeconds < 0) {
    throw new Error('minClosedSeconds must be a non-negative finite number');
  }
}

function percentile(sorted, fraction) {
  if (sorted.length === 0) return 0;
  return sorted[Math.floor((sorted.length - 1) * fraction)];
}

/**
 * @param {number[]} energies
 * @param {number} sensitivity
 * @returns {number}
 */
export function calculateSpeechThreshold(energies, sensitivity) {
  if (!Number.isFinite(sensitivity) || sensitivity < 0 || sensitivity > 100) {
    throw new Error('sensitivity must be between 0 and 100');
  }

  const sorted = energies.filter(Number.isFinite).sort((a, b) => a - b);
  const floor = percentile(sorted, 0.1);
  const speech = percentile(sorted, 0.9);
  if (speech - floor < 0.002) return Math.max(0.002, speech * 0.5);
  return Math.max(0.002, floor + (speech - floor) * (1 - sensitivity / 100));
}

/**
 * @param {number[]} energies
 * @param {TimelineOptions} options
 * @returns {MouthCue[]}
 */
export function buildMouthTimeline(energies, options) {
  validateOptions(options);

  const {
    frameSeconds,
    minOpenSeconds,
    minClosedSeconds = 0,
    threshold,
  } = options;
  const classifiedStates = energies.map((energy) => (
    energy > threshold ? 'open' : 'closed'
  ));
  const speechStates = classifiedStates.map(() => false);
  const openFrames = Math.max(1, Math.ceil(minOpenSeconds / frameSeconds));

  for (let index = 0; index < classifiedStates.length; index += 1) {
    if (classifiedStates[index] !== 'open') continue;

    const start = index;
    while (
      index < classifiedStates.length
      && classifiedStates[index] === 'open'
    ) index += 1;

    const minimumEnd = Math.min(
      speechStates.length,
      start + openFrames,
    );
    const speechEnd = Math.max(index, minimumEnd);
    for (let speech = start; speech < speechEnd; speech += 1) {
      speechStates[speech] = true;
    }
  }

  const closedFrames = Math.ceil(minClosedSeconds / frameSeconds);
  const cycleFrames = openFrames + closedFrames;
  let phase = 0;
  const states = speechStates.map((isSpeech) => {
    if (!isSpeech) {
      phase = 0;
      return 'closed';
    }

    const state = closedFrames === 0 || phase < openFrames ? 'open' : 'closed';
    phase = (phase + 1) % cycleFrames;
    return state;
  });

  if (states.length === 0) return [];

  const cues = [];
  let start = 0;
  for (let index = 1; index <= states.length; index += 1) {
    if (index < states.length && states[index] === states[start]) continue;

    cues.push({
      start: roundTime(start * frameSeconds),
      end: roundTime(index * frameSeconds),
      state: states[start],
    });
    start = index;
  }

  return cues;
}

/**
 * @param {MouthCue[]} cues
 * @param {number} seconds
 * @returns {MouthState}
 */
export function mouthAtTime(cues, seconds) {
  return cues.find(({ start, end }) => seconds >= start && seconds < end)?.state ?? 'closed';
}
