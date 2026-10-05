// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Wire codecs: the boundary between the SDK's canonical vocabulary and the two
 * dialects Transmission understands.
 *
 * A codec owns exactly three responsibilities:
 *
 * 1. spelling the method name,
 * 2. wrapping/unwrapping the request/response envelope,
 * 3. translating field names through {@link KeyConverter}.
 *
 * Everything above this layer works exclusively with canonical snake_case
 * names, so application code never has to care which dialect is in use.
 *
 * @since 1.0.0
 */

import { Json, JsonObject, JsonValue } from '../util/Json';
import { RpcErrorCode, rpcErrorCodeFromMessage, rpcErrorMessage, TransmissionError } from '../error/TransmissionError';
import { ApiStyle } from './ApiStyle';
import { ConversionContext, KeyConverter } from './KeyConversion';
import { JSONRPC_VERSION, LEGACY_SUCCESS, WireKeys } from '../constants/WireProtocol';
import { RpcMethod } from '../constants/RpcMethods';

/** A logical RPC invocation expressed in canonical terms. */
export class RpcCall {
  /** Canonical method name. */
  readonly method: RpcMethod;
  /** Canonical parameters (snake_case keys). */
  readonly params: JsonObject;

  /**
   * @param method canonical method
   * @param params canonical parameters; `undefined` means "no parameters"
   */
  constructor(method: RpcMethod, params?: JsonObject) {
    this.method = method;
    this.params = params === undefined ? Json.emptyObject() : params;
  }
}

/** Decoded contents of a JSON-RPC `error` object. */
export class RpcErrorInfo {
  /** Normalised error code. */
  readonly code: RpcErrorCode;
  /** Code as received on the wire (`-32601`, `7`, …). */
  readonly rawCode: number;
  /** Short description from the server, or the canonical text for `code`. */
  readonly message: string;
  /** Additional `error.data.error_string`, when the server sent one. */
  readonly detail: string | undefined;
  /** Full `error.data` object, when the server sent one. */
  readonly data: JsonObject | undefined;
  /** `error.data.result`, carrying method-specific extra information. */
  readonly result: JsonObject | undefined;

  constructor(
    code: RpcErrorCode,
    rawCode: number,
    message: string,
    detail?: string,
    data?: JsonObject,
    result?: JsonObject,
  ) {
    this.code = code;
    this.rawCode = rawCode;
    this.message = message;
    this.detail = detail;
    this.data = data;
    this.result = result;
  }
}

/**
 * The decoded outcome of a single RPC call.
 *
 * Exactly one of {@link result} and {@link error} is set.
 */
export class RpcOutcome {
  /** Correlation id echoed by the server, when the dialect supports it. */
  readonly id: number | undefined;
  /** Canonical `result`/`arguments` object on success. */
  readonly result: JsonObject | undefined;
  /** Decoded error on failure. */
  readonly error: RpcErrorInfo | undefined;
  /**
   * True when the reply arrived in the legacy envelope shape
   * (`{"arguments": …, "result": …}`) rather than the JSON-RPC one.
   *
   * This is the reliable dialect signal. A server older than 4.1.0 has no
   * notion of `jsonrpc` at all, so it answers a JSON-RPC request in its own
   * envelope — and the *text* of the error it puts in `result` differs between
   * releases ("method name not recognized" in 4.0.x, "no method name" from
   * 4.1.0's compatibility layer). The shape never lies.
   */
  readonly legacyEnvelope: boolean;

  private constructor(
    id: number | undefined,
    result: JsonObject | undefined,
    error: RpcErrorInfo | undefined,
    legacyEnvelope: boolean,
  ) {
    this.id = id;
    this.result = result;
    this.error = error;
    this.legacyEnvelope = legacyEnvelope;
  }

  /**
   * Builds a successful outcome.
   *
   * @param legacyEnvelope true when the reply used the legacy envelope
   */
  static success(id: number | undefined, result: JsonObject | undefined, legacyEnvelope: boolean = false): RpcOutcome {
    return new RpcOutcome(id, result === undefined ? Json.emptyObject() : result, undefined, legacyEnvelope);
  }

