import { FileValidator, MaxFileSizeValidator } from '@nestjs/common';

/**
 * Validates an uploaded file by inspecting its actual magic bytes (file
 * signature) rather than trusting the client-supplied `mimetype` header,
 * which is trivially spoofable. This prevents an attacker from storing an
 * HTML/SVG/script payload (or a polyglot) under an image/video content type
 * and later having it served from the public bucket as active content.
 */
export type FileKind = 'image' | 'video';

interface Signature {
  /** Byte offset at which `bytes` must appear. */
  offset: number;
  /** Expected byte sequence. */
  bytes: number[];
}

// Only formats we actually accept. Each entry is one acceptable signature.
const IMAGE_SIGNATURES: Signature[] = [
  { offset: 0, bytes: [0xff, 0xd8, 0xff] }, // JPEG
  { offset: 0, bytes: [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a] }, // PNG
  { offset: 0, bytes: [0x52, 0x49, 0x46, 0x46] }, // RIFF (WebP container; 'WEBP' checked below)
];

const VIDEO_SIGNATURES: Signature[] = [
  { offset: 4, bytes: [0x66, 0x74, 0x79, 0x70] }, // ISO-BMFF 'ftyp' → MP4 / MOV / QuickTime
  { offset: 0, bytes: [0x1a, 0x45, 0xdf, 0xa3] }, // EBML → WebM / Matroska
];

function matches(buffer: Buffer, sig: Signature): boolean {
  if (buffer.length < sig.offset + sig.bytes.length) return false;
  for (let i = 0; i < sig.bytes.length; i++) {
    if (buffer[sig.offset + i] !== sig.bytes[i]) return false;
  }
  return true;
}

function isWebp(buffer: Buffer): boolean {
  // RIFF....WEBP — verify the 'WEBP' fourcc at offset 8
  return buffer.length >= 12 && buffer.toString('ascii', 8, 12) === 'WEBP';
}

export class FileSignatureValidator extends FileValidator<{ kind: FileKind }> {
  constructor(kind: FileKind) {
    super({ kind });
  }

  isValid(file?: Express.Multer.File): boolean {
    if (!file?.buffer || file.buffer.length < 12) return false;
    const buf = file.buffer;

    if (this.validationOptions.kind === 'image') {
      return IMAGE_SIGNATURES.some((sig) => {
        if (!matches(buf, sig)) return false;
        // RIFF alone is ambiguous (could be WAV/AVI); require the WEBP fourcc.
        if (sig.bytes[0] === 0x52 /* 'R' */) return isWebp(buf);
        return true;
      });
    }

    return VIDEO_SIGNATURES.some((sig) => matches(buf, sig));
  }

  buildErrorMessage(): string {
    return this.validationOptions.kind === 'image'
      ? 'Uploaded file is not a valid JPEG, PNG, or WebP image'
      : 'Uploaded file is not a valid MP4, MOV, or WebM video';
  }
}

/** Convenience validator lists for ParseFilePipe. */
export const imageFileValidators = (maxSize: number) => [
  new MaxFileSizeValidator({ maxSize }),
  new FileSignatureValidator('image'),
];

export const videoFileValidators = (maxSize: number) => [
  new MaxFileSizeValidator({ maxSize }),
  new FileSignatureValidator('video'),
];
