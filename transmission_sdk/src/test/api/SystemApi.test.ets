// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for the server utility facade.
 *
 * `free_space`, `port_test` and `blocklist_update` are small but each has a
 * parameter or default worth pinning: the path, the optional IP protocol and
 * the `-1` fallback for a blocklist size the server did not report.
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { TransmissionClient } from '../../main/ets/client/TransmissionClient';
import { TransmissionClientBuilder } from '../../main/ets/client/TransmissionClientBuilder';
import { ApiStyleMode } from '../../main/ets/compat/ApiStyle';
import { Json, JsonObject } from '../../main/ets/util/Json';
import { IpProtocol } from '../../main/ets/model/Enums';
import { FakeTransport } from '../helpers/FakeTransport';
import { RpcFakes } from '../helpers/RpcFakes';

/** Endpoint used by every client in this suite. */
const TEST_URL: string = 'http://127.0.0.1:9091/transmission/rpc';

/** Builds an already-handshaken client in the modern dialect. */
function clientFor(transport: FakeTransport): TransmissionClient {
  return new TransmissionClientBuilder()
    .url(TEST_URL)
    .apiStyleMode(ApiStyleMode.MODERN)
    .sessionId('test-session')
    .transport(transport)
    .build();
}

/** Parsed body of the `index`-th request. */
function bodyAt(transport: FakeTransport, index: number): JsonObject {
  return transport.requests[index].json;
}

/** Modern `params` object of the `index`-th request. */
function paramsAt(transport: FakeTransport, index: number): JsonObject {
  const params = Json.getObject(bodyAt(transport, index), 'params');
  return params === undefined ? Json.emptyObject() : params;
}

/** Queues one successful modern response. */
function scriptModern(transport: FakeTransport, result: JsonObject): void {
  transport.enqueueJson(RpcFakes.modernSuccess(result, 1));
}

/** An empty result object. */
function emptyResult(): JsonObject {
  return Json.emptyObject();
}

export default function systemApiTest(): void {
  describe('SystemApi.freeSpace', () => {
    it('sends the directory path and maps the capacity report', async () => {
      const transport = FakeTransport.create();
      const result: JsonObject = {};
      result['path'] = '/data';
      result['size_bytes'] = 1000;
      result['total_size'] = 4000;
      scriptModern(transport, result);
      const client = clientFor(transport);

      const space = await client.system.freeSpace('/data');

      expect(Json.getString(bodyAt(transport, 0), 'method')).assertEqual('free_space');
      expect(Json.getString(paramsAt(transport, 0), 'path')).assertEqual('/data');
      expect(space.path).assertEqual('/data');
      expect(space.sizeBytes).assertEqual(1000);
      expect(space.totalSize).assertEqual(4000);
      expect(space.usedBytes).assertEqual(3000);
    });
  });

  describe('SystemApi.portTest', () => {
    it('omits the protocol when none was requested', async () => {
      const transport = FakeTransport.create();
      const result: JsonObject = {};
      result['port_is_open'] = true;
      result['ip_protocol'] = 'ipv4';
      scriptModern(transport, result);
      const client = clientFor(transport);

      const test = await client.system.portTest();

      expect(Json.getString(bodyAt(transport, 0), 'method')).assertEqual('port_test');
      expect(Json.has(paramsAt(transport, 0), 'ip_protocol')).assertFalse();
      expect(test.portIsOpen).assertTrue();
      expect(test.ipProtocol).assertEqual(IpProtocol.IPV4);
    });

    it('sends the requested protocol', async () => {
      const transport = FakeTransport.create();
      scriptModern(transport, emptyResult());
      const client = clientFor(transport);

      await client.system.portTest(IpProtocol.IPV6);

      expect(Json.getString(bodyAt(transport, 0), 'method')).assertEqual('port_test');
      expect(Json.getString(paramsAt(transport, 0), 'ip_protocol')).assertEqual('ipv6');
    });
  });

  describe('SystemApi.updateBlocklist', () => {
    it('returns the reported blocklist size', async () => {
      const transport = FakeTransport.create();
      const result: JsonObject = {};
      result['blocklist_size'] = 1234;
      scriptModern(transport, result);
      const client = clientFor(transport);

      const size = await client.system.updateBlocklist();

      expect(Json.getString(bodyAt(transport, 0), 'method')).assertEqual('blocklist_update');
      expect(size).assertEqual(1234);
    });

    it('returns -1 when the server did not report a size', async () => {
      const transport = FakeTransport.create();
      scriptModern(transport, emptyResult());
      const client = clientFor(transport);

      const size = await client.system.updateBlocklist();

      expect(size).assertEqual(-1);
    });
  });
}
