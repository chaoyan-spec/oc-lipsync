const SUPPORTED_AUDIO_EXTENSION = /\.(mp3|wav|m4a)$/i;

export function isSupportedAudio(fileName) {
  return SUPPORTED_AUDIO_EXTENSION.test(fileName);
}

export function createInitialUiState() {
  return {
    file: null,
    sensitivity: 35,
    minOpenMs: 120,
    characterScale: 72,
    canPlay: false,
    canExport: false,
    error: '',
  };
}
