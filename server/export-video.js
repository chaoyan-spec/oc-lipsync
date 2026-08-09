import { execFile } from 'node:child_process';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { promisify } from 'node:util';

import { resolveExecutable } from './resolve-executable.js';

const execFileAsync = promisify(execFile);
const FFMPEG_PATH = await resolveExecutable('ffmpeg');
const FFPROBE_PATH = await resolveExecutable('ffprobe');

export class ExportError extends Error {
  constructor(cause) {
    super('Could not export transparent MOV.', { cause });
    this.name = 'ExportError';
  }
}

function quoteConcatPath(path) {
  return `'${path.replaceAll("'", "'\\''")}'`;
}

function createManifest(mouthCues, closedMouthPath, openMouthPath) {
  const entries = mouthCues.map(({ start, end, state }) => ({
    duration: end - start,
    path: state === 'open' ? openMouthPath : closedMouthPath,
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

async function inspectExport(path) {
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
    || video.width !== 320
    || video.height !== 366
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
 * @param {{start: number, end: number, state: 'open' | 'closed'}[]} input.mouthCues
 * @param {string} input.closedMouthPath
 * @param {string} input.openMouthPath
 * @param {string} [input.temporaryRoot]
 */
export async function exportCompactMov({
  audioPath,
  mouthCues,
  closedMouthPath,
  openMouthPath,
  temporaryRoot = tmpdir(),
}) {
  let exportDirectory;

  try {
    exportDirectory = await mkdtemp(join(temporaryRoot, 'oc-lipsync-export-'));
    const manifestPath = join(exportDirectory, 'mouth-cues.ffconcat');
    const outputPath = join(exportDirectory, 'transparent.mov');
    const duration = mouthCues.at(-1).end - mouthCues[0].start;

    await writeFile(
      manifestPath,
      createManifest(mouthCues, closedMouthPath, openMouthPath),
      'utf8',
    );

    await execFileAsync(FFMPEG_PATH, [
      '-hide_banner', '-loglevel', 'error', '-y',
      '-f', 'concat', '-safe', '0', '-i', manifestPath,
      '-i', audioPath,
      '-filter_complex',
      '[0:v]crop=622:711:213:188,scale=320:366:flags=lanczos,fps=15,format=argb[video]',
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

    const video = await inspectExport(outputPath);
    await verifyTransparentCorner(outputPath);
    await rm(manifestPath);

    return {
      path: outputPath,
      width: 320,
      height: 366,
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
