/**
 * Host-side (Node.js) stand-in for the `BusinessError` export of
 * `@kit.BasicServicesKit`.
 */

declare class BusinessError extends Error {
  code: number;
  name: string;
  data?: Object;
  constructor(code?: number, message?: string);
}

export { BusinessError };
