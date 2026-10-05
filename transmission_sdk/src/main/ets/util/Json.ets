// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Minimal, dependency-free JSON model used across the SDK.
 *
 * Transmission's RPC payloads are JSON objects whose exact shape depends on the
 * server version (see `compat/`). The compatibility layer therefore needs a
 * *dynamic* representation of JSON in addition to the strongly typed `model/`
 * classes that application code consumes.
 *
 * ### Why this file looks the way it does
 *
 * ArkTS deliberately forbids `any`, `unknown`, index signatures, tuple/object
 * literal *types* and most of `Object`'s reflective API. The one sanctioned way
 * to express "an object with dynamic keys" is `Record<string, T>`.
 *
 * A self-referential alias such as `type JsonValue = ... | Record<string,
 * JsonValue>` is rejected by the TypeScript compiler (TS2456), so the dynamic
 * payload type is deliberately *not* recursive: nested objects and arrays are
 * carried as `Object` and narrowed through {@link Json}. This keeps the type
 * legal in both ArkTS and TypeScript while still giving every reader a total,
 * never-throwing accessor.
 *
 * `@since 1.0.0`
 */

/** A JSON scalar. */
export type JsonPrimitive = string | number | boolean | null;

/**
 * Any JSON value.
 *
 * Objects and arrays are typed as `Object` because a recursive alias is not
 * expressible in ArkTS; use {@link Json.asObject} / {@link Json.asArray} to
 * narrow them.
 */
export type JsonValue = JsonPrimitive | Object;

/** A JSON object: the only dynamic-key container ArkTS supports. */
export type JsonObject = Record<string, JsonValue>;

/** A JSON array. */
export type JsonArray = JsonValue[];

/**
 * Defensive readers for dynamically typed JSON.
 *
 * Every method accepts `undefined` and returns a sane fallback, so callers can
 * chain lookups without explicit null checks. This keeps the parsing code in
 * `model/` declarative and easy to skim.
 */
export class Json {
  private constructor() {
    // Static-only utility class.
  }

  /**
   * Creates a new, empty JSON object.
   *
   * ArkTS accepts an object literal only when it has a contextual type, so a
   * bare `{}` cannot be used as, for example, a ternary branch or a default
   * argument. This factory provides an explicitly typed empty object for those
   * positions. A fresh instance is returned every time so that callers can
   * mutate the result freely.
   */
  static emptyObject(): JsonObject {
    const value: JsonObject = {};
    return value;
  }

  /** True when `value` is a JSON object (and not `null` or an array). */
  static isObject(value: JsonValue | undefined): boolean {
    return value !== undefined && value !== null && typeof value === 'object' && !Array.isArray(value);
  }

  /** True when `value` is a JSON array. */
  static isArray(value: JsonValue | undefined): boolean {
    return Array.isArray(value);
  }

  /** Reads `value` as a JSON object, or `undefined` when it is not one. */
  static asObject(value: JsonValue | undefined): JsonObject | undefined {
    if (!Json.isObject(value)) {
      return undefined;
    }
    return value as object as JsonObject;
  }

  /** Reads `value` as a JSON array, or `undefined` when it is not one. */
  static asArray(value: JsonValue | undefined): JsonArray | undefined {
    if (!Json.isArray(value)) {
      return undefined;
    }
    return value as JsonArray;
  }

  /** Reads `value` as a string, or `undefined` when it is not one. */
  static asString(value: JsonValue | undefined): string | undefined {
    return typeof value === 'string' ? value : undefined;
  }

  /** Reads `value` as a finite number, or `undefined` when it is not one. */
  static asNumber(value: JsonValue | undefined): number | undefined {
    return typeof value === 'number' && Number.isFinite(value) ? value : undefined;
  }

  /** Reads `value` as an integer, or `undefined` when it is not a number. */
  static asInteger(value: JsonValue | undefined): number | undefined {
    const num = Json.asNumber(value);
    return num === undefined ? undefined : Math.trunc(num);
  }

