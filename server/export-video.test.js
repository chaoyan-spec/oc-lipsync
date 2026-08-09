import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { mkdtemp, readdir, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { basename, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';
import { afterEach, it } from 'node:test';

import { exportCompactMov } from './export-video.js';
import { resolveExecutable } from './resolve-executable.js';

const execFileAsync = promisify(execFile);
const projectRoot = dirname(dirname(fileURLToPath(import.meta.url)));
let temporaryRoot;

afterEach(async () => {
  if (temporaryRoot) await rm(temporaryRoot, { recursive: true, force: true });
  temporaryRoot = undefined;
});

it('exports a verified transparent 320x366 Animation MOV with AAC audio', { timeout: 120_000 }, async () => {
  temporaryRoot = await mkdtemp(join(tmpdir(), 'oc-lipsync-export-test-'));
  const [ffmpegPath, ffprobePath] = await Promise.all([
    resolveExecutable('ffmpeg'),
    resolveExecutable('ffprobe'),
  ]);

  const result = await exportCompactMov({
    audioPath: join(projectRoot, 'test/fixtures/tone-silence.wav'),
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
    { width: 320, height: 366, fps: 15, hasAudio: true },
  );

  const { stdout } = await execFileAsync(ffprobePath, [
    '-v', 'error',
    '-show_streams',
    '-of', 'json',
    result.path,
  ]);
  const streams = JSON.parse(stdout).streams;
  const video = streams.find(({ codec_type: type }) => type === 'video');
  const audio = streams.filter(({ codec_type: type }) => type === 'audio');

  assert.equal(video.codec_name, 'qtrle');
  assert.equal(video.width, 320);
  assert.equal(video.height, 366);
  assert.equal(video.avg_frame_rate, '15/1');
  assert.equal(video.pix_fmt, 'argb');
  assert.equal(audio.length, 1);
  assert.equal(audio[0].codec_name, 'aac');
  assert.equal(result.pixelFormat, video.pix_fmt);
  assert.deepEqual(await readdir(dirname(result.path)), [basename(result.path)]);

  const { stdout: corner } = await execFileAsync(ffmpegPath, [
    '-hide_banner', '-loglevel', 'error',
    '-i', result.path,
    '-vf', 'format=rgba,crop=1:1:0:0',
    '-frames:v', '1',
    '-f', 'rawvideo',
    '-pix_fmt', 'rgba',
    'pipe:1',
  ], { encoding: 'buffer' });
  assert.equal(corner[3], 0, 'top-left corner must be transparent');
});
