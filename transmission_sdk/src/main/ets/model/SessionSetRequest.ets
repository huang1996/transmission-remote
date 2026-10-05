// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// GENERATED from the Transmission sources - see LICENSE.

/**
 * Request of the `session_set` method.
 *
 * GENERATED FILE - DO NOT EDIT BY HAND.
 *
 * Source of truth: section 4.1.1 of `docs/rpc-spec.md` in the Transmission
 * repository. Regenerate with `node scripts/generate-session-set-request.mjs`.
 *
 * Only the setters that are called end up on the wire: Transmission applies a
 * setting only when its key is present, so untouched settings keep their value.
 *
 * ```ts
 * await client.session.set(
 *   new SessionSetRequest()
 *     .downloadDir('/srv/media')
 *     .speedLimitDownEnabled(true)
 *     .speedLimitDown(2048),
 * );
 * ```
 *
 * @since 1.0.0
 */

import { Json, JsonObject, JsonObjectBuilder, JsonValue } from '../util/Json';
import { EncryptionMode, TransportProtocol } from './Enums';

export class SessionSetRequest {
  private readonly params: JsonObjectBuilder = new JsonObjectBuilder();

  /** True when at least one setting has been provided. */
  get hasChanges(): boolean {
    return !Json.isEmpty(this.params.build());
  }

  /** Number of settings that will be sent. */
  get size(): number {
    return Json.keys(this.params.build()).length;
  }

  /**
   * Sets a raw setting by its canonical wire name.
   *
   * Escape hatch for settings this class does not model; prefer the typed
   * setters below so that typos are caught at compile time.
   */
  setRaw(key: string, value: JsonValue): SessionSetRequest {
    this.params.set(key, value);
    return this;
  }

  /**
   * AltSpeedDown.
   *
   * Wire key: `alt_speed_down`.
   */
  altSpeedDown(value: number): SessionSetRequest {
    this.params.setAlways('alt_speed_down', value);
    return this;
  }

  /**
   * AltSpeedEnabled.
   *
   * Wire key: `alt_speed_enabled`.
   */
  altSpeedEnabled(value: boolean): SessionSetRequest {
    this.params.setAlways('alt_speed_enabled', value);
    return this;
  }

  /**
   * AltSpeedTimeBegin.
   *
   * Wire key: `alt_speed_time_begin`.
   */
  altSpeedTimeBegin(value: number): SessionSetRequest {
    this.params.setAlways('alt_speed_time_begin', value);
    return this;
  }

  /**
   * AltSpeedTimeDay.
   *
   * Wire key: `alt_speed_time_day`.
   */
  altSpeedTimeDay(value: number): SessionSetRequest {
    this.params.setAlways('alt_speed_time_day', value);
    return this;
  }

  /**
   * AltSpeedTimeEnabled.
   *
   * Wire key: `alt_speed_time_enabled`.
   */
  altSpeedTimeEnabled(value: boolean): SessionSetRequest {
    this.params.setAlways('alt_speed_time_enabled', value);
    return this;
  }

  /**
   * AltSpeedTimeEnd.
   *
   * Wire key: `alt_speed_time_end`.
   */
  altSpeedTimeEnd(value: number): SessionSetRequest {
    this.params.setAlways('alt_speed_time_end', value);
    return this;
  }

  /**
   * AltSpeedUp.
   *
   * Wire key: `alt_speed_up`.
   */
  altSpeedUp(value: number): SessionSetRequest {
    this.params.setAlways('alt_speed_up', value);
    return this;
  }

  /**
   * AntiBruteForceEnabled.
   *
   * Wire key: `anti_brute_force_enabled`.
   */
  antiBruteForceEnabled(value: boolean): SessionSetRequest {
    this.params.setAlways('anti_brute_force_enabled', value);
    return this;
  }

  /**
   * BlocklistEnabled.
   *
   * Wire key: `blocklist_enabled`.
   */
  blocklistEnabled(value: boolean): SessionSetRequest {
    this.params.setAlways('blocklist_enabled', value);
    return this;
  }

  /**
   * BlocklistUrl.
   *
   * Wire key: `blocklist_url`.
   */
  blocklistUrl(value: string): SessionSetRequest {
    this.params.setAlways('blocklist_url', value);
    return this;
  }

  /**
   * DefaultTrackers.
   *
   * Wire key: `default_trackers`.
   */
  defaultTrackers(value: string): SessionSetRequest {
    this.params.setAlways('default_trackers', value);
    return this;
  }

  /**
   * DhtEnabled.
   *
   * Wire key: `dht_enabled`.
   */
  dhtEnabled(value: boolean): SessionSetRequest {
    this.params.setAlways('dht_enabled', value);
    return this;
  }

