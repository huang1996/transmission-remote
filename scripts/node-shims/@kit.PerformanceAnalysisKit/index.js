'use strict';

/**
 * Host-side (Node.js) stand-in for the `hilog` export of
 * `@kit.PerformanceAnalysisKit`: the very same implementation as the
 * `@ohos.hilog` shim, re-exported under the kit name.
 */

const hilogModule = require('@ohos.hilog');
const hilog = hilogModule.hilog || hilogModule.default || hilogModule;

module.exports = { hilog };
module.exports.default = { hilog };
Object.defineProperty(module.exports, '__esModule', { value: true });
