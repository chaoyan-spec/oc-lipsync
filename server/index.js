import { createReadStream } from 'node:fs';
import { mkdtemp, realpath, rm, stat, writeFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { pipeline } from 'node:stream/promises';
import { fileURLToPath } from 'node:url';

import { decodeExportRequest, ExportRequestError } from '../public/lib/request-envelope.js';
import { isSupportedAudio } from '../public/lib/ui-state.js';
import { exportTransparentWebm } from './export-video.js';

const MAX_BODY_BYTES = 500 * 1024 * 1024;
const PROJECT_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const DEFAULT_PUBLIC_ROOT = await realpath(path.join(PROJECT_ROOT, 'public'));
const MISSING_AUDIO_ERROR = '请先选择口播音频';
const UNSUPPORTED_AUDIO_ERROR = '暂不支持该音频，请换用 MP3、WAV 或 M4A';
const INVALID_SETTINGS_ERROR = '导出参数无效';

const contentTypes = new Map([
  ['.css', 'text/css; charset=utf-8'],
  ['.html', 'text/html; charset=utf-8'],
  ['.js', 'text/javascript; charset=utf-8'],
  ['.png', 'image/png'],
  ['.svg', 'image/svg+xml'],
]);

function respondText(response, statusCode, message) {
  response.writeHead(statusCode, { 'Content-Type': 'text/plain; charset=utf-8' });
  response.end(message);
}

function respondJson(response, statusCode, body) {
  response.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'X-Content-Type-Options': 'nosniff',
  });
  response.end(JSON.stringify(body));
}

function isInside(root, filePath) {
  return filePath === root || filePath.startsWith(`${root}${path.sep}`);
}