  /**
   * DownloadDir.
   *
   * Wire key: `download_dir`.
   */
  downloadDir(value: string): SessionSetRequest {
    this.params.setAlways('download_dir', value);
    return this;
  }

  /**
   * DownloadQueueEnabled.
   *
   * Wire key: `download_queue_enabled`.
   */
  downloadQueueEnabled(value: boolean): SessionSetRequest {
    this.params.setAlways('download_queue_enabled', value);
    return this;
  }

  /**
   * DownloadQueueSize.
   *
   * Wire key: `download_queue_size`.
   */
  downloadQueueSize(value: number): SessionSetRequest {
    this.params.setAlways('download_queue_size', value);
    return this;
  }

  /**
   * Encryption.
   *
   * Wire key: `encryption`.
   */
  encryption(value: EncryptionMode): SessionSetRequest {
    this.params.setAlways('encryption', value);
    return this;
  }

  /**
   * IdleSeedingLimit.
   *
   * Wire key: `idle_seeding_limit`.
   */
  idleSeedingLimit(value: number): SessionSetRequest {
    this.params.setAlways('idle_seeding_limit', value);
    return this;
  }

  /**
   * IdleSeedingLimitEnabled.
   *
   * Wire key: `idle_seeding_limit_enabled`.
   */
  idleSeedingLimitEnabled(value: boolean): SessionSetRequest {
    this.params.setAlways('idle_seeding_limit_enabled', value);
    return this;
  }

  /**
   * IncompleteDir.
   *
   * Wire key: `incomplete_dir`.
   */
  incompleteDir(value: string): SessionSetRequest {
    this.params.setAlways('incomplete_dir', value);
    return this;
  }

  /**
   * IncompleteDirEnabled.
   *
   * Wire key: `incomplete_dir_enabled`.
   */
  incompleteDirEnabled(value: boolean): SessionSetRequest {
    this.params.setAlways('incomplete_dir_enabled', value);
    return this;
  }

  /**
   * LpdEnabled.
   *
   * Wire key: `lpd_enabled`.
   */
  lpdEnabled(value: boolean): SessionSetRequest {
    this.params.setAlways('lpd_enabled', value);
    return this;
  }

  /**
   * PeerLimitGlobal.
   *
   * Wire key: `peer_limit_global`.
   */
  peerLimitGlobal(value: number): SessionSetRequest {
    this.params.setAlways('peer_limit_global', value);
    return this;
  }

  /**
   * PeerLimitPerTorrent.
   *
   * Wire key: `peer_limit_per_torrent`.
   */
  peerLimitPerTorrent(value: number): SessionSetRequest {
    this.params.setAlways('peer_limit_per_torrent', value);
    return this;
  }

  /**
   * PeerPortRandomOnStart.
   *
   * Wire key: `peer_port_random_on_start`.
   */
  peerPortRandomOnStart(value: boolean): SessionSetRequest {
    this.params.setAlways('peer_port_random_on_start', value);
    return this;
  }

  /**
   * PeerPort.
   *
   * Wire key: `peer_port`.
   */
  peerPort(value: number): SessionSetRequest {
    this.params.setAlways('peer_port', value);
    return this;
  }

  /**
   * PexEnabled.
   *
   * Wire key: `pex_enabled`.
   */
  pexEnabled(value: boolean): SessionSetRequest {
    this.params.setAlways('pex_enabled', value);
    return this;
  }

  /**
   * PortForwardingEnabled.
   *
   * Wire key: `port_forwarding_enabled`.
   */
  portForwardingEnabled(value: boolean): SessionSetRequest {
    this.params.setAlways('port_forwarding_enabled', value);
    return this;
  }

  /**
   * PreferredTransports (preference order).
   *
   * Wire key: `preferred_transports`.
   */
  preferredTransports(value: TransportProtocol[]): SessionSetRequest {
    const encoded: string[] = [];
    for (const protocol of value) {
      encoded.push(protocol);
    }
    this.params.setAlways('preferred_transports', encoded);
    return this;
  }

  /**
   * QueueStalledEnabled.
   *
   * Wire key: `queue_stalled_enabled`.
   */
  queueStalledEnabled(value: boolean): SessionSetRequest {
    this.params.setAlways('queue_stalled_enabled', value);
    return this;
  }

  /**
   * QueueStalledMinutes.
   *
   * Wire key: `queue_stalled_minutes`.
   */
  queueStalledMinutes(value: number): SessionSetRequest {
    this.params.setAlways('queue_stalled_minutes', value);
    return this;
  }

  /**
   * RenamePartialFiles.
   *
   * Wire key: `rename_partial_files`.
   */
  renamePartialFiles(value: boolean): SessionSetRequest {
    this.params.setAlways('rename_partial_files', value);
    return this;
  }

