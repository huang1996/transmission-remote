// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Transport abstraction.
 *
 * The SDK talks to the network exclusively through {@link HttpTransport}. That
 * single seam is what makes the whole client testable without a server: unit
 * tests inject a scripted fake, while production code uses
 * `platform/ArkHttpTransport` (backed by `@kit.NetworkKit`).
 *
 * @since 1.0.0
 */

/** HTTP verbs used by the RPC protocol. */
export enum HttpVerb {
  /** Used for nothing today, but kept for completeness/custom transports. */
  GET = 'GET',
  /** Every RPC call is a JSON `POST`. */
  POST = 'POST',
}

/** An outbound HTTP request. */
export class HttpRequest {
  /** Absolute URL. */
  readonly url: string;
  /** HTTP verb. */
  readonly verb: HttpVerb;
  /** Request headers. Names must be lower-case. */
  readonly headers: Map<string, string>;
  /** Request body, or `undefined` for body-less requests. */
  readonly body: string | undefined;
  /** Timeout in milliseconds. */
  readonly timeoutMs: number;

  constructor(url: string, verb: HttpVerb, headers: Map<string, string>, body: string | undefined, timeoutMs: number) {
    this.url = url;
    this.verb = verb;
    this.headers = headers;
    this.body = body;
    this.timeoutMs = timeoutMs;
  }

  /** `"POST https://host/transmission/rpc"`, for diagnostics. */
  get description(): string {
    return `${this.verb} ${this.url}`;
  }
}

/** An inbound HTTP response. */
export class HttpResponse {
  /** HTTP status code. */
  readonly status: number;
  /** Response headers. Names must be lower-case. */
  readonly headers: Map<string, string>;
  /** Response body; empty string when the server sent none. */
  readonly body: string;

  constructor(status: number, headers: Map<string, string>, body: string) {
    this.status = status;
    this.headers = headers;
    this.body = body;
  }

  /**
   * Case-insensitive header lookup.
   *
   * @param name header name; lower-cased by this method
   */
  header(name: string): string | undefined {
    return this.headers.get(name.toLowerCase());
  }
}

/** Performs HTTP requests. */
export interface HttpTransport {
  /** Executes `request`. Implementations must reject only on transport errors. */
  execute(request: HttpRequest): Promise<HttpResponse>;

  /** Releases pooled resources. Safe to call more than once. */
  destroy(): void;
}

/**
 * Convenience base class for transports that own a disposable HTTP client.
 */
export abstract class AbstractHttpTransport implements HttpTransport {
  private disposed: boolean = false;

  abstract execute(request: HttpRequest): Promise<HttpResponse>;

  destroy(): void {
    if (!this.disposed) {
      this.disposed = true;
      this.onDestroy();
    }
  }

  /** True once {@link destroy} has run. */
  protected get isDisposed(): boolean {
    return this.disposed;
  }

  /** Releases subclass-owned resources. */
  protected abstract onDestroy(): void;
}
