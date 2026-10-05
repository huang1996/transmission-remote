/**
 * Host-side (Node.js) stand-in for `@ohos.hilog`.
 *
 * Only the logging entry points that SDK code realistically uses are declared.
 * The runtime is silent unless the DSH_TEST_VERBOSE environment variable is set.
 */

declare namespace hilog {
  function debug(domain: number, tag: string, format: string, ...args: any[]): void;
  function info(domain: number, tag: string, format: string, ...args: any[]): void;
  function warn(domain: number, tag: string, format: string, ...args: any[]): void;
  function error(domain: number, tag: string, format: string, ...args: any[]): void;
  function fatal(domain: number, tag: string, format: string, ...args: any[]): void;
  function isLoggable(domain: number, tag: string, level: number): boolean;
}

export default hilog;
export { hilog };
