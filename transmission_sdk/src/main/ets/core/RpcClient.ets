// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * The RPC engine.
 *
 * `RpcClient` owns everything that is protocol plumbing rather than API
 * surface: request numbering, the CSRF session-id handshake, dialect
 * negotiation, HTTP error mapping and batch dispatch. Service classes
 * (`api/`) are thin, readable wrappers around {@link RpcClient.call}.
 *
 * ### Request lifecycle
 *
 * ```
 * call(method, params)
 *   └─ encode with the negotiated codec
 *       └─ POST to the configured endpoint
 *           ├─ 409 → capture session id + dialect hint, retry (once)
 *           ├─ 401 → TransmissionError(authentication)
 *           ├─ 200 → decode
 *           │        ├─ METHOD_NOT_FOUND in AUTO mode → downgrade, retry (once)
 *           │        └─ success | RPC error
 *           └─ other → TransmissionError(http)
 * ```
 *
 * At most three HTTP round trips can occur for a single call, and only on a
 * first contact with an old server.
 *
 * @since 1.0.0
 */

import { Json, JsonObject, JsonValue } from '../util/Json';
import { Logger, NoopLogger } from '../util/Logger';
import { Base64 } from '../util/Base64';
import { RpcErrorCode, TransmissionError } from '../error/TransmissionError';
import { ApiStyle } from '../compat/ApiStyle';
import { RpcCall, RpcCodec, RpcOutcome } from '../compat/RpcCodec';
import { StyleNegotiator } from '../compat/StyleNegotiator';
import { RpcMethod } from '../constants/RpcMethods';
import {
  CONTENT_TYPE_JSON,
  HEADER_AUTHORIZATION,
  HEADER_CONTENT_TYPE,
  HEADER_RPC_VERSION,
  HEADER_SESSION_ID,
  HttpStatus,
  WireKeys,
} from '../constants/WireProtocol';
import { HttpRequest, HttpResponse, HttpTransport, HttpVerb } from '../transport/HttpTransport';
import { RpcVersion } from '../util/Semver';
import { TransmissionConfig } from './TransmissionConfig';

/** Log tag used by this class. */
const LOG_TAG: string = 'RpcClient';

/** Hard cap on HTTP attempts for a single logical call. */
const MAX_ATTEMPTS: number = 4;

/** How many times a stale CSRF session id may be refreshed within one call. */
const MAX_SESSION_REFRESHES: number = 2;

/**
 * Sends RPC calls to a Transmission server.
 *
 * Prefer the high-level `TransmissionClient` facade; this class is public so
 * that advanced callers can issue methods the SDK does not wrap yet.
 */
export class RpcClient {
  private readonly config: TransmissionConfig;
  private readonly transport: HttpTransport;
  private readonly negotiator: StyleNegotiator;
  private readonly logger: Logger;
  private sessionId: string | undefined;
  private nextRequestId: number = 1;
  private closed: boolean = false;

  /**
   * @param config validated client configuration
   * @param transport HTTP transport to use
   * @param negotiator shared dialect negotiator
   * @param logger diagnostics sink
   */
  constructor(config: TransmissionConfig, transport: HttpTransport, negotiator: StyleNegotiator, logger?: Logger) {
    this.config = config;
    this.transport = transport;
    this.negotiator = negotiator;
    this.logger = logger ?? new NoopLogger();
    this.sessionId = config.sessionId;
  }

  /** Dialect currently in use. */
  get currentStyle(): ApiStyle {
    return this.negotiator.currentStyle;
  }

  /** True while the dialect is still being negotiated. */
  get isNegotiating(): boolean {
    return this.negotiator.isAuto;
  }

  /** RPC version reported by the server, once observed. */
  get serverVersion(): RpcVersion | undefined {
    return this.negotiator.serverVersion;
  }

  /** The CSRF session id, for applications that persist it between launches. */
  get currentSessionId(): string | undefined {
    return this.sessionId;
  }

  /** True once {@link close} has been called. */
  get isClosed(): boolean {
    return this.closed;
  }

