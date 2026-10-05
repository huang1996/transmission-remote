'use strict';

/**
 * Host-side (Node.js) reimplementation of the tiny slice of `@ohos/hypium`
 * that ArkTS unit tests use.
 *
 * Exports the framework's free functions both as named properties of
 * `module.exports` and as `module.exports.default`, so that all of these work
 * after TypeScript compiles the test files to CommonJS:
 *
 *   import { describe, it, expect } from '@ohos/hypium';
 *   import hypium from '@ohos/hypium';
 *   import * as hypium from '@ohos/hypium';
 *   const hypium = require('@ohos/hypium');
 */

class AssertionError extends Error {
  constructor(message) {
    super(message);
    this.name = 'AssertionError';
  }
}

function formatValue(value) {
  try {
    if (value === null) return 'null';
    if (value === undefined) return 'undefined';
    if (typeof value === 'string') return JSON.stringify(value);
    if (typeof value === 'function') {
      return '[Function ' + (value.name || 'anonymous') + ']';
    }
    if (typeof value === 'bigint') return String(value) + 'n';
    if (value instanceof Error) return value.name + ': ' + value.message;
    if (value instanceof Uint8Array) {
      return 'Uint8Array(' + value.length + ') [' + Array.from(value).join(', ') + ']';
    }
    if (value instanceof Map) {
      return 'Map(' + value.size + ') ' + JSON.stringify(Array.from(value.entries()));
    }
    if (value instanceof Set) {
      return 'Set(' + value.size + ') ' + JSON.stringify(Array.from(value));
    }
    if (typeof value === 'symbol') return value.toString();
    const json = JSON.stringify(value);
    if (json === undefined) return String(value);
    return json.length > 300 ? json.slice(0, 297) + '...' : json;
  } catch (err) {
    try {
      return String(value);
    } catch (ignored) {
      return '[unprintable value]';
    }
  }
}

function deepEqual(a, b) {
  if (Object.is(a, b)) return true;
  if (a === null || b === null || typeof a !== 'object' || typeof b !== 'object') {
    return false;
  }
  if (Array.isArray(a) || Array.isArray(b)) {
    if (!Array.isArray(a) || !Array.isArray(b) || a.length !== b.length) return false;
    for (let i = 0; i < a.length; i++) if (!deepEqual(a[i], b[i])) return false;
    return true;
  }
  if (a instanceof Date || b instanceof Date) {
    return a instanceof Date && b instanceof Date && a.getTime() === b.getTime();
  }
  if (a instanceof Uint8Array || b instanceof Uint8Array) {
    if (!(a instanceof Uint8Array) || !(b instanceof Uint8Array) || a.length !== b.length) {
      return false;
    }
    for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return false;
    return true;
  }
  if (a instanceof Map || b instanceof Map) {
    if (!(a instanceof Map) || !(b instanceof Map) || a.size !== b.size) return false;
    for (const [key, value] of a) {
      if (!b.has(key) || !deepEqual(value, b.get(key))) return false;
    }
    return true;
  }
  if (a instanceof Set || b instanceof Set) {
    if (!(a instanceof Set) || !(b instanceof Set) || a.size !== b.size) return false;
    for (const value of a) if (!b.has(value)) return false;
    return true;
  }
  const keysA = Object.keys(a);
  const keysB = Object.keys(b);
  if (keysA.length !== keysB.length) return false;
  for (const key of keysA) {
    if (!Object.prototype.hasOwnProperty.call(b, key)) return false;
    if (!deepEqual(a[key], b[key])) return false;
  }
  return true;
}

function errorMessage(err) {
  if (err instanceof Error) return err.message || String(err);
  return formatValue(err);
}

/* ------------------------------------------------------------------ */
/* Assertions                                                          */
/* ------------------------------------------------------------------ */

function check(negated, ok, message) {
  if (negated ? ok : !ok) {
    throw new AssertionError((negated ? '[not] ' : '') + message);
  }
}

