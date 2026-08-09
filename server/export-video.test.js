import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { mkdtemp, readdir, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { basename, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';
import { afterEach, it } from 'node:test';

import {
  calculateAutoFitDimensions,
  detectImageBounds,
  exportCompactMov,
  mergeImageBounds,
} from './export-video.js';
import { resolveExecutable } from './resolve-executable.js';

const execFileAsync = promisify(execFile);
const projectRoot = dirname(dirname(fileURLToPath(import.meta.url)));
let temporaryRoot;
let transparentSourceDirectory;

async function decodeRgbaFrame(ffmpegPath, videoPath, time, width, height) {
  const { stdout } = await execFileAsync(ffmpegPath, [
    '-hide_banner', '-loglevel', 'error',
    '-ss', String(time),
    '-i', videoPath,
    '-frames:v', '1',
    '-f', 'rawvideo',
    '-pix_fmt', 'rgba',
    'pipe:1',
  ], { encoding: 'buffer', maxBuffer: width * height * 4 + 1024 });
  assert.equal(stdout.length, width * height * 4);
  return stdout;
}

function findAlphaBounds(rgba, width, height) {
  let left = width;
  let top = height;
  let right = -1;
  let bottom = -1;

  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      if (rgba[(y * width + x) * 4 + 3] === 0) continue;
      left = Math.min(left, x);
      top = Math.min(top, y);
      right = Math.max(right, x);
      bottom = Math.max(bottom, y);
    }
  }

  return { x: left, y: top, width: right - left + 1, height: bottom - top + 1 };
}

afterEach(async () => {
  if (temporaryRoot) await rm(temporaryRoot, { recursive: true, force: true });
  if (transparentSourceDirectory) {
    await rm(transparentSourceDirectory, { recursive: true, force: true });
  }
  temporaryRoot = undefined;
  transparentSourceDirectory = undefined;
});

it('merges both mouth bounds and preserves their shared canvas', () => {
  assert.deepEqual(
    mergeImageBounds(
      { x: 12, y: 20, width: 100, height: 180, canvasWidth: 500, canvasHeight: 500 },
      { x: 8, y: 24, width: 120, height: 170, canvasWidth: 500, canvasHeight: 500 },
    ),
    { x: 8, y: 20, width: 120, height: 180, canvasWidth: 500, canvasHeight: 500 },
  );
});

it('rejects mouth images with different source canvases', () => {
  assert.throws(() => mergeImageBounds(
    { x: 0, y: 0, width: 20, height: 20, canvasWidth: 100, canvasHeight: 100 },
    { x: 0, y: 0, width: 20, height: 20, canvasWidth: 120, canvasHeight: 100 },
  ), /same canvas dimensions/);
});

it('fits a portrait OC inside 304px and adds 8px padding', () => {
  assert.deepEqual(
    calculateAutoFitDimensions({ width: 622, height: 711 }),
    { contentWidth: 266, contentHeight: 304, width: 282, height: 320, padding: 8 },
  );
});

it('does not enlarge a smaller landscape OC', () => {
  assert.deepEqual(
    calculateAutoFitDimensions({ width: 200, height: 101 }),
    { contentWidth: 200, contentHeight: 100, width: 216, height: 116, padding: 8 },
  );
});

it('rounds odd small OC dimensions down instead of enlarging them', () => {
  assert.deepEqual(
    calculateAutoFitDimensions({ width: 201, height: 101 }),
    { contentWidth: 200, contentHeight: 100, width: 216, height: 116, padding: 8 },
  );
});

it('rejects one-pixel-wide bounds instead of enlarging them', () => {
  assert.throws(
    () => calculateAutoFitDimensions({ width: 1, height: 20 }),
    /at least 2 pixels/,
  );
});

it('rejects one-pixel-high bounds instead of enlarging them', () => {
  assert.throws(
    () => calculateAutoFitDimensions({ width: 20, height: 1 }),
    /at least 2 pixels/,
  );
});

it('keeps auto-fit sizing constants private', () => {
  assert.deepEqual(
    calculateAutoFitDimensions(
      { width: 622, height: 711 },
      { maxContentSide: 100, padding: 0 },
    ),
    { contentWidth: 266, contentHeight: 304, width: 282, height: 320, padding: 8 },
  );
});

it('detects the current OC alpha bounds instead of using fixed coordinates', async () => {
  assert.deepEqual(
    await detectImageBounds(join(projectRoot, 'public/oc-mouth-closed.png')),
    { x: 213, y: 188, width: 622, height: 711, canvasWidth: 1000, canvasHeight: 1000 },
  );
});

