import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';

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