  /**
   * Builds a failed outcome.
   *
   * @param legacyEnvelope true when the reply used the legacy envelope
   */
  static failure(id: number | undefined, error: RpcErrorInfo, legacyEnvelope: boolean = false): RpcOutcome {
    return new RpcOutcome(id, undefined, error, legacyEnvelope);
  }

  /** True when the server reported success. */
  get isSuccess(): boolean {
    return this.error === undefined;
  }

  /** The result object, or an empty object when the call failed. */
  get resultOrEmpty(): JsonObject {
    return this.result === undefined ? Json.emptyObject() : this.result;
  }

  /**
   * Converts this outcome into the SDK's error type.
   *
   * @param request `"METHOD url"` description used in diagnostics
   */
  toError(request?: string): TransmissionError {
    const info = this.error;
    if (info === undefined) {
      return TransmissionError.rpc(RpcErrorCode.UNKNOWN, 'the request did not fail', { request: request });
    }
    const message = info.message.length > 0 ? info.message : rpcErrorMessage(info.code);
    return TransmissionError.rpc(info.code, message, {
      rawCode: info.rawCode,
      data: info.data,
      detail: info.detail,
      request: request,
    });
  }
}

/**
 * Encodes canonical calls into a specific dialect and decodes the replies.
 *
 * Implementations are stateless, so a single instance can be shared by any
 * number of in-flight requests.
 */
export interface RpcCodec {
  /** Dialect implemented by this codec. */
  readonly style: ApiStyle;

  /** Wire spelling of `method`. */
  encodeMethodName(method: RpcMethod): string;

  /** Builds the complete request body for `call`. */
  encodeRequest(call: RpcCall, id: number): JsonObject;

  /** Wraps already-encoded requests into a batch body. */
  encodeBatch(encodedRequests: JsonObject[]): JsonValue;

  /** Decodes a single response body (or batch element). */
  decodeResponse(raw: JsonValue): RpcOutcome;

  /** Decodes a batch response body. */
  decodeBatch(raw: JsonValue): RpcOutcome[];
}

/**
 * Shared behaviour of both codecs.
 *
 * Subclasses only supply the envelope shape; error decoding, batch handling and
 * envelope validation live here so the two dialects cannot drift apart.
 */
export abstract class BaseRpcCodec implements RpcCodec {
  abstract readonly style: ApiStyle;

  abstract encodeMethodName(method: RpcMethod): string;

  abstract encodeRequest(call: RpcCall, id: number): JsonObject;

  abstract decodeResponse(raw: JsonValue): RpcOutcome;

  /** Both dialects accept a top-level JSON array of requests. */
  encodeBatch(encodedRequests: JsonObject[]): JsonValue {
    return encodedRequests;
  }

  /** Both dialects answer a batch with an array of responses. */
  decodeBatch(raw: JsonValue): RpcOutcome[] {
    const array = Json.asArray(raw);
    if (array === undefined) {
      return [this.decodeResponse(raw)];
    }
    const outcomes: RpcOutcome[] = [];
    for (const item of array) {
      outcomes.push(this.decodeResponse(item));
    }
    return outcomes;
  }

  /**
   * Extracts the correlation id from an envelope.
   *
   * @param envelope parsed response object
   * @param key `id` for JSON-RPC, `tag` for the legacy dialect
   */
  protected static extractId(envelope: JsonObject, key: string): number | undefined {
    return Json.asInteger(Json.get(envelope, key));
  }

  /** Reads the `error` member of an envelope, when present. */
  protected static extractErrorObject(envelope: JsonObject): JsonObject | undefined {
    return Json.asObject(Json.get(envelope, WireKeys.ERROR));
  }

  /** Reads the `result` member of an envelope, when present. */
  protected static extractResult(envelope: JsonObject): JsonValue | undefined {
    return Json.get(envelope, WireKeys.RESULT);
  }

  /** Requires `raw` to be a JSON object. */
  protected static requireEnvelope(raw: JsonValue): JsonObject {
    const envelope = Json.asObject(raw);
    if (envelope === undefined) {
      throw TransmissionError.protocol('the server did not return a JSON object');
    }
    return envelope;
  }

