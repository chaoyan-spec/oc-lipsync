import { mouthAtTime } from './lipsync.js';

export function createMouthPreview({
  audio,
  getCues,
  render,
  requestFrame = requestAnimationFrame,
  cancelFrame = cancelAnimationFrame,
}) {
  let frameId = null;

  const draw = () => {
    frameId = null;
    render(mouthAtTime(getCues(), audio.currentTime));
    if (!audio.paused && !audio.ended) frameId = requestFrame(draw);
  };

  return {
    start() {
      if (frameId === null) draw();
    },
    stop() {
      if (frameId !== null) cancelFrame(frameId);
      frameId = null;
      render('closed');
    },
    sync() {
      render(mouthAtTime(getCues(), audio.currentTime));
    },
  };
}
