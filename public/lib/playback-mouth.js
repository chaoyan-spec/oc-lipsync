import { frameAtTime, mouthAtTime } from './lipsync.js';

export function createMouthPreview({
  audio,
  getCues,
  render,
  requestFrame = requestAnimationFrame,
  cancelFrame = cancelAnimationFrame,
}) {
  let frameId = null;

  const currentValue = () => {
    const cues = getCues();
    return cues.some(({ frame }) => Number.isInteger(frame))
      ? frameAtTime(cues, audio.currentTime)
      : mouthAtTime(cues, audio.currentTime);
  };

  const draw = () => {
    frameId = null;
    render(currentValue());
    if (!audio.paused && !audio.ended) frameId = requestFrame(draw);
  };

  return {
    start() {
      if (frameId === null) draw();
    },
    stop() {
      if (frameId !== null) cancelFrame(frameId);
      frameId = null;
      const usesFrames = getCues().some(({ frame }) => Number.isInteger(frame));
      render(usesFrames ? 0 : 'closed');
    },
    sync() {
      render(currentValue());
    },
  };
}
