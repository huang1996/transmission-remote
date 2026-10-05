// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for the `session_stats` model.
 *
 * `session_stats` nests the same counter object twice: `cumulative_stats`
 * covers every session the daemon has served, `current_stats` only the running
 * one. Both must be parsed, and the ratio must survive a zero denominator
 * because a freshly started daemon reports all-zero counters.
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { Json, JsonObject } from '../../main/ets/util/Json';
import { SessionStats, SessionStatsEntry } from '../../main/ets/model/SessionStats';

export default function sessionStatsTest(): void {
  describe('SessionStatsEntry', () => {
    it('computes the upload/download ratio', () => {
      const entry = new SessionStatsEntry();
      entry.uploadedBytes = 100;
      entry.downloadedBytes = 400;
      expect(entry.ratio).assertEqual(0.25);
    });

    it('reports a zero ratio when nothing has been downloaded', () => {
      const entry = new SessionStatsEntry();
      entry.uploadedBytes = 100;
      entry.downloadedBytes = 0;
      expect(entry.ratio).assertEqual(0);
    });

    it('sums both directions for totalBytes', () => {
      const entry = new SessionStatsEntry();
      entry.uploadedBytes = 100;
      entry.downloadedBytes = 250;
      expect(entry.totalBytes).assertEqual(350);
    });

    it('reads every canonical counter key', () => {
      const json: JsonObject = {};
      json['uploaded_bytes'] = 1024;
      json['downloaded_bytes'] = 2048;
      json['files_added'] = 3;
      json['seconds_active'] = 60;
      json['session_count'] = 2;
      const entry = SessionStatsEntry.fromJson(json);
      expect(entry.uploadedBytes).assertEqual(1024);
      expect(entry.downloadedBytes).assertEqual(2048);
      expect(entry.filesAdded).assertEqual(3);
      expect(entry.secondsActive).assertEqual(60);
      expect(entry.sessionCount).assertEqual(2);
    });

    it('returns zeroed counters for an undefined payload', () => {
      const entry = SessionStatsEntry.fromJson(undefined);
      expect(entry.totalBytes).assertEqual(0);
      expect(entry.ratio).assertEqual(0);
      expect(entry.filesAdded).assertEqual(0);
      expect(entry.sessionCount).assertEqual(0);
    });
  });

  describe('SessionStats.fromJson', () => {
    it('reads the top-level counters and the nested session entries', () => {
      const current: JsonObject = {};
      current['uploaded_bytes'] = 10;
      current['downloaded_bytes'] = 20;
      current['files_added'] = 1;
      current['seconds_active'] = 5;
      current['session_count'] = 1;
      const cumulative: JsonObject = {};
      cumulative['uploaded_bytes'] = 100;
      cumulative['downloaded_bytes'] = 200;
      cumulative['files_added'] = 4;
      cumulative['seconds_active'] = 500;
      cumulative['session_count'] = 9;
      const json: JsonObject = {};
      json['active_torrent_count'] = 3;
      json['download_speed'] = 1024;
      json['paused_torrent_count'] = 1;
      json['torrent_count'] = 7;
      json['upload_speed'] = 256;
      json['current_stats'] = current;
      json['cumulative_stats'] = cumulative;
      const stats = SessionStats.fromJson(json);
      expect(stats.activeTorrentCount).assertEqual(3);
      expect(stats.downloadSpeed).assertEqual(1024);
      expect(stats.pausedTorrentCount).assertEqual(1);
      expect(stats.torrentCount).assertEqual(7);
      expect(stats.uploadSpeed).assertEqual(256);
      expect(stats.currentStats.uploadedBytes).assertEqual(10);
      expect(stats.currentStats.downloadedBytes).assertEqual(20);
      expect(stats.currentStats.sessionCount).assertEqual(1);
      expect(stats.cumulativeStats.uploadedBytes).assertEqual(100);
      expect(stats.cumulativeStats.downloadedBytes).assertEqual(200);
      expect(stats.cumulativeStats.sessionCount).assertEqual(9);
    });

    it('sums both speeds for totalRate', () => {
      const json: JsonObject = {};
      json['download_speed'] = 1024;
      json['upload_speed'] = 256;
      expect(SessionStats.fromJson(json).totalRate).assertEqual(1280);
    });

    it('returns safe defaults for an undefined payload', () => {
      const stats = SessionStats.fromJson(undefined);
      expect(stats.activeTorrentCount).assertEqual(0);
      expect(stats.torrentCount).assertEqual(0);
      expect(stats.totalRate).assertEqual(0);
      expect(stats.currentStats.totalBytes).assertEqual(0);
      expect(stats.cumulativeStats.totalBytes).assertEqual(0);
    });

    it('falls back to empty entries when the nested stats objects are absent', () => {
      const stats = SessionStats.fromJson(Json.emptyObject() as JsonObject);
      expect(stats.currentStats.uploadedBytes).assertEqual(0);
      expect(stats.cumulativeStats.downloadedBytes).assertEqual(0);
    });
  });
}
