// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Translation between canonical (snake_case) and legacy RPC key names.
 *
 * This is a faithful port of `convert_key()` / `convert_string()` /
 * `convert_keys()` from `libtransmission/api-compat.cc`, including its "crazy
 * cases". Keeping the quirks in one place means the rest of the SDK can pretend
 * the legacy dialect does not exist.
 *
 * @since 1.0.0
 */

import { Json, JsonArray, JsonObject, JsonValue } from '../util/Json';
import { WireKeys } from '../constants/WireProtocol';
import { LegacyKeys } from './LegacyKeys';
import { RpcMethod } from '../constants/RpcMethods';

/** Direction of a key translation. */
export enum KeyDirection {
  /** Canonical (modern) -> legacy. Used when encoding a request. */
  TO_LEGACY = 0,
  /** Legacy -> canonical (modern). Used when decoding a response. */
  TO_CANONICAL = 1,
}

/**
 * Everything the key translator needs to know about the message it is walking.
 *
 * Both flags exist because the legacy dialect reuses the same odd spelling in
 * two different contexts. They mirror the `is_torrent` and
 * `is_free_space_response` fields of api-compat's `State`.
 */
export class ConversionContext {
  /**
   * True when the payload belongs to `torrent_get` / `torrent_set`, whose
   * legacy `download-dir` spelling is camelCase (`downloadDir`) instead of the
   * kebab-case used everywhere else.
   */
  readonly isTorrent: boolean;

  /**
   * True when the payload is the response of `free_space`, which uses
   * `total_size` (underscore) rather than `totalSize` even in the legacy API.
   */
  readonly isFreeSpaceResponse: boolean;

  private constructor(isTorrent: boolean, isFreeSpaceResponse: boolean) {
    this.isTorrent = isTorrent;
    this.isFreeSpaceResponse = isFreeSpaceResponse;
  }

  /**
   * Context for encoding a request.
   *
   * @param method canonical method being invoked
   */
  static forRequest(method: RpcMethod): ConversionContext {
    const isTorrent = method === RpcMethod.TORRENT_GET || method === RpcMethod.TORRENT_SET;
    return new ConversionContext(isTorrent, method === RpcMethod.FREE_SPACE);
  }

  /**
   * Context for decoding a response.
   *
   * @param payload the `result` (modern) or `arguments` (legacy) object
   */
  static forResponse(payload: JsonObject | undefined): ConversionContext {
    const isTorrent = Json.getArray(payload, WireKeys.TORRENTS) !== undefined;
    // The legacy `free_space` response is identified by having both `path` and
    // `size-bytes`; this mirrors api-compat's `makeState()`.
    const hasPath = Json.get(payload, WireKeys.PATH) !== undefined;
    const hasSizeBytes =
      Json.get(payload, WireKeys.SIZE_BYTES) !== undefined ||
      Json.get(payload, WireKeys.LEGACY_SIZE_BYTES_KEBAB) !== undefined;
    return new ConversionContext(isTorrent, isTorrent ? false : hasPath && hasSizeBytes);
  }

  /** Context that performs no context-sensitive translation. */
  static neutral(): ConversionContext {
    return new ConversionContext(false, false);
  }
}

/**
 * Recursive key/value translator for RPC payloads.
 *
 * All methods are pure: they return new JSON structures and never mutate their
 * input, so request templates owned by the caller stay untouched.
 */
export class KeyConverter {
  /**
   * Fields whose *string values* are themselves RPC keys.
   *
   * `{"fields": ["download_dir"]}` is a list of keys, so the list elements have
   * to be translated just like object keys. `ids` is included because
   * api-compat does the same; its values are hashes that never match a known
   * key, so the translation is a no-op there.
   */
  private static readonly KEY_VALUED_FIELDS: string[] = [
    WireKeys.METHOD,
    WireKeys.FIELDS,
    WireKeys.IDS,
    WireKeys.TORRENTS,
  ];

  private constructor() {
    // Static-only utility class.
  }

  /**
   * Translates every key of `value` from its canonical spelling to the legacy
   * spelling, and normalises value-level differences (`wanted` booleans).
   */
  static toLegacy(context: ConversionContext, value: JsonValue | undefined): JsonValue {
    return value === undefined ? Json.emptyObject() : KeyConverter.convert(context, '', value, KeyDirection.TO_LEGACY);
  }

  /**
   * Translates every key of `value` from the legacy spelling to the canonical
   * spelling, and normalises value-level differences (`wanted` `0`/`1`).
   */
  static toCanonical(context: ConversionContext, value: JsonValue | undefined): JsonValue {
    return value === undefined ? Json.emptyObject() : KeyConverter.convert(context, '', value, KeyDirection.TO_CANONICAL);
  }

