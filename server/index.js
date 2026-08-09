import { createReadStream } from 'node:fs';
import { mkdtemp, open, realpath, rm, stat } from 'node:fs/promises';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { pipeline } from 'node:stream/promises';
import { fileURLToPath } from 'node:url';

import { decodeExportMetadata, ExportRequestError } from '../public/lib/request-envelope.js';
import { isSupportedAudio } from '../public/lib/ui-state.js';
import { exportCompactMov } from './export-video.js';

const MAX_BODY_BYTES = 500 * 1024 * 1024;
const MAX_METADATA_BYTES = 1024 * 1024;
const PROJECT_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const DEFAULT_PUBLIC_ROOT = await realpath(path.join(PROJECT_ROOT, 'public'));
const MISSING_AUDIO_ERROR = '请先选择口播音频';
const UNSUPPORTED_AUDIO_ERROR = '暂不支持该音频，请换用 MP3、WAV 或 M4A';
const INVALID_SETTINGS_ERROR = '导出参数无效';
const OVERSIZED_METADATA_ERROR = '导出参数过大';
const UNSUPPORTED_MEDIA_TYPE_ERROR = '请求格式不受支持';
const READY_PATH = '/__oc-lipsync/ready';
const READY_MARKER = 'OC_LIPSYNC_READY';

const contentTypes = new Map([
  ['.css', 'text/css; charset=utf-8'],
  ['.html', 'text/html; charset=utf-8'],
  ['.js', 'text/javascript; charset=utf-8'],
  ['.json', 'application/json; charset=utf-8'],
  ['.png', 'image/png'],
  ['.svg', 'image/svg+xml'],
  ['.webp', 'image/webp'],
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

function bodyTooLargeError() {
  const error = new Error('request too large');
  error.code = 'BODY_TOO_LARGE';
  return error;
}

function metadataTooLargeError() {
  return new ExportRequestError('Export metadata is too large.', 'METADATA_TOO_LARGE');
}

function validateContentLength(request, limit) {
  const contentLength = Number(request.headers['content-length']);
  if (Number.isFinite(contentLength) && contentLength > limit) throw bodyTooLargeError();
  return Number.isFinite(contentLength) ? contentLength : undefined;
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
      || !Number.isInteger(cue.frame)
      || cue.frame < 0
      || cue.frame > 7
    ) return false;

    if (index === 0) return Math.abs(cue.start) <= 1e-6;
    return Math.abs(cues[index - 1].end - cue.start) <= 1e-6;
  });
}

function validateMetadata(metadata) {
  if (typeof metadata.filename !== 'string' || !isSupportedAudio(metadata.filename)) {
    const error = new ExportRequestError('Unsupported audio extension.', 'UNSUPPORTED_AUDIO');
    throw error;
  }
  if (!hasValidCues(metadata.cues)) {
    throw new ExportRequestError('Invalid export settings.');
  }
  return metadata;
}

async function writeAll(file, chunk) {
  let offset = 0;
  while (offset < chunk.length) {
    const { bytesWritten } = await file.write(chunk, offset, chunk.length - offset, null);
    if (bytesWritten === 0) throw new Error('Could not write audio payload.');
    offset += bytesWritten;
  }
}

async function streamExportRequest(request, { limit, metadataLimit, temporaryRoot }) {
  const contentLength = validateContentLength(request, limit);
  const prefix = Buffer.alloc(4);
  let prefixBytes = 0;
  let metadataLength;
  let metadataBytes;
  let metadataOffset = 0;
  let metadata;
  let audioPath;
  let audioFile;
  let audioLength = 0;
  let totalLength = 0;

  try {
    for await (const chunk of request) {
      totalLength += chunk.length;
      if (totalLength > limit) throw bodyTooLargeError();

      let chunkOffset = 0;
      while (chunkOffset < chunk.length) {
        if (prefixBytes < prefix.length) {
          const count = Math.min(prefix.length - prefixBytes, chunk.length - chunkOffset);
          chunk.copy(prefix, prefixBytes, chunkOffset, chunkOffset + count);
          prefixBytes += count;
          chunkOffset += count;
          if (prefixBytes < prefix.length) continue;

          metadataLength = prefix.readUInt32BE(0);
          if (metadataLength > metadataLimit) throw metadataTooLargeError();
          if (contentLength !== undefined && metadataLength === contentLength - prefix.length) {
            throw new ExportRequestError('Audio payload is empty.', 'EMPTY_AUDIO');
          }
          if (
            metadataLength === 0
            || metadataLength > limit - prefix.length - 1
            || (contentLength !== undefined && metadataLength > contentLength - prefix.length - 1)
          ) {
            throw new ExportRequestError('Invalid export request: oversized JSON-length prefix.');
          }
          metadataBytes = Buffer.alloc(metadataLength);
          continue;
        }

        if (metadataOffset < metadataLength) {
          const count = Math.min(metadataLength - metadataOffset, chunk.length - chunkOffset);
          chunk.copy(metadataBytes, metadataOffset, chunkOffset, chunkOffset + count);
          metadataOffset += count;
          chunkOffset += count;
          if (metadataOffset < metadataLength) continue;

          metadata = validateMetadata(decodeExportMetadata(metadataBytes));
          const extension = path.extname(metadata.filename).toLowerCase();
          audioPath = path.join(temporaryRoot, `audio${extension}`);
          audioFile = await open(audioPath, 'wx');
          continue;
        }

        const audioChunk = chunk.subarray(chunkOffset);
        await writeAll(audioFile, audioChunk);
        audioLength += audioChunk.length;
        chunkOffset = chunk.length;
      }
    }

    if (prefixBytes < prefix.length || metadataOffset < metadataLength) {
      throw new ExportRequestError('Invalid export request: missing or oversized prefix.');
    }
    if (audioLength === 0) {
      throw new ExportRequestError('Audio payload is empty.', 'EMPTY_AUDIO');
    }

    await audioFile.close();
    audioFile = undefined;
    return { metadata, audioPath };
  } finally {
    if (audioFile) await audioFile.close().catch(() => {});
  }
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
  const encodedFilename = encodeURIComponent(filename).replace(/[!'()*]/g, (character) => (
    `%${character.charCodeAt(0).toString(16).toUpperCase()}`
  ));
  return `attachment; filename="${asciiFallback}"; filename*=UTF-8''${encodedFilename}`;
}

