import { decodeAudio } from './lib/audio.js';
import { createExportController } from './lib/export-client.js';
import { buildMouthTimeline, mouthAtTime } from './lib/lipsync.js';
import { createInitialUiState, isSupportedAudio } from './lib/ui-state.js';

const CLOSED_MOUTH = '/oc-mouth-closed.png';
const OPEN_MOUTH = '/oc-mouth-open.png';
const FRAME_SECONDS = 1 / 30;
const DECODE_ERROR = '暂不支持该音频，请换用 MP3、WAV 或 M4A';
const SILENT_ERROR = '未检测到有效声音，请调低嘴型灵敏度后重试';

const elements = {
  audio: document.querySelector('#preview-audio'),
  character: document.querySelector('#character'),
  characterScale: document.querySelector('#character-scale'),
  characterScaleValue: document.querySelector('#character-scale-value'),
  currentTime: document.querySelector('#current-time'),
  dropZone: document.querySelector('#drop-zone'),
  duration: document.querySelector('#duration'),
  error: document.querySelector('#error-message'),
  exportButton: document.querySelector('.export-button'),
  fileInput: document.querySelector('#audio-file'),
  fileName: document.querySelector('#file-name'),
  minOpen: document.querySelector('#min-open'),
  minOpenValue: document.querySelector('#min-open-value'),
  playButton: document.querySelector('#play-button'),
  progress: document.querySelector('#progress'),
  sensitivity: document.querySelector('#sensitivity'),
  sensitivityValue: document.querySelector('#sensitivity-value'),
};

const initialUiState = createInitialUiState();
const state = {
  ...initialUiState,
  minOpenSeconds: initialUiState.minOpenMs / 1000,
  cues: [],
  energies: [],
  audioUrl: '',
  loadId: 0,
};

function formatTime(seconds) {
  if (!Number.isFinite(seconds)) return '00:00';
  const minutes = Math.floor(seconds / 60);
  const remaining = Math.floor(seconds % 60);
  return `${String(minutes).padStart(2, '0')}:${String(remaining).padStart(2, '0')}`;
}

function showError(message = '') {
  state.error = message;
  elements.error.textContent = message;
  elements.error.hidden = !message;
}

function setMouth(mouthState) {
  const isOpen = mouthState === 'open';
  const nextSource = isOpen ? OPEN_MOUTH : CLOSED_MOUTH;
  if (!elements.character.src.endsWith(nextSource)) {
    elements.character.src = nextSource;
  }
  elements.character.alt = `${isOpen ? '张嘴' : '闭嘴'}状态的 OC`;
}

function rebuildTimeline() {
  if (state.energies.length === 0) {
    state.cues = [];
    state.canExport = false;
    elements.exportButton.disabled = true;
    setMouth('closed');
    return;
  }

  const peak = state.energies.reduce((highest, energy) => Math.max(highest, energy), 0);
  const threshold = Math.max(0.002, peak * (1 - state.sensitivity / 100));
  state.cues = buildMouthTimeline(state.energies, {
    frameSeconds: FRAME_SECONDS,
    threshold,
    minOpenSeconds: state.minOpenSeconds,
  });
  state.canExport = Boolean(state.file) && state.cues.some(({ state: mouthState }) => (
    mouthState === 'open'
  ));
  elements.exportButton.disabled = !state.canExport;
  setMouth(mouthAtTime(state.cues, elements.audio.currentTime));
}

function resetTransport() {
  elements.audio.pause();
  elements.audio.removeAttribute('src');
  elements.audio.load();
  state.canPlay = false;
  state.canExport = false;
  elements.playButton.disabled = !state.canPlay;
  elements.exportButton.disabled = !state.canExport;
  elements.playButton.textContent = '播放';
  elements.progress.disabled = true;
  elements.progress.value = '0';
  elements.currentTime.value = '00:00';
  elements.duration.textContent = '00:00';
  setMouth('closed');
}

async function loadAudio(file) {
  const loadId = state.loadId + 1;
  state.loadId = loadId;
  state.file = file;
  state.energies = [];
  state.cues = [];

  if (state.audioUrl) URL.revokeObjectURL(state.audioUrl);
  state.audioUrl = '';
  resetTransport();
  showError();
  elements.fileName.textContent = file.name;
  elements.fileName.title = file.name;

  try {
    const { buffer, energies } = await decodeAudio(file);
    if (loadId !== state.loadId) return;

    state.energies = energies;
    state.audioUrl = URL.createObjectURL(file);
    elements.audio.src = state.audioUrl;
    elements.duration.textContent = formatTime(buffer.duration);
    state.canPlay = true;
    elements.playButton.disabled = !state.canPlay;
    elements.progress.disabled = false;

    const peak = energies.reduce((highest, energy) => Math.max(highest, energy), 0);
    if (peak < 0.0001) showError(SILENT_ERROR);
    rebuildTimeline();
  } catch {
    if (loadId !== state.loadId) return;
    state.file = null;
    elements.fileName.textContent = '无法读取的音频';
    showError(DECODE_ERROR);
  }
}

