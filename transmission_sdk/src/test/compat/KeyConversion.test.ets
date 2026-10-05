// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for the recursive key/value translator.
 *
 * This is a port of `convert_key()` / `convert_string()` / `convert_keys()`
 * from `libtransmission/api-compat.cc`. The "crazy cases" below are the exact
 * places where a naive snake_case-to-camelCase conversion produces requests an
 * older Transmission rejects, so each one gets an explicit test.
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { ConversionContext, KeyConverter, KeyDirection } from '../../main/ets/compat/KeyConversion';
import { Json, JsonArray, JsonObject } from '../../main/ets/util/Json';
import { RpcMethod } from '../../main/ets/constants/RpcMethods';

export default function keyConversionTest(): void {
  describe('KeyConverter single keys', () => {
    it('translates canonical keys to their legacy spelling', () => {
      const context = ConversionContext.neutral();
      expect(KeyConverter.convertKey(context, 'percent_done', KeyDirection.TO_LEGACY)).assertEqual('percentDone');
      expect(KeyConverter.convertKey(context, 'alt_speed_down', KeyDirection.TO_LEGACY)).assertEqual('alt-speed-down');
    });

    it('translates legacy keys back to canonical', () => {
      const context = ConversionContext.neutral();
      expect(KeyConverter.convertKey(context, 'percentDone', KeyDirection.TO_CANONICAL)).assertEqual('percent_done');
      expect(KeyConverter.convertKey(context, 'alt-speed-down', KeyDirection.TO_CANONICAL)).assertEqual('alt_speed_down');
    });

    it('passes unknown keys through unchanged', () => {
      const context = ConversionContext.neutral();
      expect(KeyConverter.convertKey(context, 'future_field', KeyDirection.TO_LEGACY)).assertEqual('future_field');
      expect(KeyConverter.convertKey(context, 'futureField', KeyDirection.TO_CANONICAL)).assertEqual('futureField');
    });
  });

  describe('KeyConverter crazy case: download_dir', () => {
    it('uses camelCase inside torrent_get and torrent_set', () => {
      const torrentContext = ConversionContext.forRequest(RpcMethod.TORRENT_GET);
      expect(KeyConverter.convertKey(torrentContext, 'download_dir', KeyDirection.TO_LEGACY)).assertEqual('downloadDir');
      const setContext = ConversionContext.forRequest(RpcMethod.TORRENT_SET);
      expect(KeyConverter.convertKey(setContext, 'download_dir', KeyDirection.TO_LEGACY)).assertEqual('downloadDir');
    });

    it('uses kebab-case for a session request', () => {
      const sessionContext = ConversionContext.forRequest(RpcMethod.SESSION_GET);
      expect(KeyConverter.convertKey(sessionContext, 'download_dir', KeyDirection.TO_LEGACY)).assertEqual('download-dir');
    });

    it('normalises either legacy spelling back to download_dir', () => {
      const context = ConversionContext.neutral();
      expect(KeyConverter.convertKey(context, 'downloadDir', KeyDirection.TO_CANONICAL)).assertEqual('download_dir');
      expect(KeyConverter.convertKey(context, 'download-dir', KeyDirection.TO_CANONICAL)).assertEqual('download_dir');
    });
  });

  describe('KeyConverter crazy case: total_size in a free_space response', () => {
    it('detects the free_space response shape', () => {
      const payload: JsonObject = {};
      payload['path'] = '/srv';
      payload['size-bytes'] = 10;
      payload['totalSize'] = 100;
      const context = ConversionContext.forResponse(payload);
      expect(context.isFreeSpaceResponse).assertTrue();
      expect(context.isTorrent).assertFalse();
    });

    it('keeps total_size underscored even for the legacy dialect', () => {
      const payload: JsonObject = {};
      payload['path'] = '/srv';
      payload['size-bytes'] = 10;
      payload['totalSize'] = 100;
      const context = ConversionContext.forResponse(payload);
      expect(KeyConverter.convertKey(context, 'total_size', KeyDirection.TO_LEGACY)).assertEqual('total_size');
      expect(KeyConverter.convertKey(context, 'totalSize', KeyDirection.TO_LEGACY)).assertEqual('total_size');
      expect(KeyConverter.convertKey(context, 'totalSize', KeyDirection.TO_CANONICAL)).assertEqual('total_size');
    });

    it('still maps total_size to totalSize outside a free_space response', () => {
      const context = ConversionContext.forRequest(RpcMethod.TORRENT_GET);
      expect(KeyConverter.convertKey(context, 'total_size', KeyDirection.TO_LEGACY)).assertEqual('totalSize');
    });

    it('does not mistake a torrent response for a free_space response', () => {
      const payload: JsonObject = {};
      payload['path'] = '/srv';
      payload['size-bytes'] = 10;
      payload['torrents'] = [] as JsonArray;
      const context = ConversionContext.forResponse(payload);
      expect(context.isFreeSpaceResponse).assertFalse();
      expect(context.isTorrent).assertTrue();
    });
  });

  describe('ConversionContext', () => {
    it('flags torrent methods for requests', () => {
      expect(ConversionContext.forRequest(RpcMethod.TORRENT_GET).isTorrent).assertTrue();
      expect(ConversionContext.forRequest(RpcMethod.TORRENT_SET).isTorrent).assertTrue();
      expect(ConversionContext.forRequest(RpcMethod.SESSION_GET).isTorrent).assertFalse();
      expect(ConversionContext.forRequest(RpcMethod.FREE_SPACE).isFreeSpaceResponse).assertTrue();
    });

    it('flags torrent responses by the presence of a torrents array', () => {
      const payload: JsonObject = {};
      payload['torrents'] = [] as JsonArray;
      expect(ConversionContext.forResponse(payload).isTorrent).assertTrue();
      expect(ConversionContext.forResponse(Json.emptyObject()).isTorrent).assertFalse();
      expect(ConversionContext.forResponse(undefined).isTorrent).assertFalse();
    });
  });

  describe('KeyConverter recursive translation', () => {
    it('walks nested objects and arrays', () => {
      const torrent: JsonObject = {};
      torrent['rate_download'] = 1;
      torrent['file_stats'] = [] as JsonArray;
      const payload: JsonObject = {};
      payload['torrents'] = [torrent] as JsonArray;

      const legacy = Json.asObject(KeyConverter.toLegacy(ConversionContext.neutral(), payload));
      expect(legacy === undefined).assertFalse();
      if (legacy !== undefined) {
        const torrents = Json.getArray(legacy, 'torrents');
        expect(torrents === undefined ? -1 : torrents.length).assertEqual(1);
        const first = Json.asObject(torrents === undefined ? undefined : torrents[0]);
        expect(Json.has(first, 'rateDownload')).assertTrue();
        expect(Json.has(first, 'fileStats')).assertTrue();
      }
    });

    it('translates the strings inside a fields array', () => {
      const params: JsonObject = {};
      params['fields'] = ['name', 'percent_done', 'rate_download'] as JsonArray;
      const legacy = ConversionContext.forRequest(RpcMethod.TORRENT_GET);
      const converted = Json.asObject(KeyConverter.toLegacy(legacy, params));
      expect(Json.getStringArray(converted, 'fields')).assertDeepEquals(['name', 'percentDone', 'rateDownload']);
    });

    it('applies the torrent-specific spelling inside a fields array', () => {
      const params: JsonObject = {};
      params['fields'] = ['download_dir'] as JsonArray;
      const context = ConversionContext.forRequest(RpcMethod.TORRENT_GET);
      const converted = Json.asObject(KeyConverter.toLegacy(context, params));
      expect(Json.getStringArray(converted, 'fields')).assertDeepEquals(['downloadDir']);
    });

    it('does not translate unrelated string values', () => {
      const params: JsonObject = {};
      params['location'] = 'download-dir';
      params['name'] = 'percentDone';
      const converted = Json.asObject(KeyConverter.toLegacy(ConversionContext.neutral(), params));
      expect(Json.getString(converted, 'location')).assertEqual('download-dir');
      expect(Json.getString(converted, 'name')).assertEqual('percentDone');
    });

    it('converts the wanted array between booleans and 0/1 integers', () => {
      const modern: JsonObject = {};
      modern['wanted'] = [true, false, true] as JsonArray;
      const legacy = Json.asObject(KeyConverter.toLegacy(ConversionContext.neutral(), modern));
      expect(Json.getArray(legacy, 'wanted')).assertDeepEquals([1, 0, 1]);

      const backToModern = Json.asObject(KeyConverter.toCanonical(ConversionContext.neutral(), legacy));
      expect(Json.getArray(backToModern, 'wanted')).assertDeepEquals([true, false, true]);
    });

    it('converts the encryption mode spelling', () => {
      const modern: JsonObject = {};
      modern['encryption'] = 'allowed';
      const legacy = Json.asObject(KeyConverter.toLegacy(ConversionContext.neutral(), modern));
      expect(Json.getString(legacy, 'encryption')).assertEqual('tolerated');

      const backToModern = Json.asObject(KeyConverter.toCanonical(ConversionContext.neutral(), legacy));
      expect(Json.getString(backToModern, 'encryption')).assertEqual('allowed');
    });

    it('passes unknown encryption modes through unchanged', () => {
      const modern: JsonObject = {};
      modern['encryption'] = 'post-quantum';
      const legacy = Json.asObject(KeyConverter.toLegacy(ConversionContext.neutral(), modern));
      expect(Json.getString(legacy, 'encryption')).assertEqual('post-quantum');
    });

    it('never mutates its input', () => {
      const torrent: JsonObject = {};
      torrent['percent_done'] = 0.5;
      const payload: JsonObject = {};
      payload['torrents'] = [torrent] as JsonArray;

      KeyConverter.toLegacy(ConversionContext.neutral(), payload);

      expect(Json.has(torrent, 'percent_done')).assertTrue();
      expect(Json.has(torrent, 'percentDone')).assertFalse();
    });

    it('tolerates undefined input', () => {
      expect(Json.isEmpty(Json.asObject(KeyConverter.toLegacy(ConversionContext.neutral(), undefined)))).assertTrue();
      expect(Json.isEmpty(Json.asObject(KeyConverter.toCanonical(ConversionContext.neutral(), undefined)))).assertTrue();
    });

    it('leaves scalars and null alone', () => {
      const payload: JsonObject = {};
      payload['a'] = 1;
      payload['b'] = null;
      payload['c'] = true;
      const converted = Json.asObject(KeyConverter.toLegacy(ConversionContext.neutral(), payload));
      expect(Json.getNumber(converted, 'a')).assertEqual(1);
      expect(Json.get(converted, 'b')).assertNull();
      expect(Json.getBoolean(converted, 'c')).assertTrue();
    });
  });

  describe('KeyConverter round trip', () => {
    it('returns to the original payload after two conversions', () => {
      const original: JsonObject = {};
      original['alt_speed_down'] = 100;
      original['download_dir'] = '/srv';
      const nested: JsonObject = {};
      nested['percent_done'] = 0.5;
      original['torrents'] = [nested] as JsonArray;

      const context = ConversionContext.neutral();
      const legacy = KeyConverter.toLegacy(context, original);
      const roundTripped = KeyConverter.toCanonical(context, legacy);

      expect(Json.deepEquals(original, roundTripped)).assertTrue();
    });
  });
}
