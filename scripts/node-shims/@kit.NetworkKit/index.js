'use strict';

/**
 * Host-side (Node.js) stand-in for the `http` part of `@kit.NetworkKit`.
 *
 * Requests are not available under Node.js: `request()` rejects with
 * `not available in node`. Everything else is a no-op so that imported modules
 * can be constructed and inspected in unit tests.
 */

const RequestMethod = {
  OPTIONS: 'OPTIONS',
  GET: 'GET',
  HEAD: 'HEAD',
  POST: 'POST',
  PUT: 'PUT',
  DELETE: 'DELETE',
  TRACE: 'TRACE',
  CONNECT: 'CONNECT',
};

const HttpDataType = {
  STRING: 0,
  OBJECT: 1,
  ARRAY_BUFFER: 2,
};

class HttpRequest {
  async request(url, options) {
    throw new Error('not available in node');
  }

  destroy() {
    // no-op on the host
  }

  on(type, cb) {
    // no-op on the host
  }

  off(type, cb) {
    // no-op on the host
  }
}

function createHttp() {
  return new HttpRequest();
}

const http = { RequestMethod, HttpDataType, HttpRequest, createHttp };

module.exports = { http };
module.exports.default = { http };
Object.defineProperty(module.exports, '__esModule', { value: true });