  /**
   * Invokes a method and returns its result object.
   *
   * @param method canonical method name
   * @param params canonical parameters
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async call(method: RpcMethod, params?: JsonObject): Promise<JsonObject> {
    const outcome = await this.execute(new RpcCall(method, params));
    if (!outcome.isSuccess) {
      throw outcome.toError(`${method} ${this.config.url}`);
    }
    if (method === RpcMethod.SESSION_GET) {
      // Opportunistically refine the negotiated dialect/version from the reply.
      this.negotiator.observeSessionFields(outcome.result);
      this.logger.debug(LOG_TAG, `negotiated api style=${this.negotiator.currentStyle}`);
    }
    return outcome.resultOrEmpty;
  }

  /**
   * Invokes several methods in a single HTTP round trip.
   *
   * Both dialects support a top-level JSON array of requests. Failures are
   * reported per element so one bad call does not discard the others.
   *
   * @param calls canonical calls to perform
   * @returns one outcome per call, in the same order
   */
  async callBatch(calls: RpcCall[]): Promise<RpcOutcome[]> {
    if (calls.length === 0) {
      return [];
    }
    if (this.closed) {
      throw TransmissionError.transport('the client has been closed', this.config.url);
    }

    const requestId = this.nextRequestId++;
    let sessionRefreshes = 0;
    let styleRetries = 0;

    for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
      const codec = this.negotiator.codec();
      const encoded = calls.map((call: RpcCall) => codec.encodeRequest(call, requestId));
      const response = await this.send(JSON.stringify(codec.encodeBatch(encoded)), true);

      if (response.status === HttpStatus.CONFLICT) {
        sessionRefreshes++;
        if (sessionRefreshes > MAX_SESSION_REFRESHES) {
          throw TransmissionError.protocol('the server kept rejecting the CSRF session id', this.config.url);
        }
        this.handleConflict(response);
        continue;
      }

      const outcomes = this.decode(response, (raw: JsonValue) => codec.decodeBatch(raw));
      if (this.shouldDowngrade(codec, outcomes)) {
        styleRetries++;
        if (styleRetries <= 1 && this.negotiator.observeMethodNotFound()) {
          this.logger.info(LOG_TAG, 'server rejected the modern API; retrying in legacy mode');
          continue;
        }
      }
      return outcomes;
    }

