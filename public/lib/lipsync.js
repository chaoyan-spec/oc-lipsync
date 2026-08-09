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
 */

const roundTime = (seconds) => Number(seconds.toFixed(6));

/** @param {TimelineOptions} options */
function validateOptions({ frameSeconds, threshold, minOpenSeconds }) {
  if (!Number.isFinite(frameSeconds) || frameSeconds <= 0) {
    throw new Error('frameSeconds must be a positive finite number');
  }

  if (!Number.isFinite(threshold) || threshold < 0) {
    throw new Error('threshold must be a non-negative finite number');
  }

  if (!Number.isFinite(minOpenSeconds) || minOpenSeconds < 0) {
    throw new Error('minOpenSeconds must be a non-negative finite number');
  }
}

/**
 * @param {number[]} energies
 * @param {TimelineOptions} options
 * @returns {MouthCue[]}
 */
export function buildMouthTimeline(energies, options) {
  validateOptions(options);

  const { frameSeconds, minOpenSeconds, threshold } = options;
  const classifiedStates = energies.map((energy) => (
    energy > threshold ? 'open' : 'closed'
  ));
  const states = [...classifiedStates];

  for (let index = 0; index < classifiedStates.length; index += 1) {
    if (classifiedStates[index] !== 'open') continue;

    const start = index;
    while (
      index < classifiedStates.length
      && classifiedStates[index] === 'open'
    ) index += 1;

    const minimumEnd = Math.min(
      states.length,
      start + Math.ceil(minOpenSeconds / frameSeconds),
    );
    for (let extension = index; extension < minimumEnd; extension += 1) {
      states[extension] = 'open';
    }
  }

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
