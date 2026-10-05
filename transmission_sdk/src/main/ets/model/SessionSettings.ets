// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Session settings returned by `session_get`.
 *
 * `session_get` reports every daemon-wide option as a flat object, plus a nested
 * `units` object describing how the daemon displays byte sizes. The
 * compatibility layer normalises legacy kebab-case keys before the payload
 * reaches this model, so every parser here reads canonical snake_case keys.
 *
 * @since 1.0.0
 */

import { Json, JsonObject } from '../util/Json';
import { RpcVersion, RpcVersions } from '../util/Semver';
import { EncryptionMode, TransportProtocol } from './Enums';

/**
 * The `units` object of `session_get`.
 *
 * Transmission reports the unit names and the number of bytes per unit for
 * speeds, sizes and memory separately, because a daemon may display decimal
 * (SI) units for some values and binary (IEC) units for others.
 */
export class SessionUnits {
  /** Display unit names for transfer speeds, e.g. `["B/s", "kB/s", "MB/s"]`. */
  speedUnits: string[] = [];
  /** Number of bytes in one speed unit. */
  speedBytes: number = 0;
  /** Display unit names for sizes, e.g. `["B", "kB", "MB"]`. */
  sizeUnits: string[] = [];
  /** Number of bytes in one size unit: `1000` for decimal, `1024` for binary. */
  sizeBytes: number = 0;
  /** Display unit names for memory, e.g. `["B", "KiB", "MiB"]`. */
  memoryUnits: string[] = [];
  /** Number of bytes in one memory unit. */
  memoryBytes: number = 0;

  /** Number of bytes in one kilobyte, according to the size units. */
  bytesPerKb(): number {
    return this.sizeBytes;
  }

  /** True when size units are decimal (SI), i.e. one kilobyte is 1000 bytes. */
  isDecimal(): boolean {
    return this.sizeBytes === 1000;
  }

  /**
   * Parses a `units` object.
   *
   * @param json wire object with canonical keys
   */
  static fromJson(json: JsonObject | undefined): SessionUnits {
    const units = new SessionUnits();
    units.speedUnits = Json.getStringArray(json, 'speed_units');
    units.speedBytes = Json.getNumber(json, 'speed_bytes');
    units.sizeUnits = Json.getStringArray(json, 'size_units');
    units.sizeBytes = Json.getNumber(json, 'size_bytes');
    units.memoryUnits = Json.getStringArray(json, 'memory_units');
    units.memoryBytes = Json.getNumber(json, 'memory_bytes');
    return units;
  }
}

/**
 * The result object of `blocklist_update`.
 *
 * Updating the blocklist returns only the number of rules that are now loaded;
 * the configured URL and enabled flag live on {@link SessionSettings}.
 */
export class BlocklistInfo {
  /** Number of rules in the loaded blocklist. */
  blocklistSize: number = 0;

  /**
   * Parses a `blocklist_update` result.
   *
   * @param json wire object with canonical keys
   */
  static fromJson(json: JsonObject | undefined): BlocklistInfo {
    const info = new BlocklistInfo();
    info.blocklistSize = Json.getNumber(json, 'blocklist_size');
    return info;
  }
}

/**
 * A complete `session_get` result.
 *
 * Every field keeps a safe default so that the object can be read even when the
 * server predates a setting or the caller requested only a subset of keys.
 * Read-only and deprecated settings are marked as such; they are still parsed so
 * that the model mirrors the wire payload exactly.
 */
