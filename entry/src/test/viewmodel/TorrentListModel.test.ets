// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for the torrent list's filtering, sorting and row formatting.
 *
 * These are the app's only pieces of non-trivial pure logic — the UI is a
 * declarative shell around them — so they are tested on the host rather than
 * only on a device. `scripts/run-tests.mjs` copies this file together with the
 * ArkUI-free part of `entry/src/main/ets` and runs it under Node.
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { JsonObject, Torrent, TorrentStatus } from 'transmission_sdk';
import { AppSettings, TorrentFilter, TorrentSort } from '../../main/ets/model/AppModels';
import {
  ALL_FILTERS,
  ALL_SORTS,
  countForFilter,
  matchesFilter,
  sortTorrents,
  toRow,
  TorrentListModel,
} from '../../main/ets/viewmodel/TorrentListModel';

/**
 * Builds a torrent from the handful of fields the list logic reads.
 *
 * Going through `Torrent.fromJson` rather than assigning fields directly keeps
 * the tests honest: they exercise the same parsing path the app uses.
 */
function makeTorrent(
  id: number,
  name: string,
  status: TorrentStatus,
  percentDone: number,
  queuePosition: number,
): Torrent {
  const json: JsonObject = {};
  json['id'] = id;
  json['name'] = name;
  json['hash_string'] = `hash-${id}`;
  json['status'] = status;
  json['percent_done'] = percentDone;
  json['queue_position'] = queuePosition;
  json['total_size'] = 4096;
  json['rate_download'] = 100;
  json['rate_upload'] = 10;
  json['eta'] = 60;
  json['is_finished'] = percentDone >= 1;
  json['error'] = 0;
  json['error_string'] = '';
  json['labels'] = [];
  return Torrent.fromJson(json);
}

/** A torrent that is downloading. */
function downloading(id: number, queue: number): Torrent {
  return makeTorrent(id, `down-${id}`, TorrentStatus.DOWNLOADING, 0.25, queue);
}

/** A torrent that is seeding. */
function seeding(id: number, queue: number): Torrent {
  return makeTorrent(id, `seed-${id}`, TorrentStatus.SEEDING, 1, queue);
}

/** A stopped torrent. */
function stopped(id: number, queue: number): Torrent {
  return makeTorrent(id, `stop-${id}`, TorrentStatus.STOPPED, 0.5, queue);
}

