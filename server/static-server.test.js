import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { createServer } from 'node:http';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';
import { test } from 'node:test';

const execFileAsync = promisify(execFile);
const projectRoot = dirname(dirname(fileURLToPath(import.meta.url)));

test('prints EADDRINUSE and exits nonzero when the port is occupied', async () => {
  const blocker = createServer((_request, response) => response.end('unrelated service'));
  await new Promise((resolve, reject) => {
    blocker.once('error', reject);
    blocker.listen(0, '127.0.0.1', resolve);
  });

  try {
    const { port } = blocker.address();
    await assert.rejects(
      execFileAsync(process.execPath, ['server/static-server.js'], {
        cwd: projectRoot,
        env: { ...process.env, PORT: String(port) },
      }),
      (error) => {
        assert.notEqual(error.code, 0);
        assert.match(error.stderr, /EADDRINUSE/);
        return true;
      },
    );
  } finally {
    await new Promise((resolve, reject) => {
      blocker.close((error) => error ? reject(error) : resolve());
    });
  }
});
