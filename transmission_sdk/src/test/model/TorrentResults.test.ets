// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for the `torrent_get` / `torrent_add` / `torrent_rename_path` results.
 *
 * `torrent_get` can answer in two encodings: `objects` (an array of key/value
 * objects) and `table` (a header row followed by positional rows). The table
 * decoder is therefore the risky part of this file: a short row, an empty
 * header or a stray non-array element must never read past the end of an array.
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { Json, JsonArray, JsonObject } from '../../main/ets/util/Json';
import {
  RecentlyActiveTorrents,
  TorrentAddResult,
  TorrentRenameResult,
  TorrentTable,
} from '../../main/ets/model/TorrentResults';

/** A `format: "objects"` payload with one malformed entry. */
function objectsPayload(): JsonObject {
  const first: JsonObject = {};
  first['id'] = 1;
  first['name'] = 'First';
  first['percent_done'] = 0.5;
  const second: JsonObject = {};
  second['id'] = 2;
  second['name'] = 'Second';
  second['percent_done'] = 1;
  const json: JsonObject = {};
  json['torrents'] = [first, 5, second] as JsonArray;
  json['removed'] = [7, 8] as JsonArray;
  return json;
}

/** A `format: "table"` payload: header row followed by positional rows. */
function tablePayload(): JsonObject {
  const header: JsonArray = ['id', 'name', 'percent_done'] as JsonArray;
  const first: JsonArray = [1, 'First', 0.5] as JsonArray;
  const second: JsonArray = [2, 'Second', 1] as JsonArray;
  const json: JsonObject = {};
  json['torrents'] = [header, first, second] as JsonArray;
  json['removed'] = [7, 8] as JsonArray;
  return json;
}

