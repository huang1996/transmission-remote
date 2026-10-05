// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * End-to-end tests for the SDK entry point.
 *
 * `TransmissionClient` is what applications actually hold. The key property to
 * prove here is that the two wire dialects are invisible above the RPC engine:
 * a modern and a legacy server must yield the same typed `SessionSettings`.
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { TransmissionClient } from '../../main/ets/client/TransmissionClient';
import { TransmissionClientBuilder } from '../../main/ets/client/TransmissionClientBuilder';
import { ApiStyle, ApiStyleMode } from '../../main/ets/compat/ApiStyle';
import { RpcMethod } from '../../main/ets/constants/RpcMethods';
import { EncryptionMode } from '../../main/ets/model/Enums';
import { RpcErrorCode, TransmissionError, TransmissionErrorKind } from '../../main/ets/error/TransmissionError';
import { Json, JsonObject } from '../../main/ets/util/Json';
import { FakeTransport } from '../helpers/FakeTransport';
import { RpcFakes } from '../helpers/RpcFakes';

/** Endpoint used by every client in this suite. */
const TEST_URL: string = 'http://127.0.0.1:9091/transmission/rpc';

/** Builds an AUTO-mode client over an injected transport. */
function buildClient(transport: FakeTransport): TransmissionClient {
  return new TransmissionClientBuilder().url(TEST_URL).transport(transport).build();
}

/** A `session_get` payload as a JSON-RPC 2.0 server sends it. */
function modernSessionResult(): JsonObject {
  const result: JsonObject = {};
  result['version'] = '4.1.0';
  result['rpc_version_semver'] = '6.0.0';
  result['download_dir'] = '/downloads';
  result['peer_port'] = 51413;
  result['encryption'] = 'allowed';
  return result;
}

/** The same payload as a pre-4.1.0 server sends it, with legacy key spellings. */
function legacySessionResult(): JsonObject {
  const result: JsonObject = {};
  result['version'] = '4.1.0';
  result['rpc-version-semver'] = '5.3.0';
  result['download-dir'] = '/downloads';
  result['peer-port'] = 51413;
  result['encryption'] = 'tolerated';
  return result;
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

export default function transmissionClientTest(): void {
  describe('TransmissionClient dialect equivalence', () => {
    it('connect() returns identical typed settings from a modern and a legacy server', async () => {
      const modernTransport = FakeTransport.create();
      modernTransport.enqueueCsrf('modern-session', '6.0.0');
      modernTransport.enqueueJson(RpcFakes.modernSuccess(modernSessionResult(), 1));
      const modernClient = buildClient(modernTransport);

      const modern = await modernClient.connect();

      const legacyTransport = FakeTransport.create();
      legacyTransport.enqueueCsrf('legacy-session');
      legacyTransport.enqueueJson(RpcFakes.legacySuccess(legacySessionResult(), 1));
      const legacyClient = buildClient(legacyTransport);

      const legacy = await legacyClient.connect();

      expect(modern.version).assertEqual(legacy.version);
      expect(modern.downloadDir).assertEqual(legacy.downloadDir);
      expect(modern.peerPort).assertEqual(legacy.peerPort);
      expect(modern.encryption).assertEqual(legacy.encryption);

      expect(modern.version).assertEqual('4.1.0');
      expect(modern.downloadDir).assertEqual('/downloads');
      expect(modern.peerPort).assertEqual(51413);
      expect(modern.encryption).assertEqual(EncryptionMode.ALLOWED);

      expect(modernClient.apiStyle).assertEqual(ApiStyle.MODERN);
      expect(legacyClient.apiStyle).assertEqual(ApiStyle.LEGACY);
      expect(modernClient.isConnected).assertTrue();
      expect(legacyClient.isConnected).assertTrue();
    });
  });

  describe('TransmissionClient.ping', () => {
    it('returns true when the server answers', async () => {
      const transport = FakeTransport.create();
      transport.enqueueCsrf('ping-session', '6.0.0');
      transport.enqueueJson(RpcFakes.modernSuccess(modernSessionResult(), 1));
      const client = buildClient(transport);

      expect(await client.ping()).assertTrue();
    });

    it('returns false without throwing when the transport rejects', async () => {
      const transport = FakeTransport.create();
      transport.failWith(new Error('socket closed'));
      const client = buildClient(transport);

      expect(await client.ping()).assertFalse();
    });
  });

  describe('TransmissionClient badge facts', () => {
    it('reports the dialect label, server version, session id and lifecycle flags', async () => {
      const transport = FakeTransport.create();
      transport.enqueueCsrf('badge-session', '6.0.0');
      transport.enqueueJson(RpcFakes.modernSuccess(modernSessionResult(), 1));
      const client = buildClient(transport);

      await client.connect();

      expect(client.apiStyleLabel).assertEqual('JSON-RPC 2.0 (Transmission >= 4.1.0)');
      expect(client.serverVersion === undefined ? 'unknown' : client.serverVersion.toString()).assertEqual('6.0.0');
      expect(client.sessionId).assertEqual('badge-session');
      expect(client.isClosed).assertFalse();

      client.close();

      expect(client.isClosed).assertTrue();
      expect(transport.isDestroyed).assertTrue();
    });
  });

  describe('TransmissionClientBuilder', () => {
    it('host() builds the conventional endpoint url', () => {
      const client = new TransmissionClientBuilder()
        .host('h', 1234, 'rpc')
        .transport(FakeTransport.create())
        .build();

      expect(client.url).assertEqual('http://h:1234/rpc');
    });

    it('build() rejects an invalid url with a configuration error', () => {
      const builder = new TransmissionClientBuilder()
        .url('ftp://host/rpc')
        .transport(FakeTransport.create());

      try {
        builder.build();
        expect(true).assertFalse();
      } catch (error) {
        expect((error as TransmissionError).kind).assertEqual(TransmissionErrorKind.CONFIGURATION);
      }
    });
  });

  describe('TransmissionClient escape hatches', () => {
    it('raw() passes params through and returns the server result', async () => {
      const transport = FakeTransport.create();
      const result: JsonObject = {};
      result['marker'] = 42;
      transport.enqueueJson(RpcFakes.modernSuccess(result, 1));
      const client = new TransmissionClientBuilder()
        .url(TEST_URL)
        .apiStyleMode(ApiStyleMode.MODERN)
        .sessionId('raw-session')
        .transport(transport)
        .build();
      const params: JsonObject = {};
      params['ids'] = 'recently_active';

      const returned = await client.raw(RpcMethod.TORRENT_GET, params);

      expect(Json.getString(bodyAt(transport, 0), 'method')).assertEqual('torrent_get');
      expect(Json.getString(paramsAt(transport, 0), 'ids')).assertEqual('recently_active');
      expect(Json.getNumber(returned, 'marker')).assertEqual(42);
    });

    it('surfaces a failing torrent_get as a TransmissionError', async () => {
      const transport = FakeTransport.create();
      transport.enqueueJson(RpcFakes.modernError(RpcErrorCode.SYSTEM_ERROR, 'system error', 1));
      const client = new TransmissionClientBuilder()
        .url(TEST_URL)
        .apiStyleMode(ApiStyleMode.MODERN)
        .sessionId('fail-session')
        .transport(transport)
        .build();

      try {
        await client.torrents.get();
        expect(true).assertFalse();
      } catch (error) {
        expect(error instanceof TransmissionError).assertTrue();
        expect((error as TransmissionError).kind).assertEqual(TransmissionErrorKind.RPC);
        expect((error as TransmissionError).rpcCode).assertEqual(RpcErrorCode.SYSTEM_ERROR);
      }
    });
  });
}
