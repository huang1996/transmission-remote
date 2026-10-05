// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Semantic-version handling for Transmission's RPC protocol version.
 *
 * Transmission exposes two version numbers:
 *
 * - `rpc_version_semver` (string, e.g. `"6.0.0"`) — the recommended one. It was
 *   introduced in Transmission 4.0.0 and became meaningful for feature
 *   detection from `6.0.0` (Transmission 4.1.0) onwards.
 * - `rpc_version` (integer, e.g. `17`) — the deprecated counter, still the only
 *   version number reported by Transmission < 4.0.0.
 *
 * {@link RpcVersion} models the semver form and {@link RpcVersions} provides the
 * translation table between the two schemes so the SDK can reason about server
 * capabilities regardless of which number the server reported.
 *
 * @since 1.0.0
 */

/** Splits a version string into numeric components, ignoring any suffix. */
function splitComponents(text: string): number[] {
  const withoutBuild = text.split('+')[0];
  const withoutPreRelease = withoutBuild.split('-')[0];
  const parts = withoutPreRelease.split('.');
  const numbers: number[] = [];
  for (const part of parts) {
    const trimmed = part.trim();
    if (trimmed.length === 0) {
      continue;
    }
    const value = Number.parseInt(trimmed, 10);
    numbers.push(Number.isNaN(value) ? 0 : value);
  }
  return numbers;
}

/**
 * True when `text` contains at least one ASCII digit.
 *
 * ArkTS does not support regular-expression literals, so this is a plain scan.
 */
function containsDigit(text: string): boolean {
  for (let i = 0; i < text.length; i++) {
    const code = text.charCodeAt(i);
    if (code >= 48 && code <= 57) {
      return true;
    }
  }
  return false;
}

/** Compares two component arrays using semver precedence rules. */
function compareComponents(left: number[], right: number[]): number {
  const length = Math.max(left.length, right.length);
  for (let i = 0; i < length; i++) {
    const a = i < left.length ? left[i] : 0;
    const b = i < right.length ? right[i] : 0;
    if (a !== b) {
      return a < b ? -1 : 1;
    }
  }
  return 0;
}

/**
 * An immutable `major.minor.patch` RPC protocol version.
 *
 * Instances are created through {@link RpcVersion.parse} or the named
 * constants on {@link RpcVersions}; the constructor is intentionally public so
 * that tests and callers can build ad-hoc versions.
 */
export class RpcVersion {
  /** Major component. */
  readonly major: number;
  /** Minor component. */
  readonly minor: number;
  /** Patch component. */
  readonly patch: number;

  constructor(major: number, minor: number = 0, patch: number = 0) {
    this.major = major;
    this.minor = minor;
    this.patch = patch;
  }

  /**
   * Parses a version string such as `"6.0.0"`, `"6.1.0-dev"` or `"4.1.0 (abc)"`.
   *
   * @returns the parsed version, or `undefined` when `text` contains no digits.
   */
  static parse(text: string | undefined): RpcVersion | undefined {
    if (text === undefined || text.length === 0) {
      return undefined;
    }
    const numbers = splitComponents(text);
    if (numbers.length === 0 || !containsDigit(text)) {
      return undefined;
    }
    while (numbers.length < 3) {
      numbers.push(0);
    }
    return new RpcVersion(numbers[0], numbers[1], numbers[2]);
  }

  /** @returns a negative number, zero or a positive number, like `Array.sort`. */
  compareTo(other: RpcVersion): number {
    return compareComponents([this.major, this.minor, this.patch], [other.major, other.minor, other.patch]);
  }

  /** True when this version is greater than or equal to `other`. */
  isAtLeast(other: RpcVersion): boolean {
    return this.compareTo(other) >= 0;
  }

  /** True when this version is strictly lower than `other`. */
  isBelow(other: RpcVersion): boolean {
    return this.compareTo(other) < 0;
  }

  /** True when both versions carry the same components. */
  equals(other: RpcVersion | undefined): boolean {
    return other !== undefined && this.compareTo(other) === 0;
  }

  /** `"major.minor.patch"`. */
  toString(): string {
    return `${this.major}.${this.minor}.${this.patch}`;
  }
}

/**
 * Well-known RPC versions and the mapping between the deprecated integer
 * counter and the semver string.
 *
 * The table mirrors section 5 of Transmission's `docs/rpc-spec.md`.
 */
export class RpcVersions {
  /** Transmission 1.30 — the first RPC revision. */
  static readonly V1_0_0: RpcVersion = new RpcVersion(1, 0, 0);
  /** Transmission 4.0.x — the last revision of the legacy-only era. */
  static readonly V5_3_0: RpcVersion = new RpcVersion(5, 3, 0);
  /**
   * Transmission 4.1.0 — JSON-RPC 2.0 and snake_case keys were introduced.
   * This is the compatibility boundary the SDK negotiates around.
   */
  static readonly V6_0_0: RpcVersion = new RpcVersion(6, 0, 0);
  /** Transmission 5.0.x — the legacy bespoke API is expected to be removed. */
  static readonly V7_0_0: RpcVersion = new RpcVersion(7, 0, 0);

  /** The lowest RPC version the SDK understands. */
  static readonly MINIMUM_SUPPORTED: RpcVersion = RpcVersions.V1_0_0;

  /** Integer `rpc_version` for every semver revision, ascending. */
  private static readonly SEMVER_BY_INTEGER: string[] = [
    '1.0.0', // 1  — Transmission 1.30
    '1.1.0', // 2  — 1.40
    '1.2.0', // 3  — 1.41
    '1.3.0', // 4  — 1.50
    '2.0.0', // 5  — 1.60
    '2.1.0', // 6  — 1.70
    '3.0.0', // 7  — 1.80
    '3.1.0', // 8  — 1.90 / 1.92
    '3.3.0', // 9  — 2.00
    '3.4.0', // 10 — 2.10
    '3.5.0', // 11 — 2.12
    '3.6.0', // 12 — 2.20
    '4.0.0', // 13 — 2.30
    '5.0.0', // 14 — 2.40
    '5.1.0', // 15 — 2.80
    '5.2.0', // 16 — 3.00
    '5.3.0', // 17 — 4.0.0
    '6.0.0', // 18 — 4.1.0
  ];

  private constructor() {
    // Static-only utility class.
  }

  /**
   * Translates a deprecated integer `rpc_version` into a semver version.
   *
   * @returns the matching version, or `undefined` when the integer is unknown.
   */
  static fromInteger(rpcVersion: number | undefined): RpcVersion | undefined {
    if (rpcVersion === undefined || !Number.isFinite(rpcVersion)) {
      return undefined;
    }
    const index = Math.trunc(rpcVersion) - 1;
    if (index < 0 || index >= RpcVersions.SEMVER_BY_INTEGER.length) {
      return undefined;
    }
    return RpcVersion.parse(RpcVersions.SEMVER_BY_INTEGER[index]);
  }

  /** Highest integer `rpc_version` the SDK knows about. */
  static readonly MAXIMUM_KNOWN_INTEGER: number = RpcVersions.SEMVER_BY_INTEGER.length;

  /**
   * True when a server reporting `version` speaks JSON-RPC 2.0.
   *
   * JSON-RPC support (and therefore snake_case field names) starts at
   * `rpc-version-semver` 6.0.0 / Transmission 4.1.0.
   */
  static supportsJsonRpc(version: RpcVersion | undefined): boolean {
    return version !== undefined && version.isAtLeast(RpcVersions.V6_0_0);
  }
}
