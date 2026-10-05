// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// GENERATED from the Transmission sources - see LICENSE.

/**
 * Canonical (Transmission >= 4.1.0, snake_case) to legacy (Transmission < 4.1.0,
 * mixed kebab-case / camelCase) RPC key mapping.
 *
 * GENERATED FILE - DO NOT EDIT BY HAND.
 *
 * Source of truth: the `RpcKeys` table in `libtransmission/api-compat.cc` of the
 * Transmission repository, resolved through the quark string table in
 * `libtransmission/quark.cc`. Regenerate with
 * `node scripts/generate-legacy-keys.mjs`.
 *
 * The legacy API mixes naming styles, so the mapping cannot be derived from the
 * canonical name alone; the table below is exhaustive for RPC traffic.
 *
 * @since 1.0.0
 */

/** A single `[canonical, legacy]` key pair. */
type LegacyKeyPair = [string, string];

/** Every RPC key understood by the compatibility layer. */
const LEGACY_RPC_KEY_PAIRS: LegacyKeyPair[] = [
  ['active_torrent_count', 'activeTorrentCount'],
  ['activity_date', 'activityDate'],
  ['added_date', 'addedDate'],
  ['alt_speed_down', 'alt-speed-down'],
  ['alt_speed_enabled', 'alt-speed-enabled'],
  ['alt_speed_time_begin', 'alt-speed-time-begin'],
  ['alt_speed_time_day', 'alt-speed-time-day'],
  ['alt_speed_time_enabled', 'alt-speed-time-enabled'],
  ['alt_speed_time_end', 'alt-speed-time-end'],
  ['alt_speed_up', 'alt-speed-up'],
  ['announce_state', 'announceState'],
  ['anti_brute_force_enabled', 'anti-brute-force-enabled'],
  ['anti_brute_force_threshold', 'anti-brute-force-threshold'],
  ['bandwidth_priority', 'bandwidthPriority'],
  ['blocklist_enabled', 'blocklist-enabled'],
  ['blocklist_size', 'blocklist-size'],
  ['blocklist_update', 'blocklist-update'],
  ['blocklist_url', 'blocklist-url'],
  ['bytes_completed', 'bytesCompleted'],
  ['cache_size_mib', 'cache-size-mb'],
  ['client_is_choked', 'clientIsChoked'],
  ['client_is_interested', 'clientIsInterested'],
  ['client_name', 'clientName'],
  ['config_dir', 'config-dir'],
  ['corrupt_ever', 'corruptEver'],
  ['cumulative_stats', 'cumulative-stats'],
  ['current_stats', 'current-stats'],
  ['date_created', 'dateCreated'],
  ['default_trackers', 'default-trackers'],
  ['delete_local_data', 'delete-local-data'],
  ['desired_available', 'desiredAvailable'],
  ['dht_enabled', 'dht-enabled'],
  ['done_date', 'doneDate'],
  ['download_count', 'downloadCount'],
  ['download_dir', 'download-dir'],
  ['download_dir_free_space', 'download-dir-free-space'],
  ['download_limit', 'downloadLimit'],
  ['download_limited', 'downloadLimited'],
  ['download_queue_enabled', 'download-queue-enabled'],
  ['download_queue_size', 'download-queue-size'],
  ['download_speed', 'downloadSpeed'],
  ['downloaded_bytes', 'downloadedBytes'],
  ['downloaded_ever', 'downloadedEver'],
  ['edit_date', 'editDate'],
  ['error_string', 'errorString'],
  ['eta_idle', 'etaIdle'],
  ['file_count', 'file-count'],
  ['file_stats', 'fileStats'],
  ['files_added', 'filesAdded'],
  ['files_unwanted', 'files-unwanted'],
  ['files_wanted', 'files-wanted'],
  ['flag_str', 'flagStr'],
  ['free_space', 'free-space'],
  ['from_cache', 'fromCache'],
  ['from_dht', 'fromDht'],
  ['from_incoming', 'fromIncoming'],
  ['from_lpd', 'fromLpd'],
  ['from_ltep', 'fromLtep'],
  ['from_pex', 'fromPex'],
  ['from_tracker', 'fromTracker'],
  ['group_get', 'group-get'],
  ['group_set', 'group-set'],
  ['has_announced', 'hasAnnounced'],
  ['has_scraped', 'hasScraped'],
  ['hash_string', 'hashString'],
  ['have_unchecked', 'haveUnchecked'],
  ['have_valid', 'haveValid'],
  ['honors_session_limits', 'honorsSessionLimits'],
  ['idle_seeding_limit', 'idle-seeding-limit'],
  ['idle_seeding_limit_enabled', 'idle-seeding-limit-enabled'],
  ['incomplete_dir', 'incomplete-dir'],
  ['incomplete_dir_enabled', 'incomplete-dir-enabled'],
  ['is_backup', 'isBackup'],
  ['is_downloading_from', 'isDownloadingFrom'],
  ['is_encrypted', 'isEncrypted'],
  ['is_finished', 'isFinished'],
  ['is_incoming', 'isIncoming'],
  ['is_private', 'isPrivate'],
  ['is_stalled', 'isStalled'],
  ['is_uploading_to', 'isUploadingTo'],
  ['is_utp', 'isUTP'],
  ['last_announce_peer_count', 'lastAnnouncePeerCount'],
  ['last_announce_result', 'lastAnnounceResult'],
  ['last_announce_start_time', 'lastAnnounceStartTime'],
  ['last_announce_succeeded', 'lastAnnounceSucceeded'],
  ['last_announce_time', 'lastAnnounceTime'],
  ['last_announce_timed_out', 'lastAnnounceTimedOut'],
  ['last_scrape_result', 'lastScrapeResult'],
  ['last_scrape_start_time', 'lastScrapeStartTime'],
  ['last_scrape_succeeded', 'lastScrapeSucceeded'],
  ['last_scrape_time', 'lastScrapeTime'],
  ['last_scrape_timed_out', 'lastScrapeTimedOut'],
  ['leecher_count', 'leecherCount'],
  ['left_until_done', 'leftUntilDone'],
  ['lpd_enabled', 'lpd-enabled'],
  ['magnet_link', 'magnetLink'],
  ['manual_announce_time', 'manualAnnounceTime'],
  ['max_connected_peers', 'maxConnectedPeers'],
  ['memory_bytes', 'memory-bytes'],
  ['memory_units', 'memory-units'],
  ['metadata_percent_complete', 'metadataPercentComplete'],
  ['next_announce_time', 'nextAnnounceTime'],
  ['next_scrape_time', 'nextScrapeTime'],
  ['paused_torrent_count', 'pausedTorrentCount'],
  ['peer_is_choked', 'peerIsChoked'],
  ['peer_is_interested', 'peerIsInterested'],
  ['peer_limit', 'peer-limit'],
  ['peer_limit_global', 'peer-limit-global'],
  ['peer_limit_per_torrent', 'peer-limit-per-torrent'],
  ['peer_port', 'peer-port'],
  ['peer_port_random_on_start', 'peer-port-random-on-start'],
  ['peers_connected', 'peersConnected'],
  ['peers_from', 'peersFrom'],
  ['peers_getting_from_us', 'peersGettingFromUs'],
  ['peers_sending_to_us', 'peersSendingToUs'],
  ['percent_complete', 'percentComplete'],
  ['percent_done', 'percentDone'],
  ['pex_enabled', 'pex-enabled'],
  ['piece_count', 'pieceCount'],
  ['piece_size', 'pieceSize'],
  ['port_forwarding_enabled', 'port-forwarding-enabled'],
  ['port_is_open', 'port-is-open'],
  ['port_test', 'port-test'],
  ['primary_mime_type', 'primary-mime-type'],
  ['priority_high', 'priority-high'],
  ['priority_low', 'priority-low'],
  ['priority_normal', 'priority-normal'],
  ['queue_move_bottom', 'queue-move-bottom'],
  ['queue_move_down', 'queue-move-down'],
  ['queue_move_top', 'queue-move-top'],
  ['queue_move_up', 'queue-move-up'],
  ['queue_position', 'queuePosition'],
  ['queue_stalled_enabled', 'queue-stalled-enabled'],
  ['queue_stalled_minutes', 'queue-stalled-minutes'],
  ['rate_download', 'rateDownload'],
  ['rate_to_client', 'rateToClient'],
  ['rate_to_peer', 'rateToPeer'],
  ['rate_upload', 'rateUpload'],
  ['recently_active', 'recently-active'],
  ['recheck_progress', 'recheckProgress'],
  ['rename_partial_files', 'rename-partial-files'],
  ['rpc_host_whitelist', 'rpc-host-whitelist'],
  ['rpc_host_whitelist_enabled', 'rpc-host-whitelist-enabled'],
  ['rpc_version', 'rpc-version'],
  ['rpc_version_minimum', 'rpc-version-minimum'],
  ['rpc_version_semver', 'rpc-version-semver'],
  ['scrape_state', 'scrapeState'],
  ['script_torrent_added_enabled', 'script-torrent-added-enabled'],
  ['script_torrent_added_filename', 'script-torrent-added-filename'],
  ['script_torrent_done_enabled', 'script-torrent-done-enabled'],
  ['script_torrent_done_filename', 'script-torrent-done-filename'],
  ['script_torrent_done_seeding_enabled', 'script-torrent-done-seeding-enabled'],
  ['script_torrent_done_seeding_filename', 'script-torrent-done-seeding-filename'],
  ['seconds_active', 'secondsActive'],
  ['seconds_downloading', 'secondsDownloading'],
  ['seconds_seeding', 'secondsSeeding'],
  ['seed_idle_limit', 'seedIdleLimit'],
  ['seed_idle_mode', 'seedIdleMode'],
  ['seed_queue_enabled', 'seed-queue-enabled'],
  ['seed_queue_size', 'seed-queue-size'],
  ['seed_ratio_limit', 'seedRatioLimit'],
  ['seed_ratio_limited', 'seedRatioLimited'],
  ['seed_ratio_mode', 'seedRatioMode'],
  ['seeder_count', 'seederCount'],
  ['session_close', 'session-close'],
  ['session_count', 'sessionCount'],
  ['session_get', 'session-get'],
  ['session_id', 'session-id'],
  ['session_set', 'session-set'],
  ['session_stats', 'session-stats'],
  ['size_bytes', 'size-bytes'],
  ['size_units', 'size-units'],
  ['size_when_done', 'sizeWhenDone'],
  ['speed_bytes', 'speed-bytes'],
  ['speed_limit_down', 'speed-limit-down'],
  ['speed_limit_down_enabled', 'speed-limit-down-enabled'],
  ['speed_limit_up', 'speed-limit-up'],
  ['speed_limit_up_enabled', 'speed-limit-up-enabled'],
  ['speed_units', 'speed-units'],
  ['start_added_torrents', 'start-added-torrents'],
  ['start_date', 'startDate'],
  ['tcp_enabled', 'tcp-enabled'],
  ['torrent_add', 'torrent-add'],
  ['torrent_added', 'torrent-added'],
  ['torrent_count', 'torrentCount'],
  ['torrent_duplicate', 'torrent-duplicate'],
  ['torrent_file', 'torrentFile'],
  ['torrent_get', 'torrent-get'],
  ['torrent_reannounce', 'torrent-reannounce'],
  ['torrent_remove', 'torrent-remove'],
  ['torrent_rename_path', 'torrent-rename-path'],
  ['torrent_set', 'torrent-set'],
  ['torrent_set_location', 'torrent-set-location'],
  ['torrent_start', 'torrent-start'],
  ['torrent_start_now', 'torrent-start-now'],
  ['torrent_stop', 'torrent-stop'],
  ['torrent_verify', 'torrent-verify'],
  ['total_size', 'totalSize'],
  ['tracker_add', 'trackerAdd'],
  ['tracker_list', 'trackerList'],
  ['tracker_remove', 'trackerRemove'],
  ['tracker_replace', 'trackerReplace'],
  ['tracker_stats', 'trackerStats'],
  ['trash_original_torrent_files', 'trash-original-torrent-files'],
  ['upload_limit', 'uploadLimit'],
  ['upload_limited', 'uploadLimited'],
  ['upload_ratio', 'uploadRatio'],
  ['upload_speed', 'uploadSpeed'],
  ['uploaded_bytes', 'uploadedBytes'],
  ['uploaded_ever', 'uploadedEver'],
  ['utp_enabled', 'utp-enabled'],
  ['webseeds_sending_to_us', 'webseedsSendingToUs'],
];

