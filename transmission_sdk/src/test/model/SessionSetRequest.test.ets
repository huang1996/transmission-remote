// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for the generated `session_set` request builder.
 *
 * Every setter must emit exactly one canonical snake_case key, and it must do
 * so even when the value is an empty string, `false` or `0`: Transmission treats
 * a present key as an instruction and an absent key as "leave it alone", so
 * dropping a falsy value would silently ignore the caller.
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { Json } from '../../main/ets/util/Json';
import { SessionSetRequest } from '../../main/ets/model/SessionSetRequest';
import { EncryptionMode, TransportProtocol } from '../../main/ets/model/Enums';

export default function sessionSetRequestTest(): void {
  describe('SessionSetRequest wire shape', () => {
    it('serialises a fresh request to an empty object', () => {
      const request = new SessionSetRequest();
      expect(request.hasChanges).assertFalse();
      expect(request.size).assertEqual(0);
      expect(Json.isEmpty(request.toJson())).assertTrue();
      expect(Json.keys(request.toJson()).length).assertEqual(0);
    });

    it('emits exactly one canonical key for the spot-checked setters', () => {
      const download = new SessionSetRequest().downloadDir('/srv/media').toJson();
      expect(Json.keys(download).length).assertEqual(1);
      expect(Json.getString(download, 'download_dir')).assertEqual('/srv/media');

      const limit = new SessionSetRequest().speedLimitDown(2048).toJson();
      expect(Json.keys(limit).length).assertEqual(1);
      expect(Json.getNumber(limit, 'speed_limit_down')).assertEqual(2048);

      const sequential = new SessionSetRequest().sequentialDownload(true).toJson();
      expect(Json.keys(sequential).length).assertEqual(1);
      expect(Json.getBoolean(sequential, 'sequential_download')).assertTrue();

      const encryption = new SessionSetRequest().encryption(EncryptionMode.REQUIRED).toJson();
      expect(Json.keys(encryption).length).assertEqual(1);
      expect(Json.getString(encryption, 'encryption')).assertEqual('required');

      const transports = new SessionSetRequest()
        .preferredTransports([TransportProtocol.UTP, TransportProtocol.TCP])
        .toJson();
      expect(Json.keys(transports).length).assertEqual(1);
      expect(Json.getArray(transports, 'preferred_transports')).assertDeepEquals(['utp', 'tcp']);
    });

    it('maps each enum constant onto its documented wire string', () => {
      const required = new SessionSetRequest().encryption(EncryptionMode.REQUIRED).toJson();
      const preferred = new SessionSetRequest().encryption(EncryptionMode.PREFERRED).toJson();
      const allowed = new SessionSetRequest().encryption(EncryptionMode.ALLOWED).toJson();
      expect(Json.getString(required, 'encryption')).assertEqual('required');
      expect(Json.getString(preferred, 'encryption')).assertEqual('preferred');
      expect(Json.getString(allowed, 'encryption')).assertEqual('allowed');
    });

    it('sends preferred_transports as an ordered array of strings', () => {
      const json = new SessionSetRequest()
        .preferredTransports([TransportProtocol.TCP, TransportProtocol.UTP])
        .toJson();
      const array = Json.getArray(json, 'preferred_transports');
      expect(array).assertDeepEquals(['tcp', 'utp']);
      expect(array?.length).assertEqual(2);
    });

    it('sends an empty preferred_transports array rather than dropping the key', () => {
      const json = new SessionSetRequest().preferredTransports([]).toJson();
      expect(Json.has(json, 'preferred_transports')).assertTrue();
      expect(Json.getArray(json, 'preferred_transports')?.length).assertEqual(0);
    });

    it('keeps empty strings, false and zero because presence is the instruction', () => {
      const json = new SessionSetRequest().downloadDir('').dhtEnabled(false).peerPort(0).toJson();
      expect(Json.keys(json).length).assertEqual(3);
      expect(Json.has(json, 'download_dir')).assertTrue();
      expect(Json.getString(json, 'download_dir')).assertEqual('');
      expect(Json.has(json, 'dht_enabled')).assertTrue();
      expect(Json.getBoolean(json, 'dht_enabled')).assertFalse();
      expect(Json.has(json, 'peer_port')).assertTrue();
      expect(Json.getNumber(json, 'peer_port')).assertEqual(0);
    });

    it('puts the whole spot-checked sample under its canonical keys', () => {
      const request = new SessionSetRequest()
        .altSpeedDown(100)
        .altSpeedEnabled(true)
        .altSpeedTimeBegin(540)
        .altSpeedTimeDay(7)
        .altSpeedTimeEnd(1020)
        .altSpeedUp(50)
        .antiBruteForceEnabled(true)
        .blocklistEnabled(false)
        .blocklistUrl('https://example/blocklist')
        .defaultTrackers('https://tracker/announce')
        .dhtEnabled(true)
        .downloadQueueEnabled(true)
        .downloadQueueSize(5)
        .idleSeedingLimit(30)
        .idleSeedingLimitEnabled(true)
        .incompleteDir('/srv/incomplete')
        .incompleteDirEnabled(true)
        .lpdEnabled(true)
        .peerLimitGlobal(200)
        .peerLimitPerTorrent(50)
        .peerPortRandomOnStart(true)
        .peerPort(51413)
        .pexEnabled(true)
        .portForwardingEnabled(true)
        .queueStalledEnabled(true)
        .queueStalledMinutes(10)
        .renamePartialFiles(true)
        .reqq(500)
        .scriptTorrentAddedEnabled(true)
        .scriptTorrentAddedFilename('/bin/added')
        .scriptTorrentDoneEnabled(true)
        .scriptTorrentDoneFilename('/bin/done')
        .scriptTorrentDoneSeedingEnabled(true)
        .scriptTorrentDoneSeedingFilename('/bin/done-seeding')
        .seedQueueEnabled(true)
        .seedQueueSize(3)
        .seedRatioLimit(2.5)
        .seedRatioLimited(true)
        .speedLimitDownEnabled(true)
        .speedLimitUp(512)
        .speedLimitUpEnabled(true)
        .startAddedTorrents(true)
        .trashOriginalTorrentFiles(true);
      const json = request.toJson();
      expect(request.size).assertEqual(43);
      expect(Json.keys(json).length).assertEqual(43);
      expect(Json.getNumber(json, 'alt_speed_down')).assertEqual(100);
      expect(Json.getBoolean(json, 'alt_speed_enabled')).assertTrue();
      expect(Json.getNumber(json, 'alt_speed_time_begin')).assertEqual(540);
      expect(Json.getNumber(json, 'alt_speed_time_day')).assertEqual(7);
      expect(Json.getNumber(json, 'alt_speed_time_end')).assertEqual(1020);
      expect(Json.getNumber(json, 'alt_speed_up')).assertEqual(50);
      expect(Json.getBoolean(json, 'anti_brute_force_enabled')).assertTrue();
      expect(Json.has(json, 'blocklist_enabled')).assertTrue();
      expect(Json.getBoolean(json, 'blocklist_enabled')).assertFalse();
      expect(Json.getString(json, 'blocklist_url')).assertEqual('https://example/blocklist');
      expect(Json.getString(json, 'default_trackers')).assertEqual('https://tracker/announce');
      expect(Json.getBoolean(json, 'dht_enabled')).assertTrue();
      expect(Json.getBoolean(json, 'download_queue_enabled')).assertTrue();
      expect(Json.getNumber(json, 'download_queue_size')).assertEqual(5);
      expect(Json.getNumber(json, 'idle_seeding_limit')).assertEqual(30);
      expect(Json.getBoolean(json, 'idle_seeding_limit_enabled')).assertTrue();
      expect(Json.getString(json, 'incomplete_dir')).assertEqual('/srv/incomplete');
      expect(Json.getBoolean(json, 'incomplete_dir_enabled')).assertTrue();
      expect(Json.getBoolean(json, 'lpd_enabled')).assertTrue();
      expect(Json.getNumber(json, 'peer_limit_global')).assertEqual(200);
      expect(Json.getNumber(json, 'peer_limit_per_torrent')).assertEqual(50);
      expect(Json.getBoolean(json, 'peer_port_random_on_start')).assertTrue();
      expect(Json.getNumber(json, 'peer_port')).assertEqual(51413);
      expect(Json.getBoolean(json, 'pex_enabled')).assertTrue();
      expect(Json.getBoolean(json, 'port_forwarding_enabled')).assertTrue();
      expect(Json.getBoolean(json, 'queue_stalled_enabled')).assertTrue();
      expect(Json.getNumber(json, 'queue_stalled_minutes')).assertEqual(10);
      expect(Json.getBoolean(json, 'rename_partial_files')).assertTrue();
      expect(Json.getNumber(json, 'reqq')).assertEqual(500);
      expect(Json.getBoolean(json, 'script_torrent_added_enabled')).assertTrue();
      expect(Json.getString(json, 'script_torrent_added_filename')).assertEqual('/bin/added');
      expect(Json.getBoolean(json, 'script_torrent_done_enabled')).assertTrue();
      expect(Json.getString(json, 'script_torrent_done_filename')).assertEqual('/bin/done');
      expect(Json.getBoolean(json, 'script_torrent_done_seeding_enabled')).assertTrue();
      expect(Json.getString(json, 'script_torrent_done_seeding_filename')).assertEqual('/bin/done-seeding');
      expect(Json.getBoolean(json, 'seed_queue_enabled')).assertTrue();
      expect(Json.getNumber(json, 'seed_queue_size')).assertEqual(3);
      expect(Json.getNumber(json, 'seed_ratio_limit')).assertEqual(2.5);
      expect(Json.getBoolean(json, 'seed_ratio_limited')).assertTrue();
      expect(Json.getBoolean(json, 'speed_limit_down_enabled')).assertTrue();
      expect(Json.getNumber(json, 'speed_limit_up')).assertEqual(512);
      expect(Json.getBoolean(json, 'speed_limit_up_enabled')).assertTrue();
      expect(Json.getBoolean(json, 'start_added_torrents')).assertTrue();
      expect(Json.getBoolean(json, 'trash_original_torrent_files')).assertTrue();
    });
  });

  describe('SessionSetRequest bookkeeping', () => {
    it('reports one change per distinct key', () => {
      const request = new SessionSetRequest();
      expect(request.hasChanges).assertFalse();
      expect(request.size).assertEqual(0);
      request.downloadDir('/srv/media');
      expect(request.hasChanges).assertTrue();
      expect(request.size).assertEqual(1);
      request.speedLimitDown(100);
      expect(request.size).assertEqual(2);
    });

    it('does not grow when a key is overwritten', () => {
      const request = new SessionSetRequest().downloadDir('/first').downloadDir('/second');
      expect(request.size).assertEqual(1);
      expect(Json.getString(request.toJson(), 'download_dir')).assertEqual('/second');
    });

    it('supports raw keys as an escape hatch', () => {
      const json = new SessionSetRequest().setRaw('some_future_option', 42).toJson();
      expect(Json.keys(json).length).assertEqual(1);
      expect(Json.getNumber(json, 'some_future_option')).assertEqual(42);
    });

    it('lets setRaw override a typed setter for the same key', () => {
      const request = new SessionSetRequest().speedLimitDown(100).setRaw('speed_limit_down', 200);
      expect(request.size).assertEqual(1);
      expect(Json.getNumber(request.toJson(), 'speed_limit_down')).assertEqual(200);
    });

    it('returns the same instance from every setter so calls can be chained', () => {
      const request = new SessionSetRequest();
      expect(request.downloadDir('/srv/media') === request).assertTrue();
      expect(request.speedLimitDown(100) === request).assertTrue();
      expect(request.encryption(EncryptionMode.ALLOWED) === request).assertTrue();
      expect(request.sequentialDownload(true) === request).assertTrue();
      expect(request.preferredTransports([TransportProtocol.UTP]) === request).assertTrue();
      expect(request.setRaw('custom', true) === request).assertTrue();
      expect(request.size).assertEqual(6);
    });

    it('copies the transports array instead of aliasing the caller', () => {
      const transports: TransportProtocol[] = [TransportProtocol.UTP];
      const request = new SessionSetRequest().preferredTransports(transports);
      transports.push(TransportProtocol.TCP);
      expect(Json.getArray(request.toJson(), 'preferred_transports')).assertDeepEquals(['utp']);
    });
  });
}
