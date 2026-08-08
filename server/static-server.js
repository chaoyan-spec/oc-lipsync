import { createReadStream } from 'node:fs';
import { realpath, stat } from 'node:fs/promises';
import { createServer } from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HOST = '127.0.0.1';
const PORT = Number(process.env.PORT || 4173);
const PROJECT_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const PUBLIC_ROOT = await realpath(path.join(PROJECT_ROOT, 'public'));

const contentTypes = new Map([
  ['.css', 'text/css; charset=utf-8'],
  ['.html', 'text/html; charset=utf-8'],
  ['.js', 'text/javascript; charset=utf-8'],
  ['.png', 'image/png'],
  ['.svg', 'image/svg+xml'],
]);

function respond(response, statusCode, message) {
  response.writeHead(statusCode, { 'Content-Type': 'text/plain; charset=utf-8' });
  response.end(message);
}

function isInsidePublic(filePath) {
  return filePath === PUBLIC_ROOT || filePath.startsWith(`${PUBLIC_ROOT}${path.sep}`);
}

async function resolveRequestPath(requestUrl) {
  const rawPath = (requestUrl || '/').split(/[?#]/, 1)[0];
  const decodedPath = decodeURIComponent(rawPath);
  const segments = decodedPath.split(/[\\/]+/);

  if (decodedPath.includes('\0') || segments.includes('..')) {
    throw new Error('forbidden');
  }

  let requestedPath = path.resolve(PUBLIC_ROOT, `.${decodedPath}`);
  if (!isInsidePublic(requestedPath)) throw new Error('forbidden');

  const metadata = await stat(requestedPath);
  if (metadata.isDirectory()) requestedPath = path.join(requestedPath, 'index.html');

  const canonicalPath = await realpath(requestedPath);
  if (!isInsidePublic(canonicalPath)) throw new Error('forbidden');
  return canonicalPath;
}

const server = createServer(async (request, response) => {
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    response.setHeader('Allow', 'GET, HEAD');
    respond(response, 405, 'Method Not Allowed');
    return;
  }

  try {
    const filePath = await resolveRequestPath(request.url);
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

    createReadStream(filePath).on('error', () => {
      if (!response.headersSent) respond(response, 500, 'Internal Server Error');
      else response.destroy();
    }).pipe(response);
  } catch (error) {
    if (error instanceof URIError) {
      respond(response, 400, 'Bad Request');
    } else if (error instanceof Error && error.message === 'forbidden') {
      respond(response, 403, 'Forbidden');
    } else {
      respond(response, 404, 'Not Found');
    }
  }
});

server.listen(PORT, HOST, () => {
  console.log(`http://${HOST}:${PORT}`);
});
