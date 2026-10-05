// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for the torrent service facade.
 *
 * `TorrentApi` is a thin wrapper: every method maps onto exactly one RPC method
 * with a well-defined parameter object, and every response is mapped onto the
 * `model/` classes. These tests pin both halves of that contract.
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { TransmissionClient } from '../../main/ets/client/TransmissionClient';
import { TransmissionClientBuilder } from '../../main/ets/client/TransmissionClientBuilder';
import { ApiStyleMode } from '../../main/ets/compat/ApiStyle';
import { TransmissionError, TransmissionErrorKind } from '../../main/ets/error/TransmissionError';
import { Json, JsonArray, JsonObject, JsonValue } from '../../main/ets/util/Json';
import { Base64 } from '../../main/ets/util/Base64';
import {
  TorrentAddRequest,
  TorrentGetRequest,
  TorrentIds,
  TorrentSetRequest,
} from '../../main/ets/model/TorrentRequests';
import { FakeTransport, ScriptedResponse } from '../helpers/FakeTransport';
import { RpcFakes } from '../helpers/RpcFakes';

/** Endpoint used by every client in this suite. */
const TEST_URL: string = 'http://127.0.0.1:9091/transmission/rpc';

/** Builds an already-handshaken client in the requested dialect. */
function clientFor(transport: FakeTransport, mode: ApiStyleMode): TransmissionClient {
  return new TransmissionClientBuilder()
    .url(TEST_URL)
    .apiStyleMode(mode)
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

/** Legacy `arguments` object of the `index`-th request. */
function argumentsAt(transport: FakeTransport, index: number): JsonObject {
  const args = Json.getObject(bodyAt(transport, index), 'arguments');
  return args === undefined ? Json.emptyObject() : args;
}

/** Queues one successful modern response. */
function scriptModern(transport: FakeTransport, result: JsonValue): void {
  transport.enqueueJson(RpcFakes.modernSuccess(result, 1));
}

/** A `torrent_add` result containing a newly added torrent. */
function addResult(id: number, name: string): JsonObject {
  const result: JsonObject = {};
  result['torrent_added'] = RpcFakes.torrent(id, name);
  return result;
}

/** An empty `torrent_add` result. */
function emptyResult(): JsonObject {
  return Json.emptyObject();
}

export default function torrentApiTest(): void {
  describe('TorrentApi reads', () => {
    it('get() requests objects format with the chosen fields and maps torrents', async () => {
      const transport = FakeTransport.create();
      scriptModern(transport, RpcFakes.torrentGetResult([RpcFakes.torrent(1, 'one'), RpcFakes.torrent(2, 'two')]));
      const client = clientFor(transport, ApiStyleMode.MODERN);

      const torrents = await client.torrents.get(new TorrentGetRequest(['id', 'name']));

      expect(transport.callCount).assertEqual(1);
      expect(Json.getString(bodyAt(transport, 0), 'method')).assertEqual('torrent_get');
      const params = paramsAt(transport, 0);
      expect(Json.getString(params, 'format')).assertEqual('objects');
      expect(Json.getStringArray(params, 'fields')).assertDeepEquals(['id', 'name']);
      expect(torrents.length).assertEqual(2);
      expect(torrents[0].id).assertEqual(1);
      expect(torrents[1].name).assertEqual('two');
    });

    it('get() without a request uses the default field selection', async () => {
      const transport = FakeTransport.create();
      scriptModern(transport, RpcFakes.torrentGetResult([]));
      const client = clientFor(transport, ApiStyleMode.MODERN);

      await client.torrents.get();

      expect(Json.getStringArray(paramsAt(transport, 0), 'fields')).assertDeepEquals([
        'id',
        'name',
        'status',
        'percent_done',
      ]);
    });

    it('getTable() requests table format and returns a TorrentTable', async () => {
      const transport = FakeTransport.create();
      const rows: JsonArray = [];
      const header: JsonArray = ['id', 'name'];
      const firstRow: JsonArray = [1, 'one'];
      const secondRow: JsonArray = [2, 'two'];
      rows.push(header);
      rows.push(firstRow);
      rows.push(secondRow);
      const result: JsonObject = {};
      result['torrents'] = rows;
      scriptModern(transport, result);
      const client = clientFor(transport, ApiStyleMode.MODERN);

      const table = await client.torrents.getTable(new TorrentGetRequest(['id', 'name']));

      expect(Json.getString(bodyAt(transport, 0), 'method')).assertEqual('torrent_get');
      expect(Json.getString(paramsAt(transport, 0), 'format')).assertEqual('table');
      expect(table.columns).assertDeepEquals(['id', 'name']);
      expect(table.rows.length).assertEqual(2);
      expect(Json.getString(table.rows[0], 'name')).assertEqual('one');
      expect(Json.getString(table.rows[1], 'name')).assertEqual('two');
    });

    it('getOne() returns undefined when the server reports no torrents', async () => {
      const transport = FakeTransport.create();
      scriptModern(transport, RpcFakes.torrentGetResult([]));
      const client = clientFor(transport, ApiStyleMode.MODERN);

      const torrent = await client.torrents.getOne(7);

      expect(torrent).assertUndefined();
      expect(Json.get(paramsAt(transport, 0), 'ids')).assertDeepEquals([7]);
    });

    it('getRecentlyActive() asks for recently_active and parses removed ids', async () => {
      const transport = FakeTransport.create();
      const result: JsonObject = {};
      result['torrents'] = [RpcFakes.torrent(3, 'three')];
      result['removed'] = [9, 10];
      scriptModern(transport, result);
      const client = clientFor(transport, ApiStyleMode.MODERN);

      const recent = await client.torrents.getRecentlyActive(new TorrentGetRequest(['id', 'name']));

      expect(Json.getString(paramsAt(transport, 0), 'ids')).assertEqual('recently_active');
      expect(recent.torrents.length).assertEqual(1);
      expect(recent.removed).assertDeepEquals([9, 10]);
    });

    it('getFiles() requests the files field of one torrent', async () => {
      const transport = FakeTransport.create();
      const file: JsonObject = {};
      file['name'] = 'a.txt';
      file['length'] = 100;
      file['bytes_completed'] = 50;
      const torrent: JsonObject = {};
      torrent['id'] = 5;
      torrent['files'] = [file];
      scriptModern(transport, RpcFakes.torrentGetResult([torrent]));
      const client = clientFor(transport, ApiStyleMode.MODERN);

      const files = await client.torrents.getFiles(5);

      const params = paramsAt(transport, 0);
      expect(Json.get(params, 'ids')).assertDeepEquals([5]);
      expect(Json.getStringArray(params, 'fields')).assertDeepEquals(['id', 'files']);
      expect(files.length).assertEqual(1);
      expect(files[0].name).assertEqual('a.txt');
      expect(files[0].bytesCompleted).assertEqual(50);
    });

    it('count() asks for ids only and returns how many arrived', async () => {
      const transport = FakeTransport.create();
      scriptModern(
        transport,
        RpcFakes.torrentGetResult([RpcFakes.torrent(1, 'a'), RpcFakes.torrent(2, 'b'), RpcFakes.torrent(3, 'c')]),
      );
      const client = clientFor(transport, ApiStyleMode.MODERN);

      const count = await client.torrents.count();

      expect(Json.getStringArray(paramsAt(transport, 0), 'fields')).assertDeepEquals(['id']);
      expect(count).assertEqual(3);
    });
  });

  describe('TorrentApi actions', () => {
    it('action methods send the documented RPC method name and omit ids for ALL', async () => {
      const transport = FakeTransport.create();
      transport.always(ScriptedResponse.json(RpcFakes.modernSuccess(emptyResult(), 1)));
      const client = clientFor(transport, ApiStyleMode.MODERN);

      await client.torrents.start();
      await client.torrents.startNow();
      await client.torrents.stop();
      await client.torrents.verify();
      await client.torrents.reannounce();
      await client.torrents.moveToTop();
      await client.torrents.moveUp();
      await client.torrents.moveDown();
      await client.torrents.moveToBottom();

      expect(transport.methods).assertDeepEquals([
        'torrent_start',
        'torrent_start_now',
        'torrent_stop',
        'torrent_verify',
        'torrent_reannounce',
        'queue_move_top',
        'queue_move_up',
        'queue_move_down',
        'queue_move_bottom',
      ]);
      for (let index = 0; index < transport.callCount; index++) {
        expect(Json.has(paramsAt(transport, index), 'ids')).assertFalse();
      }
    });

    it('action methods address explicit ids when given', async () => {
      const transport = FakeTransport.create();
      transport.always(ScriptedResponse.json(RpcFakes.modernSuccess(emptyResult(), 1)));
      const client = clientFor(transport, ApiStyleMode.MODERN);

      const ids = TorrentIds.ofNumbers([9]);
      await client.torrents.start(ids);
      await client.torrents.startNow(ids);
      await client.torrents.stop(ids);
      await client.torrents.verify(ids);
      await client.torrents.reannounce(ids);
      await client.torrents.moveToTop(ids);
      await client.torrents.moveUp(ids);
      await client.torrents.moveDown(ids);
      await client.torrents.moveToBottom(ids);

      for (let index = 0; index < transport.callCount; index++) {
        expect(Json.get(paramsAt(transport, index), 'ids')).assertDeepEquals([9]);
      }
    });
  });

  describe('TorrentApi mutators', () => {
    it('add() sends the filename and maps the added torrent', async () => {
      const transport = FakeTransport.create();
      scriptModern(transport, addResult(11, 'added'));
      const client = clientFor(transport, ApiStyleMode.MODERN);

      const result = await client.torrents.add(TorrentAddRequest.fromFilename('http://host/a.torrent'));

      expect(Json.getString(bodyAt(transport, 0), 'method')).assertEqual('torrent_add');
      expect(Json.getString(paramsAt(transport, 0), 'filename')).assertEqual('http://host/a.torrent');
      expect(result.wasAdded).assertTrue();
      expect(result.torrent === undefined ? 0 : result.torrent.id).assertEqual(11);
    });

    it('add() rejects a request without filename or metainfo without calling the server', async () => {
      const transport = FakeTransport.create();
      const client = clientFor(transport, ApiStyleMode.MODERN);

      try {
        await client.torrents.add(TorrentAddRequest.create());
        expect(true).assertFalse();
      } catch (error) {
        expect((error as TransmissionError).kind).assertEqual(TransmissionErrorKind.CONFIGURATION);
      }
      expect(transport.callCount).assertEqual(0);
    });

    it('addMagnet() sends the magnet link as the filename', async () => {
      const transport = FakeTransport.create();
      scriptModern(transport, addResult(1, 'magnet'));
      const client = clientFor(transport, ApiStyleMode.MODERN);

      await client.torrents.addMagnet('magnet:?xt=urn:btih:abc');

      expect(Json.getString(bodyAt(transport, 0), 'method')).assertEqual('torrent_add');
      expect(Json.getString(paramsAt(transport, 0), 'filename')).assertEqual('magnet:?xt=urn:btih:abc');
    });

    it('addFromBytes() base64-encodes the metainfo', async () => {
      const transport = FakeTransport.create();
      scriptModern(transport, addResult(1, 'bytes'));
      const client = clientFor(transport, ApiStyleMode.MODERN);
      const bytes = new Uint8Array([1, 2, 3, 4]);

      await client.torrents.addFromBytes(bytes);

      const params = paramsAt(transport, 0);
      expect(Json.getString(params, 'metainfo')).assertEqual(Base64.encodeBytes(bytes));
      expect(Json.has(params, 'filename')).assertFalse();
    });

    it('remove() sends delete_local_data and the addressed ids', async () => {
      const transport = FakeTransport.create();
      transport.always(ScriptedResponse.json(RpcFakes.modernSuccess(emptyResult(), 1)));
      const client = clientFor(transport, ApiStyleMode.MODERN);

      await client.torrents.remove(TorrentIds.ofNumbers([1, 2]), true);

      const params = paramsAt(transport, 0);
      expect(Json.getString(bodyAt(transport, 0), 'method')).assertEqual('torrent_remove');
      expect(Json.get(params, 'ids')).assertDeepEquals([1, 2]);
      expect(Json.getBoolean(params, 'delete_local_data')).assertTrue();

      await client.torrents.remove(TorrentIds.ALL);

      const second = paramsAt(transport, 1);
      expect(Json.has(second, 'ids')).assertFalse();
      expect(Json.getBoolean(second, 'delete_local_data')).assertFalse();
    });

    it('set() forwards the builder output', async () => {
      const transport = FakeTransport.create();
      scriptModern(transport, emptyResult());
      const client = clientFor(transport, ApiStyleMode.MODERN);
      const request = new TorrentSetRequest(TorrentIds.ofNumbers([4]))
        .downloadLimit(100)
        .downloadLimited(true)
        .sequentialDownload(true);

      await client.torrents.set(request);

      const params = paramsAt(transport, 0);
      expect(Json.getString(bodyAt(transport, 0), 'method')).assertEqual('torrent_set');
      expect(Json.get(params, 'ids')).assertDeepEquals([4]);
      expect(Json.getNumber(params, 'download_limit')).assertEqual(100);
      expect(Json.getBoolean(params, 'download_limited')).assertTrue();
      expect(Json.getBoolean(params, 'sequential_download')).assertTrue();
    });

    it('setLocation() sends the location and move flag', async () => {
      const transport = FakeTransport.create();
      scriptModern(transport, emptyResult());
      const client = clientFor(transport, ApiStyleMode.MODERN);

      await client.torrents.setLocation(TorrentIds.ofNumbers([3]), '/data/media', true);

      const params = paramsAt(transport, 0);
      expect(Json.getString(bodyAt(transport, 0), 'method')).assertEqual('torrent_set_location');
      expect(Json.get(params, 'ids')).assertDeepEquals([3]);
      expect(Json.getString(params, 'location')).assertEqual('/data/media');
      expect(Json.getBoolean(params, 'move')).assertTrue();
    });

    it('renamePath() sends path and name and maps the rename result', async () => {
      const transport = FakeTransport.create();
      const renameResult: JsonObject = {};
      renameResult['id'] = 3;
      renameResult['path'] = 'old/name';
      renameResult['name'] = 'new/name';
      scriptModern(transport, renameResult);
      const client = clientFor(transport, ApiStyleMode.MODERN);

      const result = await client.torrents.renamePath(3, 'old/name', 'new/name');

      const params = paramsAt(transport, 0);
      expect(Json.getString(bodyAt(transport, 0), 'method')).assertEqual('torrent_rename_path');
      expect(Json.get(params, 'ids')).assertDeepEquals([3]);
      expect(Json.getString(params, 'path')).assertEqual('old/name');
      expect(Json.getString(params, 'name')).assertEqual('new/name');
      expect(result.id).assertEqual(3);
      expect(result.path).assertEqual('old/name');
      expect(result.name).assertEqual('new/name');
    });
  });

  describe('TorrentApi legacy dialect', () => {
    it('get() uses the legacy envelope and legacy field spellings', async () => {
      const transport = FakeTransport.create();
      const torrent: JsonObject = {};
      torrent['id'] = 1;
      torrent['name'] = 'one';
      torrent['percentDone'] = 0.5;
      torrent['downloadDir'] = '/downloads';
      const args: JsonObject = {};
      args['torrents'] = [torrent];
      transport.enqueueJson(RpcFakes.legacySuccess(args, 1));
      const client = clientFor(transport, ApiStyleMode.LEGACY);

      const torrents = await client.torrents.get(new TorrentGetRequest(['id', 'percent_done', 'download_dir']));

      const body = bodyAt(transport, 0);
      expect(Json.getString(body, 'method')).assertEqual('torrent-get');
      expect(Json.has(body, 'jsonrpc')).assertFalse();
      expect(Json.has(body, 'arguments')).assertTrue();
      expect(Json.getNumber(body, 'tag') > 0).assertTrue();
      expect(Json.getStringArray(argumentsAt(transport, 0), 'fields')).assertDeepEquals([
        'id',
        'percentDone',
        'downloadDir',
      ]);
      expect(torrents.length).assertEqual(1);
      expect(torrents[0].id).assertEqual(1);
      expect(torrents[0].percentDone).assertEqual(0.5);
      expect(torrents[0].downloadDir).assertEqual('/downloads');
    });
  });
}