async function handleExport(request, response, options) {
  let temporaryRoot;
  try {
    temporaryRoot = await mkdtemp(path.join(options.temporaryRoot, 'oc-lipsync-request-'));
    const { metadata, audioPath } = await streamExportRequest(request, {
      limit: options.maxBodyBytes,
      metadataLimit: options.maxMetadataBytes,
      temporaryRoot,
    });

    const result = await options.exportVideo({
      audioPath,
      mouthCues: metadata.cues,
      mouthFramePaths: Array.from({ length: 8 }, (_, frame) => (
        path.join(PROJECT_ROOT, `public/papalu-talking/frames/${frame}.png`)
      )),
      temporaryRoot,
    });
    const downloadName = `${safeDownloadBase(metadata.filename)}-OC口播.mov`;
    const outputMetadata = await stat(result.path);
    response.writeHead(200, {
      'Content-Type': 'video/quicktime',
      'Content-Length': outputMetadata.size,
      'Content-Disposition': contentDisposition(downloadName),
      'X-Content-Type-Options': 'nosniff',
    });
    await pipeline(createReadStream(result.path), response);
  } catch (error) {
    if (error?.code === 'BODY_TOO_LARGE') {
      request.resume();
      if (!response.headersSent) respondJson(response, 413, { error: '音频文件过大' });
    } else if (error instanceof ExportRequestError && error.code === 'METADATA_TOO_LARGE') {
      request.resume();
      if (!response.headersSent) respondJson(response, 413, { error: OVERSIZED_METADATA_ERROR });
    } else if (error instanceof ExportRequestError && error.code === 'EMPTY_AUDIO') {
      if (!response.headersSent) respondJson(response, 400, { error: MISSING_AUDIO_ERROR });
    } else if (error instanceof ExportRequestError && error.code === 'UNSUPPORTED_AUDIO') {
      if (!response.headersSent) respondJson(response, 400, { error: UNSUPPORTED_AUDIO_ERROR });
    } else if (error instanceof ExportRequestError) {
      if (!response.headersSent) respondJson(response, 400, { error: INVALID_SETTINGS_ERROR });
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
  exportVideo = exportCompactMov,
  maxBodyBytes = MAX_BODY_BYTES,
  maxMetadataBytes = MAX_METADATA_BYTES,
  publicRoot = DEFAULT_PUBLIC_ROOT,
  temporaryRoot = tmpdir(),
} = {}) {
  return createServer((request, response) => {
    const authority = `127.0.0.1:${request.socket.localPort}`;
    if (request.headers.host !== authority) {
      request.resume();
      respondText(response, 403, 'Forbidden');
      return;
    }

    const pathname = (request.url || '/').split(/[?#]/, 1)[0];
    if (pathname === READY_PATH) {
      if (request.method !== 'GET' && request.method !== 'HEAD') {
        response.setHeader('Allow', 'GET, HEAD');
        respondText(response, 405, 'Method Not Allowed');
        return;
      }
      response.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
      response.end(request.method === 'HEAD' ? undefined : READY_MARKER);
      return;
    }
    if (pathname === '/api/export') {
      if (
        request.headers.origin !== undefined
        && request.headers.origin !== `http://${authority}`
      ) {
        request.resume();
        respondText(response, 403, 'Forbidden');
        return;
      }
      if (request.method !== 'POST') {
        response.setHeader('Allow', 'POST');
        respondText(response, 405, 'Method Not Allowed');
        return;
      }
      if (request.headers['content-type'] !== 'application/octet-stream') {
        request.resume();
        respondJson(response, 415, { error: UNSUPPORTED_MEDIA_TYPE_ERROR });
        return;
      }
      void handleExport(request, response, {
        exportVideo,
        maxBodyBytes,
        maxMetadataBytes,
        temporaryRoot,
      });
      return;
    }
    void serveStatic(request, response, publicRoot);
  });
}
