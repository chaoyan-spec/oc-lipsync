import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { mkdtemp, readFile, rm, symlink } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';
import { test } from 'node:test';

const execFileAsync = promisify(execFile);
const launcherPath = fileURLToPath(new URL('../启动OC口播机.command', import.meta.url));

test('opens the browser only after the OC readiness marker matches', async () => {
  const launcher = await readFile(new URL('../启动OC口播机.command', import.meta.url), 'utf8');

  assert.match(launcher, /\/__oc-lipsync\/ready/);
  assert.match(launcher, /OC_LIPSYNC_READY/);
  assert.match(launcher, /\[\[ "\$READY_RESPONSE" == "\$READY_MARKER" \]\]/);
  assert.ok(
    launcher.indexOf('[[ "$READY_RESPONSE" == "$READY_MARKER" ]]')
      < launcher.indexOf('/usr/bin/open "$LOCAL_URL"'),
    'the readiness marker must be checked before opening the browser',
  );
});

test('fails clearly and nonzero when node is unavailable', async () => {
  await assert.rejects(
    execFileAsync('/bin/zsh', [launcherPath], {
      env: { ...process.env, PATH: '' },
    }),
    (error) => {
      assert.equal(error.code, 1);
      assert.match(error.stdout, /无法启动：未找到 Node\.js.*Node\.js 18/);
      return true;
    },
  );
});

test('fails clearly and nonzero when npm is unavailable', async () => {
  const temporaryBin = await mkdtemp(join(tmpdir(), 'oc-lipsync-launcher-'));
  try {
    await symlink(process.execPath, join(temporaryBin, 'node'));
    await assert.rejects(
      execFileAsync('/bin/zsh', [launcherPath], {
        env: { ...process.env, PATH: temporaryBin },
      }),
      (error) => {
        assert.equal(error.code, 1);
        assert.match(error.stdout, /无法启动：未找到 npm.*Node\.js 18/);
        return true;
      },
    );
  } finally {
    await rm(temporaryBin, { recursive: true, force: true });
  }
});

test('documents the tested and minimum Node versions plus the final save click', async () => {
  const readme = await readFile(new URL('../README.md', import.meta.url), 'utf8');

  assert.match(readme, /Node\.js 18[^\n]*最低/);
  assert.match(readme, /Node\.js 24\.16\.0[^\n]*测试/);
  assert.match(readme, /导出完成，点击保存 MOV/);
});