  /**
   * Decodes a JSON-RPC 2.0 `error` object.
   *
   * @param error the `error` member of the envelope
   * @param fallbackMessage used when the server omitted `message`
   */
  protected static decodeModernError(error: JsonObject): RpcErrorInfo {
    const rawCode = Json.asInteger(Json.get(error, WireKeys.CODE));
    const code = BaseRpcCodec.normaliseErrorCode(rawCode);
    const message = Json.asString(Json.get(error, WireKeys.MESSAGE));
    const data = Json.asObject(Json.get(error, WireKeys.DATA));
    const detail = data === undefined ? undefined : Json.asString(Json.get(data, WireKeys.ERROR_STRING));
    const result = data === undefined ? undefined : Json.asObject(Json.get(data, WireKeys.RESULT));
    return new RpcErrorInfo(
      code,
      rawCode === undefined ? 0 : rawCode,
      // When the server omits `message`, the canonical text for the code is far
      // more useful than a generic "unknown error".
      message === undefined ? rpcErrorMessage(code) : message,
      detail,
      data,
      result,
    );
  }

  /**
   * Decodes a *legacy* error, which is nothing more than a string in the
   * top-level `result` field.
   *
   * @param message the raw `result` string
   * @param data the legacy `arguments` object, re-exposed as `error.data`
   * @param id the correlation id carried by `tag`
   */
  protected static decodeLegacyError(
    message: string,
    data: JsonObject | undefined,
    id: number | undefined,
  ): RpcOutcome {
    const code = rpcErrorCodeFromMessage(message);
    // The legacy API has no `message` field; substitute the canonical text when
    // the phrase was recognised so callers get a stable, translatable string.
    // Unrecognised phrases are surfaced verbatim.
    const text = code === RpcErrorCode.UNKNOWN ? message : rpcErrorMessage(code);
    return RpcOutcome.failure(id, new RpcErrorInfo(code, code, text, message, data, data), true);
  }

  /**
   * Decodes a legacy-shaped body: `{"arguments": {...}, "result": "success"}`.
   *
   * A Transmission < 4.1.0 server always answers in this shape, even when it
   * received a JSON-RPC request, because it has no notion of `jsonrpc`.
   */
  protected static decodeLegacyEnvelope(envelope: JsonObject): RpcOutcome {
    const id = BaseRpcCodec.extractId(envelope, WireKeys.TAG);
    const args = Json.asObject(Json.get(envelope, WireKeys.ARGUMENTS));
    const result = BaseRpcCodec.extractResult(envelope);

    if (typeof result === 'string') {
      if (result === LEGACY_SUCCESS) {
        const canonical = KeyConverter.toCanonical(ConversionContext.forResponse(args), args);
        return RpcOutcome.success(id, Json.asObject(canonical), true);
      }
      return BaseRpcCodec.decodeLegacyError(result, args, id);
    }

    // Leniency: a modern server may reject a legacy batch element with a
    // JSON-RPC style error object.
    const error = BaseRpcCodec.extractErrorObject(envelope);
    if (error !== undefined) {
      return RpcOutcome.failure(id, BaseRpcCodec.decodeModernError(error));
    }

    throw TransmissionError.protocol('the legacy response has no `result` field');
  }

  /** Maps an arbitrary wire code onto {@link RpcErrorCode}. */
  private static normaliseErrorCode(rawCode: number | undefined): RpcErrorCode {
    if (rawCode === undefined) {
      return RpcErrorCode.UNKNOWN;
    }
    switch (rawCode) {
      case RpcErrorCode.SUCCESS:
      case RpcErrorCode.PARSE_ERROR:
      case RpcErrorCode.INVALID_REQUEST:
      case RpcErrorCode.METHOD_NOT_FOUND:
      case RpcErrorCode.INVALID_PARAMS:
      case RpcErrorCode.INTERNAL_ERROR:
      case RpcErrorCode.SET_ANNOUNCE_LIST:
      case RpcErrorCode.INVALID_TRACKER_LIST:
      case RpcErrorCode.PATH_NOT_ABSOLUTE:
      case RpcErrorCode.UNRECOGNIZED_INFO:
      case RpcErrorCode.SYSTEM_ERROR:
      case RpcErrorCode.FILE_IDX_OOR:
      case RpcErrorCode.PIECE_IDX_OOR:
      case RpcErrorCode.HTTP_ERROR:
      case RpcErrorCode.CORRUPT_TORRENT:
      case RpcErrorCode.INVALID_BLOCKLIST_DATA:
        return rawCode as RpcErrorCode;
      default:
        return RpcErrorCode.UNKNOWN;
    }
  }
}

