// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Client configuration.
 *
 * Instances are mutable and fluent so a client can be described in one
 * expression:
 *
 * ```ts
 * const config = TransmissionConfig.forHost('192.168.1.10')
 *   .withCredentials('admin', 'secret')
 *   .withTimeout(8_000);
 * ```
 *
 * @since 1.0.0
 */

import { TransmissionError } from '../error/TransmissionError';
import { ApiStyleMode } from '../compat/ApiStyle';
import { DEFAULT_RPC_PATH, DEFAULT_RPC_PORT, DEFAULT_RPC_URL } from '../constants/WireProtocol';

/** Default per-request timeout, in milliseconds. */
export const DEFAULT_TIMEOUT_MS: number = 15_000;

/**
 * Everything the SDK needs to reach a Transmission RPC endpoint.
 */
export class TransmissionConfig {
  private endpoint: string;
  private userName: string | undefined;
  private passWord: string | undefined;
  private mode: ApiStyleMode;
  private timeout: number;
  private extraHeaders: Map<string, string>;
  private persistentSessionId: string | undefined;

  private constructor(url: string) {
    this.endpoint = url;
    this.mode = ApiStyleMode.AUTO;
    this.timeout = DEFAULT_TIMEOUT_MS;
    this.extraHeaders = new Map<string, string>();
  }

  /**
   * Creates a configuration for an explicit RPC URL.
   *
   * @param url full endpoint, e.g. `http://127.0.0.1:9091/transmission/rpc`
   */
  static of(url: string = DEFAULT_RPC_URL): TransmissionConfig {
    return new TransmissionConfig(url);
  }

  /**
   * Creates a configuration for a host, using Transmission's default port and
   * RPC path unless told otherwise.
   *
   * @param host host name or IP address
   * @param port RPC port, defaults to 9091
   * @param path RPC path, defaults to `/transmission/rpc`
   */
  static forHost(host: string, port: number = DEFAULT_RPC_PORT, path: string = DEFAULT_RPC_PATH): TransmissionConfig {
    const normalizedPath = path.startsWith('/') ? path : `/${path}`;
    return new TransmissionConfig(`http://${host}:${port}${normalizedPath}`);
  }

  /** The configured RPC endpoint. */
  get url(): string {
    return this.endpoint;
  }

  /** Account name used for HTTP Basic authentication. */
  get username(): string | undefined {
    return this.userName;
  }

  /** Account password used for HTTP Basic authentication. */
  get password(): string | undefined {
    return this.passWord;
  }

  /** Configured dialect-selection strategy. */
  get apiStyleMode(): ApiStyleMode {
    return this.mode;
  }

  /** Per-request timeout, in milliseconds. */
  get timeoutMs(): number {
    return this.timeout;
  }

  /** Additional headers sent with every request (read-only view). */
  get headers(): Map<string, string> {
    return this.extraHeaders;
  }

  /**
   * CSRF session id restored from a previous run.
   *
   * Persisting this value lets an application skip the 409 handshake on the
   * next launch. The SDK still recovers automatically if it has gone stale.
   */
  get sessionId(): string | undefined {
    return this.persistentSessionId;
  }

  /** Sets the RPC endpoint. */
  withUrl(url: string): TransmissionConfig {
    this.endpoint = url;
    return this;
  }

  /** Sets HTTP Basic credentials. */
  withCredentials(username: string, password: string): TransmissionConfig {
    this.userName = username;
    this.passWord = password;
    return this;
  }

  /**
   * Pins the dialect instead of negotiating it.
   *
   * Use {@link ApiStyleMode.MODERN} when the server is known to be
   * Transmission >= 4.1.0, and {@link ApiStyleMode.LEGACY} for anything older.
   */
  withApiStyleMode(mode: ApiStyleMode): TransmissionConfig {
    this.mode = mode;
    return this;
  }

  /** Sets the per-request timeout in milliseconds. */
  withTimeout(timeoutMs: number): TransmissionConfig {
    this.timeout = timeoutMs;
    return this;
  }

  /** Adds or replaces an extra request header. */
  withHeader(name: string, value: string): TransmissionConfig {
    this.extraHeaders.set(name.toLowerCase(), value);
    return this;
  }

  /** Seeds the CSRF session id, typically restored from persistent storage. */
  withSessionId(sessionId: string | undefined): TransmissionConfig {
    this.persistentSessionId = sessionId;
    return this;
  }

  /**
   * Validates the configuration.
   *
   * @throws TransmissionError with kind `configuration` when the URL is missing
   *         or not an `http`/`https` endpoint, or when the timeout is invalid.
   */
  validate(): void {
    if (this.endpoint.length === 0) {
      throw TransmissionError.configuration('the RPC url must not be empty');
    }
    if (!this.endpoint.startsWith('http://') && !this.endpoint.startsWith('https://')) {
      throw TransmissionError.configuration(`the RPC url must be an http(s) endpoint: ${this.endpoint}`);
    }
    if (!Number.isFinite(this.timeout) || this.timeout <= 0) {
      throw TransmissionError.configuration(`the timeout must be a positive number of milliseconds: ${this.timeout}`);
    }
    const hasUser = this.userName !== undefined && this.userName.length > 0;
    const hasPassword = this.passWord !== undefined;
    if (hasPassword && !hasUser) {
      throw TransmissionError.configuration('a password was configured without a username');
    }
  }
}
