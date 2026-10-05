'use strict';

/**
 * Host-side (Node.js) stand-in for the `BusinessError` export of
 * `@kit.BasicServicesKit`.
 */

class BusinessError extends Error {
  constructor(code, message) {
    super(message === undefined ? '' : String(message));
    this.name = 'BusinessError';
    this.code = code === undefined ? 0 : code;
  }
}

module.exports = { BusinessError };
module.exports.default = module.exports;
Object.defineProperty(module.exports, '__esModule', { value: true });
