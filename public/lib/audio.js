/**
 * @param {Float32Array} samples
 * @param {number} sampleRate
 * @param {number} windowSeconds
 * @returns {number[]}
 */
export function calculateWindowRms(samples, sampleRate, windowSeconds) {
  const windowSamples = Math.max(1, Math.round(sampleRate * windowSeconds));
  const energies = [];

  for (let start = 0; start < samples.length; start += windowSamples) {
    const end = Math.min(start + windowSamples, samples.length);
    let sum = 0;

    for (let index = start; index < end; index += 1) {
      sum += samples[index] ** 2;
    }

    energies.push(Math.sqrt(sum / (end - start)));
  }

  return energies;
}

/**
 * @param {File} file
 * @returns {Promise<{ buffer: AudioBuffer, energies: number[] }>}
 */
export async function decodeAudio(file) {
  const context = new AudioContext();

  try {
    const buffer = await context.decodeAudioData(await file.arrayBuffer());
    const mixedSamples = new Float32Array(buffer.length);

    for (let channel = 0; channel < buffer.numberOfChannels; channel += 1) {
      const samples = buffer.getChannelData(channel);
      for (let index = 0; index < samples.length; index += 1) {
        mixedSamples[index] += samples[index] / buffer.numberOfChannels;
      }
    }

    return {
      buffer,
      energies: calculateWindowRms(mixedSamples, buffer.sampleRate, 1 / 30),
    };
  } finally {
    await context.close();
  }
}
