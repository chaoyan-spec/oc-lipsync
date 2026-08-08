import { encodeExportRequest } from './request-envelope.js';

const EXPORT_LABEL = '导出透明 WebM';
const EXPORTING_LABEL = '正在导出…';
const EXPORT_ERROR = '导出失败，请重试';

function normalizeScale(value) {
  const numericValue = Number(value);
  const normalized = numericValue > 1 ? numericValue / 100 : numericValue;
  return Math.min(1, Math.max(0.4, normalized));
}

function downloadBase(fileName) {
  const leafName = fileName.split(/[\\/]/).at(-1);
  return leafName.replace(/\.[^.]+$/, '') || 'audio';
}

function browserDownload(url, filename) {
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = filename;
  anchor.hidden = true;
  document.body.append(anchor);
  anchor.click();
  anchor.remove();
}

export function createExportController({
  button,
  controls = [],
  getExportInput,
  fetchImpl = (...args) => fetch(...args),
  createObjectURL = (blob) => URL.createObjectURL(blob),
  revokeObjectURL = (url) => URL.revokeObjectURL(url),
  download = browserDownload,
  showError = () => {},
}) {
  let exporting = false;

  async function exportVideo() {
    if (exporting) return;
    exporting = true;
    const buttonWasDisabled = button.disabled;
    const disabledStates = controls.map((control) => control.disabled);
    button.textContent = EXPORTING_LABEL;
    button.disabled = true;
    controls.forEach((control) => { control.disabled = true; });
    showError('');

    try {
      const { file, cues, characterScale } = getExportInput();
      const audioBytes = new Uint8Array(await file.arrayBuffer());
      const body = encodeExportRequest({
        filename: file.name,
        cues,
        scale: normalizeScale(characterScale),
      }, audioBytes);
      const response = await fetchImpl('/api/export', {
        method: 'POST',
        headers: { 'Content-Type': 'application/octet-stream' },
        body,
      });
      if (!response.ok) throw new Error(`Export failed with status ${response.status}.`);

      const blob = await response.blob();
      const url = createObjectURL(blob);
      try {
        download(url, `${downloadBase(file.name)}-oc-lipsync.webm`);
      } finally {
        revokeObjectURL(url);
      }
    } catch {
      showError(EXPORT_ERROR);
    } finally {
      controls.forEach((control, index) => {
        control.disabled = disabledStates[index];
      });
      button.textContent = EXPORT_LABEL;
      button.disabled = buttonWasDisabled;
      exporting = false;
    }
  }

  return { exportVideo };
}
