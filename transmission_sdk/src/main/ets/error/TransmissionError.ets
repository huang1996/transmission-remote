// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Error model shared by every layer of the SDK.
 *
 * Two numbering schemes exist on the wire and both are normalised into
 * {@link RpcErrorCode}:
 *
 * - JSON-RPC 2.0 reserved codes (`-32700` … `-32603`), used by
 *   Transmission >= 4.1.0.
 * - Transmission-specific codes (`1` … `10`), used by the JSON-RPC API and
 *   approximated from the error *message* when talking to the legacy API,
 *   which only ever returns a human readable string.
 *
 * @since 1.0.0
 */

import { JsonObject } from '../util/Json';

/** Normalised RPC error codes. */
export enum RpcErrorCode {
  /** The request was successful. Never surfaced as an error. */
  SUCCESS = 0,
  /** Invalid JSON was received by the server. */
  PARSE_ERROR = -32700,
  /** The JSON sent is not a valid Request object. */
  INVALID_REQUEST = -32600,
  /** The method does not exist / is not available. */
  METHOD_NOT_FOUND = -32601,
  /** Invalid method parameter(s). */
  INVALID_PARAMS = -32602,
  /** Internal JSON-RPC error. */
  INTERNAL_ERROR = -32603,
  /** Transmission: could not apply the announce list. */
  SET_ANNOUNCE_LIST = 1,
  /** Transmission: the tracker list is malformed. */
  INVALID_TRACKER_LIST = 2,
  /** Transmission: a path argument was not absolute. */
  PATH_NOT_ABSOLUTE = 3,
  /** Transmission: unrecognised metainfo. */
  UNRECOGNIZED_INFO = 4,
  /** Transmission: a filesystem or operating-system call failed. */
  SYSTEM_ERROR = 5,
  /** Transmission: a file index was out of range. */
  FILE_IDX_OOR = 6,
  /** Transmission: a piece index was out of range. */
  PIECE_IDX_OOR = 7,
  /** Transmission: an HTTP request to a backend service failed. */
  HTTP_ERROR = 8,
  /** Transmission: the .torrent payload is invalid or corrupt. */
  CORRUPT_TORRENT = 9,
  /** Transmission: no valid rules were found in the blocklist. */
  INVALID_BLOCKLIST_DATA = 10,
  /** The server reported a code this SDK does not know about. */
  UNKNOWN = 1000,
}

/** Human readable description of an {@link RpcErrorCode}. */
export function rpcErrorMessage(code: RpcErrorCode): string {
  switch (code) {
    case RpcErrorCode.SUCCESS:
      return 'success';
    case RpcErrorCode.PARSE_ERROR:
      return 'Parse error';
    case RpcErrorCode.INVALID_REQUEST:
      return 'Invalid Request';
    case RpcErrorCode.METHOD_NOT_FOUND:
      return 'Method not found';
    case RpcErrorCode.INVALID_PARAMS:
      return 'Invalid params';
    case RpcErrorCode.INTERNAL_ERROR:
      return 'Internal error';
    case RpcErrorCode.SET_ANNOUNCE_LIST:
      return 'error setting announce list';
    case RpcErrorCode.INVALID_TRACKER_LIST:
      return 'Invalid tracker list';
    case RpcErrorCode.PATH_NOT_ABSOLUTE:
      return 'path is not absolute';
    case RpcErrorCode.UNRECOGNIZED_INFO:
      return 'unrecognized info';
    case RpcErrorCode.SYSTEM_ERROR:
      return 'system error';
    case RpcErrorCode.FILE_IDX_OOR:
      return 'file index out of range';
    case RpcErrorCode.PIECE_IDX_OOR:
      return 'piece index out of range';
    case RpcErrorCode.HTTP_ERROR:
      return 'HTTP error from backend service';
    case RpcErrorCode.CORRUPT_TORRENT:
      return 'invalid or corrupt torrent file';
    case RpcErrorCode.INVALID_BLOCKLIST_DATA:
      return "couldn't parse any valid blocklist rules";
    default:
      return 'unknown error';
  }
}

/**
 * A legacy error message and the code it stands for.
 *
 * A class rather than two parallel arrays: the phrase and its code used to be
 * separate lists, where inserting one without the other would silently mislabel
 * every subsequent error.
 */
export class LegacyErrorPhrase {
  /** Substring to look for, lower-cased. */
  readonly phrase: string;
  /** Code the phrase stands for. */
  readonly code: RpcErrorCode;

  /**
   * @param phrase substring to look for
   * @param code code the phrase stands for
   */
  constructor(phrase: string, code: RpcErrorCode) {
    this.phrase = phrase;
    this.code = code;
  }
}