export class SessionSettings {
  /** Alternate download speed limit, in kB/s. */
  altSpeedDown: number = 0;
  /** True when the alternate speed limits are active. */
  altSpeedEnabled: boolean = false;
  /** Minute of the day the alternate speed schedule starts, `0` – `1439`. */
  altSpeedTimeBegin: number = 0;
  /** Day the alternate speed schedule starts, `0` (Sun) – `7` (every day). */
  altSpeedTimeDay: number = 0;
  /** True when the alternate speed schedule is honoured. */
  altSpeedTimeEnabled: boolean = false;
  /** Minute of the day the alternate speed schedule ends, `0` – `1439`. */
  altSpeedTimeEnd: number = 0;
  /** Alternate upload speed limit, in kB/s. */
  altSpeedUp: number = 0;
  /** True when anti-brute-force protection is enabled. */
  antiBruteForceEnabled: boolean = false;
  /** True when the IP blocklist is enabled. */
  blocklistEnabled: boolean = false;
  /** Number of rules in the loaded blocklist. **Read-only.** */
  blocklistSize: number = 0;
  /** URL the blocklist is downloaded from. */
  blocklistUrl: string = '';
  /** **Deprecated** disk cache size, in MiB. */
  cacheSizeMib: number = 0;
  /** Directory holding the daemon's configuration files. **Read-only.** */
  configDir: string = '';
  /** Default announce URLs, one per line. */
  defaultTrackers: string = '';
  /** True when DHT is enabled. */
  dhtEnabled: boolean = false;
  /** Directory incomplete downloads are written to. */
  downloadDir: string = '';
  /** **Deprecated**, **read-only** free space in {@link downloadDir}, in bytes. */
  downloadDirFreeSpace: number = 0;
  /** True when the download queue is enabled. */
  downloadQueueEnabled: boolean = false;
  /** Maximum number of actively downloading torrents. */
  downloadQueueSize: number = 0;
  /** Peer encryption policy. Defaults to {@link EncryptionMode.PREFERRED}. */
  encryption: EncryptionMode = EncryptionMode.PREFERRED;
  /** Minutes of seeding inactivity before a torrent stops. */
  idleSeedingLimit: number = 0;
  /** True when {@link idleSeedingLimit} is honoured. */
  idleSeedingLimitEnabled: boolean = false;
  /** Directory incomplete torrents are written to. */
  incompleteDir: string = '';
  /** True when {@link incompleteDir} is used. */
  incompleteDirEnabled: boolean = false;
  /** True when local peer discovery is enabled. */
  lpdEnabled: boolean = false;
  /** Maximum number of peers for the whole session. */
  peerLimitGlobal: number = 0;
  /** Default maximum number of peers per torrent. */
  peerLimitPerTorrent: number = 0;
  /** True when a random peer port is picked at startup. */
  peerPortRandomOnStart: boolean = false;
  /** Port the peer listener binds to. */
  peerPort: number = 0;
  /** True when peer exchange (PEX) is enabled. */
  pexEnabled: boolean = false;
  /** True when the router's port-mapping protocol is used. */
  portForwardingEnabled: boolean = false;
  /** Transports to try first, in order; unknown values are dropped. */
  preferredTransports: TransportProtocol[] = [];
  /** True when stalled torrents are moved to the end of the queue. */
  queueStalledEnabled: boolean = false;
  /** Minutes a torrent must be stalled before it is requeued. */
  queueStalledMinutes: number = 0;
  /** True when partially downloaded files get a `.part` suffix. */
  renamePartialFiles: boolean = false;
  /** Size of the request queue, in blocks. */
  reqq: number = 0;
  /** **Deprecated**, **read-only** minimum RPC version the server accepts. */
  rpcVersionMinimum: number = 0;
  /** RPC protocol version as a semver string, e.g. `"6.0.0"`. **Read-only.** */
  rpcVersionSemver: string = '';
  /**
   * **Deprecated**, **read-only** integer RPC version counter. Prefer
   * {@link rpcVersionSemver} or the {@link rpcVersion} getter.
   */
  rpcVersionInteger: number = 0;
  /** True when a script runs after a torrent is added. */
  scriptTorrentAddedEnabled: boolean = false;
  /** Script to run after a torrent is added. */
  scriptTorrentAddedFilename: string = '';
  /** True when a script runs after a torrent finishes downloading. */
  scriptTorrentDoneEnabled: boolean = false;
  /** Script to run after a torrent finishes downloading. */
  scriptTorrentDoneFilename: string = '';
  /** True when a script runs after a torrent finishes seeding. */
  scriptTorrentDoneSeedingEnabled: boolean = false;
  /** Script to run after a torrent finishes seeding. */
  scriptTorrentDoneSeedingFilename: string = '';
  /** True when the seed queue is enabled. */
  seedQueueEnabled: boolean = false;
  /** Maximum number of actively seeding torrents. */
  seedQueueSize: number = 0;
  /** Default seeding ratio limit. */
  seedRatioLimit: number = 0;
  /** True when {@link seedRatioLimit} is honoured. */
  seedRatioLimited: boolean = false;
  /** True when new torrents download pieces in order. */
  sequentialDownload: boolean = false;
  /** Identifier of the current RPC session. **Read-only.** */
  sessionId: string = '';
  /** Global download speed limit, in kB/s. */
  speedLimitDown: number = 0;
  /** True when {@link speedLimitDown} is honoured. */
  speedLimitDownEnabled: boolean = false;
  /** Global upload speed limit, in kB/s. */
  speedLimitUp: number = 0;
  /** True when {@link speedLimitUp} is honoured. */
  speedLimitUpEnabled: boolean = false;
  /** True when added torrents start immediately. */
  startAddedTorrents: boolean = false;
  /** **Deprecated** True when the TCP listener is enabled. */
  tcpEnabled: boolean = false;
  /** True when original `.torrent` files are moved to the trash. */
  trashOriginalTorrentFiles: boolean = false;
  /** Display units and byte counts. **Read-only.** */
  units: SessionUnits = new SessionUnits();
  /** **Deprecated** True when the uTP listener is enabled. */
  utpEnabled: boolean = false;
  /** Version string of the Transmission daemon. **Read-only.** */
  version: string = '';

