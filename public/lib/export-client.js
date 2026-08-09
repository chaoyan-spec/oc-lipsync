import { createExportRequestBody } from './request-envelope.js';

const EXPORT_LABEL = '导出透明 WebM';
const EXPORTING_LABEL = '正在导出…';
const EXPORT_ERROR = '导出失败，请重试';
const EXPORT_ERROR_WITH_RESULT = '本次导出失败，上次完成的 WebM 仍可保存';
const EXPORT_SUCCESS = '导出完成，点击保存 WebM';

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
  downloadLink,
  controls = [],
  getExportInput,
  fetchImpl = (...args) => fetch(...args),
  createObjectURL = (blob) => URL.createObjectURL(blob),
  revokeObjectURL = (url) => URL.revokeObjectURL(url),
  showError = () => {},
  setExporting = () => {},
  canExport = () => true,
}) {
  let exporting = false;
  let resultUrl = '';

  function clearDownload() {
    if (resultUrl) revokeObjectURL(resultUrl);
    resultUrl = '';
    downloadLink.hidden = true;
    downloadLink.removeAttribute('href');
    downloadLink.removeAttribute('download');
  }

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
      const nextResultUrl = createObjectURL(blob);
      downloadLink.href = nextResultUrl;
      downloadLink.download = `${downloadBase(file.name)}-oc-lipsync.webm`;
      downloadLink.textContent = EXPORT_SUCCESS;
      downloadLink.hidden = false;
      const previousResultUrl = resultUrl;
      resultUrl = nextResultUrl;
      if (previousResultUrl) revokeObjectURL(previousResultUrl);
    } catch {
      showError(resultUrl ? EXPORT_ERROR_WITH_RESULT : EXPORT_ERROR);
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

  return { dispose: clearDownload, exportVideo };
}
