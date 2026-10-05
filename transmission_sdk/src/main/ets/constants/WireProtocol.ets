// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Constants of the Transmission RPC wire protocol.
 *
 * @since 1.0.0
 */

/** HTTP header carrying the CSRF session id. */
export const HEADER_SESSION_ID: string = 'x-transmission-session-id';

/**
 * HTTP header carrying `rpc_version_semver`.
 *
 * Transmission >= 4.1.0 adds it to the HTTP 409 (CSRF) response, which lets a
 * client decide between the JSON-RPC and the legacy protocol without spending
 * an extra request.
 */
export const HEADER_RPC_VERSION: string = 'x-transmission-rpc-version';

/** HTTP header used for HTTP Basic authentication. */
export const HEADER_AUTHORIZATION: string = 'authorization';

/** HTTP header declaring the request body type. */
export const HEADER_CONTENT_TYPE: string = 'content-type';

/** MIME type of every RPC request body. */
export const CONTENT_TYPE_JSON: string = 'application/json';

/** Default RPC endpoint of a Transmission daemon. */
export const DEFAULT_RPC_URL: string = 'http://127.0.0.1:9091/transmission/rpc';

/** Default RPC port of a Transmission daemon. */
export const DEFAULT_RPC_PORT: number = 9091;

/** Default RPC path of a Transmission daemon. */
export const DEFAULT_RPC_PATH: string = '/transmission/rpc';

/** The only `jsonrpc` version Transmission accepts. */
export const JSONRPC_VERSION: string = '2.0';

/** Legacy success marker returned in the top-level `result` field. */
export const LEGACY_SUCCESS: string = 'success';

/** Key of the JSON-RPC request/response envelope fields. */
export class WireKeys {
  /** `jsonrpc` */
  static readonly JSONRPC: string = 'jsonrpc';
  /** `method` */
  static readonly METHOD: string = 'method';
  /** `params` (JSON-RPC) */
  static readonly PARAMS: string = 'params';
  /** `arguments` (legacy) */
  static readonly ARGUMENTS: string = 'arguments';
  /** `result` */
  static readonly RESULT: string = 'result';
  /** `error` */
  static readonly ERROR: string = 'error';
  /** `id` (JSON-RPC) */
  static readonly ID: string = 'id';
  /** `tag` (legacy) */
  static readonly TAG: string = 'tag';
  /** `code` */
  static readonly CODE: string = 'code';
  /** `message` */
  static readonly MESSAGE: string = 'message';
  /** `data` */
  static readonly DATA: string = 'data';
  /** `error_string` */
  static readonly ERROR_STRING: string = 'error_string';
  /** `torrents` */
  static readonly TORRENTS: string = 'torrents';
  /** `fields` */
  static readonly FIELDS: string = 'fields';
  /** `ids` */
  static readonly IDS: string = 'ids';
  /** `format` */
  static readonly FORMAT: string = 'format';
  /** `wanted` */
  static readonly WANTED: string = 'wanted';
  /** `download_dir` */
  static readonly DOWNLOAD_DIR: string = 'download_dir';
  /** `total_size` */
  static readonly TOTAL_SIZE: string = 'total_size';
  /** `path` */
  static readonly PATH: string = 'path';
  /** `size_bytes` */
  static readonly SIZE_BYTES: string = 'size_bytes';
  /** `encryption` */
  static readonly ENCRYPTION: string = 'encryption';

  /** Legacy spellings that the compatibility layer must recognise. */
  static readonly LEGACY_DOWNLOAD_DIR_CAMEL: string = 'downloadDir';
  /** `download-dir` */
  static readonly LEGACY_DOWNLOAD_DIR_KEBAB: string = 'download-dir';
  /** `totalSize` */
  static readonly LEGACY_TOTAL_SIZE_CAMEL: string = 'totalSize';
  /** `size-bytes` */
  static readonly LEGACY_SIZE_BYTES_KEBAB: string = 'size-bytes';

  private constructor() {
    // Static-only utility class.
  }
}

/** HTTP status codes the SDK reacts to explicitly. */
export enum HttpStatus {
  /** Request succeeded. */
  OK = 200,
  /** JSON-RPC notification accepted; no body. */
  NO_CONTENT = 204,
  /** Missing or stale CSRF session id. */
  CONFLICT = 409,
  /** Authentication required or rejected. */
  UNAUTHORIZED = 401,
  /** Hostname rejected by DNS-rebinding protection. */
  FORBIDDEN = 403,
  /** Payload too large. */
  PAYLOAD_TOO_LARGE = 413,
}
