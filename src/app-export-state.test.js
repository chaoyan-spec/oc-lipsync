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

test('sets the OC size control minimum to 40 percent', async () => {
  const html = await readFile(new URL('../public/index.html', import.meta.url), 'utf8');
  assert.match(html, /id="character-scale"[^>]*min="40"/);
});
