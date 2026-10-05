/**
 * Host-side (Node.js) stand-in for the `@ohos/hypium` test framework.
 *
 * This declaration file mirrors the tiny slice of the hypium API that ArkTS
 * unit tests use. It is intentionally self-contained: nothing from the real
 * hypium runtime is required to type-check against it.
 */

declare function describe(name: string, fn: () => void): void;
declare function it(name: string, fn: () => void | Promise<void>): void;
// DevEco Studio's generated test template uses the 3-argument hypium form
// `it(name, filter, fn)`, where `filter` is a TestType/Size/Level bitmask.
declare function it(name: string, filter: number, fn: () => void | Promise<void>): void;
declare function beforeAll(fn: () => void | Promise<void>): void;
declare function beforeEach(fn: () => void | Promise<void>): void;
declare function afterEach(fn: () => void | Promise<void>): void;
declare function afterAll(fn: () => void | Promise<void>): void;
declare function expect(actual: any): Assertion;

interface Assertion {
  assertEqual(expected: any): void;
  assertNotEqual(expected: any): void;
  assertTrue(): void;
  assertFalse(): void;
  assertNull(): void;
  assertUndefined(): void;
  assertDeepEquals(expected: any): void;
  assertContain(expected: any): void;
  assertLarger(expected: any): void;
  assertLess(expected: any): void;
  assertThrowError(expected?: any): void;
  assertInstanceOf(expected: any): void;
  not: Assertion;
}

interface HypiumFailure {
  name: string;
  message: string;
  stack?: string;
}

interface HypiumRunResult {
  total: number;
  passed: number;
  failed: number;
  skipped: number;
  failures: HypiumFailure[];
}

declare namespace hypium {
  export {
    describe,
    it,
    beforeAll,
    beforeEach,
    afterEach,
    afterAll,
    expect,
    Assertion,
    HypiumFailure,
    HypiumRunResult,
  };
  export function __runAll(): Promise<HypiumRunResult>;
}

/**
 * hypium also supports the global (import-less) style inside ArkTS test files.
 * The declarations below are only used by files that do not import the module.
 */
declare global {
  function describe(name: string, fn: () => void): void;
  function it(name: string, fn: () => void | Promise<void>): void;
  function it(name: string, filter: number, fn: () => void | Promise<void>): void;
  function beforeAll(fn: () => void | Promise<void>): void;
  function beforeEach(fn: () => void | Promise<void>): void;
  function afterEach(fn: () => void | Promise<void>): void;
  function afterAll(fn: () => void | Promise<void>): void;
  function expect(actual: any): Assertion;
}

export default hypium;
export { describe, it, beforeAll, beforeEach, afterEach, afterAll, expect };
export type { Assertion, HypiumFailure, HypiumRunResult };