  /** Translates a single key. Used directly by tests and diagnostics. */
  static convertKey(context: ConversionContext, key: string, direction: KeyDirection): string {
    // Crazy case 1: `download_dir`.
    //   - torrent_get / torrent_set in the legacy API use camelCase
    //     (`downloadDir`)
    //   - session_get / session_set and everything else use kebab-case
    //     (`download-dir`)
    //   - the canonical spelling is always `download_dir`
    if (
      key === WireKeys.DOWNLOAD_DIR ||
      key === WireKeys.LEGACY_DOWNLOAD_DIR_CAMEL ||
      key === WireKeys.LEGACY_DOWNLOAD_DIR_KEBAB
    ) {
      if (direction === KeyDirection.TO_CANONICAL) {
        return WireKeys.DOWNLOAD_DIR;
      }
      return context.isTorrent ? WireKeys.LEGACY_DOWNLOAD_DIR_CAMEL : WireKeys.LEGACY_DOWNLOAD_DIR_KEBAB;
    }

    // Crazy case 2: the `free_space` response reports `total_size` with an
    // underscore even in the legacy API, unlike `totalSize` in torrent_get.
    if (context.isFreeSpaceResponse && (key === WireKeys.TOTAL_SIZE || key === WireKeys.LEGACY_TOTAL_SIZE_CAMEL)) {
      return WireKeys.TOTAL_SIZE;
    }

    const mapped = direction === KeyDirection.TO_LEGACY ? LegacyKeys.toLegacy(key) : LegacyKeys.toCanonical(key);
    return mapped === undefined ? key : mapped;
  }

  /**
   * Walks `value`, translating keys and the handful of fields whose wire
   * representation differs between the dialects.
   *
   * @param parentKey wire key under which `value` appears (empty at the root)
   */
  private static convert(
    context: ConversionContext,
    parentKey: string,
    value: JsonValue,
    direction: KeyDirection,
  ): JsonValue {
    if (typeof value === 'string') {
      return KeyConverter.convertKeyValuedString(context, parentKey, value, direction);
    }

    if (Json.isArray(value)) {
      const source = value as JsonArray;
      const result: JsonArray = [];
      for (const item of source) {
        result.push(KeyConverter.convert(context, parentKey, item, direction));
      }
      return result;
    }

    if (Json.isObject(value)) {
      const source = value as JsonObject;
      const result: JsonObject = {};
      for (const key of Json.keys(source)) {
        const child = source[key];
        const targetKey = KeyConverter.convertKey(context, key, direction);
        result[targetKey] = KeyConverter.convertValue(context, targetKey, child, direction);
      }
      return result;
    }

    return value;
  }

  /** Translates a string that is itself a key, when its field says so. */
  private static convertKeyValuedString(
    context: ConversionContext,
    parentKey: string,
    value: string,
    direction: KeyDirection,
  ): string {
    if (!KeyConverter.KEY_VALUED_FIELDS.includes(parentKey)) {
      return value;
    }
    return KeyConverter.convertKey(context, value, direction);
  }

  /**
   * Translates the *values* of a field whose wire representation differs
   * between the two dialects.
   *
   * Two fields qualify:
   *
   * - `wanted`: JSON-RPC 2.0 uses real booleans, the legacy API serialises the
   *   same array as `0` / `1` integers.
   * - `encryption`: JSON-RPC 2.0 spells the "prefer clear" mode `"allowed"`,
   *   the legacy API calls the very same mode `"tolerated"`.
   */
  private static convertValue(
    context: ConversionContext,
    key: string,
    value: JsonValue,
    direction: KeyDirection,
  ): JsonValue {
    if (key === WireKeys.ENCRYPTION) {
      return KeyConverter.convertEncryption(value, direction);
    }
    if (key !== WireKeys.WANTED) {
      return KeyConverter.convert(context, key, value, direction);
    }
    const array = Json.asArray(value);
    if (array === undefined) {
      return KeyConverter.convert(context, key, value, direction);
    }
    const result: JsonArray = [];
    for (const item of array) {
      const asBoolean = Json.asLooseBoolean(item);
      if (asBoolean === undefined) {
        // Preserve anything unexpected rather than silently dropping data.
        result.push(KeyConverter.convert(context, key, item, direction));
      } else {
        result.push(direction === KeyDirection.TO_LEGACY ? (asBoolean ? 1 : 0) : asBoolean);
      }
    }
    return result;
  }

  /**
   * Translates an `encryption` value between the two spellings.
   *
   * Ported from `convert_encryption()` in `libtransmission/api-compat.cc`.
   * Unrecognised values are passed through so a newer server can still teach
   * this SDK a new mode.
   */
  private static convertEncryption(value: JsonValue, direction: KeyDirection): JsonValue {
    const text = Json.asString(value);
    if (text === undefined) {
      return value;
    }
    if (direction === KeyDirection.TO_LEGACY) {
      return text === 'allowed' ? 'tolerated' : text;
    }
    return text === 'tolerated' ? 'allowed' : text;
  }
}
