// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Builders for the response envelopes of both RPC dialects.
 *
 * Keeping the envelope shapes in one place makes the dialect-specific tests read
 * as a description of the protocol rather than as JSON soup.
 *
 * @since 1.0.0
 */

import { Json, JsonObject, JsonValue } from '../../main/ets/util/Json';

/** Wire helpers for constructing canned server responses. */
export class RpcFakes {
  private constructor() {
    // Static-only utility class.
  }

  /**
   * A successful JSON-RPC 2.0 response.
   *
   * @param result the `result` object
   * @param id correlation id, matching the request
   */
  static modernSuccess(result: JsonValue, id: number = 1): JsonValue {
    const body: JsonObject = {};
    body['jsonrpc'] = '2.0';
    body['result'] = result;
    body['id'] = id;
    return body;
  }

  /**
   * A failed JSON-RPC 2.0 response.
   *
   * @param code JSON-RPC or Transmission error code
   * @param message short description
   * @param id correlation id
   * @param data optional `error.data` payload
   */
  static modernError(code: number, message: string = 'error', id: number = 1, data?: JsonValue): JsonValue {
    const body: JsonObject = {};
    body['jsonrpc'] = '2.0';
    body['error'] = RpcFakes.modernErrorObject(code, message, data);
    body['id'] = id;
    return body;
  }

  /**
   * The bare JSON-RPC `error` object, for tests that build an envelope by hand.
   *
   * @param code JSON-RPC or Transmission error code
   * @param message short description; omit it to exercise the client's fallback
   * @param data optional `error.data` payload
   */
  static modernErrorObject(code: number, message?: string, data?: JsonValue): JsonObject {
    const error: JsonObject = {};
    error['code'] = code;
    if (message !== undefined) {
      error['message'] = message;
    }
    if (data !== undefined) {
      error['data'] = data;
    }
    return error;
  }

  /**
   * A successful legacy response.
   *
   * @param args the `arguments` object
   * @param tag correlation id, matching the request
   */
  static legacySuccess(args: JsonValue, tag: number = 1): JsonValue {
    const body: JsonObject = {};
    body['arguments'] = args;
    body['result'] = 'success';
    body['tag'] = tag;
    return body;
  }

  /**
   * A failed legacy response.
   *
   * The legacy API carries errors as a plain string in `result`.
   *
   * @param message error text, e.g. `"no method name"`
   * @param args optional `arguments` payload
   * @param tag correlation id
   */
  static legacyError(message: string, args?: JsonValue, tag: number = 1): JsonValue {
    const body: JsonObject = {};
    body['arguments'] = args === undefined ? Json.emptyObject() : args;
    body['result'] = message;
    body['tag'] = tag;
    return body;
  }

  /**
   * A `torrent_get` result carrying torrent objects.
   *
   * @param torrents raw torrent objects in canonical (modern) form
   */
  static torrentGetResult(torrents: JsonValue[]): JsonValue {
    const result: JsonObject = {};
    result['torrents'] = torrents;
    return result;
  }

  /** A minimal, fully populated torrent object. */
  static torrent(id: number, name: string, percentDone: number = 0.5): JsonObject {
    const torrent: JsonObject = {};
    torrent['id'] = id;
    torrent['name'] = name;
    torrent['status'] = 4;
    torrent['percent_done'] = percentDone;
    torrent['rate_download'] = 1024;
    torrent['rate_upload'] = 128;
    torrent['total_size'] = 4096;
    torrent['hash_string'] = `hash-${id}`;
    return torrent;
  }
}
