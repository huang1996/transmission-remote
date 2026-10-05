'use strict';

/**
 * Installs the ArkTS globals that do not already exist in Node.js.
 *
 * Only `$r` needs one: `console` and the timer functions are native. The stub
 * returns a synthetic resource handle, because these tests cover the app's
 * logic rather than its styling — `scripts/lint-arkts.mjs` already proves that
 * every `$r('app.color.*')` / `$r('app.string.*')` reference resolves against
 * the generated resource files.
 */

if (typeof globalThis.$r !== 'function') {
  let nextId = 1;
  globalThis.$r = function $r(name, ...params) {
    const resource = {
      id: nextId++,
      name,
      type: 10000,
      params,
      bundleName: 'huangtao.hmapp.transmissionremote',
      moduleName: 'entry',
    };
    return resource;
  };
}

module.exports = {};