    throw TransmissionError.protocol('the request could not be completed after several attempts', this.config.url);
  }

  /**
   * Sends a caller-built JSON body verbatim.
   *
   * Escape hatch for RPC methods or payload shapes the SDK does not model. The
   * body is not passed through the compatibility layer, so callers talking to
   * pre-4.1.0 servers must spell out the legacy shape themselves.
   *
   * @param body a complete JSON-RPC or legacy request object
   */
  async callRaw(body: JsonObject): Promise<JsonObject> {
    if (this.closed) {
      throw TransmissionError.transport('the client has been closed', this.config.url);
    }
    for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
      const response = await this.send(JSON.stringify(body), true);
      if (response.status === HttpStatus.CONFLICT) {
        this.handleConflict(response);
        continue;
      }
      const outcome = this.decode(response, (raw: JsonValue) => this.negotiator.codec().decodeResponse(raw));
      if (!outcome.isSuccess) {
        throw outcome.toError(this.config.url);
      }
      return outcome.resultOrEmpty;
    }
    throw TransmissionError.protocol('the request could not be completed after several attempts', this.config.url);
  }

  /**
   * Overrides the CSRF session id.
   *
   * Applications that persist the id can restore it here instead of waiting for
   * a 409 on the next launch.
   */
  setSessionId(sessionId: string | undefined): void {
    this.sessionId = sessionId;
  }

  /** Releases the transport. The client cannot be used afterwards. */
  close(): void {
    if (!this.closed) {
      this.closed = true;
      this.transport.destroy();
    }
  }

  /** Runs a single call through the retry state machine. */
  private async execute(call: RpcCall): Promise<RpcOutcome> {
    if (this.closed) {
      throw TransmissionError.transport('the client has been closed', this.config.url);
    }

    const requestId = this.nextRequestId++;
    let sessionRefreshes = 0;
    let styleRetries = 0;

    for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
      const codec: RpcCodec = this.negotiator.codec();
      const encoded = codec.encodeRequest(call, requestId);
      const response = await this.send(JSON.stringify(encoded), false);

      if (response.status === HttpStatus.CONFLICT) {
        sessionRefreshes++;
        if (sessionRefreshes > MAX_SESSION_REFRESHES) {
          throw TransmissionError.protocol('the server kept rejecting the CSRF session id', this.config.url);
        }
        this.handleConflict(response);
        continue;
      }

      const outcome = this.decode(response, (raw: JsonValue) => codec.decodeResponse(raw));
      if (this.isDialectMismatch(codec, outcome)) {
        styleRetries++;
        if (styleRetries <= 1 && this.negotiator.observeMethodNotFound()) {
          if (outcome.isSuccess) {
            // The payload decoded cleanly, so hand it back and simply stop
            // speaking the modern dialect from here on.
            this.logger.info(LOG_TAG, 'server answered in the legacy envelope; switching dialect');
            return outcome;
          }
          this.logger.info(LOG_TAG, 'server rejected the modern API; retrying in legacy mode');
          continue;
        }
      }
      return outcome;
    }

    throw TransmissionError.protocol('the request could not be completed after several attempts', this.config.url);
  }

  /**
   * True when the reply proves the request was written in the wrong dialect.
   *
   * Two independent signals, in order of reliability:
   *
   * 1. **Envelope shape.** A legacy-shaped reply to a modern request means the
   *    server has no JSON-RPC support at all. This does not depend on the error
   *    text, which varies between releases.
   * 2. **`METHOD_NOT_FOUND`.** The fallback for the case where the session id was
   *    already cached, so no 409 exposed the dialect, and the reply happens to
   *    be JSON-RPC shaped.
   *
   * @param codec the codec the request was encoded with
   * @param outcome the decoded reply
   */
  private isDialectMismatch(codec: RpcCodec, outcome: RpcOutcome): boolean {
    if (codec.style !== ApiStyle.MODERN) {
      return false;
    }
    if (outcome.legacyEnvelope) {
      return true;
    }
    return !outcome.isSuccess && outcome.error?.code === RpcErrorCode.METHOD_NOT_FOUND;
  }

  /** True when any element of `outcomes` indicates a dialect mismatch. */
  private shouldDowngrade(codec: RpcCodec, outcomes: RpcOutcome[]): boolean {
    return outcomes.some((outcome: RpcOutcome) => this.isDialectMismatch(codec, outcome));
  }

  /** Applies the CSRF hints carried by a 409 response. */
  private handleConflict(response: HttpResponse): void {
    const sessionId = response.header(HEADER_SESSION_ID);
    if (sessionId === undefined || sessionId.length === 0) {
      throw TransmissionError.protocol(
        'the server returned HTTP 409 without an X-Transmission-Session-Id header',
        this.config.url,
      );
    }
    this.setSessionId(sessionId);
    this.negotiator.observeVersionHeader(response.header(HEADER_RPC_VERSION));
    this.logger.debug(
      LOG_TAG,
      `csrf handshake ok, style=${this.negotiator.currentStyle} version=${this.negotiator.serverVersion?.toString() ?? 'unknown'}`,
    );
  }

  /** Validates the HTTP status and decodes the body. */
  private decode<T>(response: HttpResponse, decoder: (raw: JsonValue) => T): T {
    const request = `${HttpVerb.POST} ${this.config.url}`;
    switch (response.status) {
      case HttpStatus.OK:
        break;
      case HttpStatus.NO_CONTENT:
        throw TransmissionError.protocol('the server returned an empty response', request);
      case HttpStatus.UNAUTHORIZED:
        throw TransmissionError.authentication(
          'authentication failed; check the configured username and password',
          response.status,
          request,
        );
      case HttpStatus.FORBIDDEN:
        throw TransmissionError.http(
          'the server refused the request; the host may be missing from rpc_host_whitelist',
          response.status,
          request,
        );
      default:
        throw TransmissionError.http(`unexpected HTTP status ${response.status}`, response.status, request);
    }

    if (response.body.length === 0) {
      throw TransmissionError.protocol('the server returned an empty body', request);
    }

    let parsed: JsonValue;
    try {
      parsed = Json.parse(response.body);
    } catch (error) {
      throw TransmissionError.protocol(
        `the server returned malformed JSON: ${(error as Error).message}`,
        request,
      );
    }
    return decoder(parsed);
  }

  /** Builds and executes the HTTP request. */
  private async send(body: string, isBatch: boolean): Promise<HttpResponse> {
    const headers = new Map<string, string>();
    headers.set(HEADER_CONTENT_TYPE, CONTENT_TYPE_JSON);
    headers.set('accept', CONTENT_TYPE_JSON);
    if (this.sessionId !== undefined && this.sessionId.length > 0) {
      headers.set(HEADER_SESSION_ID, this.sessionId);
    }
    if (this.config.username !== undefined && this.config.username.length > 0) {
      headers.set(HEADER_AUTHORIZATION, Base64.basicAuthorization(this.config.username, this.config.password ?? ''));
    }
    this.config.headers.forEach((value: string, key: string) => {
      headers.set(key.toLowerCase(), value);
    });

    const request = new HttpRequest(this.config.url, HttpVerb.POST, headers, body, this.config.timeoutMs);
    this.logger.debug(LOG_TAG, `--> ${isBatch ? 'batch ' : ''}${request.description}`);

    let response: HttpResponse;
    try {
      response = await this.transport.execute(request);
    } catch (error) {
      if (error instanceof TransmissionError) {
        throw error;
      }
      throw TransmissionError.transport(
        `the request failed: ${(error as Error).message ?? 'unknown error'}`,
        request.description,
        error as Error,
      );
    }

    this.logger.debug(LOG_TAG, `<-- ${response.status} (${response.body.length} bytes)`);
    return response;
  }
}
