export type MouthState = 'open' | 'closed';

export type MouthCue = {
  start: number;
  end: number;
  state: MouthState;
};

export type TimelineOptions = {
  frameSeconds: number;
  threshold: number;
  minOpenSeconds: number;
};

const roundTime = (seconds: number): number => Number(seconds.toFixed(6));

function validateOptions({ frameSeconds, threshold, minOpenSeconds }: TimelineOptions): void {
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

export function buildMouthTimeline(
  energies: number[],
  options: TimelineOptions,
): MouthCue[] {
  validateOptions(options);

  const { frameSeconds, minOpenSeconds, threshold } = options;
  const states: MouthState[] = energies.map((energy) => (
    energy > threshold ? 'open' : 'closed'
  ));

  for (let index = 0; index < states.length; index += 1) {
    if (states[index] !== 'open') continue;

    const start = index;
    while (index < states.length && states[index] === 'open') index += 1;

    const minimumEnd = Math.min(
      states.length,
      start + Math.ceil(minOpenSeconds / frameSeconds),
    );
    for (let extension = index; extension < minimumEnd; extension += 1) {
      states[extension] = 'open';
    }
  }

  if (states.length === 0) return [];

  const cues: MouthCue[] = [];
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

export function mouthAtTime(cues: MouthCue[], seconds: number): MouthState {
  return cues.find(({ start, end }) => seconds >= start && seconds < end)?.state ?? 'closed';
}
