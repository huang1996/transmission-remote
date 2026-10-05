// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for the `session_get` model.
 *
 * The compatibility layer is responsible for normalising legacy keys before
 * this model sees them; what matters here is the canonical snake_case payload,
 * plus the two places where the model itself has to translate a wire value:
 * the `encryption` enum (legacy `"tolerated"`) and `preferred_transports`
 * (unknown transports must be dropped, not turned into garbage).
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { Json, JsonArray, JsonObject } from '../../main/ets/util/Json';
import {
  BlocklistInfo,
  SessionSettings,
  SessionUnits,
} from '../../main/ets/model/SessionSettings';
import { EncryptionMode, TransportProtocol } from '../../main/ets/model/Enums';

/** A `session_get` payload covering every group of canonical keys. */
function fullSettingsJson(): JsonObject {
  const units: JsonObject = {};
  units['speed_units'] = ['B/s', 'kB/s', 'MB/s'] as JsonArray;
  units['speed_bytes'] = 1000;
  units['size_units'] = ['B', 'kB', 'MB'] as JsonArray;
  units['size_bytes'] = 1000;
  units['memory_units'] = ['B', 'KiB', 'MiB'] as JsonArray;
  units['memory_bytes'] = 1024;

  const json: JsonObject = {};
  json['alt_speed_down'] = 100;
  json['alt_speed_enabled'] = true;
  json['alt_speed_time_begin'] = 540;
  json['alt_speed_time_day'] = 7;
  json['alt_speed_time_enabled'] = true;
  json['alt_speed_time_end'] = 1020;
  json['alt_speed_up'] = 50;
  json['anti_brute_force_enabled'] = true;
  json['blocklist_enabled'] = true;
  json['blocklist_size'] = 1234;
  json['blocklist_url'] = 'https://example/blocklist';
  json['cache_size_mib'] = 64;
  json['config_dir'] = '/etc/transmission';
  json['default_trackers'] = 'https://tracker/announce';
  json['dht_enabled'] = true;
  json['download_dir'] = '/srv/media';
  json['download_dir_free_space'] = 1024;
  json['download_queue_enabled'] = true;
  json['download_queue_size'] = 5;
  json['encryption'] = 'required';
  json['idle_seeding_limit'] = 30;
  json['idle_seeding_limit_enabled'] = true;
  json['incomplete_dir'] = '/srv/incomplete';
  json['incomplete_dir_enabled'] = true;
  json['lpd_enabled'] = true;
  json['peer_limit_global'] = 200;
  json['peer_limit_per_torrent'] = 50;
  json['peer_port_random_on_start'] = true;
  json['peer_port'] = 51413;
  json['pex_enabled'] = true;
  json['port_forwarding_enabled'] = true;
  json['preferred_transports'] = ['utp', 'tcp'] as JsonArray;
  json['queue_stalled_enabled'] = true;
  json['queue_stalled_minutes'] = 10;
  json['rename_partial_files'] = true;
  json['reqq'] = 500;
  json['rpc_version_minimum'] = 1;
  json['rpc_version_semver'] = '6.0.0';
  json['rpc_version'] = 18;
  json['script_torrent_added_enabled'] = true;
  json['script_torrent_added_filename'] = '/bin/added';
  json['script_torrent_done_enabled'] = true;
  json['script_torrent_done_filename'] = '/bin/done';
  json['script_torrent_done_seeding_enabled'] = true;
  json['script_torrent_done_seeding_filename'] = '/bin/done-seeding';
  json['seed_queue_enabled'] = true;
  json['seed_queue_size'] = 3;
  json['seed_ratio_limit'] = 2.5;
  json['seed_ratio_limited'] = true;
  json['sequential_download'] = true;
  json['session_id'] = 'session-1';
  json['speed_limit_down'] = 2048;
  json['speed_limit_down_enabled'] = true;
  json['speed_limit_up'] = 512;
  json['speed_limit_up_enabled'] = true;
  json['start_added_torrents'] = true;
  json['tcp_enabled'] = true;
  json['trash_original_torrent_files'] = true;
  json['units'] = units;
  json['utp_enabled'] = true;
  json['version'] = '4.1.0';
  return json;
}

/** A minimal payload carrying only an `encryption` string. */
function encryptionJson(value: string): JsonObject {
  const json: JsonObject = {};
  json['encryption'] = value;
  return json;
}

