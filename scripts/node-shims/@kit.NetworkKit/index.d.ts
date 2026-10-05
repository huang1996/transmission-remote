/**
 * Host-side (Node.js) stand-in for the `http` part of `@kit.NetworkKit`.
 *
 * This gives SDK sources something to type-check against. Calling
 * `createHttp().request()` at runtime throws: this shim exists so that files
 * which *import* the network kit still load under Node.js, not so that real
 * network calls can be made in unit tests.
 */

export namespace http {
  export enum RequestMethod {
    OPTIONS = 'OPTIONS',
    GET = 'GET',
    HEAD = 'HEAD',
    POST = 'POST',
    PUT = 'PUT',
    DELETE = 'DELETE',
    TRACE = 'TRACE',
    CONNECT = 'CONNECT',
  }

  export enum HttpDataType {
    STRING = 0,
    OBJECT = 1,
    ARRAY_BUFFER = 2,
  }

  export interface HttpRequestOptions {
    method?: RequestMethod;
    header?: Record<string, string>;
    extraData?: string | Object | ArrayBuffer;
    connectTimeout?: number;
    readTimeout?: number;
    expectDataType?: HttpDataType;
  }

  export interface HttpResponse {
    result: string | Object | ArrayBuffer;
    responseCode: number;
    header: Object;
    cookies: string;
  }

  export class HttpRequest {
    request(url: string, options?: HttpRequestOptions): Promise<HttpResponse>;
    destroy(): void;
    on(type: string, cb: Function): void;
    off(type: string, cb?: Function): void;
  }

  export function createHttp(): HttpRequest;
}
