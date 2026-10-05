// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for {@link Torrent} and its nested collections.
 *
 * The payloads pinned down here use the canonical snake_case keys of
 * Transmission 4.1+ (RPC 6.0.0 / JSON-RPC 2.0). Two pieces of legacy wire
 * behaviour are covered explicitly: the `wanted` array may arrive as booleans
 * (modern) or `0`/`1` numbers (legacy), and malformed array entries must be
 * skipped rather than crash the parser.
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { Json, JsonArray, JsonObject } from '../../main/ets/util/Json';
import {
  Peer,
  PeerSources,
  Torrent,
  TorrentFile,
  TorrentFileStat,
  Tracker,
  TrackerStat,
  Webseed,
} from '../../main/ets/model/Torrent';
import {
  FilePriority,
  IdleLimitMode,
  RatioLimitMode,
  TorrentPriority,
  TorrentStatus,
} from '../../main/ets/model/Enums';

/** One canonical `files` entry. */
function fileJson(): JsonObject {
  const file: JsonObject = {};
  file['name'] = 'ubuntu.iso';
  file['length'] = 2048;
  file['bytes_completed'] = 1024;
  file['begin_piece'] = 2;
  file['end_piece'] = 15;
  return file;
}

/** One canonical `file_stats` entry. */
function fileStatJson(): JsonObject {
  const stat: JsonObject = {};
  stat['bytes_completed'] = 1000;
  stat['wanted'] = true;
  stat['priority'] = 1;
  return stat;
}

/** One canonical `peers` entry. */
function peerJson(): JsonObject {
  const peer: JsonObject = {};
  peer['address'] = '1.2.3.4:51413';
  peer['peer_id'] = '-TR4000-abcdefghijkl';
  peer['client_name'] = 'Transmission 4.0';
  peer['port'] = 51413;
  peer['bytes_to_peer'] = 10;
  peer['bytes_to_client'] = 20;
  peer['rate_to_peer'] = 1;
  peer['rate_to_client'] = 2;
  peer['progress'] = 0.5;
  peer['flag_str'] = 'UE';
  peer['client_is_choked'] = false;
  peer['client_is_interested'] = true;
  peer['peer_is_choked'] = true;
  peer['peer_is_interested'] = false;
  peer['is_downloading_from'] = true;
  peer['is_uploading_to'] = false;
  peer['is_encrypted'] = true;
  peer['is_incoming'] = false;
  peer['is_utp'] = true;
  peer['supports_holepunch'] = false;
  return peer;
}

/** One canonical `peers_from` object. */
function peersFromJson(): JsonObject {
  const sources: JsonObject = {};
  sources['from_cache'] = 1;
  sources['from_dht'] = 2;
  sources['from_holepunch'] = 3;
  sources['from_incoming'] = 4;
  sources['from_lpd'] = 5;
  sources['from_ltep'] = 6;
  sources['from_pex'] = 7;
  sources['from_tracker'] = 8;
  return sources;
}

/** One canonical `trackers` entry. */
function trackerJson(): JsonObject {
  const tracker: JsonObject = {};
  tracker['id'] = 3;
  tracker['announce'] = 'https://tracker.example/announce';
  tracker['scrape'] = 'https://tracker.example/scrape';
  tracker['sitename'] = 'Example';
  tracker['tier'] = 1;
  return tracker;
}

/** One canonical `tracker_stats` entry. */
function trackerStatJson(): JsonObject {
  const stat: JsonObject = {};
  stat['id'] = 3;
  stat['announce'] = 'https://tracker.example/announce';
  stat['scrape'] = 'https://tracker.example/scrape';
  stat['host'] = 'tracker.example';
  stat['sitename'] = 'Example';
  stat['tier'] = 1;
  stat['is_backup'] = true;
  stat['announce_state'] = 3;
  stat['scrape_state'] = 1;
  stat['has_announced'] = true;
  stat['has_scraped'] = false;
  stat['last_announce_time'] = 100;
  stat['last_announce_start_time'] = 101;
  stat['last_announce_succeeded'] = true;
  stat['last_announce_timed_out'] = false;
  stat['last_announce_result'] = 'success';
  stat['last_announce_peer_count'] = 9;
  stat['last_scrape_time'] = 200;
  stat['last_scrape_start_time'] = 201;
  stat['last_scrape_succeeded'] = true;
  stat['last_scrape_timed_out'] = false;
  stat['last_scrape_result'] = 'ok';
  stat['next_announce_time'] = 300;
  stat['next_scrape_time'] = 301;
  stat['seeder_count'] = 11;
  stat['leecher_count'] = 12;
  stat['download_count'] = 13;
  return stat;
}

