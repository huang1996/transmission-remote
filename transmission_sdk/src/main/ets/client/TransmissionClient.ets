// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * The SDK entry point.
 *
 * `TransmissionClient` wires the transport, the RPC engine and the four service
 * facades together, and exposes the small amount of state that belongs to a
 * connection: the negotiated dialect, the reported server version and the CSRF
 * session id.
 *
 * ```ts
 * const client = new TransmissionClientBuilder()
 *   .url('http://192.168.1.10:9091/transmission/rpc')
 *   .credentials('admin', 'secret')
 *   .build();
 *
 * const settings = await client.connect();
 * const torrents = await client.torrents.get(new TorrentGetRequest(TorrentFields.BASIC));
 * client.close();
 * ```
 *
 * @since 1.0.0
 */

import { JsonObject } from '../util/Json';
import { Logger, NoopLogger } from '../util/Logger';
import { ApiStyle, apiStyleLabel } from '../compat/ApiStyle';
import { StyleNegotiator } from '../compat/StyleNegotiator';
import { RpcVersion } from '../util/Semver';
import { RpcClient } from '../core/RpcClient';
import { RpcBatch } from '../core/RpcBatch';
import { TransmissionConfig } from '../core/TransmissionConfig';
import { RpcMethod } from '../constants/RpcMethods';
import { TorrentApi } from '../api/TorrentApi';
import { SessionApi } from '../api/SessionApi';
import { SystemApi } from '../api/SystemApi';
import { BandwidthGroupApi } from '../api/BandwidthGroupApi';
import { SessionSettings } from '../model/SessionSettings';

/** Log tag used by this class. */
const LOG_TAG: string = 'TransmissionClient';

/**
 * A connection to one Transmission RPC endpoint.
 *
 * Instances are cheap and hold no background threads; create one per server and
 * reuse it. Call {@link close} when the client is no longer needed so the
 * underlying HTTP transport releases its resources.
 */
export class TransmissionClient {
  /** Torrent operations. */
  readonly torrents: TorrentApi;
  /** Session settings, statistics and lifecycle. */
  readonly session: SessionApi;
  /** Server utilities: free space, port test, blocklist. */
  readonly system: SystemApi;
  /** Bandwidth groups. */
  readonly groups: BandwidthGroupApi;

  private readonly config: TransmissionConfig;
  private readonly rpc: RpcClient;
  private readonly negotiator: StyleNegotiator;
  private readonly logger: Logger;
  private connected: boolean = false;

  /**
   * Prefer {@link TransmissionClientBuilder}; the constructor exists so that
   * advanced callers can inject a custom transport or RPC engine.
   *
   * @param config validated configuration
   * @param rpc the RPC engine to use
   * @param negotiator the dialect negotiator shared with `rpc`
   * @param logger diagnostics sink
   */
  constructor(config: TransmissionConfig, rpc: RpcClient, negotiator: StyleNegotiator, logger?: Logger) {
    this.config = config;
    this.rpc = rpc;
    this.negotiator = negotiator;
    this.logger = logger === undefined ? new NoopLogger() : logger;

    this.torrents = new TorrentApi(rpc);
    this.session = new SessionApi(rpc);
    this.system = new SystemApi(rpc);
    this.groups = new BandwidthGroupApi(rpc);
  }

  /** The configured RPC endpoint. */
  get url(): string {
    return this.config.url;
  }

  /** The dialect currently in use. */
  get apiStyle(): ApiStyle {
    return this.negotiator.currentStyle;
  }

  /** Human readable description of {@link apiStyle}. */
  get apiStyleLabel(): string {
    return apiStyleLabel(this.negotiator.currentStyle);
  }

  /** True while the dialect is still being negotiated. */
  get isNegotiating(): boolean {
    return this.negotiator.isAuto && this.negotiator.serverVersion === undefined;
  }

  /** RPC version reported by the server, once any call has succeeded. */
  get serverVersion(): RpcVersion | undefined {
    return this.negotiator.serverVersion;
  }

  /** True after a successful {@link connect} (or any successful call). */
  get isConnected(): boolean {
    return this.connected;
  }

  /** The CSRF session id, for applications that persist it between launches. */
  get sessionId(): string | undefined {
    return this.rpc.currentSessionId;
  }

  /** True once {@link close} has been called. */
  get isClosed(): boolean {
    return this.rpc.isClosed;
  }

  /**
   * Verifies connectivity and learns the server's capabilities.
   *
   * This performs a single `session_get` and, on a first contact with an older
   * server, transparently downgrades the dialect. Call it during application
   * start-up so that later calls cannot fail for negotiation reasons.
   *
   * @returns the server's session settings
   * @throws TransmissionError when the server is unreachable, rejects the
   *         credentials, or is older than the API this SDK can drive
   */
  async connect(): Promise<SessionSettings> {
    const settings = await this.session.get();
    this.connected = true;
    this.logger.info(
      LOG_TAG,
      `connected to ${this.config.url} — ${this.apiStyleLabel}, rpc ${this.versionLabel()}`,
    );
    return settings;
  }

  /**
   * Runs a quick health check.
   *
   * Lighter than {@link connect}: it fetches only the version fields.
   *
   * @returns true when the server answered
   */
  async ping(): Promise<boolean> {
    try {
      await this.session.getRaw(['version', 'rpc_version', 'rpc_version_semver']);
      this.connected = true;
      return true;
    } catch (error) {
      this.logger.debug(LOG_TAG, `ping failed: ${(error as Error).message}`);
      return false;
    }
  }

  /**
   * Starts a batch: several calls, one HTTP round trip.
   *
   * @returns a fresh {@link RpcBatch}
   */
  batch(): RpcBatch {
    return new RpcBatch(this.rpc);
  }

  /**
   * Invokes an RPC method the SDK does not wrap yet.
   *
   * Parameters and the returned object use the canonical snake_case keys; the
   * compatibility layer translates them for older servers.
   *
   * @param method canonical method name
   * @param params canonical parameters
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async raw(method: RpcMethod, params?: JsonObject): Promise<JsonObject> {
    return this.rpc.call(method, params);
  }

  /**
   * Overrides the CSRF session id.
   *
   * Applications that persisted the id from a previous run can restore it here
   * to skip the 409 handshake. The SDK still recovers automatically when the id
   * has gone stale.
   *
   * @param sessionId the id, or `undefined` to forget it
   */
  setSessionId(sessionId: string | undefined): void {
    this.rpc.setSessionId(sessionId);
  }

  /** Releases the HTTP transport. The client cannot be used afterwards. */
  close(): void {
    this.rpc.close();
    this.connected = false;
  }

  /** `"6.0.0"`, or `"unknown"` before the version has been observed. */
  private versionLabel(): string {
    const version = this.negotiator.serverVersion;
    return version === undefined ? 'unknown' : version.toString();
  }
}
