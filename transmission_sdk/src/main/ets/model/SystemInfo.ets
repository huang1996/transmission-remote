// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Miscellaneous session diagnostics.
 *
 * This file models two independent RPC results:
 *
 * - {@link FreeSpace}, returned by `free_space`, reports the disk capacity of a
 *   directory.
 * - {@link PortTestResult}, returned by `port_test`, reports whether the peer
 *   port is reachable from the internet.
 *
 * @since 1.0.0
 */

import { Json, JsonObject } from '../util/Json';
import { IpProtocol } from './Enums';

/**
 * The result object of `free_space`.
 */
export class FreeSpace {
  /** Directory the free space was measured in. */
  path: string = '';
  /** Free bytes available to the daemon. */
  sizeBytes: number = 0;
  /** Total capacity of the filesystem, in bytes. */
  totalSize: number = 0;

  /** Bytes already in use, floored at `0` when the payload is inconsistent. */
  get usedBytes(): number {
    const used = this.totalSize - this.sizeBytes;
    return used < 0 ? 0 : used;
  }

  /** Fraction of the filesystem that is in use, `0.0` – `1.0`; `0` when unknown. */
  get usedFraction(): number {
    return this.totalSize === 0 ? 0 : this.usedBytes / this.totalSize;
  }

  /**
   * Parses a `free_space` result.
   *
   * @param json wire object with canonical keys
   */
  static fromJson(json: JsonObject | undefined): FreeSpace {
    const space = new FreeSpace();
    space.path = Json.getString(json, 'path');
    space.sizeBytes = Json.getNumber(json, 'size_bytes');
    space.totalSize = Json.getNumber(json, 'total_size');
    return space;
  }
}

/**
 * The result object of `port_test`.
 */
export class PortTestResult {
  /** True when the port accepted a connection from the outside. */
  portIsOpen: boolean = false;
  /** Protocol that was tested, or `undefined` when the server omitted it. */
  ipProtocol: IpProtocol | undefined = undefined;

  /**
   * Parses a `port_test` result.
   *
   * @param json wire object with canonical keys
   */
  static fromJson(json: JsonObject | undefined): PortTestResult {
    const result = new PortTestResult();
    result.portIsOpen = Json.getBoolean(json, 'port_is_open');
    result.ipProtocol = PortTestResult.parseIpProtocol(Json.getString(json, 'ip_protocol'));
    return result;
  }

  /**
   * Maps the wire `ip_protocol` string onto {@link IpProtocol}.
   *
   * @param value raw wire value
   * @returns the matching protocol, or `undefined` when it is absent or unknown
   */
  private static parseIpProtocol(value: string): IpProtocol | undefined {
    if (value === 'ipv4') {
      return IpProtocol.IPV4;
    }
    if (value === 'ipv6') {
      return IpProtocol.IPV6;
    }
    return undefined;
  }
}
