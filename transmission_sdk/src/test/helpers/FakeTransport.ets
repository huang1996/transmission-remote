// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Scripted {@link HttpTransport} for unit tests.
 *
 * The SDK's only outward dependency is the transport port, so replacing it with
 * a queue of canned responses is enough to exercise the whole client — session
 * id handling, dialect negotiation, error mapping and model parsing — without a
 * server, a network, or a platform.
 *
 * @since 1.0.0
 */

import { HttpRequest, HttpResponse, HttpTransport } from '../../main/ets/transport/HttpTransport';
import { JsonValue } from '../../main/ets/util/Json';
import { HEADER_SESSION_ID, HEADER_RPC_VERSION, HttpStatus } from '../../main/ets/constants/WireProtocol';

/** Builds a lower-cased header map from alternating key/value arguments. */
export function headers(...pairs: string[]): Map<string, string> {
  const map = new Map<string, string>();
  for (let i = 0; i + 1 < pairs.length; i += 2) {
    map.set(pairs[i].toLowerCase(), pairs[i + 1]);
  }
  return map;
}

/** A single scripted response. */
export class ScriptedResponse {
  /** HTTP status to return. */
  readonly status: number;
  /** Response body. */
  readonly body: string;
  /** Response headers. */
  readonly responseHeaders: Map<string, string>;

  constructor(status: number, body: string, responseHeaders: Map<string, string>) {
    this.status = status;
    this.body = body;
    this.responseHeaders = responseHeaders;
  }

  /** A `200 OK` carrying `body` verbatim. */
  static ok(body: string, responseHeaders?: Map<string, string>): ScriptedResponse {
    return new ScriptedResponse(HttpStatus.OK, body, responseHeaders === undefined ? new Map<string, string>() : responseHeaders);
  }

  /** A `200 OK` carrying a serialised JSON value. */
  static json(body: JsonValue, responseHeaders?: Map<string, string>): ScriptedResponse {
    return ScriptedResponse.ok(JSON.stringify(body), responseHeaders);
  }

  /**
   * The CSRF challenge every Transmission server sends first.
   *
   * @param sessionId value of `X-Transmission-Session-Id`
   * @param rpcVersion value of `X-Transmission-Rpc-Version`; omit it to mimic a
   *        server older than 4.1.0, which never sends the header
   */
  static csrf(sessionId: string, rpcVersion?: string): ScriptedResponse {
    const map = new Map<string, string>();
    map.set(HEADER_SESSION_ID, sessionId);
    if (rpcVersion !== undefined) {
      map.set(HEADER_RPC_VERSION, rpcVersion);
    }
    return new ScriptedResponse(HttpStatus.CONFLICT, '', map);
  }

  /** A `401 Unauthorized` response. */
  static unauthorized(): ScriptedResponse {
    return new ScriptedResponse(HttpStatus.UNAUTHORIZED, '', new Map<string, string>());
  }

  /** A `500 Internal Server Error` response. */
  static serverError(body: string = 'boom'): ScriptedResponse {
    return new ScriptedResponse(500, body, new Map<string, string>());
  }
}

/** One request captured by {@link FakeTransport}. */
export class RecordedRequest {
  /** The request as the SDK built it. */
  readonly request: HttpRequest;

  constructor(request: HttpRequest) {
    this.request = request;
  }

  /** Request body. */
  get body(): string {
    return this.request.body === undefined ? '' : this.request.body;
  }

  /** Parsed request body. */
  get json(): Record<string, JsonValue> {
    return JSON.parse(this.body) as Record<string, JsonValue>;
  }

  /** Value of a response header, or `undefined`. */
  header(name: string): string | undefined {
    return this.request.headers.get(name.toLowerCase());
  }
}

/**
 * An {@link HttpTransport} that replays a scripted list of responses and records
 * every request it receives.
 */
export class FakeTransport implements HttpTransport {
  private readonly script: ScriptedResponse[] = [];
  private fallback: ScriptedResponse | undefined;
  private readonly recorded: RecordedRequest[] = [];
  private destroyed: boolean = false;
  private failure: Error | undefined;

  /** Creates an empty transport. */
  static create(): FakeTransport {
    return new FakeTransport();
  }

  /**
   * Queues a response.
   *
   * Queued responses are consumed in order; once the queue is empty the
   * fallback (see {@link always}) is used, and failing that an empty `200`.
   */
  enqueue(response: ScriptedResponse): FakeTransport {
    this.script.push(response);
    return this;
  }

  /** Queues a `200 OK` JSON response. */
  enqueueJson(body: JsonValue): FakeTransport {
    return this.enqueue(ScriptedResponse.json(body));
  }

  /** Queues the CSRF challenge. */
  enqueueCsrf(sessionId: string, rpcVersion?: string): FakeTransport {
    return this.enqueue(ScriptedResponse.csrf(sessionId, rpcVersion));
  }

  /** Sets the response used once the queue is exhausted. */
  always(response: ScriptedResponse): FakeTransport {
    this.fallback = response;
    return this;
  }

  /** Makes every request reject with `error`, simulating a network failure. */
  failWith(error: Error): FakeTransport {
    this.failure = error;
    return this;
  }

  execute(request: HttpRequest): Promise<HttpResponse> {
    this.recorded.push(new RecordedRequest(request));
    if (this.failure !== undefined) {
      return Promise.reject(this.failure);
    }
    const scripted = this.script.length > 0 ? this.script.shift() : undefined;
    const response = scripted === undefined ? (this.fallback === undefined ? ScriptedResponse.ok('{}') : this.fallback) : scripted;
    return Promise.resolve(new HttpResponse(response.status, response.responseHeaders, response.body));
  }

  destroy(): void {
    this.destroyed = true;
  }

  /** True once {@link destroy} has been called. */
  get isDestroyed(): boolean {
    return this.destroyed;
  }

  /** Number of requests received. */
  get callCount(): number {
    return this.recorded.length;
  }

  /** Requests received, in order. */
  get requests(): RecordedRequest[] {
    return this.recorded;
  }

  /** The most recent request, or `undefined`. */
  get lastRequest(): RecordedRequest | undefined {
    return this.recorded.length === 0 ? undefined : this.recorded[this.recorded.length - 1];
  }

  /** Parsed bodies of every request received. */
  get bodies(): Record<string, JsonValue>[] {
    const result: Record<string, JsonValue>[] = [];
    for (const recorded of this.recorded) {
      result.push(recorded.json);
    }
    return result;
  }

  /** Every method name the caller invoked, in order. */
  get methods(): string[] {
    const result: string[] = [];
    for (const recorded of this.recorded) {
      const method = recorded.json['method'];
      result.push(typeof method === 'string' ? method : '');
    }
    return result;
  }
}
