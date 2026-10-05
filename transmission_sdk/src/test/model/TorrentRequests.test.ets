// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for the `torrent_*` request builders.
 *
 * The wire contract pinned down here is "omit what the caller did not set,
 * except where Transmission treats an empty array as a meaningful reset".
 * Getting that boundary wrong either silently resets settings or makes a reset
 * impossible, so both directions are asserted.
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { Json, JsonObject, JsonObjectBuilder } from '../../main/ets/util/Json';
import {
  TorrentAddRequest,
  TorrentFields,
  TorrentGetRequest,
  TorrentIds,
  TorrentSetRequest,
} from '../../main/ets/model/TorrentRequests';
import { IdleLimitMode, RatioLimitMode, TorrentFormat, TorrentPriority } from '../../main/ets/model/Enums';

/** True when `values` repeats an entry. */
function hasDuplicates(values: string[]): boolean {
  const seen: string[] = [];
  for (const value of values) {
    if (seen.includes(value)) {
      return true;
    }
    seen.push(value);
  }
  return false;
}

/** True when every entry of `subset` also appears in `superset`. */
function isSubset(subset: string[], superset: string[]): boolean {
  for (const value of subset) {
    if (!superset.includes(value)) {
      return false;
    }
  }
  return true;
}

export default function torrentRequestsTest(): void {
  describe('TorrentIds', () => {
    it('serialises ALL as an omitted argument', () => {
      expect(TorrentIds.ALL.toJson()).assertUndefined();
      expect(TorrentIds.ALL.isAll).assertTrue();
      expect(TorrentIds.ALL.isRecentlyActive).assertFalse();
      expect(TorrentIds.ALL.size).assertEqual(0);
    });

    it('omits ids entirely when applied to a builder', () => {
      const builder = new JsonObjectBuilder();
      TorrentIds.ALL.applyTo(builder);
      expect(Json.isEmpty(builder.build())).assertTrue();
    });

    it('serialises RECENTLY_ACTIVE as the documented pseudo-id string', () => {
      expect(TorrentIds.RECENTLY_ACTIVE.toJson()).assertEqual('recently_active');
      expect(TorrentIds.RECENTLY_ACTIVE.isRecentlyActive).assertTrue();
      expect(TorrentIds.RECENTLY_ACTIVE.isAll).assertFalse();
      expect(TorrentIds.RECENTLY_ACTIVE.size).assertEqual(0);
      const builder = new JsonObjectBuilder();
      TorrentIds.RECENTLY_ACTIVE.applyTo(builder);
      expect(Json.getString(builder.build(), 'ids')).assertEqual('recently_active');
    });

    it('serialises explicit id lists as arrays', () => {
      expect(TorrentIds.of([42, 'a1b2c3']).toJson()).assertDeepEquals([42, 'a1b2c3']);
      expect(TorrentIds.single(7).toJson()).assertDeepEquals([7]);
      expect(TorrentIds.ofHashes(['aa', 'bb']).toJson()).assertDeepEquals(['aa', 'bb']);
      expect(TorrentIds.ofNumbers([1, 2, 3]).toJson()).assertDeepEquals([1, 2, 3]);
    });

    it('reports the size of explicit id lists', () => {
      expect(TorrentIds.of([1, 2, 3]).size).assertEqual(3);
      expect(TorrentIds.single('hash').size).assertEqual(1);
      expect(TorrentIds.ofNumbers([]).size).assertEqual(0);
    });

    it('describes itself for diagnostics', () => {
      expect(TorrentIds.ALL.toString()).assertEqual('all');
      expect(TorrentIds.RECENTLY_ACTIVE.toString()).assertEqual('recently_active');
      expect(TorrentIds.of([1, 2]).toString()).assertEqual('2 ids');
    });

    it('copies the input array so later mutations do not leak into the request', () => {
      const hashes = ['aa'];
      const ids = TorrentIds.ofHashes(hashes);
      hashes.push('bb');
      expect(ids.toJson()).assertDeepEquals(['aa']);
    });
  });

  describe('TorrentFields presets', () => {
    it('ships non-empty, duplicate-free presets', () => {
      expect(TorrentFields.BASIC.length).assertLarger(0);
      expect(TorrentFields.PROGRESS.length).assertLarger(0);
      expect(TorrentFields.DETAILED.length).assertLarger(0);
      expect(hasDuplicates(TorrentFields.BASIC)).assertFalse();
      expect(hasDuplicates(TorrentFields.PROGRESS)).assertFalse();
      expect(hasDuplicates(TorrentFields.DETAILED)).assertFalse();
    });

    it('makes DETAILED a superset of PROGRESS', () => {
      expect(isSubset(TorrentFields.PROGRESS, TorrentFields.DETAILED)).assertTrue();
      expect(TorrentFields.DETAILED.length).assertLarger(TorrentFields.PROGRESS.length);
    });
  });

  describe('TorrentGetRequest', () => {
    it('always sends fields and format', () => {
      const json = new TorrentGetRequest().toJson();
      expect(Json.has(json, 'fields')).assertTrue();
      expect(Json.getArray(json, 'fields')?.length).assertEqual(TorrentFields.BASIC.length);
      expect(Json.getString(json, 'format')).assertEqual(TorrentFormat.OBJECTS);
    });

    it('omits ids while every torrent is addressed', () => {
      const json = new TorrentGetRequest(TorrentFields.BASIC).toJson();
      expect(Json.has(json, 'ids')).assertFalse();
    });

    it('sends ids once a subset is addressed', () => {
      const json = new TorrentGetRequest(TorrentFields.BASIC).ids(TorrentIds.RECENTLY_ACTIVE).toJson();
      expect(Json.getString(json, 'ids')).assertEqual('recently_active');
    });

    it('sends an empty fields array rather than dropping the key', () => {
      const json = new TorrentGetRequest([]).toJson();
      expect(Json.has(json, 'fields')).assertTrue();
      expect(Json.getArray(json, 'fields')?.length).assertEqual(0);
    });

    it('does not duplicate a field that is already selected', () => {
      const request = new TorrentGetRequest(['id', 'name']);
      request.addField('id');
      request.addField('status');
      request.addField('status');
      expect(request.fieldsList).assertDeepEquals(['id', 'name', 'status']);
    });

    it('replaces the whole selection through fields and appends many through addFields', () => {
      const request = new TorrentGetRequest(['id']);
      request.fields(['name', 'hash_string']);
      request.addFields(['eta', 'name']);
      expect(request.fieldsList).assertDeepEquals(['name', 'hash_string', 'eta']);
      expect(request.fieldsList).assertNotEqual(null);
    });

    it('remembers the chosen response encoding', () => {
      const request = new TorrentGetRequest();
      expect(request.formatMode).assertEqual(TorrentFormat.OBJECTS);
      request.format(TorrentFormat.TABLE);
      expect(request.formatMode).assertEqual(TorrentFormat.TABLE);
      expect(Json.getString(request.toJson(), 'format')).assertEqual(TorrentFormat.TABLE);
    });
  });

  describe('TorrentAddRequest', () => {
    it('base64-encodes raw metainfo bytes', () => {
      const request = TorrentAddRequest.fromBytes(new Uint8Array([104, 105]));
      expect(Json.getString(request.toJson(), 'metainfo')).assertEqual('aGk=');
      expect(request.isComplete).assertTrue();
    });

    it('is incomplete until filename or metainfo is set', () => {
      const request = TorrentAddRequest.create();
      expect(request.isComplete).assertFalse();
      request.filename('magnet:?xt=urn:btih:abcdef');
      expect(request.isComplete).assertTrue();
      expect(TorrentAddRequest.fromMetainfo('YmFzZTY0').isComplete).assertTrue();
      expect(TorrentAddRequest.fromFilename('/tmp/a.torrent').isComplete).assertTrue();
      expect(TorrentAddRequest.fromMagnet('magnet:?xt=urn:btih:abcdef').isComplete).assertTrue();
    });

    it('omits optional fields that were never set', () => {
      const json = TorrentAddRequest.fromFilename('/tmp/a.torrent').toJson();
      expect(Json.has(json, 'download_dir')).assertFalse();
      expect(Json.has(json, 'cookies')).assertFalse();
      expect(Json.has(json, 'labels')).assertFalse();
      expect(Json.has(json, 'paused')).assertFalse();
      expect(Json.has(json, 'peer_limit')).assertFalse();
      expect(Json.has(json, 'bandwidth_priority')).assertFalse();
      expect(Json.has(json, 'files_wanted')).assertFalse();
      expect(Json.has(json, 'sequential_download')).assertFalse();
    });

    it('sends optional scalars only when they are set, including false and zero', () => {
      const json = TorrentAddRequest.fromFilename('/tmp/a.torrent')
        .downloadDir('/srv/media')
        .cookies('session=1')
        .paused(false)
        .peerLimit(0)
        .bandwidthPriority(TorrentPriority.HIGH)
        .sequentialDownload(true)
        .sequentialDownloadFromPiece(4)
        .toJson();
      expect(Json.getString(json, 'download_dir')).assertEqual('/srv/media');
      expect(Json.getString(json, 'cookies')).assertEqual('session=1');
      expect(Json.getBoolean(json, 'paused')).assertFalse();
      expect(Json.has(json, 'paused')).assertTrue();
      expect(Json.getNumber(json, 'peer_limit')).assertEqual(0);
      expect(Json.getNumber(json, 'bandwidth_priority')).assertEqual(TorrentPriority.HIGH);
      expect(Json.getBoolean(json, 'sequential_download')).assertTrue();
      expect(Json.getNumber(json, 'sequential_download_from_piece')).assertEqual(4);
    });

    it('serialises labels and priority arrays as JSON arrays', () => {
      const json = TorrentAddRequest.fromFilename('magnet:?xt=urn:btih:abcdef')
        .labels(['linux', 'iso'])
        .filesWanted([0, 2])
        .filesUnwanted([1])
        .priorityHigh([2])
        .priorityLow([0])
        .priorityNormal([1])
        .toJson();
      expect(Json.getStringArray(json, 'labels')).assertDeepEquals(['linux', 'iso']);
      expect(Json.getArray(json, 'files_wanted')).assertDeepEquals([0, 2]);
      expect(Json.getArray(json, 'files_unwanted')).assertDeepEquals([1]);
      expect(Json.getArray(json, 'priority_high')).assertDeepEquals([2]);
      expect(Json.getArray(json, 'priority_low')).assertDeepEquals([0]);
      expect(Json.getArray(json, 'priority_normal')).assertDeepEquals([1]);
    });

    it('omits empty array options because Transmission has no reset semantics here', () => {
      const json = TorrentAddRequest.fromFilename('/tmp/a.torrent').labels([]).filesWanted([]).toJson();
      expect(Json.has(json, 'labels')).assertFalse();
      expect(Json.has(json, 'files_wanted')).assertFalse();
    });

    it('copies label and index arrays instead of aliasing the caller', () => {
      const labels = ['linux'];
      const wanted = [0];
      const request = TorrentAddRequest.fromFilename('/tmp/a.torrent').labels(labels).filesWanted(wanted);
      labels.push('later');
      wanted.push(9);
      const json = request.toJson();
      expect(Json.getStringArray(json, 'labels')).assertDeepEquals(['linux']);
      expect(Json.getArray(json, 'files_wanted')).assertDeepEquals([0]);
    });
  });

  describe('TorrentSetRequest', () => {
    it('sends nothing for a fresh request', () => {
      const request = new TorrentSetRequest();
      expect(request.hasChanges).assertFalse();
      expect(Json.isEmpty(request.toJson())).assertTrue();
    });

    it('sends exactly the requested scalar keys', () => {
      const json = new TorrentSetRequest()
        .bandwidthPriority(TorrentPriority.LOW)
        .downloadLimit(2048)
        .downloadLimited(true)
        .uploadLimit(256)
        .uploadLimited(false)
        .honorsSessionLimits(true)
        .location('/srv/new')
        .peerLimit(40)
        .queuePosition(2)
        .seedIdleLimit(30)
        .seedIdleMode(IdleLimitMode.SINGLE)
        .seedRatioLimit(2.5)
        .seedRatioMode(RatioLimitMode.UNLIMITED)
        .sequentialDownload(true)
        .sequentialDownloadFromPiece(5)
        .toJson();
      expect(Json.getNumber(json, 'bandwidth_priority')).assertEqual(TorrentPriority.LOW);
      expect(Json.getNumber(json, 'download_limit')).assertEqual(2048);
      expect(Json.getBoolean(json, 'download_limited')).assertTrue();
      expect(Json.getNumber(json, 'upload_limit')).assertEqual(256);
      expect(Json.has(json, 'upload_limited')).assertTrue();
      expect(Json.getBoolean(json, 'upload_limited')).assertFalse();
      expect(Json.getBoolean(json, 'honors_session_limits')).assertTrue();
      expect(Json.getString(json, 'location')).assertEqual('/srv/new');
      expect(Json.getNumber(json, 'peer_limit')).assertEqual(40);
      expect(Json.getNumber(json, 'queue_position')).assertEqual(2);
      expect(Json.getNumber(json, 'seed_idle_limit')).assertEqual(30);
      expect(Json.getNumber(json, 'seed_idle_mode')).assertEqual(IdleLimitMode.SINGLE);
      expect(Json.getNumber(json, 'seed_ratio_limit')).assertEqual(2.5);
      expect(Json.getNumber(json, 'seed_ratio_mode')).assertEqual(RatioLimitMode.UNLIMITED);
      expect(Json.getBoolean(json, 'sequential_download')).assertTrue();
      expect(Json.getNumber(json, 'sequential_download_from_piece')).assertEqual(5);
      expect(requestKeyCount(json)).assertEqual(15);
    });

    it('leaves untouched fields absent, so Transmission keeps their values', () => {
      const json = new TorrentSetRequest().downloadLimit(100).toJson();
      expect(Json.has(json, 'download_limit')).assertTrue();
      expect(Json.has(json, 'upload_limit')).assertFalse();
      expect(Json.has(json, 'labels')).assertFalse();
      expect(Json.has(json, 'group')).assertFalse();
      expect(Json.has(json, 'tracker_list')).assertFalse();
    });

    it('reports hasChanges once any setter is called', () => {
      const request = new TorrentSetRequest();
      expect(request.hasChanges).assertFalse();
      request.downloadLimit(0);
      expect(request.hasChanges).assertTrue();
      expect(Json.has(request.toJson(), 'download_limit')).assertTrue();
    });

    it('sends empty arrays for the reset-capable options', () => {
      const json = new TorrentSetRequest()
        .filesWanted([])
        .filesUnwanted([])
        .priorityHigh([])
        .priorityLow([])
        .priorityNormal([])
        .labels([])
        .toJson();
      expect(Json.has(json, 'files_wanted')).assertTrue();
      expect(Json.has(json, 'files_unwanted')).assertTrue();
      expect(Json.has(json, 'priority_high')).assertTrue();
      expect(Json.has(json, 'priority_low')).assertTrue();
      expect(Json.has(json, 'priority_normal')).assertTrue();
      expect(Json.has(json, 'labels')).assertTrue();
      expect(Json.getArray(json, 'labels')?.length).assertEqual(0);
      expect(Json.getArray(json, 'files_wanted')?.length).assertEqual(0);
    });

    it('sends empty group and tracker_list strings because they are meaningful resets', () => {
      const json = new TorrentSetRequest().group('').trackerList('').toJson();
      expect(Json.has(json, 'group')).assertTrue();
      expect(Json.getString(json, 'group')).assertEqual('');
      expect(Json.has(json, 'tracker_list')).assertTrue();
      expect(Json.getString(json, 'tracker_list')).assertEqual('');
    });

    it('sends populated reset-capable arrays', () => {
      const json = new TorrentSetRequest().filesWanted([0, 1]).labels(['a']).toJson();
      expect(Json.getArray(json, 'files_wanted')).assertDeepEquals([0, 1]);
      expect(Json.getStringArray(json, 'labels')).assertDeepEquals(['a']);
    });

    it('omits empty setArray options that have no reset semantics', () => {
      const json = new TorrentSetRequest().trackerAdd([]).trackerRemove([]).trackerReplace([]).toJson();
      expect(Json.has(json, 'tracker_add')).assertFalse();
      expect(Json.has(json, 'tracker_remove')).assertFalse();
      expect(Json.has(json, 'tracker_replace')).assertFalse();
    });

    it('serialises populated tracker arrays', () => {
      const json = new TorrentSetRequest()
        .trackerAdd(['https://a/announce'])
        .trackerRemove([1, 2])
        .trackerReplace([[0, 3]])
        .toJson();
      expect(Json.getArray(json, 'tracker_add')).assertDeepEquals(['https://a/announce']);
      expect(Json.getArray(json, 'tracker_remove')).assertDeepEquals([1, 2]);
      expect(Json.getArray(json, 'tracker_replace')).assertDeepEquals([[0, 3]]);
    });

    it('omits ids for every-torrent requests', () => {
      expect(Json.has(new TorrentSetRequest().downloadLimit(1).toJson(), 'ids')).assertFalse();
    });

    it('keeps accumulated changes when ids is switched', () => {
      const request = new TorrentSetRequest().downloadLimit(100).sequentialDownload(true);
      const retargeted = request.ids(TorrentIds.ofNumbers([4, 5]));
      const json = retargeted.toJson();
      expect(Json.getArray(json, 'ids')).assertDeepEquals([4, 5]);
      expect(Json.getNumber(json, 'download_limit')).assertEqual(100);
      expect(Json.getBoolean(json, 'sequential_download')).assertTrue();
    });

    it('does not mutate the original request when ids is switched', () => {
      const request = new TorrentSetRequest().downloadLimit(100);
      request.ids(TorrentIds.single(9));
      const json = request.toJson();
      expect(Json.has(json, 'ids')).assertFalse();
      expect(Json.getNumber(json, 'download_limit')).assertEqual(100);
    });

    it('copies index arrays instead of aliasing the caller', () => {
      const indices = [0];
      const request = new TorrentSetRequest().filesWanted(indices);
      indices.push(1);
      expect(Json.getArray(request.toJson(), 'files_wanted')).assertDeepEquals([0]);
    });
  });
}

/** Number of own keys of `json`; kept local so no reflective API is needed. */
function requestKeyCount(json: JsonObject): number {
  let count = 0;
  for (const key of Json.keys(json)) {
    if (key.length > 0) {
      count += 1;
    }
  }
  return count;
}
