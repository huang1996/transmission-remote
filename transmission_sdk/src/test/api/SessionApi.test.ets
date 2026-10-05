// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for the session service facade.
 *
 * `SessionApi` covers `session_get`, `session_set`, `session_stats` and
 * `session_close`. The two `session_set` paths (a typed request and a single
 * value) are the ones most likely to drift, so both are pinned exactly.
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { TransmissionClient } from '../../main/ets/client/TransmissionClient';
import { TransmissionClientBuilder } from '../../main/ets/client/TransmissionClientBuilder';
import { ApiStyleMode } from '../../main/ets/compat/ApiStyle';
import { Json, JsonObject } from '../../main/ets/util/Json';
import { EncryptionMode } from '../../main/ets/model/Enums';
import { SessionSetRequest } from '../../main/ets/model/SessionSetRequest';
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

/** A `session_get` payload with a few representative fields. */
function settingsResult(): JsonObject {
  const result: JsonObject = {};
  result['version'] = '4.1.0';
  result['rpc_version_semver'] = '6.0.0';
  result['download_dir'] = '/downloads';
  result['peer_port'] = 51413;
  result['encryption'] = 'allowed';
  return result;
}

/** An empty result object. */
function emptyResult(): JsonObject {
  return Json.emptyObject();
}

export default function sessionApiTest(): void {
  describe('SessionApi reads', () => {
    it('getRaw() without fields sends session_get without a fields argument', async () => {
      const transport = FakeTransport.create();
      scriptModern(transport, settingsResult());
      const client = clientFor(transport);

      const raw = await client.session.getRaw();

      expect(Json.getString(bodyAt(transport, 0), 'method')).assertEqual('session_get');
      expect(Json.has(paramsAt(transport, 0), 'fields')).assertFalse();
      expect(Json.getString(raw, 'version')).assertEqual('4.1.0');
    });

    it('getRaw() with fields forwards the selection', async () => {
      const transport = FakeTransport.create();
      scriptModern(transport, settingsResult());
      const client = clientFor(transport);

      await client.session.getRaw(['version', 'peer_port']);

      expect(Json.getStringArray(paramsAt(transport, 0), 'fields')).assertDeepEquals(['version', 'peer_port']);
    });

    it('get() maps the payload onto SessionSettings', async () => {
      const transport = FakeTransport.create();
      scriptModern(transport, settingsResult());
      const client = clientFor(transport);

      const settings = await client.session.get();

      expect(Json.getString(bodyAt(transport, 0), 'method')).assertEqual('session_get');
      expect(settings.version).assertEqual('4.1.0');
      expect(settings.downloadDir).assertEqual('/downloads');
      expect(settings.peerPort).assertEqual(51413);
      expect(settings.encryption).assertEqual(EncryptionMode.ALLOWED);
    });

    it('stats() maps the counters of both reporting windows', async () => {
      const transport = FakeTransport.create();
      const current: JsonObject = {};
      current['downloaded_bytes'] = 1000;
      current['uploaded_bytes'] = 250;
      const result: JsonObject = {};
      result['torrent_count'] = 4;
      result['download_speed'] = 100;
      result['upload_speed'] = 50;
      result['current_stats'] = current;
      scriptModern(transport, result);
      const client = clientFor(transport);

      const stats = await client.session.stats();

      expect(Json.getString(bodyAt(transport, 0), 'method')).assertEqual('session_stats');
      expect(stats.torrentCount).assertEqual(4);
      expect(stats.downloadSpeed).assertEqual(100);
      expect(stats.uploadSpeed).assertEqual(50);
      expect(stats.currentStats.downloadedBytes).assertEqual(1000);
      expect(stats.currentStats.ratio).assertEqual(0.25);
    });
  });

  describe('SessionApi writes', () => {
    it('set() forwards the SessionSetRequest output', async () => {
      const transport = FakeTransport.create();
      scriptModern(transport, emptyResult());
      const client = clientFor(transport);

      await client.session.set(new SessionSetRequest().peerPort(51413).speedLimitDown(2048).speedLimitDownEnabled(true));

      const params = paramsAt(transport, 0);
      expect(Json.getString(bodyAt(transport, 0), 'method')).assertEqual('session_set');
      expect(Json.getNumber(params, 'peer_port')).assertEqual(51413);
      expect(Json.getNumber(params, 'speed_limit_down')).assertEqual(2048);
      expect(Json.getBoolean(params, 'speed_limit_down_enabled')).assertTrue();
    });

    it('setValue() sends a single canonical setting', async () => {
      const transport = FakeTransport.create();
      transport.enqueueJson(RpcFakes.modernSuccess(emptyResult(), 1));
      const client = clientFor(transport);

      await client.session.setValue('download_dir', '/media');

      expect(Json.getString(bodyAt(transport, 0), 'method')).assertEqual('session_set');
      expect(Json.getString(paramsAt(transport, 0), 'download_dir')).assertEqual('/media');
    });

    it('close() sends session_close', async () => {
      const transport = FakeTransport.create();
      scriptModern(transport, emptyResult());
      const client = clientFor(transport);

      await client.session.close();

      expect(Json.getString(bodyAt(transport, 0), 'method')).assertEqual('session_close');
    });
  });
}
