// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Session operations (`session_get`, `session_set`, `session_stats`,
 * `session_close`).
 *
 * @since 1.0.0
 */

import { JsonObject, JsonObjectBuilder } from '../util/Json';
import { RpcClient } from '../core/RpcClient';
import { RpcMethod } from '../constants/RpcMethods';
import { SessionSettings } from '../model/SessionSettings';
import { SessionStats } from '../model/SessionStats';
import { SessionSetRequest } from '../model/SessionSetRequest';

/**
 * Access to session settings, statistics and lifecycle.
 *
 * ```ts
 * const settings = await client.session.get();
 * await client.session.set(new SessionSetRequest().downloadDir('/srv/media'));
 * const stats = await client.session.stats();
 * ```
 */
export class SessionApi {
  private readonly rpc: RpcClient;

  /**
   * @param rpc the shared RPC engine; normally created by `TransmissionClient`
   */
  constructor(rpc: RpcClient) {
    this.rpc = rpc;
  }

  /**
   * Reads session settings.
   *
   * @param fields limits the response to the listed keys; omit it to fetch
   *        everything. Fewer fields means a smaller payload, and the full
   *        payload includes a nested `units` object.
   *
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async get(fields?: string[]): Promise<SessionSettings> {
    return SessionSettings.fromJson(await this.getRaw(fields));
  }

  /**
   * Reads session settings without mapping them onto {@link SessionSettings}.
   *
   * @param fields limits the response to the listed keys
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async getRaw(fields?: string[]): Promise<JsonObject> {
    const params = new JsonObjectBuilder();
    if (fields !== undefined && fields.length > 0) {
      params.setAlways('fields', fields.slice());
    }
    return this.rpc.call(RpcMethod.SESSION_GET, params.build());
  }

  /**
   * Changes session settings.
   *
   * @param request a request built with {@link SessionSetRequest}
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async set(request: SessionSetRequest): Promise<void> {
    await this.rpc.call(RpcMethod.SESSION_SET, request.toJson());
  }

  /**
   * Changes a single session setting by its canonical wire name.
   *
   * @param key e.g. `download_dir`
   * @param value new value
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async setValue(key: string, value: string | number | boolean): Promise<void> {
    const params: JsonObject = {};
    params[key] = value;
    await this.rpc.call(RpcMethod.SESSION_SET, params);
  }

  /**
   * Reads session transfer statistics.
   *
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async stats(): Promise<SessionStats> {
    return SessionStats.fromJson(await this.rpc.call(RpcMethod.SESSION_STATS));
  }

  /**
   * Asks the daemon to shut down.
   *
   * The HTTP response is sent before the process exits, so a successful return
   * only means the request was accepted.
   *
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async close(): Promise<void> {
    await this.rpc.call(RpcMethod.SESSION_CLOSE);
  }
}
