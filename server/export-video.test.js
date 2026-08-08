import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { mkdtemp, readdir, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { basename, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';
import { afterEach, it } from 'node:test';

import { exportTransparentWebm } from './export-video.js';

const execFileAsync = promisify(execFile);
const projectRoot = dirname(dirname(fileURLToPath(import.meta.url)));
let temporaryRoot;

afterEach(async () => {
  if (temporaryRoot) await rm(temporaryRoot, { recursive: true, force: true });
  temporaryRoot = undefined;
});

it('exports a verified transparent VP9 WebM with Opus audio', { timeout: 120_000 }, async () => {
  temporaryRoot = await mkdtemp(join(tmpdir(), 'oc-lipsync-export-test-'));

  const result = await exportTransparentWebm({
    audioPath: join(projectRoot, 'test/fixtures/tone-silence.wav'),
    characterScale: 0.72,
    closedMouthPath: join(projectRoot, 'public/oc-mouth-closed.png'),
    openMouthPath: join(projectRoot, 'public/oc-mouth-open.png'),
    mouthCues: [
      { start: 0, end: 0.4, state: 'closed' },
      { start: 0.4, end: 0.8, state: 'open' },
      { start: 0.8, end: 1.2, state: 'closed' },
      { start: 1.2, end: 1.6, state: 'open' },
      { start: 1.6, end: 2, state: 'closed' },
    ],
    temporaryRoot,
  });

  assert.deepEqual(
    {
      width: result.width,
      height: result.height,
      fps: result.fps,
      hasAudio: result.hasAudio,
    },
    { width: 1080, height: 1920, fps: 30, hasAudio: true },
  );

  const { stdout } = await execFileAsync('/opt/homebrew/bin/ffprobe', [
    '-v', 'error',
    '-show_streams',
    '-of', 'json',
    result.path,
  ]);
  const streams = JSON.parse(stdout).streams;
  const video = streams.find(({ codec_type: type }) => type === 'video');
  const audio = streams.filter(({ codec_type: type }) => type === 'audio');

  assert.equal(video.codec_name, 'vp9');
  assert.equal(video.width, 1080);
  assert.equal(video.height, 1920);
  assert.equal(video.avg_frame_rate, '30/1');
  assert.equal(audio.length, 1);
  assert.equal(audio[0].codec_name, 'opus');
  assert.equal(result.pixelFormat, video.pix_fmt);
  assert.deepEqual(await readdir(dirname(result.path)), [basename(result.path)]);

  const { stdout: corner } = await execFileAsync('/opt/homebrew/bin/ffmpeg', [
    '-hide_banner', '-loglevel', 'error',
    '-c:v', 'libvpx-vp9',
    '-i', result.path,
    '-vf', 'format=rgba,crop=1:1:0:0',
    '-frames:v', '1',
    '-f', 'rawvideo',
    '-pix_fmt', 'rgba',
    'pipe:1',
  ], { encoding: 'buffer' });
  assert.equal(corner[3], 0, 'top-left corner must be transparent');
});