  /** Reads `value` as a boolean, or `undefined` when it is not one. */
  static asBoolean(value: JsonValue | undefined): boolean | undefined {
    return typeof value === 'boolean' ? value : undefined;
  }

  /**
   * Reads `value` as a boolean, tolerating the legacy `0`/`1` encoding that
   * Transmission < 4.1.0 uses for `wanted` and friends.
   */
  static asLooseBoolean(value: JsonValue | undefined): boolean | undefined {
    const direct = Json.asBoolean(value);
    if (direct !== undefined) {
      return direct;
    }
    const num = Json.asNumber(value);
    if (num === 0) {
      return false;
    }
    if (num === 1) {
      return true;
    }
    return undefined;
  }

  /**
   * Reads `key` of `source` without throwing.
   *
   * @returns `undefined` when the key is absent or explicitly `null`-less
   */
  static get(source: JsonObject | undefined, key: string): JsonValue | undefined {
    return source === undefined ? undefined : source[key];
  }

  /** True when `source` owns `key`. */
  static has(source: JsonObject | undefined, key: string): boolean {
    return source !== undefined && Object.keys(source).includes(key);
  }

  /** Reads `key` of `source` as a JSON object. */
  static getObject(source: JsonObject | undefined, key: string): JsonObject | undefined {
    return Json.asObject(Json.get(source, key));
  }

  /** Reads `key` of `source` as a JSON array. */
  static getArray(source: JsonObject | undefined, key: string): JsonArray | undefined {
    return Json.asArray(Json.get(source, key));
  }

  /** Reads `key` of `source` as a string. */
  static getString(source: JsonObject | undefined, key: string, fallback?: string): string {
    const value = Json.asString(Json.get(source, key));
    return value === undefined ? (fallback === undefined ? '' : fallback) : value;
  }

  /** Reads `key` of `source` as a number. */
  static getNumber(source: JsonObject | undefined, key: string, fallback: number = 0): number {
    const value = Json.asNumber(Json.get(source, key));
    return value === undefined ? fallback : value;
  }

  /** Reads `key` of `source` as a boolean, tolerating the legacy `0`/`1` form. */
  static getBoolean(source: JsonObject | undefined, key: string, fallback: boolean = false): boolean {
    const value = Json.asLooseBoolean(Json.get(source, key));
    return value === undefined ? fallback : value;
  }

  /** Reads `key` of `source` as a list of strings, skipping malformed entries. */
  static getStringArray(source: JsonObject | undefined, key: string): string[] {
    return Json.toStringArray(Json.getArray(source, key));
  }

  /** Converts a JSON array into a string array, skipping malformed entries. */
  static toStringArray(values: JsonArray | undefined): string[] {
    const result: string[] = [];
    if (values === undefined) {
      return result;
    }
    for (const value of values) {
      const text = Json.asString(value);
      if (text !== undefined) {
        result.push(text);
      }
    }
    return result;
  }

  /** Converts a JSON array into a number array, skipping malformed entries. */
  static toNumberArray(values: JsonArray | undefined): number[] {
    const result: number[] = [];
    if (values === undefined) {
      return result;
    }
    for (const value of values) {
      const num = Json.asNumber(value);
      if (num !== undefined) {
        result.push(num);
      }
    }
    return result;
  }

  /** Converts a JSON array into an object array, skipping malformed entries. */
  static toObjectArray(values: JsonArray | undefined): JsonObject[] {
    const result: JsonObject[] = [];
    if (values === undefined) {
      return result;
    }
    for (const value of values) {
      const obj = Json.asObject(value);
      if (obj !== undefined) {
        result.push(obj);
      }
    }
    return result;
  }

  /** Enumerates the own keys of a JSON object. */
  static keys(source: JsonObject | undefined): string[] {
    return source === undefined ? [] : Object.keys(source);
  }

  /** True when `source` has no own keys. */
  static isEmpty(source: JsonObject | undefined): boolean {
    return Json.keys(source).length === 0;
  }