/**
 * Bidirectional lookup between canonical and legacy RPC key names.
 *
 * Lookups are O(1) `Map` reads, so key conversion stays cheap even for
 * `torrent_get` responses containing thousands of nested objects.
 */
export class LegacyKeys {
  private static readonly TO_LEGACY: Map<string, string> = LegacyKeys.buildToLegacy();
  private static readonly TO_CANONICAL: Map<string, string> = LegacyKeys.buildToCanonical();

  private constructor() {
    // Static-only utility class.
  }

  private static buildToLegacy(): Map<string, string> {
    const map = new Map<string, string>();
    for (const pair of LEGACY_RPC_KEY_PAIRS) {
      map.set(pair[0], pair[1]);
    }
    return map;
  }

  private static buildToCanonical(): Map<string, string> {
    const map = new Map<string, string>();
    for (const pair of LEGACY_RPC_KEY_PAIRS) {
      if (!map.has(pair[1])) {
        map.set(pair[1], pair[0]);
      }
    }
    return map;
  }

  /** Number of mapped keys. */
  static get size(): number {
    return LEGACY_RPC_KEY_PAIRS.length;
  }

  /**
   * Translates a canonical key into its legacy spelling.
   *
   * @returns the legacy name, or `undefined` when the key only exists in the
   *          modern API (for example a field added after Transmission 4.1.0).
   */
  static toLegacy(canonical: string): string | undefined {
    return LegacyKeys.TO_LEGACY.get(canonical);
  }

  /**
   * Translates a legacy key into its canonical spelling.
   *
   * @returns the canonical name, or `undefined` when the key is not part of the
   *          compatibility table.
   */
  static toCanonical(legacy: string): string | undefined {
    return LegacyKeys.TO_CANONICAL.get(legacy);
  }

  /**
   * True when `key` is a canonical name whose spelling differs between the two
   * dialects.
   *
   * Keys that are spelled identically in both dialects (`name`, `status`, ...)
   * are deliberately absent from the table, so they report `false`. Callers that
   * just want a translated key should combine this with a fallback, which is
   * exactly what `KeyConverter.convertKey` does.
   */
  static hasMapping(key: string): boolean {
    return LegacyKeys.TO_LEGACY.has(key);
  }

  /** Every canonical key, in alphabetical order. */
  static canonicalKeys(): string[] {
    return Array.from(LegacyKeys.TO_LEGACY.keys());
  }
}
