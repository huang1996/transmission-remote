// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Session transfer statistics returned by `session_stats`.
 *
 * The daemon reports the same counters twice: `current_stats` covers the
 * running session, while `cumulative_stats` covers every session the daemon has
 * served since it was first configured.
 *
 * @since 1.0.0
 */

import { Json, JsonObject } from '../util/Json';

/**
 * One of the `current_stats` / `cumulative_stats` objects.
 *
 * All counters are byte or event totals; they never decrease within their
 * reporting window.
 */
export class SessionStatsEntry {
  /** Total bytes uploaded. */
  uploadedBytes: number = 0;
  /** Total bytes downloaded. */
  downloadedBytes: number = 0;
  /** Number of files added to the session. */
  filesAdded: number = 0;
  /** Number of seconds the session has been active. */
  secondsActive: number = 0;
  /** Number of sessions the daemon has served. */
  sessionCount: number = 0;

  /** Upload/download ratio; `0` when nothing has been downloaded. */
  get ratio(): number {
    return this.downloadedBytes === 0 ? 0 : this.uploadedBytes / this.downloadedBytes;
  }

  /** Bytes transferred in both directions. */
  get totalBytes(): number {
    return this.uploadedBytes + this.downloadedBytes;
  }

  /**
   * Parses a `current_stats` or `cumulative_stats` object.
   *
   * @param json wire object with canonical keys
   */
  static fromJson(json: JsonObject | undefined): SessionStatsEntry {
    const entry = new SessionStatsEntry();
    entry.uploadedBytes = Json.getNumber(json, 'uploaded_bytes');
    entry.downloadedBytes = Json.getNumber(json, 'downloaded_bytes');
    entry.filesAdded = Json.getNumber(json, 'files_added');
    entry.secondsActive = Json.getNumber(json, 'seconds_active');
    entry.sessionCount = Json.getNumber(json, 'session_count');
    return entry;
  }
}

/**
 * A complete `session_stats` result.
 */
export class SessionStats {
  /** Number of torrents that are currently active. */
  activeTorrentCount: number = 0;
  /** Current download rate, in bytes per second. */
  downloadSpeed: number = 0;
  /** Number of torrents that are currently paused. */
  pausedTorrentCount: number = 0;
  /** Total number of torrents in the session. */
  torrentCount: number = 0;
  /** Current upload rate, in bytes per second. */
  uploadSpeed: number = 0;
  /** Counters accumulated across every session. */
  cumulativeStats: SessionStatsEntry = new SessionStatsEntry();
  /** Counters for the current session. */
  currentStats: SessionStatsEntry = new SessionStatsEntry();

  /** Bytes per second transferred in both directions. */
  get totalRate(): number {
    return this.downloadSpeed + this.uploadSpeed;
  }

  /**
   * Parses a `session_stats` result.
   *
   * @param json wire object with canonical keys
   */
  static fromJson(json: JsonObject | undefined): SessionStats {
    const stats = new SessionStats();
    stats.activeTorrentCount = Json.getNumber(json, 'active_torrent_count');
    stats.downloadSpeed = Json.getNumber(json, 'download_speed');
    stats.pausedTorrentCount = Json.getNumber(json, 'paused_torrent_count');
    stats.torrentCount = Json.getNumber(json, 'torrent_count');
    stats.uploadSpeed = Json.getNumber(json, 'upload_speed');
    stats.cumulativeStats = SessionStatsEntry.fromJson(Json.getObject(json, 'cumulative_stats'));
    stats.currentStats = SessionStatsEntry.fromJson(Json.getObject(json, 'current_stats'));
    return stats;
  }
}
