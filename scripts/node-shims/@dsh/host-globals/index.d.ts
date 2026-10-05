/**
 * Type-only shim that adds the handful of globals the ArkTS runtime provides
 * (console, timers, queueMicrotask, `$r`) to the otherwise DOM-free `ES2021` lib.
 *
 * The build intentionally uses `"lib": ["ES2021"]` so that DOM-only APIs are
 * not accidentally made type-checkable. ArkTS still ships `console` and the
 * timer functions, and unit tests commonly `await new Promise(setTimeout)`,
 * so they are declared here instead of pulling in the whole DOM lib.
 *
 * There is no runtime behaviour.
 */

interface HostConsole {
  log(...data: any[]): void;
  info(...data: any[]): void;
  debug(...data: any[]): void;
  warn(...data: any[]): void;
  error(...data: any[]): void;
  trace(...data: any[]): void;
  dir(...data: any[]): void;
  assert(condition?: boolean, ...data: any[]): void;
  time(label?: string): void;
  timeEnd(label?: string): void;
}

declare global {
  /**
   * The subset of the ArkTS `Resource` shape the app relies on.
   *
   * Only `id` is ever read; the rest is declared so that structural uses such as
   * `progressColor: Resource` type-check. It lives inside `declare global`
   * because this file is a module, so a top-level interface would stay module
   * scoped and never satisfy the app sources.
   */
  interface Resource {
    id: number;
    type?: number;
    params?: Array<string | number>;
    bundleName: string;
    moduleName: string;
  }

  var console: HostConsole;

  /**
   * Resolves a resource reference such as `$r('app.color.accent')`.
   *
   * The stub returns a synthetic handle rather than reading the generated
   * resource files: these tests cover the app's *logic*, not its styling, and
   * `scripts/lint-arkts.mjs` already proves every reference resolves.
   */
  function $r(name: string, ...params: Array<string | number>): Resource;

  function setTimeout(handler: (...args: any[]) => void, timeout?: number, ...args: any[]): number;
  function clearTimeout(id?: number): void;
  function setInterval(handler: (...args: any[]) => void, timeout?: number, ...args: any[]): number;
  function clearInterval(id?: number): void;
  function queueMicrotask(callback: () => void): void;
}

export {};