  /** Parses a JSON document. Throws a `SyntaxError` when the text is malformed. */
  static parse(text: string): JsonValue {
    return JSON.parse(text) as JsonValue;
  }

  /** Serialises a JSON value. */
  static stringify(value: JsonValue): string {
    return JSON.stringify(value);
  }

  /** Deep-copies a JSON value, detaching it from the original graph. */
  static clone(value: JsonValue): JsonValue {
    if (Json.isObject(value) || Json.isArray(value)) {
      return JSON.parse(JSON.stringify(value)) as JsonValue;
    }
    return value;
  }

  /** Structural equality for JSON values. */
  static deepEquals(left: JsonValue | undefined, right: JsonValue | undefined): boolean {
    if (left === right) {
      return true;
    }
    if (left === undefined || right === undefined || left === null || right === null) {
      return false;
    }

    const leftArray = Json.asArray(left);
    const rightArray = Json.asArray(right);
    if (leftArray !== undefined && rightArray !== undefined) {
      if (leftArray.length !== rightArray.length) {
        return false;
      }
      for (let i = 0; i < leftArray.length; i++) {
        if (!Json.deepEquals(leftArray[i], rightArray[i])) {
          return false;
        }
      }
      return true;
    }

    const leftObject = Json.asObject(left);
    const rightObject = Json.asObject(right);
    if (leftObject !== undefined && rightObject !== undefined) {
      const keys = Json.keys(leftObject);
      if (keys.length !== Json.keys(rightObject).length) {
        return false;
      }
      for (const key of keys) {
        if (!Json.deepEquals(leftObject[key], rightObject[key])) {
          return false;
        }
      }
      return true;
    }

    return false;
  }
}

/**
 * Fluent builder for {@link JsonObject} literals.
 *
 * Using a builder keeps "only send what the caller actually set" logic explicit:
 * `undefined` values are silently dropped instead of being serialised as `null`.
 */
export class JsonObjectBuilder {
  private readonly values: JsonObject = {};

  /** Returns a fresh builder. */
  static create(): JsonObjectBuilder {
    return new JsonObjectBuilder();
  }

  /** Adds `key` when `value` is defined. */
  set(key: string, value: JsonValue | undefined): JsonObjectBuilder {
    if (value !== undefined) {
      this.values[key] = value;
    }
    return this;
  }

  /** Adds `key` when `value` is defined and non-empty. */
  setNonEmpty(key: string, value: string | undefined): JsonObjectBuilder {
    if (value !== undefined && value.length > 0) {
      this.values[key] = value;
    }
    return this;
  }

  /** Adds `key` when `value` is defined. */
  setNumber(key: string, value: number | undefined): JsonObjectBuilder {
    return this.set(key, value);
  }

  /** Adds `key` when `value` is defined. */
  setBoolean(key: string, value: boolean | undefined): JsonObjectBuilder {
    return this.set(key, value);
  }

  /** Adds `key` when `value` is a non-empty array. */
  setArray(key: string, value: JsonArray | undefined): JsonObjectBuilder {
    if (value !== undefined && value.length > 0) {
      this.values[key] = value;
    }
    return this;
  }

  /** Adds `key` when `value` is defined, including empty arrays and objects. */
  setAlways(key: string, value: JsonValue | undefined): JsonObjectBuilder {
    if (value !== undefined) {
      this.values[key] = value;
    }
    return this;
  }

  /** Adds `key` when `value` is a non-empty object. */
  setObject(key: string, value: JsonObject | undefined): JsonObjectBuilder {
    if (value !== undefined && !Json.isEmpty(value)) {
      this.values[key] = value;
    }
    return this;
  }

  /** True when `key` has already been set. */
  has(key: string): boolean {
    return Json.has(this.values, key);
  }

  /** Returns the accumulated object. The builder is not reused internally. */
  build(): JsonObject {
    return this.values;
  }
}