/**
 * Legacy error messages that Transmission < 4.1.0 returns in place of an error
 * code. Ported from `guess_error_code()` in `libtransmission/api-compat.cc`, and
 * extended with the messages that only older releases produce.
 *
 * The "method not found" case is why this table has to cover more than the
 * current source does: Transmission 4.0.x distinguishes
 *
 * - `"no method name"` — the request carried no `method` field, and
 * - `"method name not recognized"` — the method exists in neither dialect,
 *
 * while 4.1.0's compatibility layer only ever emits the first when it translates
 * a JSON-RPC `METHOD_NOT_FOUND`. Matching on the first alone made the automatic
 * downgrade silently fail against a 4.0.x server: the reply was classified as
 * `UNKNOWN` instead of `METHOD_NOT_FOUND`, so the retry never happened.
 */
const LEGACY_ERROR_PHRASES: LegacyErrorPhrase[] = [
  new LegacyErrorPhrase('absolute', RpcErrorCode.PATH_NOT_ABSOLUTE),
  new LegacyErrorPhrase("couldn't fetch blocklist", RpcErrorCode.HTTP_ERROR),
  new LegacyErrorPhrase("couldn't save", RpcErrorCode.SYSTEM_ERROR),
  new LegacyErrorPhrase("couldn't test port", RpcErrorCode.HTTP_ERROR),
  new LegacyErrorPhrase('file index out of range', RpcErrorCode.FILE_IDX_OOR),
  new LegacyErrorPhrase('invalid ip protocol', RpcErrorCode.INVALID_PARAMS),
  new LegacyErrorPhrase('invalid or corrupt torrent', RpcErrorCode.CORRUPT_TORRENT),
  new LegacyErrorPhrase('invalid tracker list', RpcErrorCode.INVALID_TRACKER_LIST),
  new LegacyErrorPhrase('labels cannot', RpcErrorCode.INVALID_PARAMS),
  new LegacyErrorPhrase('method name not recognized', RpcErrorCode.METHOD_NOT_FOUND),
  new LegacyErrorPhrase('no filename or metainfo specified', RpcErrorCode.INVALID_PARAMS),
  new LegacyErrorPhrase('no location', RpcErrorCode.INVALID_PARAMS),
  new LegacyErrorPhrase('no method name', RpcErrorCode.METHOD_NOT_FOUND),
  new LegacyErrorPhrase('torrent-rename-path requires 1 torrent', RpcErrorCode.INVALID_PARAMS),
  new LegacyErrorPhrase('unrecognized info', RpcErrorCode.UNRECOGNIZED_INFO),
];

/**
 * Best-effort translation of a legacy error string into a {@link RpcErrorCode}.
 *
 * The legacy API has no error codes, so the code is inferred from well-known
 * phrases. Unknown messages map to {@link RpcErrorCode.UNKNOWN} while the
 * original text is preserved on the error object.
 */
export function rpcErrorCodeFromMessage(message: string): RpcErrorCode {
  const lower = message.toLowerCase();
  if (lower === 'success') {
    return RpcErrorCode.SUCCESS;
  }
  for (const entry of LEGACY_ERROR_PHRASES) {
    if (lower.includes(entry.phrase)) {
      return entry.code;
    }
  }
  return RpcErrorCode.UNKNOWN;
}

/** Coarse classification of an SDK failure, useful for `switch`-based handling. */
export enum TransmissionErrorKind {
  /** The request never reached the server (DNS, socket, TLS, …). */
  TRANSPORT = 'transport',
  /** The server answered with an unexpected HTTP status. */
  HTTP = 'http',
  /** The response body was not valid JSON, or not a valid RPC envelope. */
  PROTOCOL = 'protocol',
  /** The server returned a JSON-RPC/bespoke error object. */
  RPC = 'rpc',
  /** The request exceeded the configured timeout. */
  TIMEOUT = 'timeout',
  /** HTTP 401 — `username`/`password` are missing or wrong. */
  AUTHENTICATION = 'authentication',
  /** The client configuration is invalid. */
  CONFIGURATION = 'configuration',
  /** The feature requires a newer Transmission/RPC version. */
  UNSUPPORTED = 'unsupported',
  /** The request was cancelled by the caller. */
  CANCELLED = 'cancelled',
}

