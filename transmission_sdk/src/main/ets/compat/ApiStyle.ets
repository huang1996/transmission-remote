// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * The two RPC dialects spoken by Transmission.
 *
 * @since 1.0.0
 */

/**
 * Wire format of a request/response pair.
 *
 * - {@link MODERN} — JSON-RPC 2.0 with snake_case keys, supported by
 *   Transmission >= 4.1.0 (`rpc-version-semver` >= 6.0.0).
 * - {@link LEGACY} — the original bespoke protocol with a mix of kebab-case and
 *   camelCase keys, used by Transmission < 4.1.0 and still *accepted* (but
 *   deprecated) by Transmission 4.1.x.
 */
export enum ApiStyle {
  /** JSON-RPC 2.0, snake_case. */
  MODERN = 'modern',
  /** Bespoke protocol, kebab-case / camelCase. */
  LEGACY = 'legacy',
}

/**
 * How the SDK should choose an {@link ApiStyle}.
 *
 * @since 1.0.0
 */
export enum ApiStyleMode {
  /**
   * Negotiate with the server and cache the result (recommended).
   *
   * The first request is sent in the modern format; if the server turns out to
   * be older, the SDK transparently downgrades and retries. The cost is at most
   * one extra round trip per client instance.
   */
  AUTO = 'auto',
  /** Always speak JSON-RPC 2.0. Fails against servers older than 4.1.0. */
  MODERN = 'modern',
  /** Always speak the legacy protocol. Works with every 4.x server. */
  LEGACY = 'legacy',
}

/** True when `value` is a valid {@link ApiStyle}. */
export function isApiStyle(value: string): boolean {
  return value === ApiStyle.MODERN || value === ApiStyle.LEGACY;
}

/** Human readable label, used in diagnostics. */
export function apiStyleLabel(style: ApiStyle): string {
  return style === ApiStyle.MODERN ? 'JSON-RPC 2.0 (Transmission >= 4.1.0)' : 'legacy RPC (Transmission < 4.1.0)';
}
