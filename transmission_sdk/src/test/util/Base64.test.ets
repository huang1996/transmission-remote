// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for the Base64 / UTF-8 helpers.
 *
 * Base64 is used for HTTP Basic authentication and for `torrent_add`'s
 * `metainfo` payload, both of which must survive non-ASCII credentials and file
 * names, so the round-trip tests deliberately include multi-byte characters.
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { Base64 } from '../../main/ets/util/Base64';

export default function base64Test(): void {
  describe('Base64 encoding', () => {
    it('matches the RFC 4648 test vectors', () => {
      expect(Base64.encodeUtf8('')).assertEqual('');
      expect(Base64.encodeUtf8('f')).assertEqual('Zg==');
      expect(Base64.encodeUtf8('fo')).assertEqual('Zm8=');
      expect(Base64.encodeUtf8('foo')).assertEqual('Zm9v');
      expect(Base64.encodeUtf8('foob')).assertEqual('Zm9vYg==');
      expect(Base64.encodeUtf8('fooba')).assertEqual('Zm9vYmE=');
      expect(Base64.encodeUtf8('foobar')).assertEqual('Zm9vYmFy');
    });

    it('decodes padded, unpadded and URL-safe alphabets', () => {
      expect(Base64.decodeUtf8('Zm9vYmFy')).assertEqual('foobar');
      expect(Base64.decodeUtf8('Zm9vYmE')).assertEqual('fooba');
      expect(Base64.decodeUtf8('Zm9vYg')).assertEqual('foob');
      // 0xFB 0xFF encodes to "+/8=" in the standard alphabet and "-_8" URL-safe.
      const bytes = new Uint8Array(2);
      bytes[0] = 0xfb;
      bytes[1] = 0xff;
      expect(Base64.encodeBytes(bytes)).assertEqual('+/8=');
      expect(Base64.encodeBytesWith(bytes, 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_', false)).assertEqual(
        '-_8',
      );
      expect(Base64.decodeToBytes('-_8').length).assertEqual(2);
    });

    it('round-trips multi-byte UTF-8 text', () => {
      const samples: string[] = ['hello', '中文测试', 'emoji 🚀 and accents éàü', 'mixed 日本語 + symbols !@#$%^&*()'];
      for (const sample of samples) {
        const encoded = Base64.encodeUtf8(sample);
        expect(Base64.decodeUtf8(encoded)).assertEqual(sample);
      }
    });

    it('round-trips every byte value', () => {
      const bytes = new Uint8Array(256);
      for (let i = 0; i < 256; i++) {
        bytes[i] = i;
      }
      const decoded = Base64.decodeToBytes(Base64.encodeBytes(bytes));
      expect(decoded.length).assertEqual(256);
      let mismatches = 0;
      for (let i = 0; i < 256; i++) {
        if (decoded[i] !== i) {
          mismatches++;
        }
      }
      expect(mismatches).assertEqual(0);
    });

    it('ignores padding and whitespace while decoding', () => {
      expect(Base64.decodeUtf8('Zm9v\nYmFy')).assertEqual('foobar');
      expect(Base64.decodeUtf8(' Zm9vYmFy ')).assertEqual('foobar');
    });

    it('produces the UTF-8 byte sequence for a surrogate pair', () => {
      // U+1F680 ROCKET is F0 9F 9A 80 in UTF-8.
      const bytes = Base64.utf8Bytes('🚀');
      expect(bytes.length).assertEqual(4);
      expect(bytes[0]).assertEqual(0xf0);
      expect(bytes[1]).assertEqual(0x9f);
      expect(bytes[2]).assertEqual(0x9a);
      expect(bytes[3]).assertEqual(0x80);
    });
  });

  describe('Base64 HTTP Basic authorization', () => {
    it('bases the header on the UTF-8 encoding of user:password', () => {
      expect(Base64.basicAuthorization('Aladdin', 'open sesame')).assertEqual('Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==');
      expect(Base64.basicAuthorization('user', 'pass')).assertEqual('Basic dXNlcjpwYXNz');
    });

    it('encodes non-ASCII credentials correctly', () => {
      const header = Base64.basicAuthorization('用户', '密码');
      expect(header.startsWith('Basic ')).assertTrue();
      expect(Base64.decodeUtf8(header.substring(6))).assertEqual('用户:密码');
    });
  });
}
