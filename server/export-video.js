import { execFile } from 'node:child_process';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { promisify } from 'node:util';

import { resolveExecutable } from './resolve-executable.js';

const execFileAsync = promisify(execFile);
const FFMPEG_PATH = await resolveExecutable('ffmpeg');
const FFPROBE_PATH = await resolveExecutable('ffprobe');
const MAX_CONTENT_SIDE = 304;
const OUTPUT_PADDING = 8;

function floorPositiveEven(value) {
  return Math.max(2, Math.floor(value / 2) * 2);
}

function roundPositiveEven(value) {
  return Math.max(2, Math.round(value / 2) * 2);
}

export function mergeImageBounds(first, second) {
  if (
    first.canvasWidth !== second.canvasWidth
    || first.canvasHeight !== second.canvasHeight
  ) throw new Error('Mouth images must use the same canvas dimensions.');

  const x = Math.min(first.x, second.x);
  const y = Math.min(first.y, second.y);
  const right = Math.max(first.x + first.width, second.x + second.width);
  const bottom = Math.max(first.y + first.height, second.y + second.height);
  return {
    x,
    y,
    width: right - x,
    height: bottom - y,
    canvasWidth: first.canvasWidth,
    canvasHeight: first.canvasHeight,
  };
}

export function calculateAutoFitDimensions(bounds) {
  if (bounds.width < 2 || bounds.height < 2) {
    throw new Error('Mouth image bounds must be at least 2 pixels wide and high.');
  }

  const scale = Math.min(1, MAX_CONTENT_SIDE / Math.max(bounds.width, bounds.height));
  const roundToEven = scale < 1 ? roundPositiveEven : floorPositiveEven;
  const contentWidth = roundToEven(bounds.width * scale);
  const contentHeight = roundToEven(bounds.height * scale);
  return {
    contentWidth,
    contentHeight,
    width: contentWidth + OUTPUT_PADDING * 2,
    height: contentHeight + OUTPUT_PADDING * 2,
    padding: OUTPUT_PADDING,
  };
}

export async function detectImageBounds(imagePath) {
  const [{ stdout }, { stderr }] = await Promise.all([
    execFileAsync(FFPROBE_PATH, [
      '-v', 'error',
      '-select_streams', 'v:0',
      '-show_entries', 'stream=width,height',
      '-of', 'json',
      imagePath,
    ]),
    execFileAsync(FFMPEG_PATH, [
      '-hide_banner', '-loglevel', 'info',
      '-i', imagePath,
      '-vf', 'alphaextract,bbox=min_val=1',
      '-frames:v', '1',
      '-f', 'null',
      '-',
    ]),
  ]);
  const video = JSON.parse(stdout).streams?.[0];
  const match = stderr.match(/x1:(\d+) x2:(\d+) y1:(\d+) y2:(\d+) w:(\d+) h:(\d+)/);
  if (!video || !match) throw new Error('Mouth image has no visible pixels.');
  return {
    x: Number(match[1]),
    y: Number(match[3]),
    width: Number(match[5]),
    height: Number(match[6]),
    canvasWidth: video.width,
    canvasHeight: video.height,
  };
}

export class ExportError extends Error {
  constructor(cause) {
    super('Could not export transparent MOV.', { cause });
    this.name = 'ExportError';
  }
}

function quoteConcatPath(path) {
  return `'${path.replaceAll("'", "'\\''")}'`;
}

function createManifest(mouthCues, closedMouthPath, openMouthPath, mouthFramePaths) {
  const entries = mouthCues.map(({ start, end, state, frame }) => ({
    duration: end - start,
    path: Number.isInteger(frame)
      ? mouthFramePaths[frame]
      : state === 'open' ? openMouthPath : closedMouthPath,
  }));
  const finalEntry = entries.at(-1);

  return [
    'ffconcat version 1.0',
    ...entries.flatMap(({ duration, path }) => [
      `file ${quoteConcatPath(path)}`,
      `duration ${duration.toFixed(6)}`,
    ]),
    `file ${quoteConcatPath(finalEntry.path)}`,
    '',
  ].join('\n');
}