async function resolveRequestPath(requestUrl, publicRoot) {
  const rawPath = (requestUrl || '/').split(/[?#]/, 1)[0];
  const decodedPath = decodeURIComponent(rawPath);
  const segments = decodedPath.split(/[\\/]+/);

  if (decodedPath.includes('\0') || segments.includes('..')) throw new Error('forbidden');

  let requestedPath = path.resolve(publicRoot, `.${decodedPath}`);
  if (!isInside(publicRoot, requestedPath)) throw new Error('forbidden');

  const metadata = await stat(requestedPath);
  if (metadata.isDirectory()) requestedPath = path.join(requestedPath, 'index.html');

  const canonicalPath = await realpath(requestedPath);
  if (!isInside(publicRoot, canonicalPath)) throw new Error('forbidden');
  return canonicalPath;
}

async function serveStatic(request, response, publicRoot) {
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    response.setHeader('Allow', 'GET, HEAD');
    respondText(response, 405, 'Method Not Allowed');
    return;
  }

  try {
    const filePath = await resolveRequestPath(request.url, publicRoot);
    const contentType = contentTypes.get(path.extname(filePath).toLowerCase())
      || 'application/octet-stream';
    response.writeHead(200, {
      'Content-Type': contentType,
      'X-Content-Type-Options': 'nosniff',
    });

    if (request.method === 'HEAD') {
      response.end();
      return;
    }
    await pipeline(createReadStream(filePath), response);
  } catch (error) {
    if (response.headersSent) {
      response.destroy();
    } else if (error instanceof URIError) {
      respondText(response, 400, 'Bad Request');
    } else if (error instanceof Error && error.message === 'forbidden') {
      respondText(response, 403, 'Forbidden');
    } else {
      respondText(response, 404, 'Not Found');
    }
  }
}

async function readRequestBody(request, limit) {
  const contentLength = Number(request.headers['content-length']);
  if (Number.isFinite(contentLength) && contentLength > limit) {
    const error = new Error('request too large');
    error.code = 'BODY_TOO_LARGE';
    throw error;
  }

  const chunks = [];
  let length = 0;
  for await (const chunk of request) {
    length += chunk.length;
    if (length > limit) {
      const error = new Error('request too large');
      error.code = 'BODY_TOO_LARGE';
      throw error;
    }
    chunks.push(chunk);
  }
  return Buffer.concat(chunks, length);
}

function hasValidScale(scale) {
  return typeof scale === 'number' && Number.isFinite(scale) && scale >= 0.4 && scale <= 1;
}

function hasValidCues(cues) {
  if (!Array.isArray(cues) || cues.length === 0) return false;

  return cues.every((cue, index) => {
    if (
      !cue
      || typeof cue !== 'object'
      || !Number.isFinite(cue.start)
      || !Number.isFinite(cue.end)
      || cue.start < 0
      || cue.end <= cue.start
      || (cue.state !== 'open' && cue.state !== 'closed')
    ) return false;

    if (index === 0) return Math.abs(cue.start) <= 1e-6;
    return Math.abs(cues[index - 1].end - cue.start) <= 1e-6;
  });
}

function safeDownloadBase(filename) {
  const extension = path.extname(filename);
  const base = path.basename(filename, extension)
    .replace(/[\u0000-\u001f\u007f"\\/]/g, '-')
    .trim();
  return base || 'audio';
}

function contentDisposition(filename) {
  const asciiFallback = filename.replace(/[^\x20-\x7e]/g, '_').replaceAll('"', '_');
  return `attachment; filename="${asciiFallback}"; filename*=UTF-8''${encodeURIComponent(filename)}`;
}

async function handleExport(request, response, options) {
  let temporaryRoot;
  try {
    const body = await readRequestBody(request, options.maxBodyBytes);
    let decoded;
    try {
      decoded = decodeExportRequest(body);
    } catch (error) {
      if (error instanceof ExportRequestError && error.code === 'EMPTY_AUDIO') {
        respondJson(response, 400, { error: MISSING_AUDIO_ERROR });
      } else {
        respondJson(response, 400, { error: INVALID_SETTINGS_ERROR });
      }
      return;
    }

    const { metadata, audioBytes } = decoded;
    if (typeof metadata.filename !== 'string' || !isSupportedAudio(metadata.filename)) {
      respondJson(response, 400, { error: UNSUPPORTED_AUDIO_ERROR });
      return;
    }
    if (!hasValidScale(metadata.scale) || !hasValidCues(metadata.cues)) {
      respondJson(response, 400, { error: INVALID_SETTINGS_ERROR });
      return;
    }

    temporaryRoot = await mkdtemp(path.join(options.temporaryRoot, 'oc-lipsync-request-'));
    const extension = path.extname(metadata.filename).toLowerCase();
    const audioPath = path.join(temporaryRoot, `audio${extension}`);
    await writeFile(audioPath, audioBytes);

    const result = await options.exportVideo({
      audioPath,
      mouthCues: metadata.cues,
      characterScale: metadata.scale,
      closedMouthPath: path.join(PROJECT_ROOT, 'public/oc-mouth-closed.png'),
      openMouthPath: path.join(PROJECT_ROOT, 'public/oc-mouth-open.png'),
      temporaryRoot,
    });
    const downloadName = `${safeDownloadBase(metadata.filename)}-oc-lipsync.webm`;
    const outputMetadata = await stat(result.path);
    response.writeHead(200, {
      'Content-Type': 'video/webm',
      'Content-Length': outputMetadata.size,
      'Content-Disposition': contentDisposition(downloadName),
      'X-Content-Type-Options': 'nosniff',
    });
    await pipeline(createReadStream(result.path), response);
  } catch (error) {
    if (error?.code === 'BODY_TOO_LARGE') {
      request.resume();
      if (!response.headersSent) respondJson(response, 413, { error: '音频文件过大' });
    } else if (response.headersSent) {
      response.destroy();
    } else {
      respondJson(response, 500, { error: '导出失败，请重试' });
    }
  } finally {
    if (temporaryRoot) await rm(temporaryRoot, { recursive: true, force: true }).catch(() => {});
  }
}

export function createAppServer({
  exportVideo = exportTransparentWebm,
  maxBodyBytes = MAX_BODY_BYTES,
  publicRoot = DEFAULT_PUBLIC_ROOT,
  temporaryRoot = tmpdir(),
} = {}) {
  return createServer((request, response) => {
    const pathname = (request.url || '/').split(/[?#]/, 1)[0];
    if (pathname === '/api/export') {
      if (request.method !== 'POST') {
        response.setHeader('Allow', 'POST');
        respondText(response, 405, 'Method Not Allowed');
        return;
      }
      void handleExport(request, response, {
        exportVideo,
        maxBodyBytes,
        temporaryRoot,
      });
      return;
    }
    void serveStatic(request, response, publicRoot);
  });
}