export default function sessionSettingsTest(): void {
  describe('SessionSettings.fromJson', () => {
    it('reads a representative full settings payload', () => {
      const settings = SessionSettings.fromJson(fullSettingsJson());
      expect(settings.altSpeedDown).assertEqual(100);
      expect(settings.altSpeedEnabled).assertTrue();
      expect(settings.altSpeedTimeBegin).assertEqual(540);
      expect(settings.altSpeedTimeDay).assertEqual(7);
      expect(settings.altSpeedTimeEnd).assertEqual(1020);
      expect(settings.altSpeedUp).assertEqual(50);
      expect(settings.antiBruteForceEnabled).assertTrue();
      expect(settings.blocklistEnabled).assertTrue();
      expect(settings.blocklistSize).assertEqual(1234);
      expect(settings.blocklistUrl).assertEqual('https://example/blocklist');
      expect(settings.configDir).assertEqual('/etc/transmission');
      expect(settings.defaultTrackers).assertEqual('https://tracker/announce');
      expect(settings.dhtEnabled).assertTrue();
      expect(settings.downloadDir).assertEqual('/srv/media');
      expect(settings.downloadQueueEnabled).assertTrue();
      expect(settings.downloadQueueSize).assertEqual(5);
      expect(settings.encryption).assertEqual(EncryptionMode.REQUIRED);
      expect(settings.idleSeedingLimit).assertEqual(30);
      expect(settings.incompleteDir).assertEqual('/srv/incomplete');
      expect(settings.peerLimitGlobal).assertEqual(200);
      expect(settings.peerPort).assertEqual(51413);
      expect(settings.reqq).assertEqual(500);
      expect(settings.rpcVersionSemver).assertEqual('6.0.0');
      expect(settings.rpcVersionInteger).assertEqual(18);
      expect(settings.scriptTorrentDoneFilename).assertEqual('/bin/done');
      expect(settings.seedRatioLimit).assertEqual(2.5);
      expect(settings.seedQueueSize).assertEqual(3);
      expect(settings.sessionId).assertEqual('session-1');
      expect(settings.speedLimitDown).assertEqual(2048);
      expect(settings.speedLimitUp).assertEqual(512);
      expect(settings.startAddedTorrents).assertTrue();
      expect(settings.trashOriginalTorrentFiles).assertTrue();
      expect(settings.version).assertEqual('4.1.0');
    });

    it('reads preferred_transports in order', () => {
      const settings = SessionSettings.fromJson(fullSettingsJson());
      expect(settings.preferredTransports).assertDeepEquals([TransportProtocol.UTP, TransportProtocol.TCP]);
    });

    it('reads the nested units object', () => {
      const settings = SessionSettings.fromJson(fullSettingsJson());
      expect(settings.units.speedUnits).assertDeepEquals(['B/s', 'kB/s', 'MB/s']);
      expect(settings.units.speedBytes).assertEqual(1000);
      expect(settings.units.sizeUnits).assertDeepEquals(['B', 'kB', 'MB']);
      expect(settings.units.sizeBytes).assertEqual(1000);
      expect(settings.units.memoryUnits).assertDeepEquals(['B', 'KiB', 'MiB']);
      expect(settings.units.memoryBytes).assertEqual(1024);
    });

    it('returns a safe default instance for an undefined payload', () => {
      const settings = SessionSettings.fromJson(undefined);
      expect(settings.encryption).assertEqual(EncryptionMode.PREFERRED);
      expect(settings.downloadDir).assertEqual('');
      expect(settings.preferredTransports.length).assertEqual(0);
      expect(settings.units.sizeBytes).assertEqual(0);
      expect(settings.units.speedUnits.length).assertEqual(0);
      expect(settings.rpcVersionSemver).assertEqual('');
      expect(settings.supportsJsonRpc).assertFalse();
    });

    it('falls back to empty transport and unit lists for missing nested data', () => {
      const settings = SessionSettings.fromJson(Json.emptyObject() as JsonObject);
      expect(settings.preferredTransports.length).assertEqual(0);
      expect(settings.units.memoryBytes).assertEqual(0);
    });
  });

  describe('SessionSettings encryption mapping', () => {
    it('maps required onto REQUIRED', () => {
      expect(SessionSettings.fromJson(encryptionJson('required')).encryption).assertEqual(EncryptionMode.REQUIRED);
    });

    it('maps the legacy tolerated spelling onto ALLOWED', () => {
      expect(SessionSettings.fromJson(encryptionJson('tolerated')).encryption).assertEqual(EncryptionMode.ALLOWED);
    });

    it('maps allowed onto ALLOWED', () => {
      expect(SessionSettings.fromJson(encryptionJson('allowed')).encryption).assertEqual(EncryptionMode.ALLOWED);
    });

    it('maps preferred onto PREFERRED', () => {
      expect(SessionSettings.fromJson(encryptionJson('preferred')).encryption).assertEqual(EncryptionMode.PREFERRED);
    });

    it('falls back to the documented default for unknown or absent values', () => {
      expect(SessionSettings.fromJson(encryptionJson('nonsense')).encryption).assertEqual(EncryptionMode.PREFERRED);
      expect(SessionSettings.fromJson(Json.emptyObject() as JsonObject).encryption).assertEqual(EncryptionMode.PREFERRED);
    });
  });

  describe('SessionSettings preferred transports', () => {
    it('drops unknown transports and preserves the order of known ones', () => {
      const json: JsonObject = {};
      json['preferred_transports'] = ['tcp', 'carrier-pigeon', 'utp'] as JsonArray;
      const settings = SessionSettings.fromJson(json);
      expect(settings.preferredTransports).assertDeepEquals([TransportProtocol.TCP, TransportProtocol.UTP]);
    });

    it('returns an empty list when every transport is unknown', () => {
      const json: JsonObject = {};
      json['preferred_transports'] = ['smoke-signals'] as JsonArray;
      expect(SessionSettings.fromJson(json).preferredTransports.length).assertEqual(0);
    });
  });

  describe('SessionUnits', () => {
    it('reports decimal units when size_bytes is 1000', () => {
      const json: JsonObject = {};
      json['size_bytes'] = 1000;
      const units = SessionUnits.fromJson(json);
      expect(units.isDecimal()).assertTrue();
      expect(units.bytesPerKb()).assertEqual(1000);
    });

    it('reports binary units when size_bytes is 1024', () => {
      const json: JsonObject = {};
      json['size_bytes'] = 1024;
      const units = SessionUnits.fromJson(json);
      expect(units.isDecimal()).assertFalse();
      expect(units.bytesPerKb()).assertEqual(1024);
    });

    it('returns zeroes for an undefined units object', () => {
      const units = SessionUnits.fromJson(undefined);
      expect(units.bytesPerKb()).assertEqual(0);
      expect(units.isDecimal()).assertFalse();
    });
  });

  describe('SessionSettings RPC version helpers', () => {
    it('parses rpc_version_semver and reports JSON-RPC support for 6.0.0', () => {
      const json: JsonObject = {};
      json['rpc_version_semver'] = '6.0.0';
      const settings = SessionSettings.fromJson(json);
      const version = settings.rpcVersion;
      expect(version === undefined).assertFalse();
      expect(version !== undefined ? version.toString() : '').assertEqual('6.0.0');
      expect(settings.supportsJsonRpc).assertTrue();
    });

    it('reports no JSON-RPC support for the legacy 5.3.0 revision', () => {
      const json: JsonObject = {};
      json['rpc_version_semver'] = '5.3.0';
      const settings = SessionSettings.fromJson(json);
      const version = settings.rpcVersion;
      expect(version === undefined).assertFalse();
      expect(version !== undefined ? version.toString() : '').assertEqual('5.3.0');
      expect(settings.supportsJsonRpc).assertFalse();
    });

    it('treats an absent version as undefined and unsupported', () => {
      const settings = SessionSettings.fromJson(Json.emptyObject() as JsonObject);
      expect(settings.rpcVersion).assertUndefined();
      expect(settings.supportsJsonRpc).assertFalse();
    });

    it('ignores the deprecated integer rpc_version when deriving capabilities', () => {
      const json: JsonObject = {};
      json['rpc_version'] = 18;
      const settings = SessionSettings.fromJson(json);
      expect(settings.rpcVersionInteger).assertEqual(18);
      expect(settings.rpcVersion).assertUndefined();
    });
  });

  describe('BlocklistInfo', () => {
    it('reads the blocklist_size key', () => {
      const json: JsonObject = {};
      json['blocklist_size'] = 99;
      expect(BlocklistInfo.fromJson(json).blocklistSize).assertEqual(99);
    });

    it('returns a zero size for an undefined payload', () => {
      expect(BlocklistInfo.fromJson(undefined).blocklistSize).assertEqual(0);
    });
  });
}
