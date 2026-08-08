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

  let metadataBytes;
  try {
    metadataBytes = textEncoder.encode(JSON.stringify(metadata));
  } catch (error) {
    throw new ExportRequestError('Invalid export request metadata.', 'INVALID_REQUEST', {
      cause: error,
    });
  }

  if (metadataBytes.byteLength === 0 || metadataBytes.byteLength > 0xffffffff) {
    throw new ExportRequestError('Invalid export request metadata.');
  }

  const envelope = new Uint8Array(PREFIX_BYTES + metadataBytes.byteLength + audio.byteLength);
  new DataView(envelope.buffer).setUint32(0, metadataBytes.byteLength, false);
  envelope.set(metadataBytes, PREFIX_BYTES);
  envelope.set(audio, PREFIX_BYTES + metadataBytes.byteLength);
  return envelope;
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

  let metadata;
  try {
    const metadataText = textDecoder.decode(bytes.subarray(PREFIX_BYTES, audioOffset));
    metadata = JSON.parse(metadataText);
  } catch (error) {
    throw new ExportRequestError('Invalid export request metadata.', 'INVALID_REQUEST', {
      cause: error,
    });
  }

  if (!metadata || typeof metadata !== 'object' || Array.isArray(metadata)) {
    throw new ExportRequestError('Invalid export request metadata.');
  }

  return {
    metadata,
    audioBytes: bytes.slice(audioOffset),
  };
}