async function inspectExport(path, { width, height }) {
  const { stdout } = await execFileAsync(FFPROBE_PATH, [
    '-v', 'error',
    '-show_entries', 'stream=codec_type,codec_name,width,height,avg_frame_rate,pix_fmt',
    '-of', 'json',
    path,
  ]);
  const streams = JSON.parse(stdout).streams;
  const video = streams.find(({ codec_type: type }) => type === 'video');
  const audio = streams.filter(({ codec_type: type }) => type === 'audio');

  if (
    video?.codec_name !== 'qtrle'
    || video.width !== width
    || video.height !== height
    || video.avg_frame_rate !== '15/1'
    || video.pix_fmt !== 'argb'
    || audio.length !== 1
    || audio[0].codec_name !== 'aac'
  ) {
    throw new Error('Encoded stream properties did not match the export contract.');
  }

  return video;
}

async function verifyTransparentCorner(path) {
  const { stdout } = await execFileAsync(FFMPEG_PATH, [
    '-hide_banner', '-loglevel', 'error',
    '-i', path,
    '-vf', 'format=rgba,crop=1:1:0:0',
    '-frames:v', '1',
    '-f', 'rawvideo',
    '-pix_fmt', 'rgba',
    'pipe:1',
  ], { encoding: 'buffer', maxBuffer: 1024 * 1024 });

  if (stdout.length !== 4 || stdout[3] !== 0) {
    throw new Error('Encoded corner pixel was not transparent.');
  }
}

/**
 * @param {object} input
 * @param {string} input.audioPath
 * @param {{start: number, end: number, state?: 'open' | 'closed', frame?: number}[]} input.mouthCues
 * @param {string} [input.closedMouthPath]
 * @param {string} [input.openMouthPath]
 * @param {string[]} [input.mouthFramePaths]
 * @param {string} [input.temporaryRoot]
 */
export async function exportCompactMov({
  audioPath,
  mouthCues,
  closedMouthPath,
  mouthFramePaths,
  openMouthPath,
  temporaryRoot = tmpdir(),
}) {
  let exportDirectory;

  try {
    const imagePaths = mouthFramePaths ?? [closedMouthPath, openMouthPath];
    const imageBounds = await Promise.all(imagePaths.map(detectImageBounds));
    const bounds = imageBounds.slice(1).reduce(mergeImageBounds, imageBounds[0]);
    const dimensions = calculateAutoFitDimensions(bounds);
    const filter = [
      `crop=${bounds.width}:${bounds.height}:${bounds.x}:${bounds.y}`,
      `scale=${dimensions.contentWidth}:${dimensions.contentHeight}:flags=lanczos`,
      `pad=${dimensions.width}:${dimensions.height}:${dimensions.padding}:${dimensions.padding}:color=black@0`,
      'fps=15',
      'format=argb',
    ].join(',');

    exportDirectory = await mkdtemp(join(temporaryRoot, 'oc-lipsync-export-'));
    const manifestPath = join(exportDirectory, 'mouth-cues.ffconcat');
    const outputPath = join(exportDirectory, 'transparent.mov');
    const duration = mouthCues.at(-1).end - mouthCues[0].start;

    await writeFile(
      manifestPath,
      createManifest(mouthCues, closedMouthPath, openMouthPath, mouthFramePaths),
      'utf8',
    );

    await execFileAsync(FFMPEG_PATH, [
      '-hide_banner', '-loglevel', 'error', '-y',
      '-f', 'concat', '-safe', '0', '-i', manifestPath,
      '-i', audioPath,
      '-filter_complex',
      `[0:v]${filter}[video]`,
      '-map', '[video]',
      '-map', '1:a:0',
      '-t', duration.toFixed(6),
      '-r', '15',
      '-c:v', 'qtrle',
      '-pix_fmt', 'argb',
      '-c:a', 'aac',
      '-b:a', '96k',
      '-movflags', '+faststart',
      outputPath,
    ], { maxBuffer: 10 * 1024 * 1024 });

    const video = await inspectExport(outputPath, dimensions);
    await verifyTransparentCorner(outputPath);
    await rm(manifestPath);

    return {
      path: outputPath,
      width: dimensions.width,
      height: dimensions.height,
      fps: 15,
      hasAudio: true,
      pixelFormat: video.pix_fmt,
    };
  } catch (error) {
    if (exportDirectory) {
      await rm(exportDirectory, { recursive: true, force: true }).catch(() => {});
    }
    throw new ExportError(error);
  }
}
