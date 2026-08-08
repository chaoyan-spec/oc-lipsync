const PREFIX_BYTES = 4;
const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder('utf-8', { fatal: true });

export class ExportRequestError extends Error {
  constructor(message, code = 'INVALID_REQUEST', options) {
    super(message, options);
    this.name = 'ExportRequestError';
    this.code = code;
  }
}

function encodeMetadata(metadata) {
  let metadataBytes;
  try {
    const json = JSON.stringify(metadata);
    if (typeof json !== 'string') throw new TypeError('Metadata must be JSON serializable.');
    metadataBytes = textEncoder.encode(json);
  } catch (error) {
    throw new ExportRequestError('Invalid export request metadata.', 'INVALID_REQUEST', {
      cause: error,
    });
  }

  if (metadataBytes.byteLength === 0 || metadataBytes.byteLength > 0xffffffff) {
    throw new ExportRequestError('Invalid export request metadata.');
  }

  const prefix = new Uint8Array(PREFIX_BYTES);
  new DataView(prefix.buffer).setUint32(0, metadataBytes.byteLength, false);
  return { prefix, metadataBytes };
}

function toBytes(value) {
  if (value instanceof Uint8Array) return value;
  if (value instanceof ArrayBuffer) return new Uint8Array(value);
  if (ArrayBuffer.isView(value)) {
    return new Uint8Array(value.buffer, value.byteOffset, value.byteLength);
  }
  throw new ExportRequestError('Invalid export request bytes.');
}

export function encodeExportRequest(metadata, audioBytes) {
  const audio = toBytes(audioBytes);
  if (audio.byteLength === 0) {
    throw new ExportRequestError('Audio payload is empty.', 'EMPTY_AUDIO');
  }

  const { prefix, metadataBytes } = encodeMetadata(metadata);
  const envelope = new Uint8Array(PREFIX_BYTES + metadataBytes.byteLength + audio.byteLength);
  envelope.set(prefix, 0);
  envelope.set(metadataBytes, PREFIX_BYTES);
  envelope.set(audio, PREFIX_BYTES + metadataBytes.byteLength);
  return envelope;
}

export function createExportRequestBody(metadata, audioBlob) {
  if (!(audioBlob instanceof Blob)) {
    throw new ExportRequestError('Invalid audio payload.');
  }
  if (audioBlob.size === 0) {
    throw new ExportRequestError('Audio payload is empty.', 'EMPTY_AUDIO');
  }

  const { prefix, metadataBytes } = encodeMetadata(metadata);
  return new Blob([prefix, metadataBytes, audioBlob], { type: 'application/octet-stream' });
}

export function decodeExportMetadata(value) {
  const bytes = toBytes(value);
  let metadata;
  try {
    metadata = JSON.parse(textDecoder.decode(bytes));
  } catch (error) {
    throw new ExportRequestError('Invalid export request metadata.', 'INVALID_REQUEST', {
      cause: error,
    });
  }

  if (!metadata || typeof metadata !== 'object' || Array.isArray(metadata)) {
    throw new ExportRequestError('Invalid export request metadata.');
  }
  return metadata;
}

export function decodeExportRequest(value) {
  const bytes = toBytes(value);
  if (bytes.byteLength < PREFIX_BYTES) {
    throw new ExportRequestError('Invalid export request: missing JSON-length prefix.');
  }

  const metadataLength = new DataView(
    bytes.buffer,
    bytes.byteOffset,
    PREFIX_BYTES,
  ).getUint32(0, false);
  const audioOffset = PREFIX_BYTES + metadataLength;
  if (metadataLength === 0 || audioOffset > bytes.byteLength) {
    throw new ExportRequestError('Invalid export request: oversized JSON-length prefix.');
  }
  if (audioOffset === bytes.byteLength) {
    throw new ExportRequestError('Audio payload is empty.', 'EMPTY_AUDIO');
  }

  const metadata = decodeExportMetadata(bytes.subarray(PREFIX_BYTES, audioOffset));

  return {
    metadata,
    audioBytes: bytes.slice(audioOffset),
  };
}