/** One canonical `webseeds_ex` entry. */
function webseedJson(): JsonObject {
  const webseed: JsonObject = {};
  webseed['url'] = 'https://mirror.example/';
  webseed['is_downloading'] = true;
  webseed['download_bytes_per_second'] = 4096;
  return webseed;
}

/** A torrent payload that exercises every group of canonical keys. */
function fullTorrentJson(): JsonObject {
  const json: JsonObject = {};
  json['id'] = 42;
  json['hash_string'] = 'abcdef0123456789';
  json['name'] = 'Ubuntu ISO';
  json['comment'] = 'a comment';
  json['creator'] = 'mktorrent';
  json['magnet_link'] = 'magnet:?xt=urn:btih:abcdef0123456789';
  json['torrent_file'] = 'YmFzZTY0YmxvYg==';
  json['primary_mime_type'] = 'application/x-bittorrent';
  json['download_dir'] = '/srv/media';
  json['group'] = 'media';
  json['labels'] = ['linux', 'iso'] as JsonArray;

  json['activity_date'] = 1600000007;
  json['added_date'] = 1600000001;
  json['date_created'] = 1600000002;
  json['edit_date'] = 1600000003;
  json['done_date'] = 1600000004;
  json['start_date'] = 1600000005;
  json['manual_announce_time'] = 1600000006;

  json['status'] = 4;
  json['error'] = 3;
  json['error_string'] = 'tracker not responding';
  json['is_finished'] = true;
  json['is_private'] = true;
  json['is_stalled'] = false;
  json['bandwidth_priority'] = 1;

  json['total_size'] = 4096;
  json['left_until_done'] = 1024;
  json['size_when_done'] = 4096;
  json['downloaded_ever'] = 3072;
  json['uploaded_ever'] = 2048;
  json['have_valid'] = 3000;
  json['have_unchecked'] = 72;
  json['corrupt_ever'] = 24;
  json['desired_available'] = 512;

  json['percent_done'] = 0.75;
  json['percent_complete'] = 0.8;
  json['metadata_percent_complete'] = 1;
  json['recheck_progress'] = 0.25;
  json['upload_ratio'] = 0.66;

  json['rate_download'] = 1024;
  json['rate_upload'] = 128;
  json['eta'] = 3600;
  json['eta_idle'] = 60;
  json['seconds_downloading'] = 7200;
  json['seconds_seeding'] = 1800;

  json['peers_connected'] = 12;
  json['max_connected_peers'] = 50;
  json['peer_limit'] = 40;
  json['peers_getting_from_us'] = 3;
  json['peers_sending_to_us'] = 4;
  json['webseeds_sending_to_us'] = 1;
  json['peers_from'] = peersFromJson();
  json['peers'] = [peerJson()] as JsonArray;

  json['download_limit'] = 2048;
  json['download_limited'] = true;
  json['upload_limit'] = 512;
  json['upload_limited'] = false;
  json['honors_session_limits'] = true;

  json['seed_idle_limit'] = 30;
  json['seed_idle_mode'] = 1;
  json['seed_ratio_limit'] = 2.5;
  json['seed_ratio_mode'] = 2;

  json['queue_position'] = 7;
  json['sequential_download'] = true;
  json['sequential_download_from_piece'] = 5;

  json['file_count'] = 1;
  json['files'] = [fileJson()] as JsonArray;
  json['file_stats'] = [fileStatJson()] as JsonArray;

  json['piece_count'] = 16;
  json['piece_size'] = 256;
  json['pieces'] = 'AAECAwQ=';
  json['availability'] = [1, 2, 3] as JsonArray;
  json['bytes_completed'] = [1, 2, 3] as JsonArray;
  json['wanted'] = [true, false, true] as JsonArray;
  json['priorities'] = [1, 0, -1] as JsonArray;

  json['trackers'] = [trackerJson()] as JsonArray;
  json['tracker_list'] = 'https://tracker.example/announce';
  json['tracker_stats'] = [trackerStatJson()] as JsonArray;
  json['webseeds'] = ['https://legacy.example/'] as JsonArray;
  json['webseeds_ex'] = [webseedJson()] as JsonArray;
  return json;
}