it('exports an auto-fit transparent Animation MOV with AAC audio', { timeout: 120_000 }, async () => {
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
    { width: 282, height: 320, fps: 15, hasAudio: true },
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
  assert.equal(video.width, 282);
  assert.equal(video.height, 320);
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

it('exports numbered sprite frames on the same transparent MOV timeline', { timeout: 120_000 }, async () => {
  temporaryRoot = await mkdtemp(join(tmpdir(), 'oc-lipsync-sprite-export-test-'));
  const mouthFramePaths = Array.from({ length: 8 }, (_, frame) => (
    join(projectRoot, `public/papalu-talking/frames/${frame}.png`)
  ));
  const ffmpegPath = await resolveExecutable('ffmpeg');

  const result = await exportCompactMov({
    audioPath: join(projectRoot, 'test/fixtures/tone-silence.wav'),
    mouthFramePaths,
    mouthCues: [
      { start: 0, end: 0.4, frame: 0 },
      { start: 0.4, end: 0.8, frame: 2 },
      { start: 0.8, end: 1.2, frame: 3 },
      { start: 1.2, end: 1.6, frame: 5 },
      { start: 1.6, end: 2, frame: 0 },
    ],
    temporaryRoot,
  });

  assert.deepEqual(
    { width: result.width, height: result.height, fps: result.fps },
    { width: 182, height: 206, fps: 15 },
  );

  const decodedFrames = await Promise.all([0.2, 0.6, 1, 1.4].map((time) => (
    decodeRgbaFrame(ffmpegPath, result.path, time, result.width, result.height)
  )));
  for (let index = 1; index < decodedFrames.length; index += 1) {
    assert.equal(decodedFrames[index].equals(decodedFrames[index - 1]), false);
  }
  assert.equal(decodedFrames[0][3], 0, 'top-left corner must stay transparent');
});

it('encodes different mouth bounds on one stable union-derived canvas', { timeout: 120_000 }, async () => {
  temporaryRoot = await mkdtemp(join(tmpdir(), 'oc-lipsync-union-export-test-'));
  transparentSourceDirectory = await mkdtemp(join(tmpdir(), 'oc-lipsync-union-source-test-'));
  const ffmpegPath = await resolveExecutable('ffmpeg');
  const closedMouthPath = join(transparentSourceDirectory, 'closed.png');
  const openMouthPath = join(transparentSourceDirectory, 'open.png');

  await Promise.all([
    execFileAsync(ffmpegPath, [
      '-hide_banner', '-loglevel', 'error', '-y',
      '-f', 'lavfi', '-i',
      'color=black@0.0:s=120x100,format=rgba,drawbox=x=20:y=20:w=40:h=40:color=red@1:t=fill:replace=1,drawbox=x=50:y=40:w=4:h=4:color=yellow@1:t=fill:replace=1',
      '-frames:v', '1',
      closedMouthPath,
    ]),
    execFileAsync(ffmpegPath, [
      '-hide_banner', '-loglevel', 'error', '-y',
      '-f', 'lavfi', '-i',
      'color=black@0.0:s=120x100,format=rgba,drawbox=x=30:y=10:w=50:h=60:color=green@1:t=fill:replace=1,drawbox=x=50:y=40:w=4:h=4:color=yellow@1:t=fill:replace=1',
      '-frames:v', '1',
      openMouthPath,
    ]),
  ]);

  assert.deepEqual(await detectImageBounds(closedMouthPath), {
    x: 20, y: 20, width: 40, height: 40, canvasWidth: 120, canvasHeight: 100,
  });
  assert.deepEqual(await detectImageBounds(openMouthPath), {
    x: 30, y: 10, width: 50, height: 60, canvasWidth: 120, canvasHeight: 100,
  });

  const result = await exportCompactMov({
    audioPath: join(projectRoot, 'test/fixtures/tone-silence.wav'),
    closedMouthPath,
    openMouthPath,
    mouthCues: [
      { start: 0, end: 0.5, state: 'closed' },
      { start: 0.5, end: 1, state: 'open' },
      { start: 1, end: 1.5, state: 'closed' },
      { start: 1.5, end: 2, state: 'open' },
    ],
    temporaryRoot,
  });

  assert.deepEqual(
    { width: result.width, height: result.height },
    { width: 76, height: 76 },
  );

  const [closedFrame, openFrame] = await Promise.all([
    decodeRgbaFrame(ffmpegPath, result.path, 0.2, result.width, result.height),
    decodeRgbaFrame(ffmpegPath, result.path, 0.7, result.width, result.height),
  ]);
  assert.deepEqual(findAlphaBounds(closedFrame, result.width, result.height), {
    x: 8, y: 18, width: 40, height: 40,
  });
  assert.deepEqual(findAlphaBounds(openFrame, result.width, result.height), {
    x: 18, y: 8, width: 50, height: 60,
  });

  const sharedMarkerOffset = (38 * result.width + 38) * 4;
  assert.ok(closedFrame[sharedMarkerOffset] > 200 && closedFrame[sharedMarkerOffset + 1] > 200);
  assert.ok(openFrame[sharedMarkerOffset] > 200 && openFrame[sharedMarkerOffset + 1] > 200);
});

it('rejects a fully transparent mouth image and cleans up the export directory', { timeout: 120_000 }, async () => {
  temporaryRoot = await mkdtemp(join(tmpdir(), 'oc-lipsync-export-test-'));
  transparentSourceDirectory = await mkdtemp(join(tmpdir(), 'oc-lipsync-transparent-test-'));
  const ffmpegPath = await resolveExecutable('ffmpeg');
  const transparentPath = join(transparentSourceDirectory, 'transparent.png');
  const audioPath = join(projectRoot, 'test/fixtures/tone-silence.wav');
  const openMouthPath = join(projectRoot, 'public/oc-mouth-open.png');
  const mouthCues = [
    { start: 0, end: 0.4, state: 'closed' },
    { start: 0.4, end: 0.8, state: 'open' },
  ];

  await execFileAsync(ffmpegPath, [
    '-hide_banner', '-loglevel', 'error', '-y',
    '-f', 'lavfi', '-i', 'color=black@0.0:s=100x100,format=rgba',
    '-frames:v', '1',
    transparentPath,
  ]);

  await assert.rejects(
    exportCompactMov({
      audioPath,
      closedMouthPath: transparentPath,
      openMouthPath,
      mouthCues,
      temporaryRoot,
    }),
    { name: 'ExportError' },
  );
  assert.deepEqual(await readdir(temporaryRoot), []);
});
