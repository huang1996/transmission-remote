// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Fluent construction of a {@link TransmissionClient}.
 *
 * The builder exists so that the parts an application wants to replace — the
 * HTTP transport, the logger, the persistence of a previously negotiated
 * dialect — can be injected without the core classes knowing about them.
 *
 * ```ts
 * const client = new TransmissionClientBuilder()
 *   .url('http://192.168.1.10:9091/transmission/rpc')
 *   .credentials('admin', 'secret')
 *   .apiStyleMode(ApiStyleMode.AUTO)
 *   .timeout(10_000)
 *   .logger(new HilogLogger(LogLevel.INFO))
 *   .build();
 * ```
 *
 * @since 1.0.0
 */

import { Logger, NoopLogger } from '../util/Logger';
import { ApiStyleMode } from '../compat/ApiStyle';
import { ApiStyleListener, StyleNegotiator } from '../compat/StyleNegotiator';
import { RpcClient } from '../core/RpcClient';
import { TransmissionConfig } from '../core/TransmissionConfig';
import { HttpTransport } from '../transport/HttpTransport';
import { ArkHttpTransport } from '../platform/ArkHttpTransport';
import { TransmissionClient } from './TransmissionClient';

/**
 * Collects the inputs of {@link TransmissionClient} and validates them in
 * {@link build}.
 */
export class TransmissionClientBuilder {
  private configuration: TransmissionConfig = TransmissionConfig.of();
  private httpTransport: HttpTransport | undefined;
  private logSink: Logger | undefined;
  private styleListener: ApiStyleListener | undefined;

  /** Returns a fresh builder. */
  static create(): TransmissionClientBuilder {
    return new TransmissionClientBuilder();
  }

  /** Uses a fully prepared configuration object. */
  config(config: TransmissionConfig): TransmissionClientBuilder {
    this.configuration = config;
    return this;
  }

  /**
   * Sets the RPC endpoint.
   *
   * @param url e.g. `http://127.0.0.1:9091/transmission/rpc`
   */
  url(url: string): TransmissionClientBuilder {
    this.configuration.withUrl(url);
    return this;
  }

  /**
   * Points the client at a host using Transmission's conventional port/path.
   *
   * @param host host name or IP address
   * @param port RPC port, defaults to 9091
   * @param path RPC path, defaults to `/transmission/rpc`
   */
  host(host: string, port?: number, path?: string): TransmissionClientBuilder {
    const portOrDefault = port === undefined ? 9091 : port;
    const pathOrDefault = path === undefined ? '/transmission/rpc' : path;
    return this.config(TransmissionConfig.forHost(host, portOrDefault, pathOrDefault));
  }

  /** Sets HTTP Basic credentials. */
  credentials(username: string, password: string): TransmissionClientBuilder {
    this.configuration.withCredentials(username, password);
    return this;
  }

  /**
   * Pins the wire dialect instead of negotiating it.
   *
   * Leave it at {@link ApiStyleMode.AUTO} unless the application has a reason to
   * avoid the extra round trip on the very first request.
   */
  apiStyleMode(mode: ApiStyleMode): TransmissionClientBuilder {
    this.configuration.withApiStyleMode(mode);
    return this;
  }

  /** Sets the per-request timeout in milliseconds. */
  timeout(timeoutMs: number): TransmissionClientBuilder {
    this.configuration.withTimeout(timeoutMs);
    return this;
  }

  /** Adds a header to every request, e.g. for a reverse proxy. */
  header(name: string, value: string): TransmissionClientBuilder {
    this.configuration.withHeader(name, value);
    return this;
  }

  /** Restores a CSRF session id captured during a previous run. */
  sessionId(sessionId: string | undefined): TransmissionClientBuilder {
    this.configuration.withSessionId(sessionId);
    return this;
  }

  /**
   * Replaces the HTTP transport.
   *
   * The default is {@link ArkHttpTransport}; tests and non-HarmonyOS hosts
   * inject their own implementation.
   */
  transport(transport: HttpTransport): TransmissionClientBuilder {
    this.httpTransport = transport;
    return this;
  }

  /** Replaces the diagnostics sink. The default is silent. */
  logger(logger: Logger): TransmissionClientBuilder {
    this.logSink = logger;
    return this;
  }

  /**
   * Observes dialect negotiation.
   *
   * Fired at most a couple of times per client. Applications can persist the
   * reported {@link ApiStyle} and pass it back through
   * {@link apiStyleMode} on the next launch to skip negotiation entirely.
   */
  onApiStyleResolved(listener: ApiStyleListener): TransmissionClientBuilder {
    this.styleListener = listener;
    return this;
  }

  /**
   * Validates the collected inputs and constructs the client.
   *
   * @throws TransmissionError with kind `configuration` when the URL, timeout
   *         or credentials are invalid
   */
  build(): TransmissionClient {
    this.configuration.validate();
    const logger = this.logSink === undefined ? new NoopLogger() : this.logSink;
    const transport = this.httpTransport === undefined ? new ArkHttpTransport() : this.httpTransport;
    const negotiator = new StyleNegotiator(this.configuration.apiStyleMode, this.styleListener);
    const rpc = new RpcClient(this.configuration, transport, negotiator, logger);
    return new TransmissionClient(this.configuration, rpc, negotiator, logger);
  }
}