export default function torrentTest(): void {
  describe('Torrent.fromJson scalar fields', () => {
    it('reads the identity, metainfo and label fields', () => {
      const torrent = Torrent.fromJson(fullTorrentJson());
      expect(torrent.id).assertEqual(42);
      expect(torrent.hashString).assertEqual('abcdef0123456789');
      expect(torrent.name).assertEqual('Ubuntu ISO');
      expect(torrent.comment).assertEqual('a comment');
      expect(torrent.creator).assertEqual('mktorrent');
      expect(torrent.magnetLink).assertEqual('magnet:?xt=urn:btih:abcdef0123456789');
      expect(torrent.torrentFile).assertEqual('YmFzZTY0YmxvYg==');
      expect(torrent.primaryMimeType).assertEqual('application/x-bittorrent');
      expect(torrent.downloadDir).assertEqual('/srv/media');
      expect(torrent.group).assertEqual('media');
      expect(torrent.labels).assertDeepEquals(['linux', 'iso']);
    });

    it('reads every timestamp field', () => {
      const torrent = Torrent.fromJson(fullTorrentJson());
      expect(torrent.activityDate).assertEqual(1600000007);
      expect(torrent.addedDate).assertEqual(1600000001);
      expect(torrent.dateCreated).assertEqual(1600000002);
      expect(torrent.editDate).assertEqual(1600000003);
      expect(torrent.doneDate).assertEqual(1600000004);
      expect(torrent.startDate).assertEqual(1600000005);
      expect(torrent.manualAnnounceTime).assertEqual(1600000006);
    });

    it('reads the status, error and flag fields', () => {
      const torrent = Torrent.fromJson(fullTorrentJson());
      expect(torrent.status).assertEqual(TorrentStatus.DOWNLOADING);
      expect(torrent.error).assertEqual(3);
      expect(torrent.errorString).assertEqual('tracker not responding');
      expect(torrent.isFinished).assertTrue();
      expect(torrent.isPrivate).assertTrue();
      expect(torrent.isStalled).assertFalse();
      expect(torrent.bandwidthPriority).assertEqual(TorrentPriority.HIGH);
    });

    it('reads the size and progress counters', () => {
      const torrent = Torrent.fromJson(fullTorrentJson());
      expect(torrent.totalSize).assertEqual(4096);
      expect(torrent.leftUntilDone).assertEqual(1024);
      expect(torrent.sizeWhenDone).assertEqual(4096);
      expect(torrent.downloadedEver).assertEqual(3072);
      expect(torrent.uploadedEver).assertEqual(2048);
      expect(torrent.haveValid).assertEqual(3000);
      expect(torrent.haveUnchecked).assertEqual(72);
      expect(torrent.corruptEver).assertEqual(24);
      expect(torrent.desiredAvailable).assertEqual(512);
      expect(torrent.percentDone).assertEqual(0.75);
      expect(torrent.percentComplete).assertEqual(0.8);
      expect(torrent.metadataPercentComplete).assertEqual(1);
      expect(torrent.recheckProgress).assertEqual(0.25);
      expect(torrent.uploadRatio).assertEqual(0.66);
    });

    it('reads the rate, ETA and duration fields', () => {
      const torrent = Torrent.fromJson(fullTorrentJson());
      expect(torrent.rateDownload).assertEqual(1024);
      expect(torrent.rateUpload).assertEqual(128);
      expect(torrent.eta).assertEqual(3600);
      expect(torrent.etaIdle).assertEqual(60);
      expect(torrent.secondsDownloading).assertEqual(7200);
      expect(torrent.secondsSeeding).assertEqual(1800);
    });

    it('reads the peer counters and the nested peers_from object', () => {
      const torrent = Torrent.fromJson(fullTorrentJson());
      expect(torrent.peersConnected).assertEqual(12);
      expect(torrent.maxConnectedPeers).assertEqual(50);
      expect(torrent.peerLimit).assertEqual(40);
      expect(torrent.peersGettingFromUs).assertEqual(3);
      expect(torrent.peersSendingToUs).assertEqual(4);
      expect(torrent.webseedsSendingToUs).assertEqual(1);
      expect(torrent.peersFrom.fromCache).assertEqual(1);
      expect(torrent.peersFrom.fromDht).assertEqual(2);
      expect(torrent.peersFrom.fromHolepunch).assertEqual(3);
      expect(torrent.peersFrom.fromIncoming).assertEqual(4);
      expect(torrent.peersFrom.fromLpd).assertEqual(5);
      expect(torrent.peersFrom.fromLtep).assertEqual(6);
      expect(torrent.peersFrom.fromPex).assertEqual(7);
      expect(torrent.peersFrom.fromTracker).assertEqual(8);
      expect(torrent.peersFrom.total).assertEqual(36);
    });

    it('reads the speed limits and seeding limit fields', () => {
      const torrent = Torrent.fromJson(fullTorrentJson());
      expect(torrent.downloadLimit).assertEqual(2048);
      expect(torrent.downloadLimited).assertTrue();
      expect(torrent.uploadLimit).assertEqual(512);
      expect(torrent.uploadLimited).assertFalse();
      expect(torrent.honorsSessionLimits).assertTrue();
      expect(torrent.seedIdleLimit).assertEqual(30);
      expect(torrent.seedIdleMode).assertEqual(IdleLimitMode.SINGLE);
      expect(torrent.seedRatioLimit).assertEqual(2.5);
      expect(torrent.seedRatioMode).assertEqual(RatioLimitMode.UNLIMITED);
    });

    it('reads the queue position and sequential-download fields', () => {
      const torrent = Torrent.fromJson(fullTorrentJson());
      expect(torrent.queuePosition).assertEqual(7);
      expect(torrent.sequentialDownload).assertTrue();
      expect(torrent.sequentialDownloadFromPiece).assertEqual(5);
    });

    it('reads the file and piece bookkeeping fields', () => {
      const torrent = Torrent.fromJson(fullTorrentJson());
      expect(torrent.fileCount).assertEqual(1);
      expect(torrent.pieceCount).assertEqual(16);
      expect(torrent.pieceSize).assertEqual(256);
      expect(torrent.pieces).assertEqual('AAECAwQ=');
      expect(torrent.availability).assertDeepEquals([1, 2, 3]);
      expect(torrent.bytesCompleted).assertDeepEquals([1, 2, 3]);
      expect(torrent.wanted).assertDeepEquals([true, false, true]);
      expect(torrent.priorities).assertDeepEquals([1, 0, -1]);
    });

    it('reads the deprecated webseeds list and the tracker list', () => {
      const torrent = Torrent.fromJson(fullTorrentJson());
      expect(torrent.trackerList).assertEqual('https://tracker.example/announce');
      expect(torrent.webseeds).assertDeepEquals(['https://legacy.example/']);
    });
  });

  describe('Torrent.fromJson nested collections', () => {
    it('parses files into TorrentFile instances', () => {
      const torrent = Torrent.fromJson(fullTorrentJson());
      expect(torrent.files.length).assertEqual(1);
      expect(torrent.files[0]).assertInstanceOf(TorrentFile);
      expect(torrent.files[0].name).assertEqual('ubuntu.iso');
      expect(torrent.files[0].length).assertEqual(2048);
      expect(torrent.files[0].bytesCompleted).assertEqual(1024);
      expect(torrent.files[0].beginPiece).assertEqual(2);
      expect(torrent.files[0].endPiece).assertEqual(15);
    });

    it('parses file_stats into TorrentFileStat instances', () => {
      const torrent = Torrent.fromJson(fullTorrentJson());
      expect(torrent.fileStats.length).assertEqual(1);
      expect(torrent.fileStats[0]).assertInstanceOf(TorrentFileStat);
      expect(torrent.fileStats[0].bytesCompleted).assertEqual(1000);
      expect(torrent.fileStats[0].wanted).assertTrue();
      expect(torrent.fileStats[0].priority).assertEqual(FilePriority.HIGH);
    });

    it('parses peers into Peer instances', () => {
      const torrent = Torrent.fromJson(fullTorrentJson());
      expect(torrent.peers.length).assertEqual(1);
      expect(torrent.peers[0]).assertInstanceOf(Peer);
      expect(torrent.peers[0].address).assertEqual('1.2.3.4:51413');
      expect(torrent.peers[0].peerId).assertEqual('-TR4000-abcdefghijkl');
      expect(torrent.peers[0].clientName).assertEqual('Transmission 4.0');
      expect(torrent.peers[0].port).assertEqual(51413);
      expect(torrent.peers[0].bytesToPeer).assertEqual(10);
      expect(torrent.peers[0].bytesToClient).assertEqual(20);
      expect(torrent.peers[0].rateToPeer).assertEqual(1);
      expect(torrent.peers[0].rateToClient).assertEqual(2);
      expect(torrent.peers[0].progress).assertEqual(0.5);
      expect(torrent.peers[0].flagStr).assertEqual('UE');
      expect(torrent.peers[0].clientIsChoked).assertFalse();
      expect(torrent.peers[0].clientIsInterested).assertTrue();
      expect(torrent.peers[0].peerIsChoked).assertTrue();
      expect(torrent.peers[0].peerIsInterested).assertFalse();
      expect(torrent.peers[0].isDownloadingFrom).assertTrue();
      expect(torrent.peers[0].isUploadingTo).assertFalse();
      expect(torrent.peers[0].isEncrypted).assertTrue();
      expect(torrent.peers[0].isIncoming).assertFalse();
      expect(torrent.peers[0].isUtp).assertTrue();
      expect(torrent.peers[0].supportsHolepunch).assertFalse();
    });

    it('parses trackers into Tracker instances', () => {
      const torrent = Torrent.fromJson(fullTorrentJson());
      expect(torrent.trackers.length).assertEqual(1);
      expect(torrent.trackers[0]).assertInstanceOf(Tracker);
      expect(torrent.trackers[0].id).assertEqual(3);
      expect(torrent.trackers[0].announce).assertEqual('https://tracker.example/announce');
      expect(torrent.trackers[0].scrape).assertEqual('https://tracker.example/scrape');
      expect(torrent.trackers[0].siteName).assertEqual('Example');
      expect(torrent.trackers[0].tier).assertEqual(1);
    });

    it('parses tracker_stats into TrackerStat instances', () => {
      const torrent = Torrent.fromJson(fullTorrentJson());
      expect(torrent.trackerStats.length).assertEqual(1);
      expect(torrent.trackerStats[0]).assertInstanceOf(TrackerStat);
      const stat = torrent.trackerStats[0];
      expect(stat.id).assertEqual(3);
      expect(stat.host).assertEqual('tracker.example');
      expect(stat.siteName).assertEqual('Example');
      expect(stat.tier).assertEqual(1);
      expect(stat.isBackup).assertTrue();
      expect(stat.announceState).assertEqual(3);
      expect(stat.scrapeState).assertEqual(1);
      expect(stat.hasAnnounced).assertTrue();
      expect(stat.hasScraped).assertFalse();
      expect(stat.lastAnnounceTime).assertEqual(100);
      expect(stat.lastAnnounceStartTime).assertEqual(101);
      expect(stat.lastAnnounceSucceeded).assertTrue();
      expect(stat.lastAnnounceTimedOut).assertFalse();
      expect(stat.lastAnnounceResult).assertEqual('success');
      expect(stat.lastAnnouncePeerCount).assertEqual(9);
      expect(stat.lastScrapeTime).assertEqual(200);
      expect(stat.lastScrapeStartTime).assertEqual(201);
      expect(stat.lastScrapeSucceeded).assertTrue();
      expect(stat.lastScrapeTimedOut).assertFalse();
      expect(stat.lastScrapeResult).assertEqual('ok');
      expect(stat.nextAnnounceTime).assertEqual(300);
      expect(stat.nextScrapeTime).assertEqual(301);
      expect(stat.seederCount).assertEqual(11);
      expect(stat.leecherCount).assertEqual(12);
      expect(stat.downloadCount).assertEqual(13);
    });

    it('parses webseeds_ex into Webseed instances', () => {
      const torrent = Torrent.fromJson(fullTorrentJson());
      expect(torrent.webseedsEx.length).assertEqual(1);
      expect(torrent.webseedsEx[0]).assertInstanceOf(Webseed);
      expect(torrent.webseedsEx[0].url).assertEqual('https://mirror.example/');
      expect(torrent.webseedsEx[0].isDownloading).assertTrue();
      expect(torrent.webseedsEx[0].downloadBytesPerSecond).assertEqual(4096);
    });
  });

  describe('Torrent.fromJson robustness', () => {
    it('returns a default instance when the payload is undefined', () => {
      const torrent = Torrent.fromJson(undefined);
      expect(torrent.id).assertEqual(0);
      expect(torrent.name).assertEqual('');
      expect(torrent.status).assertEqual(TorrentStatus.STOPPED);
      expect(torrent.bandwidthPriority).assertEqual(TorrentPriority.NORMAL);
      expect(torrent.seedIdleMode).assertEqual(IdleLimitMode.GLOBAL);
      expect(torrent.seedRatioMode).assertEqual(RatioLimitMode.GLOBAL);
      expect(torrent.eta).assertEqual(-1);
      expect(torrent.etaIdle).assertEqual(-1);
      expect(torrent.labels.length).assertEqual(0);
      expect(torrent.files.length).assertEqual(0);
      expect(torrent.fileStats.length).assertEqual(0);
      expect(torrent.peers.length).assertEqual(0);
      expect(torrent.trackers.length).assertEqual(0);
      expect(torrent.trackerStats.length).assertEqual(0);
      expect(torrent.webseedsEx.length).assertEqual(0);
      expect(torrent.peersFrom.total).assertEqual(0);
    });

    it('ignores keys the model does not know about', () => {
      const json = fullTorrentJson();
      json['a_future_transmission_field'] = 'surprise';
      json['another_one'] = 123;
      const torrent = Torrent.fromJson(json);
      expect(torrent.id).assertEqual(42);
      expect(torrent.name).assertEqual('Ubuntu ISO');
    });

    it('treats the legacy 1/0 wanted encoding exactly like booleans', () => {
      const modern: JsonObject = {};
      modern['wanted'] = [true, false, true] as JsonArray;
      const legacy: JsonObject = {};
      legacy['wanted'] = [1, 0, 1] as JsonArray;
      expect(Torrent.fromJson(modern).wanted).assertDeepEquals([true, false, true]);
      expect(Torrent.fromJson(legacy).wanted).assertDeepEquals([true, false, true]);
    });

    it('skips non-object entries in every nested collection', () => {
      const json: JsonObject = {};
      json['files'] = [fileJson(), 5, 'nope', null] as JsonArray;
      json['file_stats'] = [fileStatJson(), 7] as JsonArray;
      json['peers'] = [peerJson(), 9] as JsonArray;
      json['trackers'] = [trackerJson(), false] as JsonArray;
      json['tracker_stats'] = [trackerStatJson(), 11] as JsonArray;
      json['webseeds_ex'] = [webseedJson(), 13] as JsonArray;
      const torrent = Torrent.fromJson(json);
      expect(torrent.files.length).assertEqual(1);
      expect(torrent.fileStats.length).assertEqual(1);
      expect(torrent.peers.length).assertEqual(1);
      expect(torrent.trackers.length).assertEqual(1);
      expect(torrent.trackerStats.length).assertEqual(1);
      expect(torrent.webseedsEx.length).assertEqual(1);
      expect(torrent.files[0].name).assertEqual('ubuntu.iso');
    });

    it('falls back to defaults when peers_from is not an object', () => {
      const json: JsonObject = {};
      json['peers_from'] = 5;
      const sources: PeerSources = Torrent.fromJson(json).peersFrom;
      expect(sources.total).assertEqual(0);
      expect(sources.fromTracker).assertEqual(0);
    });
  });

  describe('Torrent enum mapping', () => {
    it('maps status numbers onto TorrentStatus', () => {
      const downloading: JsonObject = {};
      downloading['status'] = 4;
      const seeding: JsonObject = {};
      seeding['status'] = 6;
      const stopped: JsonObject = {};
      stopped['status'] = 0;
      expect(Torrent.fromJson(downloading).status).assertEqual(TorrentStatus.DOWNLOADING);
      expect(Torrent.fromJson(seeding).status).assertEqual(TorrentStatus.SEEDING);
      expect(Torrent.fromJson(stopped).status).assertEqual(TorrentStatus.STOPPED);
    });

    it('maps priority and limit-mode numbers onto their enums', () => {
      const json: JsonObject = {};
      json['bandwidth_priority'] = -1;
      json['seed_idle_mode'] = 2;
      json['seed_ratio_mode'] = 1;
      const stat: JsonObject = {};
      stat['priority'] = -1;
      json['file_stats'] = [stat] as JsonArray;
      const torrent = Torrent.fromJson(json);
      expect(torrent.bandwidthPriority).assertEqual(TorrentPriority.LOW);
      expect(torrent.seedIdleMode).assertEqual(IdleLimitMode.UNLIMITED);
      expect(torrent.seedRatioMode).assertEqual(RatioLimitMode.SINGLE);
      expect(torrent.fileStats[0].priority).assertEqual(FilePriority.LOW);
    });

    it('keeps the documented defaults when enum keys are absent', () => {
      const torrent = Torrent.fromJson(Json.emptyObject() as JsonObject);
      expect(torrent.status).assertEqual(TorrentStatus.STOPPED);
      expect(torrent.bandwidthPriority).assertEqual(TorrentPriority.NORMAL);
      expect(torrent.seedIdleMode).assertEqual(IdleLimitMode.GLOBAL);
      expect(torrent.seedRatioMode).assertEqual(RatioLimitMode.GLOBAL);
      expect(torrent.fileStats.length).assertEqual(0);
    });
  });

  describe('Torrent getters', () => {
    it('reports downloading and seeding as active', () => {
      const downloading: JsonObject = {};
      downloading['status'] = 4;
      const seeding: JsonObject = {};
      seeding['status'] = 6;
      const stopped: JsonObject = {};
      stopped['status'] = 0;
      expect(Torrent.fromJson(downloading).isActive).assertTrue();
      expect(Torrent.fromJson(seeding).isActive).assertTrue();
      expect(Torrent.fromJson(stopped).isActive).assertFalse();
    });

    it('reports complete once percent_done reaches one', () => {
      const complete: JsonObject = {};
      complete['percent_done'] = 1;
      const almost: JsonObject = {};
      almost['percent_done'] = 0.99;
      expect(Torrent.fromJson(complete).isComplete).assertTrue();
      expect(Torrent.fromJson(almost).isComplete).assertFalse();
    });

    it('sums both directions for totalRate', () => {
      const json: JsonObject = {};
      json['rate_download'] = 100;
      json['rate_upload'] = 50;
      expect(Torrent.fromJson(json).totalRate).assertEqual(150);
      expect(Torrent.fromJson(Json.emptyObject() as JsonObject).totalRate).assertEqual(0);
    });

    it('sums every peer source for PeerSources.total', () => {
      const sources: PeerSources = PeerSources.fromJson(peersFromJson());
      expect(sources.total).assertEqual(36);
    });
  });
}
