// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Server utility operations (`free_space`, `port_test`, `blocklist_update`).
 *
 * @since 1.0.0
 */

import { Json, JsonObject, JsonObjectBuilder } from '../util/Json';
import { RpcClient } from '../core/RpcClient';
import { RpcMethod } from '../constants/RpcMethods';
import { FreeSpace, PortTestResult } from '../model/SystemInfo';
import { IpProtocol } from '../model/Enums';

/**
 * Access to server-level utilities.
 *
 * Most of these require the server to reach out to the network or the
 * filesystem, so they are slower than ordinary accessors and worth caching on
 * the caller's side.
 */
export class SystemApi {
  private readonly rpc: RpcClient;

  /**
   * @param rpc the shared RPC engine; normally created by `TransmissionClient`
   */
  constructor(rpc: RpcClient) {
    this.rpc = rpc;
  }

  /**
   * Queries free space in a directory **on the server**.
   *
   * @param path absolute directory path
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async freeSpace(path: string): Promise<FreeSpace> {
    const params: JsonObject = {};
    params['path'] = path;
    const res = await this.rpc.call(RpcMethod.FREE_SPACE, params)
    return FreeSpace.fromJson(res);
  }

  /**
   * Tests whether the incoming peer port is reachable from the internet.
   *
   * @param protocol which listener to test. Omit it to reproduce the
   *        pre-4.1.0 behaviour of testing whichever protocol the server's
   *        connection happened to use; pass {@link IpProtocol.IPV4} or
   *        {@link IpProtocol.IPV6} for a deterministic result.
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async portTest(protocol?: IpProtocol): Promise<PortTestResult> {
    const params = new JsonObjectBuilder();
    if (protocol !== undefined) {
      params.setAlways('ip_protocol', protocol);
    }
    return PortTestResult.fromJson(await this.rpc.call(RpcMethod.PORT_TEST, params.build()));
  }

  /**
   * Reloads the IP blocklist from the configured `blocklist_url`.
   *
   * @returns the number of rules in the new blocklist, or `-1` when the server
   *          did not report one
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async updateBlocklist(): Promise<number> {
    const result = await this.rpc.call(RpcMethod.BLOCKLIST_UPDATE);
    return Json.getNumber(result, 'blocklist_size', -1);
  }
}