  /**
   * Reqq.
   *
   * Wire key: `reqq`.
   */
  reqq(value: number): SessionSetRequest {
    this.params.setAlways('reqq', value);
    return this;
  }

  /**
   * ScriptTorrentAddedEnabled.
   *
   * Wire key: `script_torrent_added_enabled`.
   */
  scriptTorrentAddedEnabled(value: boolean): SessionSetRequest {
    this.params.setAlways('script_torrent_added_enabled', value);
    return this;
  }

  /**
   * ScriptTorrentAddedFilename.
   *
   * Wire key: `script_torrent_added_filename`.
   */
  scriptTorrentAddedFilename(value: string): SessionSetRequest {
    this.params.setAlways('script_torrent_added_filename', value);
    return this;
  }

  /**
   * ScriptTorrentDoneEnabled.
   *
   * Wire key: `script_torrent_done_enabled`.
   */
  scriptTorrentDoneEnabled(value: boolean): SessionSetRequest {
    this.params.setAlways('script_torrent_done_enabled', value);
    return this;
  }

  /**
   * ScriptTorrentDoneFilename.
   *
   * Wire key: `script_torrent_done_filename`.
   */
  scriptTorrentDoneFilename(value: string): SessionSetRequest {
    this.params.setAlways('script_torrent_done_filename', value);
    return this;
  }

  /**
   * ScriptTorrentDoneSeedingEnabled.
   *
   * Wire key: `script_torrent_done_seeding_enabled`.
   */
  scriptTorrentDoneSeedingEnabled(value: boolean): SessionSetRequest {
    this.params.setAlways('script_torrent_done_seeding_enabled', value);
    return this;
  }

  /**
   * ScriptTorrentDoneSeedingFilename.
   *
   * Wire key: `script_torrent_done_seeding_filename`.
   */
  scriptTorrentDoneSeedingFilename(value: string): SessionSetRequest {
    this.params.setAlways('script_torrent_done_seeding_filename', value);
    return this;
  }

  /**
   * SeedQueueEnabled.
   *
   * Wire key: `seed_queue_enabled`.
   */
  seedQueueEnabled(value: boolean): SessionSetRequest {
    this.params.setAlways('seed_queue_enabled', value);
    return this;
  }

  /**
   * SeedQueueSize.
   *
   * Wire key: `seed_queue_size`.
   */
  seedQueueSize(value: number): SessionSetRequest {
    this.params.setAlways('seed_queue_size', value);
    return this;
  }

  /**
   * SeedRatioLimit.
   *
   * Wire key: `seed_ratio_limit`.
   */
  seedRatioLimit(value: number): SessionSetRequest {
    this.params.setAlways('seed_ratio_limit', value);
    return this;
  }

  /**
   * SeedRatioLimited.
   *
   * Wire key: `seed_ratio_limited`.
   */
  seedRatioLimited(value: boolean): SessionSetRequest {
    this.params.setAlways('seed_ratio_limited', value);
    return this;
  }

  /**
   * SequentialDownload.
   *
   * Wire key: `sequential_download`.
   */
  sequentialDownload(value: boolean): SessionSetRequest {
    this.params.setAlways('sequential_download', value);
    return this;
  }

  /**
   * SpeedLimitDown.
   *
   * Wire key: `speed_limit_down`.
   */
  speedLimitDown(value: number): SessionSetRequest {
    this.params.setAlways('speed_limit_down', value);
    return this;
  }

  /**
   * SpeedLimitDownEnabled.
   *
   * Wire key: `speed_limit_down_enabled`.
   */
  speedLimitDownEnabled(value: boolean): SessionSetRequest {
    this.params.setAlways('speed_limit_down_enabled', value);
    return this;
  }

  /**
   * SpeedLimitUp.
   *
   * Wire key: `speed_limit_up`.
   */
  speedLimitUp(value: number): SessionSetRequest {
    this.params.setAlways('speed_limit_up', value);
    return this;
  }

  /**
   * SpeedLimitUpEnabled.
   *
   * Wire key: `speed_limit_up_enabled`.
   */
  speedLimitUpEnabled(value: boolean): SessionSetRequest {
    this.params.setAlways('speed_limit_up_enabled', value);
    return this;
  }

  /**
   * StartAddedTorrents.
   *
   * Wire key: `start_added_torrents`.
   */
  startAddedTorrents(value: boolean): SessionSetRequest {
    this.params.setAlways('start_added_torrents', value);
    return this;
  }

  /**
   * TrashOriginalTorrentFiles.
   *
   * Wire key: `trash_original_torrent_files`.
   */
  trashOriginalTorrentFiles(value: boolean): SessionSetRequest {
    this.params.setAlways('trash_original_torrent_files', value);
    return this;
  }

  /** Serialises the request into RPC parameters. */
  toJson(): JsonObject {
    return this.params.build();
  }
}