function makeAssertion(actual, negated) {
  const assertion = {};

  Object.defineProperty(assertion, 'not', {
    enumerable: true,
    get() {
      return makeAssertion(actual, !negated);
    },
  });

  const define = (name, fn) => {
    Object.defineProperty(assertion, name, {
      enumerable: true,
      value: fn,
    });
  };

  define('assertEqual', (expected) => {
    check(negated, actual === expected, 'expected ' + formatValue(expected) + ', but found ' + formatValue(actual));
  });

  define('assertNotEqual', (expected) => {
    check(negated, actual !== expected, 'expected a value different from ' + formatValue(expected) + ', but found ' + formatValue(actual));
  });

  define('assertTrue', () => {
    check(negated, actual === true, 'expected true, but found ' + formatValue(actual));
  });

  define('assertFalse', () => {
    check(negated, actual === false, 'expected false, but found ' + formatValue(actual));
  });

  define('assertNull', () => {
    check(negated, actual === null, 'expected null, but found ' + formatValue(actual));
  });

  define('assertUndefined', () => {
    check(negated, actual === undefined, 'expected undefined, but found ' + formatValue(actual));
  });

  define('assertDeepEquals', (expected) => {
    check(negated, deepEqual(actual, expected), 'expected ' + formatValue(expected) + ', but found ' + formatValue(actual));
  });

  define('assertContain', (expected) => {
    let ok = false;
    let message = 'expected ' + formatValue(actual) + ' to contain ' + formatValue(expected);
    if (typeof actual === 'string') {
      ok = actual.includes(String(expected));
    } else if (Array.isArray(actual)) {
      ok = actual.some((item) => deepEqual(item, expected));
    } else if (actual instanceof Map) {
      ok = actual.has(expected) || Array.from(actual.values()).some((item) => deepEqual(item, expected));
    } else if (actual instanceof Set) {
      ok = Array.from(actual).some((item) => deepEqual(item, expected));
    } else if (actual !== null && typeof actual === 'object') {
      ok = Object.prototype.hasOwnProperty.call(actual, expected);
    } else {
      message = 'expected a string, array or object, but found ' + formatValue(actual);
    }
    check(negated, ok, message);
  });

  define('assertLarger', (expected) => {
    check(negated, actual > expected, 'expected ' + formatValue(actual) + ' to be larger than ' + formatValue(expected));
  });

  define('assertLess', (expected) => {
    check(negated, actual < expected, 'expected ' + formatValue(actual) + ' to be less than ' + formatValue(expected));
  });

  define('assertThrowError', (expected) => {
    const candidate = typeof expected === 'function'
      ? expected
      : (typeof actual === 'function' ? actual : null);

    if (candidate === null) {
      check(negated, false, 'assertThrowError expects a function whose invocation throws, but found ' + formatValue(actual));
      return;
    }

    let threw = false;
    let thrown;
    try {
      candidate();
    } catch (err) {
      threw = true;
      thrown = err;
    }

    let ok = threw;
    if (ok && typeof expected === 'string') {
      ok = !!thrown && (errorMessage(thrown) === expected || String(thrown) === expected);
    }
    const detail = threw ? ' but it threw ' + formatValue(thrown) : '';
    check(negated, ok, 'expected the function to throw' + (typeof expected === 'string' ? ' ' + formatValue(expected) : '') + detail);
  });

  define('assertInstanceOf', (expected) => {
    let ok = false;
    try {
      ok = actual instanceof expected;
    } catch (err) {
      ok = false;
    }
    check(negated, ok, 'expected an instance of ' + (expected && expected.name ? expected.name : formatValue(expected)) + ', but found ' + formatValue(actual));
  });

  return assertion;
}

function expect(actual) {
  return makeAssertion(actual, false);
}

/* ------------------------------------------------------------------ */
/* Suite / test registry                                                */
/* ------------------------------------------------------------------ */

function newSuite(name, parent) {
  return {
    name,
    parent,
    items: [],
    beforeAll: [],
    afterAll: [],
    beforeEach: [],
    afterEach: [],
    registrationError: null,
  };
}

const rootSuite = newSuite(null, null);
let currentSuite = rootSuite;

function describe(name, fn) {
  const suite = newSuite(String(name), currentSuite);
  currentSuite.items.push({ kind: 'suite', suite });
  const previous = currentSuite;
  currentSuite = suite;
  try {
    fn();
  } catch (err) {
    suite.registrationError = err;
  } finally {
    currentSuite = previous;
  }
}

/**
 * Accepts both the 2-argument form `it(name, fn)` and the DevEco-generated
 * 3-argument form `it(name, filter, fn)`.
 */
function it(name, filterOrFn, maybeFn) {
  const fn = typeof filterOrFn === 'function' ? filterOrFn : maybeFn;
  currentSuite.items.push({ kind: 'test', name: String(name), fn, suite: currentSuite });
}

function beforeAll(fn) {
  currentSuite.beforeAll.push(fn);
}

function beforeEach(fn) {
  currentSuite.beforeEach.push(fn);
}