export default function torrentListModelTest(): void {
  describe('Torrent filter predicates', () => {
    it('matches everything under ALL', () => {
      expect(matchesFilter(downloading(1, 0), TorrentFilter.ALL)).assertTrue();
      expect(matchesFilter(stopped(2, 1), TorrentFilter.ALL)).assertTrue();
    });

    it('treats only transferring torrents as ACTIVE', () => {
      expect(matchesFilter(downloading(1, 0), TorrentFilter.ACTIVE)).assertTrue();
      expect(matchesFilter(seeding(2, 1), TorrentFilter.ACTIVE)).assertTrue();
      expect(matchesFilter(stopped(3, 2), TorrentFilter.ACTIVE)).assertFalse();
    });

    it('includes every queued and verifying state under DOWNLOADING', () => {
      expect(matchesFilter(makeTorrent(1, 'q', TorrentStatus.QUEUED_TO_DOWNLOAD, 0, 0), TorrentFilter.DOWNLOADING)).assertTrue();
      expect(matchesFilter(makeTorrent(2, 'v', TorrentStatus.VERIFYING, 0, 1), TorrentFilter.DOWNLOADING)).assertTrue();
      expect(matchesFilter(makeTorrent(3, 'qv', TorrentStatus.QUEUED_TO_VERIFY, 0, 2), TorrentFilter.DOWNLOADING)).assertTrue();
      expect(matchesFilter(seeding(4, 3), TorrentFilter.DOWNLOADING)).assertFalse();
    });

    it('includes the queued seed state under SEEDING', () => {
      expect(matchesFilter(makeTorrent(1, 'qs', TorrentStatus.QUEUED_TO_SEED, 1, 0), TorrentFilter.SEEDING)).assertTrue();
      expect(matchesFilter(downloading(2, 1), TorrentFilter.SEEDING)).assertFalse();
    });

    it('matches only stopped torrents under PAUSED', () => {
      expect(matchesFilter(stopped(1, 0), TorrentFilter.PAUSED)).assertTrue();
      expect(matchesFilter(seeding(2, 1), TorrentFilter.PAUSED)).assertFalse();
    });

    it('separates DOWNLOADED from COMPLETED', () => {
      // Both are finished; COMPLETED additionally requires that the torrent is
      // no longer downloading.
      const finishedSeeding = makeTorrent(1, 'done', TorrentStatus.SEEDING, 1, 0);
      expect(matchesFilter(finishedSeeding, TorrentFilter.DOWNLOADED)).assertTrue();
      expect(matchesFilter(finishedSeeding, TorrentFilter.COMPLETED)).assertTrue();

      const stillDownloading = makeTorrent(2, 'partial', TorrentStatus.DOWNLOADING, 0.5, 1);
      expect(matchesFilter(stillDownloading, TorrentFilter.DOWNLOADED)).assertFalse();
      expect(matchesFilter(stillDownloading, TorrentFilter.COMPLETED)).assertFalse();
    });
  });

  describe('Torrent filter counts', () => {
    it('counts each filter independently', () => {
      const torrents: Torrent[] = [downloading(1, 0), seeding(2, 1), stopped(3, 2), seeding(4, 3)];
      expect(countForFilter(torrents, TorrentFilter.ALL)).assertEqual(4);
      expect(countForFilter(torrents, TorrentFilter.ACTIVE)).assertEqual(3);
      expect(countForFilter(torrents, TorrentFilter.DOWNLOADING)).assertEqual(1);
      expect(countForFilter(torrents, TorrentFilter.SEEDING)).assertEqual(2);
      expect(countForFilter(torrents, TorrentFilter.PAUSED)).assertEqual(1);
      expect(countForFilter(torrents, TorrentFilter.DOWNLOADED)).assertEqual(2);
    });

    it('returns zero for an empty list', () => {
      expect(countForFilter([], TorrentFilter.ALL)).assertEqual(0);
    });

    it('covers every declared filter', () => {
      expect(ALL_FILTERS.length).assertEqual(7);
      expect(ALL_SORTS.length).assertEqual(12);
    });
  });

  describe('Torrent sorting', () => {
    it('sorts by name in both directions', () => {
      const torrents: Torrent[] = [
        makeTorrent(1, 'banana', TorrentStatus.STOPPED, 0, 0),
        makeTorrent(2, 'apple', TorrentStatus.STOPPED, 0, 1),
        makeTorrent(3, 'cherry', TorrentStatus.STOPPED, 0, 2),
      ];
      const ascending = sortTorrents(torrents, TorrentSort.NAME, true);
      expect(ascending[0].name).assertEqual('apple');
      expect(ascending[2].name).assertEqual('cherry');

      const descending = sortTorrents(torrents, TorrentSort.NAME, false);
      expect(descending[0].name).assertEqual('cherry');
    });

    it('falls back to the info-hash when a name is empty', () => {
      const named = makeTorrent(1, '', TorrentStatus.STOPPED, 0, 0);
      const other = makeTorrent(2, 'zzz', TorrentStatus.STOPPED, 0, 1);
      // An empty name resolves to "hash-1", which sorts before "zzz".
      const sorted = sortTorrents([other, named], TorrentSort.NAME, true);
      expect(sorted[0].id).assertEqual(1);
    });

    it('sorts by progress, size and queue position', () => {
      const torrents: Torrent[] = [
        makeTorrent(1, 'a', TorrentStatus.STOPPED, 0.9, 2),
        makeTorrent(2, 'b', TorrentStatus.STOPPED, 0.1, 0),
        makeTorrent(3, 'c', TorrentStatus.STOPPED, 0.5, 1),
      ];
      expect(sortTorrents(torrents, TorrentSort.PROGRESS, true)[0].id).assertEqual(2);
      expect(sortTorrents(torrents, TorrentSort.PROGRESS, false)[0].id).assertEqual(1);
      expect(sortTorrents(torrents, TorrentSort.QUEUE, true)[0].id).assertEqual(2);
    });

    it('pushes unknown ETAs to the end instead of the front', () => {
      // Transmission reports -1 for "unknown"; treating that as a small number
      // would float brand-new torrents to the top of an ETA sort.
      const known: JsonObject = {};
      known['id'] = 1;
      known['name'] = 'known';
      known['eta'] = 300;
      known['queue_position'] = 0;
      const unknown: JsonObject = {};
      unknown['id'] = 2;
      unknown['name'] = 'unknown';
      unknown['eta'] = -1;
      unknown['queue_position'] = 1;

      const sorted = sortTorrents([Torrent.fromJson(unknown), Torrent.fromJson(known)], TorrentSort.ETA, true);
      expect(sorted[0].id).assertEqual(1);
      expect(sorted[1].id).assertEqual(2);
    });

    it('breaks ties on the queue position so the list does not shuffle', () => {
      const torrents: Torrent[] = [
        makeTorrent(1, 'a', TorrentStatus.STOPPED, 0.5, 3),
        makeTorrent(2, 'b', TorrentStatus.STOPPED, 0.5, 1),
        makeTorrent(3, 'c', TorrentStatus.STOPPED, 0.5, 2),
      ];
      const sorted = sortTorrents(torrents, TorrentSort.PROGRESS, true);
      expect(sorted[0].id).assertEqual(2);
      expect(sorted[1].id).assertEqual(3);
      expect(sorted[2].id).assertEqual(1);
    });

    it('does not mutate the input array', () => {
      const torrents: Torrent[] = [makeTorrent(2, 'b', TorrentStatus.STOPPED, 0, 1), makeTorrent(1, 'a', TorrentStatus.STOPPED, 0, 0)];
      sortTorrents(torrents, TorrentSort.NAME, true);
      expect(torrents[0].id).assertEqual(2);
    });

    it('sorts by every declared key without throwing', () => {
      const torrents: Torrent[] = [downloading(1, 1), seeding(2, 0), stopped(3, 2)];
      for (const sort of ALL_SORTS) {
        const ascending = sortTorrents(torrents, sort, true);
        const descending = sortTorrents(torrents, sort, false);
        expect(ascending.length).assertEqual(3);
        expect(descending.length).assertEqual(3);
      }
    });
  });

  describe('Torrent row formatting', () => {
    it('formats a downloading torrent', () => {
      const row = toRow(downloading(7, 0));
      expect(row.id).assertEqual(7);
      expect(row.name).assertEqual('down-7');
      expect(row.progressLabel).assertEqual('25%');
      expect(row.isRunning).assertTrue();
      expect(row.hasError).assertFalse();
      expect(row.sizeLabel).assertEqual('4.0 KB');
      expect(row.downSpeedLabel).assertEqual('100.0 B/s');
    });

    it('marks a torrent with an error string as failed', () => {
      const json: JsonObject = {};
      json['id'] = 1;
      json['name'] = 'bad';
      json['error'] = 3;
      json['error_string'] = 'tracker unreachable';
      const row = toRow(Torrent.fromJson(json));
      expect(row.hasError).assertTrue();
    });

    it('drives the bar from the recheck while verifying', () => {
      const json: JsonObject = {};
      json['id'] = 1;
      json['name'] = 'verifying';
      json['status'] = TorrentStatus.VERIFYING;
      json['percent_done'] = 0.2;
      json['recheck_progress'] = 0.7506;
      const row = toRow(Torrent.fromJson(json));

      expect(row.isVerifying).assertTrue();
      // The bar follows the recheck, because that is the only thing moving...
      expect(row.barValue).assertEqual(0.7506);
      expect(row.barPercentLabel).assertEqual('75.06%');
      // ...while the completion figure is left alone.
      expect(row.progressLabel).assertEqual('20%');
    });

    it('marks only an actively downloading torrent as downloading', () => {
      expect(toRow(downloading(1, 0)).isDownloading).assertTrue();
      expect(toRow(seeding(2, 1)).isDownloading).assertFalse();
      expect(toRow(stopped(3, 2)).isDownloading).assertFalse();
      // A queued download is not yet transferring.
      const queued = makeTorrent(4, 'q', TorrentStatus.QUEUED_TO_DOWNLOAD, 0, 3);
      expect(toRow(queued).isDownloading).assertFalse();
    });

    it('summarises the upload total and the share ratio', () => {
      const json: JsonObject = {};
      json['id'] = 1;
      json['name'] = 'shared';
      json['uploaded_ever'] = 2 * 1024 * 1024;
      json['upload_ratio'] = 1.25;
      const row = toRow(Torrent.fromJson(json));

      // The line shows what the torrent has contributed, not what it consumed.
      expect(row.uploadedLabel).assertEqual('2.0 MB');
      expect(row.ratioLabel).assertEqual('1.25');
    });

    it('treats queued torrents as running', () => {
      const queued = makeTorrent(1, 'q', TorrentStatus.QUEUED_TO_DOWNLOAD, 0, 0);
      expect(toRow(queued).isRunning).assertTrue();
      const verifying = makeTorrent(2, 'v', TorrentStatus.VERIFYING, 0, 1);
      expect(toRow(verifying).isRunning).assertFalse();
    });
  });

  describe('TorrentListModel', () => {
    /** Builds a model seeded with a mixed list. */
    function seededModel(): TorrentListModel {
      const model = new TorrentListModel();
      model.torrents = [downloading(1, 0), seeding(2, 1), stopped(3, 2)];
      return model;
    }

    it('filters, sorts and counts on recompute', () => {
      const model = seededModel();
      const settings = new AppSettings();
      settings.filter = TorrentFilter.SEEDING;
      settings.sortBy = TorrentSort.NAME;
      settings.sortAscending = true;
      model.recompute(settings);
      expect(model.rows.length).assertEqual(1);
      expect(model.rows[0].id).assertEqual(2);
      expect(model.count(TorrentFilter.ALL)).assertEqual(3);
      expect(model.count(TorrentFilter.SEEDING)).assertEqual(1);
    });

    it('totals the transfer rates across every torrent', () => {
      const model = seededModel();
      expect(model.totalDownloadRate).assertEqual(300);
      expect(model.totalUploadRate).assertEqual(30);
    });

    it('reports whether anything is moving', () => {
      const model = new TorrentListModel();

      model.torrents = [stopped(1, 0)];
      expect(model.hasActiveTorrents).assertFalse();

      model.torrents = [downloading(1, 0)];
      expect(model.hasActiveTorrents).assertTrue();

      // A recheck is slow and worth polling for, even though it is not a
      // download.
      model.torrents = [makeTorrent(2, 'v', TorrentStatus.VERIFYING, 0.5, 1)];
      expect(model.hasActiveTorrents).assertTrue();

      // Seeding is not: nothing on screen moves.
      model.torrents = [seeding(3, 2)];
      expect(model.hasActiveTorrents).assertFalse();
    });

    it('starts empty', () => {
      const model = new TorrentListModel();
      expect(model.rows.length).assertEqual(0);
      expect(model.totalDownloadRate).assertEqual(0);
      expect(model.count(TorrentFilter.ALL)).assertEqual(0);
    });
  });
}
