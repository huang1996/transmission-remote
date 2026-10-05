'use strict';

/**
 * Host-side (Node.js) stand-in for `@ohos.hilog`.
 *
 * Silent by default; set DSH_TEST_VERBOSE=1 to forward log records to the
 * Node.js console. `util.format` handles the %s / %d / %j placeholders that
 * hilog's format string supports.
 */

const util = require('util');

function emit(level, domain, tag, format, args, sink) {
  if (!process.env.DSH_TEST_VERBOSE) return;
  const message = util.format(format, ...args);
  sink('[' + level + '][' + domain + '][' + tag + '] ' + message);
}

const hilog = {
  debug(domain, tag, format, ...args) {
    emit('D', domain, tag, format, args, console.log);
  },
  info(domain, tag, format, ...args) {
    emit('I', domain, tag, format, args, console.log);
  },
  warn(domain, tag, format, ...args) {
    emit('W', domain, tag, format, args, console.warn);
  },
  error(domain, tag, format, ...args) {
    emit('E', domain, tag, format, args, console.error);
  },
  fatal(domain, tag, format, ...args) {
    emit('F', domain, tag, format, args, console.error);
  },
  isLoggable() {
    return !!process.env.DSH_TEST_VERBOSE;
  },
};

module.exports = hilog;
module.exports.hilog = hilog;
module.exports.default = hilog;
Object.defineProperty(module.exports, '__esModule', { value: true });
