// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for the application's data models and formatters.
 *
 * The persistence layer trusts nothing it reads from disk, so the round-trip and
 * "unknown value" cases below are the contract that keeps a hand-edited or
 * partially written preference file from breaking start-up.
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { ApiStyleMode, JsonObject, TorrentStatus } from 'transmission_sdk';
import {
  AppSettings,
  isTorrentBusy,
  readApiStyleMode,
  readThemeMode,
  readTorrentFilter,
  readTorrentSort,
  ServerProfile,
  ThemeMode,
  TorrentFilter,
  TorrentSort,
} from '../../main/ets/model/AppModels';
import { AddMethod, AddParam, DetailParam, RouteName } from '../../main/ets/model/NavParams';
import {
  formatBytes,
  formatBytesOrDash,
  formatCountOrDash,
  formatEta,
  formatPercent,
  formatPercentPrecise,
  formatRatio,
  formatSpeed,
  formatTimestamp,
} from '../../main/ets/viewmodel/Formatters';

/** Builds a profile with every field set. */
function sampleProfile(): ServerProfile {
  const profile = new ServerProfile();
  profile.id = 'srv-1';
  profile.name = 'NAS';
  profile.host = 'nas.local';
  profile.port = 9091;
  profile.path = '/transmission/rpc';
  profile.secure = false;
  profile.username = 'admin';
  profile.password = 'secret';
  return profile;
}