function useSelectedFile(file) {
  if (!file) return;

  if (!isSupportedAudio(file.name)) {
    state.loadId += 1;
    state.file = null;
    state.energies = [];
    state.cues = [];
    if (state.audioUrl) URL.revokeObjectURL(state.audioUrl);
    state.audioUrl = '';
    resetTransport();
    elements.fileName.textContent = file.name;
    elements.fileName.title = file.name;
    showError(DECODE_ERROR);
    return;
  }

  loadAudio(file);
}

elements.fileInput.addEventListener('change', () => {
  useSelectedFile(elements.fileInput.files?.[0]);
});

for (const eventName of ['dragenter', 'dragover']) {
  elements.dropZone.addEventListener(eventName, (event) => {
    event.preventDefault();
    elements.dropZone.classList.add('is-dragging');
  });
}

for (const eventName of ['dragleave', 'drop']) {
  elements.dropZone.addEventListener(eventName, (event) => {
    event.preventDefault();
    elements.dropZone.classList.remove('is-dragging');
  });
}

elements.dropZone.addEventListener('drop', (event) => {
  useSelectedFile(event.dataTransfer?.files[0]);
});

elements.dropZone.addEventListener('keydown', (event) => {
  if (event.target !== elements.dropZone) return;
  if (event.key === 'Enter' || event.key === ' ') elements.fileInput.click();
});

elements.playButton.addEventListener('click', async () => {
  if (elements.audio.paused) {
    await elements.audio.play();
  } else {
    elements.audio.pause();
  }
});

elements.audio.addEventListener('play', () => {
  elements.playButton.textContent = '暂停';
});

elements.audio.addEventListener('pause', () => {
  elements.playButton.textContent = '播放';
});

elements.audio.addEventListener('timeupdate', () => {
  const duration = elements.audio.duration;
  elements.currentTime.value = formatTime(elements.audio.currentTime);
  elements.progress.value = String(duration ? (elements.audio.currentTime / duration) * 1000 : 0);
  setMouth(mouthAtTime(state.cues, elements.audio.currentTime));
});

elements.audio.addEventListener('ended', () => setMouth('closed'));

elements.progress.addEventListener('input', () => {
  if (!elements.audio.duration) return;
  elements.audio.currentTime = (Number(elements.progress.value) / 1000) * elements.audio.duration;
});

elements.sensitivity.addEventListener('input', () => {
  state.sensitivity = Number(elements.sensitivity.value);
  elements.sensitivityValue.value = String(state.sensitivity);
  rebuildTimeline();
});

elements.minOpen.addEventListener('input', () => {
  const milliseconds = Number(elements.minOpen.value);
  state.minOpenMs = milliseconds;
  state.minOpenSeconds = milliseconds / 1000;
  elements.minOpenValue.value = `${milliseconds} ms`;
  rebuildTimeline();
});

elements.characterScale.addEventListener('input', () => {
  state.characterScale = Number(elements.characterScale.value);
  elements.characterScaleValue.value = `${state.characterScale}%`;
  elements.character.style.width = `${state.characterScale}%`;
});

const exportController = createExportController({
  button: elements.exportButton,
  controls: [
    elements.fileInput,
    elements.playButton,
    elements.progress,
    elements.sensitivity,
    elements.minOpen,
    elements.characterScale,
  ],
  getExportInput: () => ({
    file: state.file,
    cues: state.cues,
    characterScale: state.characterScale,
  }),
  showError,
});

elements.exportButton.addEventListener('click', () => {
  void exportController.exportVideo();
});

window.addEventListener('beforeunload', () => {
  if (state.audioUrl) URL.revokeObjectURL(state.audioUrl);
});

elements.sensitivity.value = String(state.sensitivity);
elements.sensitivityValue.value = String(state.sensitivity);
elements.minOpen.value = String(state.minOpenMs);
elements.minOpenValue.value = `${state.minOpenMs} ms`;
elements.characterScale.value = String(state.characterScale);
elements.characterScaleValue.value = `${state.characterScale}%`;
elements.character.style.width = `${state.characterScale}%`;
