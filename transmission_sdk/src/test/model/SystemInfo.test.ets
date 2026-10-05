// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for the `free_space` and `port_test` diagnostics.
 *
 * `free_space` can report `size_bytes` larger than `total_size` on a network
 * share whose quota shrank, so `usedBytes` is floored at zero rather than
 * producing a negative number (and a negative fraction).
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { JsonObject } from '../../main/ets/util/Json';
import { FreeSpace, PortTestResult } from '../../main/ets/model/SystemInfo';
import { IpProtocol } from '../../main/ets/model/Enums';

export default function systemInfoTest(): void {
  describe('FreeSpace.fromJson', () => {
    it('reads the canonical path, size and total keys', () => {
      const json: JsonObject = {};
      json['path'] = '/srv/media';
      json['size_bytes'] = 250;
      json['total_size'] = 1000;
      const space = FreeSpace.fromJson(json);
      expect(space.path).assertEqual('/srv/media');
      expect(space.sizeBytes).assertEqual(250);
      expect(space.totalSize).assertEqual(1000);
    });

    it('computes used bytes and the used fraction', () => {
      const json: JsonObject = {};
      json['size_bytes'] = 250;
      json['total_size'] = 1000;
      const space = FreeSpace.fromJson(json);
      expect(space.usedBytes).assertEqual(750);
      expect(space.usedFraction).assertEqual(0.75);
    });

    it('never reports negative used bytes when free space exceeds the total', () => {
      const json: JsonObject = {};
      json['size_bytes'] = 2000;
      json['total_size'] = 1000;
      const space = FreeSpace.fromJson(json);
      expect(space.usedBytes).assertEqual(0);
      expect(space.usedFraction).assertEqual(0);
    });

    it('reports a zero fraction when the total size is unknown', () => {
      const json: JsonObject = {};
      json['size_bytes'] = 500;
      json['total_size'] = 0;
      const space = FreeSpace.fromJson(json);
      expect(space.usedBytes).assertEqual(0);
      expect(space.usedFraction).assertEqual(0);
    });

    it('returns zeroed defaults for an undefined payload', () => {
      const space = FreeSpace.fromJson(undefined);
      expect(space.path).assertEqual('');
      expect(space.sizeBytes).assertEqual(0);
      expect(space.totalSize).assertEqual(0);
      expect(space.usedFraction).assertEqual(0);
    });
  });

  describe('PortTestResult.fromJson', () => {
    it('reads port_is_open and an ipv4 protocol', () => {
      const json: JsonObject = {};
      json['port_is_open'] = true;
      json['ip_protocol'] = 'ipv4';
      const result = PortTestResult.fromJson(json);
      expect(result.portIsOpen).assertTrue();
      expect(result.ipProtocol).assertEqual(IpProtocol.IPV4);
    });

    it('maps ipv6 onto IPV6', () => {
      const json: JsonObject = {};
      json['port_is_open'] = false;
      json['ip_protocol'] = 'ipv6';
      const result = PortTestResult.fromJson(json);
      expect(result.portIsOpen).assertFalse();
      expect(result.ipProtocol).assertEqual(IpProtocol.IPV6);
    });

    it('leaves ipProtocol undefined when the server omits it', () => {
      const json: JsonObject = {};
      json['port_is_open'] = true;
      expect(PortTestResult.fromJson(json).ipProtocol).assertUndefined();
    });

    it('leaves ipProtocol undefined for an unknown protocol string', () => {
      const json: JsonObject = {};
      json['ip_protocol'] = 'ipv9';
      expect(PortTestResult.fromJson(json).ipProtocol).assertUndefined();
    });

    it('returns safe defaults for an undefined payload', () => {
      const result = PortTestResult.fromJson(undefined);
      expect(result.portIsOpen).assertFalse();
      expect(result.ipProtocol).assertUndefined();
    });
  });
}