export default function appModelsTest(): void {
  describe('ServerProfile endpoint building', () => {
    it('builds an http url by default', () => {
      expect(sampleProfile().url).assertEqual('http://nas.local:9091/transmission/rpc');
    });

    it('builds an https url when secure is set', () => {
      const profile = sampleProfile();
      profile.secure = true;
      expect(profile.url).assertEqual('https://nas.local:9091/transmission/rpc');
    });

    it('adds the missing leading slash to the path', () => {
      const profile = sampleProfile();
      profile.path = 'transmission/rpc';
      expect(profile.url).assertEqual('http://nas.local:9091/transmission/rpc');
    });

    it('keeps a non-default port and path', () => {
      const profile = sampleProfile();
      profile.port = 8443;
      profile.path = '/rpc';
      profile.secure = true;
      expect(profile.url).assertEqual('https://nas.local:8443/rpc');
    });

    it('names the server after the host when no name is set', () => {
      const profile = sampleProfile();
      profile.name = '';
      expect(profile.displayName).assertEqual('nas.local:9091');
      expect(profile.endpoint).assertEqual('nas.local:9091');
    });

    it('validates the host and port range', () => {
      expect(sampleProfile().isValid).assertTrue();

      const noHost = sampleProfile();
      noHost.host = '';
      expect(noHost.isValid).assertFalse();

      const badPort = sampleProfile();
      badPort.port = 0;
      expect(badPort.isValid).assertFalse();

      const hugePort = sampleProfile();
      hugePort.port = 70000;
      expect(hugePort.isValid).assertFalse();
    });
  });

  describe('ServerProfile persistence', () => {
    it('round-trips every field', () => {
      const restored = ServerProfile.fromJson(sampleProfile().toJson());
      expect(restored.id).assertEqual('srv-1');
      expect(restored.name).assertEqual('NAS');
      expect(restored.host).assertEqual('nas.local');
      expect(restored.port).assertEqual(9091);
      expect(restored.path).assertEqual('/transmission/rpc');
      expect(restored.secure).assertFalse();
      expect(restored.username).assertEqual('admin');
      expect(restored.password).assertEqual('secret');
      expect(restored.url).assertEqual(sampleProfile().url);
    });

    it('applies defaults for a missing payload', () => {
      const restored = ServerProfile.fromJson(undefined);
      expect(restored.host).assertEqual('');
      expect(restored.port).assertEqual(9091);
      expect(restored.path).assertEqual('/transmission/rpc');
      expect(restored.secure).assertFalse();
      expect(restored.isValid).assertFalse();
    });

    it('copies without sharing state', () => {
      const original = sampleProfile();
      const copy = original.copy();
      copy.port = 1234;
      expect(original.port).assertEqual(9091);
      expect(copy.port).assertEqual(1234);
    });

    it('compares endpoints rather than names', () => {
      const left = sampleProfile();
      const right = sampleProfile();
      right.id = 'srv-2';
      right.name = 'other';
      expect(left.sameEndpointAs(right)).assertTrue();

      right.secure = true;
      expect(left.sameEndpointAs(right)).assertFalse();
    });
  });

  describe('AppSettings persistence', () => {
    it('defaults to following the system appearance', () => {
      const settings = AppSettings.fromJson(undefined);
      expect(settings.themeMode).assertEqual(ThemeMode.SYSTEM);
      expect(settings.refreshIntervalSeconds).assertEqual(0);
      expect(settings.showAddFab).assertTrue();
      expect(settings.notificationsEnabled).assertFalse();
      expect(settings.requestTimeoutSeconds).assertEqual(15);
      expect(settings.apiStyleMode).assertEqual(ApiStyleMode.AUTO);
      expect(settings.sortBy).assertEqual(TorrentSort.QUEUE);
      expect(settings.sortAscending).assertTrue();
      expect(settings.filter).assertEqual(TorrentFilter.ALL);
    });

    it('round-trips every field', () => {
      const settings = new AppSettings();
      settings.themeMode = ThemeMode.DARK;
      settings.refreshIntervalSeconds = 30;
      settings.showAddFab = false;
      settings.notificationsEnabled = true;
      settings.requestTimeoutSeconds = 45;
      settings.apiStyleMode = ApiStyleMode.LEGACY;
      settings.sortBy = TorrentSort.SIZE;
      settings.sortAscending = false;
      settings.filter = TorrentFilter.SEEDING;

      const restored = AppSettings.fromJson(settings.toJson());
      expect(restored.themeMode).assertEqual(ThemeMode.DARK);
      expect(restored.refreshIntervalSeconds).assertEqual(30);
      expect(restored.showAddFab).assertFalse();
      expect(restored.notificationsEnabled).assertTrue();
      expect(restored.requestTimeoutSeconds).assertEqual(45);
      expect(restored.apiStyleMode).assertEqual(ApiStyleMode.LEGACY);
      expect(restored.sortBy).assertEqual(TorrentSort.SIZE);
      expect(restored.sortAscending).assertFalse();
      expect(restored.filter).assertEqual(TorrentFilter.SEEDING);
    });

    it('falls back when a stored enum value is no longer recognised', () => {
      const stored: JsonObject = {};
      stored['themeMode'] = 'neon';
      stored['apiStyleMode'] = 'quantum';
      stored['sortBy'] = 'vibes';
      stored['filter'] = 'everything';

      const restored = AppSettings.fromJson(stored);
      expect(restored.themeMode).assertEqual(ThemeMode.SYSTEM);
      expect(restored.apiStyleMode).assertEqual(ApiStyleMode.AUTO);
      expect(restored.sortBy).assertEqual(TorrentSort.QUEUE);
      expect(restored.filter).assertEqual(TorrentFilter.ALL);
    });

    it('survives a payload with the wrong value types', () => {
      const stored: JsonObject = {};
      stored['themeMode'] = 7;
      stored['showAddFab'] = 'yes';
      stored['requestTimeoutSeconds'] = 'long';

      const restored = AppSettings.fromJson(stored);
      expect(restored.themeMode).assertEqual(ThemeMode.SYSTEM);
      expect(restored.showAddFab).assertTrue();
      expect(restored.requestTimeoutSeconds).assertEqual(15);
    });
  });

  describe('enum readers', () => {
    it('accepts every declared theme mode', () => {
      for (const mode of [ThemeMode.SYSTEM, ThemeMode.LIGHT, ThemeMode.DARK]) {
        const json: JsonObject = {};
        json['themeMode'] = mode;
        expect(readThemeMode(json, ThemeMode.SYSTEM)).assertEqual(mode);
      }
    });

    it('accepts every declared sort key', () => {
      const all: TorrentSort[] = [
        TorrentSort.QUEUE,
        TorrentSort.ACTIVITY,
        TorrentSort.ADDED_DATE,
        TorrentSort.LAST_ACTIVITY,
        TorrentSort.NAME,
        TorrentSort.PROGRESS,
        TorrentSort.SIZE,
        TorrentSort.STATE,
        TorrentSort.ETA,
        TorrentSort.RATIO,
        TorrentSort.DOWNLOAD_SPEED,
        TorrentSort.UPLOAD_SPEED,
      ];
      for (const sort of all) {
        const json: JsonObject = {};
        json['sortBy'] = sort;
        expect(readTorrentSort(json, TorrentSort.QUEUE)).assertEqual(sort);
      }
    });

    it('accepts every declared filter and dialect', () => {
      const filters: TorrentFilter[] = [
        TorrentFilter.ALL,
        TorrentFilter.ACTIVE,
        TorrentFilter.DOWNLOADING,
        TorrentFilter.SEEDING,
        TorrentFilter.PAUSED,
        TorrentFilter.DOWNLOADED,
        TorrentFilter.COMPLETED,
      ];
      for (const filter of filters) {
        const json: JsonObject = {};
        json['filter'] = filter;
        expect(readTorrentFilter(json, TorrentFilter.ALL)).assertEqual(filter);
      }

      const json: JsonObject = {};
      json['apiStyleMode'] = ApiStyleMode.MODERN;
      expect(readApiStyleMode(json, ApiStyleMode.AUTO)).assertEqual(ApiStyleMode.MODERN);
      expect(readApiStyleMode(undefined, ApiStyleMode.AUTO)).assertEqual(ApiStyleMode.AUTO);
    });
  });

  describe('isTorrentBusy', () => {
    it('is true for every state that moves without user input', () => {
      // These are the states that make a screen refresh itself.
      expect(isTorrentBusy(TorrentStatus.DOWNLOADING)).assertTrue();
      expect(isTorrentBusy(TorrentStatus.VERIFYING)).assertTrue();
      expect(isTorrentBusy(TorrentStatus.QUEUED_TO_DOWNLOAD)).assertTrue();
      expect(isTorrentBusy(TorrentStatus.QUEUED_TO_VERIFY)).assertTrue();
      expect(isTorrentBusy(TorrentStatus.QUEUED_TO_SEED)).assertTrue();
    });

    it('is false for states that only change when the user acts', () => {
      // A paused or seeding torrent shows the same numbers until something is
      // done to it, so polling it would be wasted requests.
      expect(isTorrentBusy(TorrentStatus.STOPPED)).assertFalse();
      expect(isTorrentBusy(TorrentStatus.SEEDING)).assertFalse();
    });
  });

  describe('Navigation parameters', () => {
    it('keeps the route names distinct', () => {
      const names: string[] = [RouteName.DETAIL, RouteName.ADD, RouteName.SERVERS, RouteName.SETTINGS];
      for (let i = 0; i < names.length; i++) {
        for (let j = i + 1; j < names.length; j++) {
          expect(names[i] === names[j]).assertFalse();
        }
      }
    });

    it('carries the torrent id', () => {
      expect(new DetailParam(42).torrentId).assertEqual(42);
    });

    it('carries the initial add method', () => {
      expect(new AddParam(AddMethod.FILE).method).assertEqual(AddMethod.FILE);
      expect(new AddParam(AddMethod.LINK).method).assertEqual(AddMethod.LINK);
    });
  });

  describe('Formatters', () => {
    it('formats byte counts with binary units', () => {
      expect(formatBytes(0)).assertEqual('0 B');
      expect(formatBytes(512)).assertEqual('512 B');
      expect(formatBytes(1024)).assertEqual('1.0 KB');
      expect(formatBytes(4096)).assertEqual('4.0 KB');
      expect(formatBytes(1536 * 1024)).assertEqual('1.5 MB');
      expect(formatBytes(-1)).assertEqual('—');
    });

    it('drops the decimal for large values', () => {
      // 500 KB reads better without a decimal than as "500.0 KB".
      expect(formatBytes(500 * 1024)).assertEqual('500 KB');
    });

    it('formats transfer rates', () => {
      expect(formatSpeed(0)).assertEqual('0.0 KB/s');
      expect(formatSpeed(-5)).assertEqual('0.0 KB/s');
      expect(formatSpeed(100)).assertEqual('100.0 B/s');
      expect(formatSpeed(2048)).assertEqual('2.0 KB/s');
    });

    it('formats durations across every unit boundary', () => {
      expect(formatEta(30)).assertEqual('30s');
      expect(formatEta(90)).assertEqual('1m');
      expect(formatEta(3660)).assertEqual('1h 01m');
      expect(formatEta(90000)).assertEqual('1d 1h');
      expect(formatEta(-1)).assertEqual('—');
    });

    it('formats fractions as percentages', () => {
      expect(formatPercent(0)).assertEqual('0%');
      expect(formatPercent(0.256)).assertEqual('26%');
      expect(formatPercent(1)).assertEqual('100%');
      expect(formatPercentPrecise(0.2567)).assertEqual('25.7%');
      expect(formatPercentPrecise(-1)).assertEqual('0.0%');
    });

    it('formats ratios with two decimals', () => {
      expect(formatRatio(0)).assertEqual('0.00');
      expect(formatRatio(1.23456)).assertEqual('1.23');
      expect(formatRatio(-1)).assertEqual('0.00');
    });

    it('renders unknown timestamps and counts as a dash', () => {
      expect(formatTimestamp(0)).assertEqual('—');
      expect(formatTimestamp(-1)).assertEqual('—');
      expect(formatCountOrDash(-1)).assertEqual('—');
      expect(formatCountOrDash(7)).assertEqual('7');
      expect(formatBytesOrDash(-1)).assertEqual('—');
      expect(formatBytesOrDash(1024)).assertEqual('1.0 KB');
    });

    it('renders a real timestamp with a fixed shape', () => {
      // The value depends on the device time zone, so only the shape is pinned.
      const formatted = formatTimestamp(1700000000);
      expect(formatted.length).assertEqual(16);
      expect(formatted.includes('-')).assertTrue();
      expect(formatted.includes(':')).assertTrue();
    });
  });
}
