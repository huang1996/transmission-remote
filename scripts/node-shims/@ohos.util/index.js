'use strict';

/**
 * Host-side (Node.js) stand-in for the `Base64Helper` part of `@ohos.util`.
 */

class Base64Helper {
  encodeToString(src) {
    return Buffer.from(src).toString('base64');
  }

  decodeSync(src) {
    if (typeof src === 'string') {
      return new Uint8Array(Buffer.from(src, 'base64'));
    }
    return new Uint8Array(Buffer.from(src));
  }
}

const util = { Base64Helper };
const exported = { Base64Helper, util };

module.exports = exported;
module.exports.default = exported;
Object.defineProperty(module.exports, '__esModule', { value: true });