function afterEach(fn) {
  currentSuite.afterEach.push(fn);
}

function afterAll(fn) {
  currentSuite.afterAll.push(fn);
}

function suitePath(suite) {
  const parts = [];
  let cursor = suite;
  while (cursor && cursor !== rootSuite) {
    parts.unshift(cursor.name);
    cursor = cursor.parent;
  }
  return parts;
}

function suiteFullName(suite) {
  return suitePath(suite).join(' ');
}

function testFullName(test) {
  return suitePath(test.suite).concat([test.name]).join(' ');
}

/* ------------------------------------------------------------------ */
/* Runner                                                               */
/* ------------------------------------------------------------------ */

function recordFailure(stats, name, err) {
  stats.failed += 1;
  stats.failures.push({
    name,
    message: errorMessage(err),
    stack: err && err.stack ? String(err.stack) : undefined,
  });
}

async function runHookList(hooks, stats, label) {
  for (const hook of hooks) {
    try {
      await hook();
    } catch (err) {
      recordFailure(stats, label, err);
    }
  }
}

async function runTest(test, chain, filter, stats) {
  const fullName = testFullName(test);
  if (filter && !fullName.includes(filter)) {
    stats.skipped += 1;
    return;
  }

  stats.total += 1;

  const befores = [];
  for (const suite of chain) befores.push(...suite.beforeEach);
  const afters = [];
  for (let i = chain.length - 1; i >= 0; i--) afters.push(...chain[i].afterEach);

  let error = null;
  for (const hook of befores) {
    try {
      await hook();
    } catch (err) {
      error = err;
      break;
    }
  }

  if (!error) {
    try {
      await test.fn();
    } catch (err) {
      error = err;
    }
  }

  for (const hook of afters) {
    try {
      await hook();
    } catch (err) {
      if (!error) error = err;
    }
  }

  if (error) {
    recordFailure(stats, fullName, error);
    if (process.env.DSH_TEST_VERBOSE) console.log('  FAIL ' + fullName + ' :: ' + errorMessage(error));
  } else {
    stats.passed += 1;
    if (process.env.DSH_TEST_VERBOSE) console.log('  ok   ' + fullName);
  }
}

async function runSuite(suite, chain, filter, stats) {
  const nextChain = chain.concat([suite]);
  const suiteName = suiteFullName(suite) || '(root)';

  if (suite.registrationError) {
    recordFailure(stats, suiteName + ' (describe)', suite.registrationError);
  }

  await runHookList(suite.beforeAll, stats, suiteName + ' (beforeAll)');

  for (const item of suite.items) {
    if (item.kind === 'suite') {
      await runSuite(item.suite, nextChain, filter, stats);
    } else {
      await runTest(item, nextChain, filter, stats);
    }
  }

  await runHookList(suite.afterAll, stats, suiteName + ' (afterAll)');
}

function printReport(stats, durationMs) {
  const filter = (process.env.DSH_TEST_FILTER || '').trim();
  console.log('');
  console.log(
    '[hypium@node] total: ' + stats.total +
    ', passed: ' + stats.passed +
    ', failed: ' + stats.failed +
    (stats.skipped ? ', filtered out: ' + stats.skipped : '') +
    (filter ? ' (filter: ' + JSON.stringify(filter) + ')' : '') +
    ' [' + durationMs + 'ms]'
  );

  if (stats.failures.length > 0) {
    console.log('');
    console.log('[hypium@node] failures:');
    for (const failure of stats.failures) {
      console.log('  - ' + failure.name + ': ' + failure.message);
      if (process.env.DSH_TEST_VERBOSE && failure.stack) {
        console.log('    ' + failure.stack.split('\n').join('\n    '));
      }
    }
  }
  console.log('');
}

async function __runAll() {
  const filter = (process.env.DSH_TEST_FILTER || '').trim();
  const stats = { total: 0, passed: 0, failed: 0, skipped: 0, failures: [] };
  const startedAt = Date.now();
  await runSuite(rootSuite, [], filter, stats);
  const durationMs = Date.now() - startedAt;
  printReport(stats, durationMs);
  return stats;
}

/* ------------------------------------------------------------------ */
/* Exports                                                             */
/* ------------------------------------------------------------------ */

const hypium = {
  describe,
  it,
  beforeAll,
  beforeEach,
  afterEach,
  afterAll,
  expect,
  __runAll,
  AssertionError,
};

module.exports = hypium;
module.exports.default = hypium;
Object.defineProperty(module.exports, '__esModule', { value: true });
