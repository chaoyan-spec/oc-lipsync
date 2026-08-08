import { execFile } from 'node:child_process';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);
const FFMPEG_PATH = '/opt/homebrew/bin/ffmpeg';
const FFPROBE_PATH = '/opt/homebrew/bin/ffprobe';

export class ExportError extends Error {
  constructor(cause) {
    super('Could not export transparent WebM.', { cause });
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
    video?.codec_name !== 'vp9'
    || video.width !== 1080
    || video.height !== 1920
    || video.avg_frame_rate !== '30/1'
    || audio.length !== 1
    || audio[0].codec_name !== 'opus'
  ) {
    throw new Error('Encoded stream properties did not match the export contract.');
  }

  return video;
}

async function verifyTransparentCorner(path) {
  const { stdout } = await execFileAsync(FFMPEG_PATH, [
    '-hide_banner', '-loglevel', 'error',
    '-c:v', 'libvpx-vp9',
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
 * @param {number} input.characterScale
 * @param {string} input.closedMouthPath
 * @param {string} input.openMouthPath
 * @param {string} [input.temporaryRoot]
 */
export async function exportTransparentWebm({
  audioPath,
  mouthCues,
  characterScale,
  closedMouthPath,
  openMouthPath,
  temporaryRoot = tmpdir(),
}) {
  let exportDirectory;

  try {
    exportDirectory = await mkdtemp(join(temporaryRoot, 'oc-lipsync-export-'));
    const manifestPath = join(exportDirectory, 'mouth-cues.ffconcat');
    const outputPath = join(exportDirectory, 'transparent.webm');
    const duration = mouthCues.at(-1).end - mouthCues[0].start;
    const characterSize = Math.round((characterScale * 1000) / 2) * 2;

    await writeFile(
      manifestPath,
      createManifest(mouthCues, closedMouthPath, openMouthPath),
      'utf8',
    );

    await execFileAsync(FFMPEG_PATH, [
      '-hide_banner', '-loglevel', 'error', '-y',
      '-f', 'concat', '-safe', '0', '-i', manifestPath,
      '-i', audioPath,
      '-filter_complex', [
        `[0:v]fps=30,scale=${characterSize}:${characterSize}:flags=lanczos,format=rgba[character]`,
        'color=c=black@0.0:s=1080x1920:r=30,format=rgba[canvas]',
        '[canvas][character]overlay=x=(W-w)/2:y=H-h:format=auto:shortest=1,format=yuva420p[video]',
      ].join(';'),
      '-map', '[video]',
      '-map', '1:a:0',
      '-t', duration.toFixed(6),
      '-r', '30',
      '-c:v', 'libvpx-vp9',
      '-pix_fmt', 'yuva420p',
      '-auto-alt-ref', '0',
      '-c:a', 'libopus',
      outputPath,
    ], { maxBuffer: 10 * 1024 * 1024 });

    const video = await inspectExport(outputPath);
    await verifyTransparentCorner(outputPath);
    await rm(manifestPath);

    return {
      path: outputPath,
      width: 1080,
      height: 1920,
      fps: 30,
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
