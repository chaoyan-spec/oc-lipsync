import assert from 'node:assert/strict';
import { chmod, mkdir, mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { delimiter, join } from 'node:path';
import { afterEach, test } from 'node:test';

import { resolveExecutable } from './resolve-executable.js';

const temporaryRoots = [];

afterEach(async () => {
  await Promise.all(temporaryRoots.splice(0).map((root) => (
    rm(root, { recursive: true, force: true })
  )));
});

async function makeExecutable(directory, name) {
  const executablePath = join(directory, name);
  await writeFile(executablePath, '#!/bin/sh\n', 'utf8');
  await chmod(executablePath, 0o755);
  return executablePath;
}

async function makeRoot() {
  const root = await mkdtemp(join(tmpdir(), 'oc-lipsync-tools-'));
  temporaryRoots.push(root);
  return root;
}

test('prefers an executable in the Homebrew bin directory', async () => {
  const root = await makeRoot();
  const homebrewBin = join(root, 'homebrew');
  const pathBin = join(root, 'path');
  await Promise.all([mkdir(homebrewBin), mkdir(pathBin)]);
  const homebrewTool = await makeExecutable(homebrewBin, 'ffmpeg');
  await makeExecutable(pathBin, 'ffmpeg');

  assert.equal(await resolveExecutable('ffmpeg', {
    homebrewBin,
    pathValue: pathBin,
  }), homebrewTool);
});

test('falls back to the first executable on PATH', async () => {
  const root = await makeRoot();
  const missingHomebrewBin = join(root, 'missing-homebrew');
  const firstPathBin = join(root, 'first');
  const secondPathBin = join(root, 'second');
  await mkdir(firstPathBin);
  await mkdir(secondPathBin);
  const expected = await makeExecutable(secondPathBin, 'ffprobe');

  assert.equal(await resolveExecutable('ffprobe', {
    homebrewBin: missingHomebrewBin,
    pathValue: `${firstPathBin}${delimiter}${secondPathBin}`,
  }), expected);
});

test('reports a clear error when the executable cannot be found', async () => {
  const root = await makeRoot();

  await assert.rejects(
    resolveExecutable('ffmpeg', {
      homebrewBin: join(root, 'homebrew'),
      pathValue: join(root, 'path'),
    }),
    /找不到 ffmpeg.*\/opt\/homebrew\/bin.*PATH/,
  );
});
