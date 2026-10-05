// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Dependency-free Base64 and UTF-8 helpers.
 *
 * The SDK needs Base64 for two things: HTTP Basic authentication, and
 * `torrent_add`'s `metainfo` payload. Implementing it here (instead of using
 * `@ohos.util`) keeps the core platform-independent, which is what allows the
 * unit tests to run on a plain JavaScript engine.
 *
 * @since 1.0.0
 */

const BASE64_ALPHABET: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
const BASE64_ALPHABET_URL_SAFE: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
const PADDING: string = '=';

/** Reverse lookup table for the standard alphabet, built once. */
function buildDecodeTable(alphabet: string): Map<string, number> {
  const table = new Map<string, number>();
  for (let i = 0; i < alphabet.length; i++) {
    table.set(alphabet.charAt(i), i);
  }
  return table;
}

const STANDARD_DECODE_TABLE: Map<string, number> = buildDecodeTable(BASE64_ALPHABET);
const URL_SAFE_DECODE_TABLE: Map<string, number> = buildDecodeTable(BASE64_ALPHABET_URL_SAFE);

/** Base64 and UTF-8 conversion utilities. */
export class Base64 {
  private constructor() {
    // Static-only utility class.
  }

  /** Encodes raw bytes using the standard alphabet with `=` padding. */
  static encodeBytes(bytes: Uint8Array): string {
    return Base64.encodeBytesWith(bytes, BASE64_ALPHABET, true);
  }

  /**
   * Encodes raw bytes.
   *
   * @param urlSafe use the URL-safe alphabet (`-`/`_` instead of `+`/`/`)
   * @param padded emit `=` padding characters
   */
  static encodeBytesWith(bytes: Uint8Array, alphabet: string, padded: boolean): string {
    let out = '';
    for (let i = 0; i < bytes.length; i += 3) {
      const byte0 = bytes[i];
      const hasByte1 = i + 1 < bytes.length;
      const hasByte2 = i + 2 < bytes.length;
      const byte1 = hasByte1 ? bytes[i + 1] : 0;
      const byte2 = hasByte2 ? bytes[i + 2] : 0;

      out += alphabet.charAt(byte0 >> 2);
      out += alphabet.charAt(((byte0 & 0x03) << 4) | (byte1 >> 4));
      if (hasByte1) {
        out += alphabet.charAt(((byte1 & 0x0f) << 2) | (byte2 >> 6));
      } else if (padded) {
        out += PADDING;
      }
      if (hasByte2) {
        out += alphabet.charAt(byte2 & 0x3f);
      } else if (padded) {
        out += PADDING;
      }
    }
    return out;
  }

  /** Decodes Base64 text (standard or URL-safe, padded or not) into bytes. */
  static decodeToBytes(text: string): Uint8Array {
    const urlSafe = text.includes('-') || text.includes('_');
    const table = urlSafe ? URL_SAFE_DECODE_TABLE : STANDARD_DECODE_TABLE;
    const values: number[] = [];
    for (let index = 0; index < text.length; index++) {
      const character = text.charAt(index);
      if (character === PADDING || character === '\n' || character === '\r' || character === ' ') {
        continue;
      }
      const value = table.get(character);
      if (value !== undefined) {
        values.push(value);
      }
    }

    const bytes = new Uint8Array(Math.floor((values.length * 6) / 8));
    let byteIndex = 0;
    let buffer = 0;
    let bitsInBuffer = 0;
    for (const value of values) {
      buffer = (buffer << 6) | value;
      bitsInBuffer += 6;
      if (bitsInBuffer >= 8) {
        bitsInBuffer -= 8;
        bytes[byteIndex] = (buffer >> bitsInBuffer) & 0xff;
        byteIndex++;
      }
    }
    return bytes;
  }

  /** Encodes a string as UTF-8 and then as Base64. */
  static encodeUtf8(text: string): string {
    return Base64.encodeBytes(Base64.utf8Bytes(text));
  }

  /** Decodes Base64 into raw bytes and then into a UTF-8 string. */
  static decodeUtf8(text: string): string {
    return Base64.utf8ToString(Base64.decodeToBytes(text));
  }

  /** Converts a JavaScript string into its UTF-8 byte representation. */
  static utf8Bytes(text: string): Uint8Array {
    const bytes: number[] = [];
    for (let i = 0; i < text.length; i++) {
      let codePoint = text.charCodeAt(i);

      // Combine a surrogate pair into a single code point.
      if (codePoint >= 0xd800 && codePoint <= 0xdbff && i + 1 < text.length) {
        const next = text.charCodeAt(i + 1);
        if (next >= 0xdc00 && next <= 0xdfff) {
          codePoint = 0x10000 + ((codePoint - 0xd800) << 10) + (next - 0xdc00);
          i++;
        }
      }

      if (codePoint < 0x80) {
        bytes.push(codePoint);
      } else if (codePoint < 0x800) {
        bytes.push(0xc0 | (codePoint >> 6), 0x80 | (codePoint & 0x3f));
      } else if (codePoint < 0x10000) {
        bytes.push(0xe0 | (codePoint >> 12), 0x80 | ((codePoint >> 6) & 0x3f), 0x80 | (codePoint & 0x3f));
      } else {
        bytes.push(
          0xf0 | (codePoint >> 18),
          0x80 | ((codePoint >> 12) & 0x3f),
          0x80 | ((codePoint >> 6) & 0x3f),
          0x80 | (codePoint & 0x3f),
        );
      }
    }
    return new Uint8Array(bytes);
  }

  /** Converts a UTF-8 byte sequence back into a JavaScript string. */
  static utf8ToString(bytes: Uint8Array): string {
    let out = '';
    let i = 0;
    while (i < bytes.length) {
      const byte0 = bytes[i];
      let codePoint = 0;
      let extraBytes = 0;

      if (byte0 < 0x80) {
        codePoint = byte0;
      } else if ((byte0 & 0xe0) === 0xc0) {
        codePoint = byte0 & 0x1f;
        extraBytes = 1;
      } else if ((byte0 & 0xf0) === 0xe0) {
        codePoint = byte0 & 0x0f;
        extraBytes = 2;
      } else {
        codePoint = byte0 & 0x07;
        extraBytes = 3;
      }

      for (let j = 0; j < extraBytes && i + 1 < bytes.length; j++) {
        i++;
        codePoint = (codePoint << 6) | (bytes[i] & 0x3f);
      }

      if (codePoint > 0xffff) {
        const adjusted = codePoint - 0x10000;
        out += String.fromCharCode(0xd800 + (adjusted >> 10), 0xdc00 + (adjusted & 0x3ff));
      } else {
        out += String.fromCharCode(codePoint);
      }
      i++;
    }
    return out;
  }

  /**
   * Builds the value of an HTTP `Authorization: Basic …` header.
   *
   * @param username account name
   * @param password account password
   */
  static basicAuthorization(username: string, password: string): string {
    return `Basic ${Base64.encodeUtf8(`${username}:${password}`)}`;
  }
}
