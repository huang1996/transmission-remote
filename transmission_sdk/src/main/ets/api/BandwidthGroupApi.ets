// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Bandwidth group operations (`group_get`, `group_set`).
 *
 * Bandwidth groups let one daemon serve several independent speed budgets; a
 * torrent joins a group through `torrent_set`'s `group` field.
 *
 * @since 1.0.0
 */

import { JsonObject, JsonObjectBuilder } from '../util/Json';
import { RpcClient } from '../core/RpcClient';
import { RpcMethod } from '../constants/RpcMethods';
import { BandwidthGroup } from '../model/BandwidthGroup';

/**
 * Fluent request for `group_set`.
 *
 * `name` is mandatory; every other field is optional and only the fields that
 * are set are sent.
 *
 * @since 1.0.0
 */
export class BandwidthGroupSetRequest {
  private readonly params: JsonObjectBuilder = new JsonObjectBuilder();

  /**
   * @param name name of the group to create or update
   */
  constructor(name: string) {
    this.params.setAlways('name', name);
  }

  /** Whether the session-wide speed limits also apply inside this group. */
  honorsSessionLimits(enabled: boolean): BandwidthGroupSetRequest {
    this.params.setAlways('honors_session_limits', enabled);
    return this;
  }

  /** Download limit in kB/s. */
  speedLimitDown(kilobytesPerSecond: number): BandwidthGroupSetRequest {
    this.params.setAlways('speed_limit_down', kilobytesPerSecond);
    return this;
  }

  /** Enables or disables the group's download limit. */
  speedLimitDownEnabled(enabled: boolean): BandwidthGroupSetRequest {
    this.params.setAlways('speed_limit_down_enabled', enabled);
    return this;
  }

  /** Upload limit in kB/s. */
  speedLimitUp(kilobytesPerSecond: number): BandwidthGroupSetRequest {
    this.params.setAlways('speed_limit_up', kilobytesPerSecond);
    return this;
  }

  /** Enables or disables the group's upload limit. */
  speedLimitUpEnabled(enabled: boolean): BandwidthGroupSetRequest {
    this.params.setAlways('speed_limit_up_enabled', enabled);
    return this;
  }

  /** Serialises the request into RPC parameters. */
  toJson(): JsonObject {
    return this.params.build();
  }
}

/**
 * Access to bandwidth groups.
 *
 * ```ts
 * const groups = await client.groups.getAll();
 * await client.groups.set(
 *   new BandwidthGroupSetRequest('media')
 *     .speedLimitDown(4096)
 *     .speedLimitDownEnabled(true),
 * );
 * ```
 */
export class BandwidthGroupApi {
  private readonly rpc: RpcClient;

  /**
   * @param rpc the shared RPC engine; normally created by `TransmissionClient`
   */
  constructor(rpc: RpcClient) {
    this.rpc = rpc;
  }

  /**
   * Reads every bandwidth group.
   *
   * @param names restrict the query to these group names
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async getAll(names?: string[]): Promise<BandwidthGroup[]> {
    const params = new JsonObjectBuilder();
    if (names !== undefined && names.length > 0) {
      params.setAlways('name', names.slice());
    }
    return BandwidthGroup.listFromJson(await this.rpc.call(RpcMethod.GROUP_GET, params.build()));
  }

  /**
   * Reads one bandwidth group.
   *
   * @param name group name
   * @returns the group, or `undefined` when it does not exist
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async get(name: string): Promise<BandwidthGroup | undefined> {
    const groups = await this.getAll([name]);
    return groups.length === 0 ? undefined : groups[0];
  }

  /**
   * Creates or updates a bandwidth group.
   *
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async set(request: BandwidthGroupSetRequest): Promise<void> {
    await this.rpc.call(RpcMethod.GROUP_SET, request.toJson());
  }
}