/** Optional details attached to a {@link TransmissionError}. */
export interface TransmissionErrorOptions {
  /** Normalised RPC error code, when the failure came from the server. */
  rpcCode?: RpcErrorCode;
  /** Raw `code` value as received on the wire, before normalisation. */
  rawCode?: number;
  /** HTTP status code, when a response was received. */
  httpStatus?: number;
  /** `error.data` payload of a JSON-RPC error object. */
  data?: JsonObject;
  /** Extra server-provided detail (`error.data.error_string`). */
  detail?: string;
  /** The HTTP method + URL that produced the failure. */
  request?: string;
  /** Underlying platform error. */
  cause?: Error;
}

/**
 * The single error type thrown by every public SDK method.
 *
 * Applications can branch on {@link kind} for coarse handling and on
 * {@link rpcCode} for protocol-level precision.
 */
export class TransmissionError extends Error {
  /** Coarse failure category. */
  readonly kind: TransmissionErrorKind;
  /** Normalised RPC error code, when applicable. */
  readonly rpcCode: RpcErrorCode | undefined;
  /** Raw code received from the server, when applicable. */
  readonly rawCode: number | undefined;
  /** HTTP status code, when a response was received. */
  readonly httpStatus: number | undefined;
  /** `error.data` payload, when supplied by the server. */
  readonly data: JsonObject | undefined;
  /** Server-provided detail string, when supplied. */
  readonly detail: string | undefined;
  /** `"METHOD https://host/path"` description of the failing request. */
  readonly request: string | undefined;
  /** Underlying platform error, when the failure was wrapped. */
  readonly cause: Error | undefined;

  constructor(kind: TransmissionErrorKind, message: string, options?: TransmissionErrorOptions) {
    super(message);
    this.name = 'TransmissionError';
    this.kind = kind;
    this.rpcCode = options?.rpcCode;
    this.rawCode = options?.rawCode;
    this.httpStatus = options?.httpStatus;
    this.data = options?.data;
    this.detail = options?.detail;
    this.request = options?.request;
    this.cause = options?.cause;
  }

  /** True when retrying the very same request may succeed. */
  get retryable(): boolean {
    switch (this.kind) {
      case TransmissionErrorKind.TRANSPORT:
      case TransmissionErrorKind.TIMEOUT:
        return true;
      case TransmissionErrorKind.HTTP:
        return this.httpStatus === 502 || this.httpStatus === 503 || this.httpStatus === 504;
      default:
        return false;
    }
  }

  /** Message including the server detail, when present. */
  get fullMessage(): string {
    const base = this.message;
    if (this.detail === undefined || this.detail.length === 0 || this.detail === base) {
      return base;
    }
    return `${base}: ${this.detail}`;
  }

  /** Builds a transport-level failure. */
  static transport(message: string, request?: string, cause?: Error): TransmissionError {
    return new TransmissionError(TransmissionErrorKind.TRANSPORT, message, { request, cause });
  }

  /** Builds a timeout failure. */
  static timeout(message: string, request?: string): TransmissionError {
    return new TransmissionError(TransmissionErrorKind.TIMEOUT, message, { request });
  }

  /** Builds a protocol failure. */
  static protocol(message: string, request?: string): TransmissionError {
    return new TransmissionError(TransmissionErrorKind.PROTOCOL, message, { request });
  }

  /** Builds an authentication failure. */
  static authentication(message: string, httpStatus: number, request?: string): TransmissionError {
    return new TransmissionError(TransmissionErrorKind.AUTHENTICATION, message, { httpStatus, request });
  }

  /** Builds an unexpected-HTTP-status failure. */
  static http(message: string, httpStatus: number, request?: string): TransmissionError {
    return new TransmissionError(TransmissionErrorKind.HTTP, message, { httpStatus, request });
  }

  /** Builds an RPC failure from a normalised code. */
  static rpc(
    code: RpcErrorCode,
    message: string,
    options?: TransmissionErrorOptions,
  ): TransmissionError {
    const merged: TransmissionErrorOptions = {
      rpcCode: code,
      rawCode: options?.rawCode,
      httpStatus: options?.httpStatus,
      data: options?.data,
      detail: options?.detail,
      request: options?.request,
      cause: options?.cause,
    };
    return new TransmissionError(TransmissionErrorKind.RPC, message, merged);
  }

  /** Builds a feature-not-supported failure with an actionable message. */
  static unsupported(feature: string, requiredVersion: string, actualVersion?: string): TransmissionError {
    const actual = actualVersion === undefined ? 'unknown' : actualVersion;
    const message = `${feature} requires RPC version ${requiredVersion}; the server reports ${actual}`;
    return new TransmissionError(TransmissionErrorKind.UNSUPPORTED, message);
  }

  /** Builds an invalid-configuration failure. */
  static configuration(message: string): TransmissionError {
    return new TransmissionError(TransmissionErrorKind.CONFIGURATION, message);
  }
}
