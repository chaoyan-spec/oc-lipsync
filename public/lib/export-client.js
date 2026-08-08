import { createExportRequestBody } from './request-envelope.js';

const EXPORT_LABEL = '导出透明 WebM';
const EXPORTING_LABEL = '正在导出…';
const EXPORT_ERROR = '导出失败，请重试';

function normalizeScale(value) {
  const numericValue = Number(value);
  if (!Number.isFinite(numericValue) || numericValue < 40 || numericValue > 100) {
    throw new RangeError('Character scale must be between 40 and 100 percent.');
  }
  return numericValue / 100;
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

export function createFileSelectionHandler({ isExporting, selectFile }) {
  return (file) => {
    if (!file || isExporting()) return false;
    selectFile(file);
    return true;
  };
}

export function updateDropZoneBusy(dropZone, isBusy) {
  dropZone.inert = isBusy;
  dropZone.setAttribute('aria-disabled', String(isBusy));
  dropZone.classList.toggle('is-disabled', isBusy);
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
  setExporting = () => {},
  canExport = () => true,
}) {
  let exporting = false;

  async function exportVideo() {
    if (exporting) return;
    exporting = true;
    const disabledStates = controls.map((control) => control.disabled);
    button.textContent = EXPORTING_LABEL;
    button.disabled = true;
    controls.forEach((control) => { control.disabled = true; });
    setExporting(true);
    showError('');

    try {
      const { file, cues, characterScale } = getExportInput();
      const body = createExportRequestBody({
        filename: file.name,
        cues,
        scale: normalizeScale(characterScale),
      }, file);
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
      setExporting(false);
      button.textContent = EXPORT_LABEL;
      button.disabled = !canExport();
      exporting = false;
    }
  }

  return { exportVideo };
}