export default function torrentResultsTest(): void {
  describe('TorrentTable.parse', () => {
    it('returns an empty table when torrents is missing', () => {
      const table = TorrentTable.parse(Json.emptyObject() as JsonObject);
      expect(table.rows.length).assertEqual(0);
      expect(table.columns.length).assertEqual(0);
      expect(table.isTable).assertFalse();
      expect(TorrentTable.parse(undefined).rows.length).assertEqual(0);
    });

    it('returns an empty table for an empty torrents array', () => {
      const json: JsonObject = {};
      json['torrents'] = [] as JsonArray;
      const table = TorrentTable.parse(json);
      expect(table.rows.length).assertEqual(0);
      expect(table.columns.length).assertEqual(0);
      expect(table.isTable).assertFalse();
    });

    it('passes objects payloads through and skips malformed entries', () => {
      const table = TorrentTable.parse(objectsPayload());
      expect(table.isTable).assertFalse();
      expect(table.columns.length).assertEqual(0);
      expect(table.rows.length).assertEqual(2);
      expect(Json.getNumber(table.rows[0], 'id')).assertEqual(1);
      expect(Json.getString(table.rows[1], 'name')).assertEqual('Second');
    });

    it('zips a header row with every data row', () => {
      const table = TorrentTable.parse(tablePayload());
      expect(table.isTable).assertTrue();
      expect(table.columns).assertDeepEquals(['id', 'name', 'percent_done']);
      expect(table.rows.length).assertEqual(2);
      expect(Json.getNumber(table.rows[0], 'id')).assertEqual(1);
      expect(Json.getString(table.rows[0], 'name')).assertEqual('First');
      expect(Json.getNumber(table.rows[0], 'percent_done')).assertEqual(0.5);
      expect(Json.getNumber(table.rows[1], 'id')).assertEqual(2);
      expect(Json.getString(table.rows[1], 'name')).assertEqual('Second');
    });

    it('leaves missing columns unset when a row is shorter than the header', () => {
      const header: JsonArray = ['id', 'name', 'eta'] as JsonArray;
      const short: JsonArray = [1] as JsonArray;
      const json: JsonObject = {};
      json['torrents'] = [header, short] as JsonArray;
      const table = TorrentTable.parse(json);
      expect(table.rows.length).assertEqual(1);
      expect(Json.getNumber(table.rows[0], 'id')).assertEqual(1);
      expect(Json.has(table.rows[0], 'name')).assertFalse();
      expect(Json.has(table.rows[0], 'eta')).assertFalse();
    });

    it('produces empty rows for an empty header row without throwing', () => {
      const header: JsonArray = [] as JsonArray;
      const row: JsonArray = [1, 2] as JsonArray;
      const json: JsonObject = {};
      json['torrents'] = [header, row] as JsonArray;
      const table = TorrentTable.parse(json);
      expect(table.isTable).assertTrue();
      expect(table.columns.length).assertEqual(0);
      expect(table.rows.length).assertEqual(1);
      expect(Json.isEmpty(table.rows[0])).assertTrue();
    });

    it('skips non-array row elements in a table payload', () => {
      const header: JsonArray = ['id'] as JsonArray;
      const json: JsonObject = {};
      json['torrents'] = [header, 5, 'nope', null] as JsonArray;
      const table = TorrentTable.parse(json);
      expect(table.isTable).assertTrue();
      expect(table.columns).assertDeepEquals(['id']);
      expect(table.rows.length).assertEqual(0);
    });

    it('ignores non-string header entries instead of inventing keys', () => {
      const header: JsonArray = ['id', 5, 'name'] as JsonArray;
      const row: JsonArray = [1, 'ignored', 'First'] as JsonArray;
      const json: JsonObject = {};
      json['torrents'] = [header, row] as JsonArray;
      const table = TorrentTable.parse(json);
      expect(table.columns).assertDeepEquals(['id', '', 'name']);
      expect(table.rows.length).assertEqual(1);
      expect(Json.getNumber(table.rows[0], 'id')).assertEqual(1);
      expect(Json.getString(table.rows[0], 'name')).assertEqual('First');
      expect(Json.has(table.rows[0], '')).assertFalse();
    });

    it('ignores extra row values beyond the header', () => {
      const header: JsonArray = ['id'] as JsonArray;
      const row: JsonArray = [1, 'extra', 3] as JsonArray;
      const json: JsonObject = {};
      json['torrents'] = [header, row] as JsonArray;
      const table = TorrentTable.parse(json);
      expect(Json.keys(table.rows[0]).length).assertEqual(1);
      expect(Json.getNumber(table.rows[0], 'id')).assertEqual(1);
    });
  });

  describe('TorrentRenameResult', () => {
    it('reads the canonical id, path and name keys', () => {
      const json: JsonObject = {};
      json['id'] = 4;
      json['path'] = 'old/name.bin';
      json['name'] = 'new.bin';
      const result = TorrentRenameResult.fromJson(json);
      expect(result.id).assertEqual(4);
      expect(result.path).assertEqual('old/name.bin');
      expect(result.name).assertEqual('new.bin');
    });

    it('returns defaults for an undefined payload', () => {
      const result = TorrentRenameResult.fromJson(undefined);
      expect(result.id).assertEqual(0);
      expect(result.path).assertEqual('');
      expect(result.name).assertEqual('');
    });
  });

  describe('TorrentAddResult', () => {
    it('reads torrent_added as a new torrent', () => {
      const added: JsonObject = {};
      added['id'] = 1;
      added['name'] = 'Added';
      const json: JsonObject = {};
      json['torrent_added'] = added;
      const result = TorrentAddResult.fromJson(json);
      expect(result.wasAdded).assertTrue();
      expect(result.wasDuplicate).assertFalse();
      expect(result.added?.name).assertEqual('Added');
      expect(result.torrent?.name).assertEqual('Added');
      expect(result.duplicate).assertUndefined();
    });

    it('reads torrent_duplicate as a pre-existing torrent', () => {
      const duplicate: JsonObject = {};
      duplicate['id'] = 2;
      duplicate['name'] = 'Duplicate';
      const json: JsonObject = {};
      json['torrent_duplicate'] = duplicate;
      const result = TorrentAddResult.fromJson(json);
      expect(result.wasAdded).assertFalse();
      expect(result.wasDuplicate).assertTrue();
      expect(result.duplicate?.name).assertEqual('Duplicate');
      expect(result.torrent?.name).assertEqual('Duplicate');
      expect(result.added).assertUndefined();
    });

    it('prefers the added torrent over the duplicate in the torrent getter', () => {
      const added: JsonObject = {};
      added['id'] = 1;
      added['name'] = 'Added';
      const duplicate: JsonObject = {};
      duplicate['id'] = 2;
      duplicate['name'] = 'Duplicate';
      const json: JsonObject = {};
      json['torrent_added'] = added;
      json['torrent_duplicate'] = duplicate;
      const result = TorrentAddResult.fromJson(json);
      expect(result.wasAdded).assertTrue();
      expect(result.wasDuplicate).assertTrue();
      expect(result.torrent?.name).assertEqual('Added');
    });

    it('reports neither outcome for an empty or undefined payload', () => {
      const empty = TorrentAddResult.fromJson(Json.emptyObject() as JsonObject);
      expect(empty.wasAdded).assertFalse();
      expect(empty.wasDuplicate).assertFalse();
      expect(empty.torrent).assertUndefined();
      const missing = TorrentAddResult.fromJson(undefined);
      expect(missing.torrent).assertUndefined();
    });
  });

  describe('RecentlyActiveTorrents', () => {
    it('parses an objects payload and its removed ids', () => {
      const result = RecentlyActiveTorrents.fromObjects(objectsPayload());
      expect(result.torrents.length).assertEqual(2);
      expect(result.torrents[0].name).assertEqual('First');
      expect(result.torrents[1].percentDone).assertEqual(1);
      expect(result.removed).assertDeepEquals([7, 8]);
    });

    it('parses a table payload and its removed ids', () => {
      const result = RecentlyActiveTorrents.fromTable(tablePayload());
      expect(result.torrents.length).assertEqual(2);
      expect(result.torrents[0].id).assertEqual(1);
      expect(result.torrents[0].name).assertEqual('First');
      expect(result.torrents[1].name).assertEqual('Second');
      expect(result.removed).assertDeepEquals([7, 8]);
    });

    it('auto-detects the format from the payload shape', () => {
      const objects = RecentlyActiveTorrents.fromJson(objectsPayload());
      expect(objects.torrents.length).assertEqual(2);
      expect(objects.torrents[1].name).assertEqual('Second');

      const table = RecentlyActiveTorrents.fromJson(tablePayload());
      expect(table.torrents.length).assertEqual(2);
      expect(table.torrents[0].name).assertEqual('First');
      expect(table.torrents[1].name).assertEqual('Second');
    });

    it('returns an empty result for missing or malformed payloads', () => {
      const empty = RecentlyActiveTorrents.fromJson(undefined);
      expect(empty.torrents.length).assertEqual(0);
      expect(empty.removed.length).assertEqual(0);
      const blank = RecentlyActiveTorrents.fromJson(Json.emptyObject() as JsonObject);
      expect(blank.torrents.length).assertEqual(0);
      expect(blank.removed.length).assertEqual(0);
    });

    it('skips malformed removed entries instead of failing', () => {
      const json: JsonObject = {};
      json['torrents'] = [] as JsonArray;
      json['removed'] = [1, 'two', 3, null] as JsonArray;
      const result = RecentlyActiveTorrents.fromJson(json);
      expect(result.removed).assertDeepEquals([1, 3]);
    });
  });
}
