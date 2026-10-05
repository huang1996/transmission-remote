// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Runtime selection of the RPC dialect.
 *
 * Transmission 4.1.0 accepts *both* dialects and mirrors the dialect of the
 * request in its response, which makes negotiation cheap: the SDK starts in the
 * modern dialect and only falls back when the server proves it is older.
 *
 * Two independent signals are used, cheapest first:
 *
 * 1. The `X-Transmission-Rpc-Version` header on the HTTP 409 (CSRF) response.
 *    Transmission >= 4.1.0 always sends it; older servers never do. Because the
 *    409 always precedes the first successful request, this resolves the
 *    dialect *before* any payload is wasted.
 * 2. A `METHOD_NOT_FOUND` reply to a modern request, which can only come from a
 *    server that does not know the snake_case method names.
 *
 * @since 1.0.0
 */

import { Json, JsonObject } from '../util/Json';
import { RpcVersion, RpcVersions } from '../util/Semver';
import { ApiStyle, ApiStyleMode } from './ApiStyle';
import { LegacyCodec, ModernCodec, RpcCodec } from './RpcCodec';

/** Callback invoked whenever the negotiated dialect changes. */
export type ApiStyleListener = (style: ApiStyle, version: RpcVersion | undefined) => void;

/**
 * Owns the negotiated {@link ApiStyle} and the server's RPC version.
 *
 * One instance is shared by every request of a single `TransmissionClient`.
 */
export class StyleNegotiator {
  private readonly mode: ApiStyleMode;
  private readonly listener: ApiStyleListener | undefined;
  private style: ApiStyle;
  private version: RpcVersion | undefined;

  /**
   * @param mode how the dialect should be chosen
   * @param listener notified on every change of the negotiated dialect
   */
  constructor(mode: ApiStyleMode = ApiStyleMode.AUTO, listener?: ApiStyleListener) {
    this.mode = mode;
    this.listener = listener;
    this.style = mode === ApiStyleMode.LEGACY ? ApiStyle.LEGACY : ApiStyle.MODERN;
  }

  /** The configured negotiation mode. */
  get styleMode(): ApiStyleMode {
    return this.mode;
  }

  /** The dialect currently in use. */
  get currentStyle(): ApiStyle {
    return this.style;
  }

  /** The server's RPC protocol version, once it has been observed. */
  get serverVersion(): RpcVersion | undefined {
    return this.version;
  }

  /** The codec matching {@link currentStyle}. */
  codec(): RpcCodec {
    return this.style === ApiStyle.MODERN ? ModernCodec.instance() : LegacyCodec.instance();
  }

  /** True when the dialect may still change without an explicit configuration. */
  get isAuto(): boolean {
    return this.mode === ApiStyleMode.AUTO;
  }

  /**
   * Records the value of the `X-Transmission-Rpc-Version` header of a 409
   * response.
   *
   * @param headerValue header value, or `undefined` when the server sent none
   * @returns `true` when the negotiated dialect changed
   */
  observeVersionHeader(headerValue: string | undefined): boolean {
    const parsed = RpcVersion.parse(headerValue);
    if (parsed !== undefined) {
      // Record the version even when the dialect is pinned: applications use it
      // for feature gating, and it is free to collect.
      this.version = parsed;
    }
    if (!this.isAuto) {
      return false;
    }
    if (parsed === undefined) {
      // The header is only emitted from rpc-version-semver 6.0.0 onwards, so its
      // absence is a positive signal that the server predates JSON-RPC support.
      return this.apply(ApiStyle.LEGACY, this.version);
    }
    return this.apply(RpcVersions.supportsJsonRpc(parsed) ? ApiStyle.MODERN : ApiStyle.LEGACY, parsed);
  }

  /**
   * Learns the RPC version from a decoded `session_get` payload.
   *
   * Both `rpc_version_semver` (preferred) and the deprecated integer
   * `rpc_version` are understood. The keys are already canonical because the
   * caller decodes the response before calling this method.
   *
   * @returns `true` when the negotiated dialect changed
   */
  observeSessionFields(settings: JsonObject | undefined): boolean {
    const semver = RpcVersion.parse(Json.asString(Json.get(settings, 'rpc_version_semver')));
    const version = semver ?? RpcVersions.fromInteger(Json.asInteger(Json.get(settings, 'rpc_version')));
    if (version === undefined) {
      return false;
    }
    if (!this.isAuto) {
      this.version = version;
      return false;
    }
    return this.apply(RpcVersions.supportsJsonRpc(version) ? ApiStyle.MODERN : ApiStyle.LEGACY, version);
  }

  /**
   * Handles a request that failed with `METHOD_NOT_FOUND`.
   *
   * In {@link ApiStyleMode.AUTO} this means the server does not understand
   * snake_case method names, so the request must be retried in the legacy
   * dialect.
   *
   * @returns `true` when the dialect changed and the caller should retry
   */
  observeMethodNotFound(): boolean {
    if (!this.isAuto || this.style === ApiStyle.LEGACY) {
      return false;
    }
    return this.apply(ApiStyle.LEGACY, this.version);
  }

  /** Re-reads the configured mode, discarding a previously negotiated result. */
  reset(): void {
    this.version = undefined;
    this.style = this.mode === ApiStyleMode.LEGACY ? ApiStyle.LEGACY : ApiStyle.MODERN;
  }

  /** Applies a new dialect and notifies the listener when it actually changed. */
  private apply(style: ApiStyle, version: RpcVersion | undefined): boolean {
    const changed = this.style !== style;
    this.style = style;
    this.version = version;
    if (changed && this.listener !== undefined) {
      this.listener(style, version);
    }
    return changed;
  }
}