  /** RPC version parsed from {@link rpcVersionSemver}, when it is present. */
  get rpcVersion(): RpcVersion | undefined {
    return RpcVersion.parse(this.rpcVersionSemver);
  }

  /** True when the server speaks JSON-RPC 2.0 (RPC version 6.0.0 or later). */
  get supportsJsonRpc(): boolean {
    return RpcVersions.supportsJsonRpc(this.rpcVersion);
  }

  /**
   * Parses a `session_get` result.
   *
   * @param json wire object with canonical keys
   */
  static fromJson(json: JsonObject | undefined): SessionSettings {
    const settings = new SessionSettings();

    settings.altSpeedDown = Json.getNumber(json, 'alt_speed_down');
    settings.altSpeedEnabled = Json.getBoolean(json, 'alt_speed_enabled');
    settings.altSpeedTimeBegin = Json.getNumber(json, 'alt_speed_time_begin');
    settings.altSpeedTimeDay = Json.getNumber(json, 'alt_speed_time_day');
    settings.altSpeedTimeEnabled = Json.getBoolean(json, 'alt_speed_time_enabled');
    settings.altSpeedTimeEnd = Json.getNumber(json, 'alt_speed_time_end');
    settings.altSpeedUp = Json.getNumber(json, 'alt_speed_up');
    settings.antiBruteForceEnabled = Json.getBoolean(json, 'anti_brute_force_enabled');
    settings.blocklistEnabled = Json.getBoolean(json, 'blocklist_enabled');
    settings.blocklistSize = Json.getNumber(json, 'blocklist_size');
    settings.blocklistUrl = Json.getString(json, 'blocklist_url');
    settings.cacheSizeMib = Json.getNumber(json, 'cache_size_mib');
    settings.configDir = Json.getString(json, 'config_dir');
    settings.defaultTrackers = Json.getString(json, 'default_trackers');
    settings.dhtEnabled = Json.getBoolean(json, 'dht_enabled');
    settings.downloadDir = Json.getString(json, 'download_dir');
    settings.downloadDirFreeSpace = Json.getNumber(json, 'download_dir_free_space');
    settings.downloadQueueEnabled = Json.getBoolean(json, 'download_queue_enabled');
    settings.downloadQueueSize = Json.getNumber(json, 'download_queue_size');
    settings.encryption = SessionSettings.parseEncryption(Json.getString(json, 'encryption'));
    settings.idleSeedingLimit = Json.getNumber(json, 'idle_seeding_limit');
    settings.idleSeedingLimitEnabled = Json.getBoolean(json, 'idle_seeding_limit_enabled');
    settings.incompleteDir = Json.getString(json, 'incomplete_dir');
    settings.incompleteDirEnabled = Json.getBoolean(json, 'incomplete_dir_enabled');
    settings.lpdEnabled = Json.getBoolean(json, 'lpd_enabled');
    settings.peerLimitGlobal = Json.getNumber(json, 'peer_limit_global');
    settings.peerLimitPerTorrent = Json.getNumber(json, 'peer_limit_per_torrent');
    settings.peerPortRandomOnStart = Json.getBoolean(json, 'peer_port_random_on_start');
    settings.peerPort = Json.getNumber(json, 'peer_port');
    settings.pexEnabled = Json.getBoolean(json, 'pex_enabled');
    settings.portForwardingEnabled = Json.getBoolean(json, 'port_forwarding_enabled');
    settings.preferredTransports = SessionSettings.parseTransports(Json.getStringArray(json, 'preferred_transports'));
    settings.queueStalledEnabled = Json.getBoolean(json, 'queue_stalled_enabled');
    settings.queueStalledMinutes = Json.getNumber(json, 'queue_stalled_minutes');
    settings.renamePartialFiles = Json.getBoolean(json, 'rename_partial_files');
    settings.reqq = Json.getNumber(json, 'reqq');
    settings.rpcVersionMinimum = Json.getNumber(json, 'rpc_version_minimum');
    settings.rpcVersionSemver = Json.getString(json, 'rpc_version_semver');
    settings.rpcVersionInteger = Json.getNumber(json, 'rpc_version');
    settings.scriptTorrentAddedEnabled = Json.getBoolean(json, 'script_torrent_added_enabled');
    settings.scriptTorrentAddedFilename = Json.getString(json, 'script_torrent_added_filename');
    settings.scriptTorrentDoneEnabled = Json.getBoolean(json, 'script_torrent_done_enabled');
    settings.scriptTorrentDoneFilename = Json.getString(json, 'script_torrent_done_filename');
    settings.scriptTorrentDoneSeedingEnabled = Json.getBoolean(json, 'script_torrent_done_seeding_enabled');
    settings.scriptTorrentDoneSeedingFilename = Json.getString(json, 'script_torrent_done_seeding_filename');
    settings.seedQueueEnabled = Json.getBoolean(json, 'seed_queue_enabled');
    settings.seedQueueSize = Json.getNumber(json, 'seed_queue_size');
    settings.seedRatioLimit = Json.getNumber(json, 'seed_ratio_limit');
    settings.seedRatioLimited = Json.getBoolean(json, 'seed_ratio_limited');
    settings.sequentialDownload = Json.getBoolean(json, 'sequential_download');
    settings.sessionId = Json.getString(json, 'session_id');
    settings.speedLimitDown = Json.getNumber(json, 'speed_limit_down');
    settings.speedLimitDownEnabled = Json.getBoolean(json, 'speed_limit_down_enabled');
    settings.speedLimitUp = Json.getNumber(json, 'speed_limit_up');
    settings.speedLimitUpEnabled = Json.getBoolean(json, 'speed_limit_up_enabled');
    settings.startAddedTorrents = Json.getBoolean(json, 'start_added_torrents');
    settings.tcpEnabled = Json.getBoolean(json, 'tcp_enabled');
    settings.trashOriginalTorrentFiles = Json.getBoolean(json, 'trash_original_torrent_files');
    settings.units = SessionUnits.fromJson(Json.getObject(json, 'units'));
    settings.utpEnabled = Json.getBoolean(json, 'utp_enabled');
    settings.version = Json.getString(json, 'version');

    return settings;
  }

  /**
   * Maps the wire `encryption` string onto {@link EncryptionMode}.
   *
   * Transmission < 4.1.0 spells `allowed` as `"tolerated"`; both forms are
   * accepted. Unknown values fall back to {@link EncryptionMode.PREFERRED}.
   *
   * @param value raw wire value
   */
  private static parseEncryption(value: string): EncryptionMode {
    if (value === 'required') {
      return EncryptionMode.REQUIRED;
    }
    if (value === 'allowed' || value === 'tolerated') {
      return EncryptionMode.ALLOWED;
    }
    return EncryptionMode.PREFERRED;
  }

  /**
   * Maps `preferred_transports` onto known {@link TransportProtocol} values,
   * dropping anything the SDK does not understand.
   *
   * @param values raw wire values
   */
  private static parseTransports(values: string[]): TransportProtocol[] {
    const transports: TransportProtocol[] = [];
    for (const value of values) {
      if (value === 'utp') {
        transports.push(TransportProtocol.UTP);
      } else if (value === 'tcp') {
        transports.push(TransportProtocol.TCP);
      }
    }
    return transports;
  }
}
