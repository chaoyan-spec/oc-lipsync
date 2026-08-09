import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';

test('blocks an unsupported drop while export state is busy', async () => {
  const { createFileSelectionHandler } = await import('../public/lib/export-client.js');
  assert.equal(typeof createFileSelectionHandler, 'function');
  const selected = [];
  const state = { isExporting: true, file: { name: 'loaded.wav' } };
  const handleSelection = createFileSelectionHandler({
    isExporting: () => state.isExporting,
    selectFile: (file) => {
      selected.push(file.name);
      state.file = file;
    },
  });

  assert.equal(handleSelection({ name: 'unsupported.aac' }), false);
  assert.deepEqual(selected, []);
  assert.equal(state.file.name, 'loaded.wav');
});

test('exposes the drop zone as inert and aria-disabled while exporting', async () => {
  const { updateDropZoneBusy } = await import('../public/lib/export-client.js');
  assert.equal(typeof updateDropZoneBusy, 'function');
  const attributes = new Map();
  const classes = new Set();
  const dropZone = {
    inert: false,
    setAttribute: (name, value) => attributes.set(name, value),
    classList: { toggle: (name, enabled) => enabled ? classes.add(name) : classes.delete(name) },
  };

  updateDropZoneBusy(dropZone, true);
  assert.equal(dropZone.inert, true);
  assert.equal(attributes.get('aria-disabled'), 'true');
  assert.equal(classes.has('is-disabled'), true);

  updateDropZoneBusy(dropZone, false);
  assert.equal(dropZone.inert, false);
  assert.equal(attributes.get('aria-disabled'), 'false');
  assert.equal(classes.has('is-disabled'), false);
});

test('removes canvas scale and labels the compact Jianying MOV export', async () => {
  const html = await readFile(new URL('../public/index.html', import.meta.url), 'utf8');

  assert.doesNotMatch(html, /id="character-scale"/);
  assert.match(html, /320 × 366/);
  assert.match(html, /导出剪映透明 MOV/);
});

test('provides a persistent visible save-link surface after export', async () => {
  const html = await readFile(new URL('../public/index.html', import.meta.url), 'utf8');

  assert.match(
    html,
    /<a[^>]*id="download-link"[^>]*hidden[^>]*>\s*导出完成，点击保存 MOV\s*<\/a>/,
  );
});

test('cleans the retained export URL before the page unloads', async () => {
  const app = await readFile(new URL('../public/app.js', import.meta.url), 'utf8');

  assert.match(app, /beforeunload[\s\S]*exportController\.dispose\(\)/);
});

test('explains when a loaded quiet clip cannot generate mouth cues', async () => {
  const app = await readFile(new URL('../public/app.js', import.meta.url), 'utf8');

  assert.match(app, /QUIET_AUDIO_ERROR\s*=\s*['"][^'"]*(声音太轻|低于)[^'"]*['"]/);
  assert.match(app, /!hasOpenMouthCue[\s\S]*showError\(QUIET_AUDIO_ERROR\)/);
});

test('gives the enabled export button an enabled cursor and color treatment', async () => {
  const css = await readFile(new URL('../public/styles.css', import.meta.url), 'utf8');

  assert.match(css, /\.export-button:not\(:disabled\)\s*\{[^}]*cursor:\s*pointer/);
  assert.match(css, /\.export-button:not\(:disabled\)\s*\{[^}]*background:/);
});
