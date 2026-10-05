// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for the bandwidth group facade.
 *
 * `group_get` optionally takes a list of names, and `group_set` is a
 * "only send what was set" builder. Both shapes are pinned here.
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { TransmissionClient } from '../../main/ets/client/TransmissionClient';
import { TransmissionClientBuilder } from '../../main/ets/client/TransmissionClientBuilder';
import { ApiStyleMode } from '../../main/ets/compat/ApiStyle';
import { Json, JsonObject } from '../../main/ets/util/Json';
import { BandwidthGroupSetRequest } from '../../main/ets/api/BandwidthGroupApi';
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

export default function bandwidthGroupApiTest(): void {
  describe('BandwidthGroupApi.getAll', () => {
    it('omits the name filter when none was requested', async () => {
      const transport = FakeTransport.create();
      const group: JsonObject = {};
      group['name'] = 'alpha';
      group['speed_limit_down'] = 100;
      group['speed_limit_down_enabled'] = true;
      const result: JsonObject = {};
      result['group'] = [group];
      scriptModern(transport, result);
      const client = clientFor(transport);

      const groups = await client.groups.getAll();

      expect(Json.getString(bodyAt(transport, 0), 'method')).assertEqual('group_get');
      expect(Json.has(paramsAt(transport, 0), 'name')).assertFalse();
      expect(groups.length).assertEqual(1);
      expect(groups[0].name).assertEqual('alpha');
      expect(groups[0].speedLimitDown).assertEqual(100);
      expect(groups[0].speedLimitDownEnabled).assertTrue();
    });

    it('forwards an explicit list of names', async () => {
      const transport = FakeTransport.create();
      const result: JsonObject = {};
      result['group'] = [];
      scriptModern(transport, result);
      const client = clientFor(transport);

      await client.groups.getAll(['alpha', 'beta']);

      expect(Json.getString(bodyAt(transport, 0), 'method')).assertEqual('group_get');
      expect(Json.get(paramsAt(transport, 0), 'name')).assertDeepEquals(['alpha', 'beta']);
    });
  });

  describe('BandwidthGroupApi.get', () => {
    it('returns undefined when the group array is empty', async () => {
      const transport = FakeTransport.create();
      const result: JsonObject = {};
      result['group'] = [];
      scriptModern(transport, result);
      const client = clientFor(transport);

      const group = await client.groups.get('missing');

      expect(group).assertUndefined();
      expect(Json.get(paramsAt(transport, 0), 'name')).assertDeepEquals(['missing']);
    });
  });

  describe('BandwidthGroupApi.set', () => {
    it('forwards every field of the request', async () => {
      const transport = FakeTransport.create();
      scriptModern(transport, emptyResult());
      const client = clientFor(transport);
      const request = new BandwidthGroupSetRequest('media')
        .honorsSessionLimits(true)
        .speedLimitDown(4096)
        .speedLimitDownEnabled(true)
        .speedLimitUp(1024)
        .speedLimitUpEnabled(false);

      await client.groups.set(request);

      const params = paramsAt(transport, 0);
      expect(Json.getString(bodyAt(transport, 0), 'method')).assertEqual('group_set');
      expect(Json.getString(params, 'name')).assertEqual('media');
      expect(Json.getBoolean(params, 'honors_session_limits')).assertTrue();
      expect(Json.getNumber(params, 'speed_limit_down')).assertEqual(4096);
      expect(Json.getBoolean(params, 'speed_limit_down_enabled')).assertTrue();
      expect(Json.getNumber(params, 'speed_limit_up')).assertEqual(1024);
      expect(Json.getBoolean(params, 'speed_limit_up_enabled')).assertFalse();
    });
  });
}