/**
 * Codec for Transmission >= 4.1.0: JSON-RPC 2.0 with snake_case keys.
 *
 * The decoder also accepts legacy-shaped bodies so that the negotiator can
 * inspect the "method not found" reply produced by an older server.
 */
export class ModernCodec extends BaseRpcCodec {
  readonly style: ApiStyle = ApiStyle.MODERN;

  /** Shared instance: the codec is stateless. */
  private static readonly SHARED: ModernCodec = new ModernCodec();

  /** Returns the shared instance. */
  static instance(): ModernCodec {
    return ModernCodec.SHARED;
  }

  encodeMethodName(method: RpcMethod): string {
    return method;
  }

  encodeRequest(call: RpcCall, id: number): JsonObject {
    const body: JsonObject = {};
    body[WireKeys.JSONRPC] = JSONRPC_VERSION;
    body[WireKeys.METHOD] = call.method;
    // Canonical keys *are* the wire keys here, so the parameters are forwarded
    // untouched. Running them through the key converter would be actively
    // harmful: `download_dir` inside a `fields` array would become
    // `download-dir`, a name this dialect does not know.
    if (!Json.isEmpty(call.params)) {
      body[WireKeys.PARAMS] = call.params;
    }
    body[WireKeys.ID] = id;
    return body;
  }

  decodeResponse(raw: JsonValue): RpcOutcome {
    const envelope = BaseRpcCodec.requireEnvelope(raw);
    const id = BaseRpcCodec.extractId(envelope, WireKeys.ID);

    const error = BaseRpcCodec.extractErrorObject(envelope);
    if (error !== undefined) {
      return RpcOutcome.failure(id, BaseRpcCodec.decodeModernError(error));
    }

    const result = BaseRpcCodec.extractResult(envelope);
    if (typeof result === 'string') {
      // Legacy-shaped reply from a server that predates JSON-RPC support.
      return BaseRpcCodec.decodeLegacyEnvelope(envelope);
    }
    if (result === undefined) {
      if (Json.get(envelope, WireKeys.ARGUMENTS) !== undefined) {
        return BaseRpcCodec.decodeLegacyEnvelope(envelope);
      }
      throw TransmissionError.protocol('the server returned neither a result nor an error');
    }
    return RpcOutcome.success(id, Json.asObject(result));
  }
}

/**
 * Codec for Transmission < 4.1.0: the original bespoke protocol.
 *
 * Requests carry `method` / `arguments` / `tag`; responses carry `arguments`
 * plus a `result` string that is either `"success"` or a human readable error.
 */
export class LegacyCodec extends BaseRpcCodec {
  readonly style: ApiStyle = ApiStyle.LEGACY;

  /** Shared instance: the codec is stateless. */
  private static readonly SHARED: LegacyCodec = new LegacyCodec();

  /** Returns the shared instance. */
  static instance(): LegacyCodec {
    return LegacyCodec.SHARED;
  }

  /** Every legacy method name is the kebab-case form of the canonical one. */
  encodeMethodName(method: RpcMethod): string {
    // No regular-expression literals in ArkTS; split/join is the idiomatic
    // replacement and is just as fast for these fixed method names.
    return method.split('_').join('-');
  }

  encodeRequest(call: RpcCall, id: number): JsonObject {
    const body: JsonObject = {};
    body[WireKeys.METHOD] = this.encodeMethodName(call.method);
    const context = ConversionContext.forRequest(call.method);
    const args = Json.asObject(KeyConverter.toLegacy(context, call.params));
    body[WireKeys.ARGUMENTS] = args === undefined ? Json.emptyObject() : args;
    body[WireKeys.TAG] = id;
    return body;
  }

  decodeResponse(raw: JsonValue): RpcOutcome {
    return BaseRpcCodec.decodeLegacyEnvelope(BaseRpcCodec.requireEnvelope(raw));
  }
}
