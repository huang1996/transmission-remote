// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Application-level models: servers, settings and the enums the UI binds to.
 *
 * These are plain data classes. Persistence lives in `store/AppStore.ets` and
 * protocol work lives in the SDK, so this file stays free of both.
 *
 * @since 1.0.0
 */

import { ApiStyleMode, Json, JsonObject, TorrentStatus } from 'transmission_sdk';

/**
 * True when a torrent is doing something that changes without user input.
 *
 * Downloading, verifying and queueing all move on their own, so any screen
 * showing them has to keep refreshing. A stopped or finished torrent does not,
 * which is what lets the refresh cadence back off when the session is idle.
 *
 * @param status the torrent's lifecycle state
 */
export function isTorrentBusy(status: TorrentStatus): boolean {
  return (
    status === TorrentStatus.DOWNLOADING ||
    status === TorrentStatus.VERIFYING ||
    status === TorrentStatus.QUEUED_TO_DOWNLOAD ||
    status === TorrentStatus.QUEUED_TO_VERIFY ||
    status === TorrentStatus.QUEUED_TO_SEED
  );
}

/** How the appearance is chosen. */
export enum ThemeMode {
  /** Follow the system setting (default). */
  SYSTEM = 'system',
  /** Always light. */
  LIGHT = 'light',
  /** Always dark. */
  DARK = 'dark',
}

/** Which torrents the list shows. */
export enum TorrentFilter {
  /** Everything. */
  ALL = 'all',
  /** Torrents transferring right now. */
  ACTIVE = 'active',
  /** Torrents that are downloading or queued to. */
  DOWNLOADING = 'downloading',
  /** Torrents that are seeding or queued to. */
  SEEDING = 'seeding',
  /** Stopped torrents. */
  PAUSED = 'paused',
  /** Torrents whose data is fully present. */
  DOWNLOADED = 'downloaded',
  /** Torrents that finished and are no longer downloading. */
  COMPLETED = 'completed',
}

/** Sort keys offered by the drawer. */
export enum TorrentSort {
  /** The server's own queue order. */
  QUEUE = 'queue',
  /** `activity_date`, most recent first. */
  ACTIVITY = 'activity',
  /** `added_date`. */
  ADDED_DATE = 'addedDate',
  /** `activity_date` again, but labelled the way the reference UI does. */
  LAST_ACTIVITY = 'lastActivity',
  /** Display name. */
  NAME = 'name',
  /** `percent_done`. */
  PROGRESS = 'progress',
  /** `total_size`. */
  SIZE = 'size',
  /** Numeric `status`. */
  STATE = 'state',
  /** `eta`. */
  ETA = 'eta',
  /** `upload_ratio`. */
  RATIO = 'ratio',
  /** `rate_download`. */
  DOWNLOAD_SPEED = 'downloadSpeed',
  /** `rate_upload`. */
  UPLOAD_SPEED = 'uploadSpeed',
}

/** A Transmission server the application can talk to. */
export class ServerProfile {
  /** Stable id used for persistence and selection. */
  id: string = '';
  /** Display name shown in the drawer and the title bar. */
  name: string = '';
  /** Host name or IP address. */
  host: string = '';
  /** RPC port. */
  port: number = 9091;
  /** RPC path. */
  path: string = '/transmission/rpc';
  /** True for `https://`. */
  secure: boolean = false;
  /** HTTP Basic user name, or an empty string. */
  username: string = '';
  /** HTTP Basic password, or an empty string. */
  password: string = '';

  /** The full endpoint URL, e.g. `http://nas:9091/transmission/rpc`. */
  get url(): string {
    const scheme = this.secure ? 'https' : 'http';
    const normalized = this.path.startsWith('/') ? this.path : `/${this.path}`;
    return `${scheme}://${this.host}:${this.port}${normalized}`;
  }

  /** `name` when set, otherwise `host:port`. */
  get displayName(): string {
    return this.name.length > 0 ? this.name : `${this.host}:${this.port}`;
  }

  /** `host:port`, used as the drawer subtitle. */
  get endpoint(): string {
    return `${this.host}:${this.port}`;
  }

  /** True when the profile has enough information to connect. */
  get isValid(): boolean {
    return this.host.length > 0 && this.port > 0 && this.port <= 65535;
  }

  /** A copy with a fresh id. */
  copy(): ServerProfile {
    const other = new ServerProfile();
    other.id = this.id;
    other.name = this.name;
    other.host = this.host;
    other.port = this.port;
    other.path = this.path;
    other.secure = this.secure;
    other.username = this.username;
    other.password = this.password;
    return other;
  }

  /**
   * Parses a persisted profile.
   *
   * @param json stored object; `undefined` yields an empty profile so that a
   *             partially written preference file cannot crash start-up
   */
  static fromJson(json: JsonObject | undefined): ServerProfile {
    const profile = new ServerProfile();
    profile.id = Json.getString(json, 'id');
    profile.name = Json.getString(json, 'name');
    profile.host = Json.getString(json, 'host');
    profile.port = Json.getNumber(json, 'port', 9091);
    profile.path = Json.getString(json, 'path', '/transmission/rpc');
    profile.secure = Json.getBoolean(json, 'secure');
    profile.username = Json.getString(json, 'username');
    profile.password = Json.getString(json, 'password');
    return profile;
  }

  /** Serialises the profile for persistence. */
  toJson(): JsonObject {
    const json: JsonObject = {};
    json['id'] = this.id;
    json['name'] = this.name;
    json['host'] = this.host;
    json['port'] = this.port;
    json['path'] = this.path;
    json['secure'] = this.secure;
    json['username'] = this.username;
    json['password'] = this.password;
    return json;
  }

  /** True when both profiles would connect to the same endpoint. */
  sameEndpointAs(other: ServerProfile): boolean {
    return this.url === other.url;
  }
}

/** Everything the Options screen can change. */
export class AppSettings {
  /** Appearance preference. */
  themeMode: ThemeMode = ThemeMode.SYSTEM;
  /** Seconds between automatic refreshes; `0` means manual only. */
  refreshIntervalSeconds: number = 0;
  /** Whether the floating add button is shown. */
  showAddFab: boolean = true;
  /** Whether a local notification is posted when a torrent finishes. */
  notificationsEnabled: boolean = false;
  /** Per-request timeout in seconds. */
  requestTimeoutSeconds: number = 15;
  /** Wire dialect; auto-detection is right almost always. */
  apiStyleMode: ApiStyleMode = ApiStyleMode.AUTO;
  /** Current sort key. */
  sortBy: TorrentSort = TorrentSort.QUEUE;
  /** Sort direction. */
  sortAscending: boolean = true;
  /** Current list filter. */
  filter: TorrentFilter = TorrentFilter.ALL;

  /** Parses persisted settings, tolerating missing or unknown values. */
  static fromJson(json: JsonObject | undefined): AppSettings {
    const settings = new AppSettings();
    if (json === undefined) {
      return settings;
    }
    settings.themeMode = readThemeMode(json, ThemeMode.SYSTEM);
    settings.refreshIntervalSeconds = Json.getNumber(json, 'refreshIntervalSeconds', 0);
    settings.showAddFab = Json.getBoolean(json, 'showAddFab', true);
    settings.notificationsEnabled = Json.getBoolean(json, 'notificationsEnabled', false);
    settings.requestTimeoutSeconds = Json.getNumber(json, 'requestTimeoutSeconds', 15);
    settings.apiStyleMode = readApiStyleMode(json, ApiStyleMode.AUTO);
    settings.sortBy = readTorrentSort(json, TorrentSort.QUEUE);
    settings.sortAscending = Json.getBoolean(json, 'sortAscending', true);
    settings.filter = readTorrentFilter(json, TorrentFilter.ALL);
    return settings;
  }

  /** Serialises the settings for persistence. */
  toJson(): JsonObject {
    const json: JsonObject = {};
    json['themeMode'] = this.themeMode;
    json['refreshIntervalSeconds'] = this.refreshIntervalSeconds;
    json['showAddFab'] = this.showAddFab;
    json['notificationsEnabled'] = this.notificationsEnabled;
    json['requestTimeoutSeconds'] = this.requestTimeoutSeconds;
    json['apiStyleMode'] = this.apiStyleMode;
    json['sortBy'] = this.sortBy;
    json['sortAscending'] = this.sortAscending;
    json['filter'] = this.filter;
    return json;
  }

}

/**
 * Readers for the persisted string enums.
 *
 * Written out one by one rather than with a generic helper: ArkTS does not let
 * an enum object be passed where `Record<string, T>` is expected, and an
 * explicit reader also documents the migration path when a stored value is no
 * longer recognised.
 */

/** Reads `themeMode`, falling back for unknown or missing values. */
export function readThemeMode(json: JsonObject | undefined, fallback: ThemeMode): ThemeMode {
  const raw = Json.asString(Json.get(json, 'themeMode'));
  if (raw === ThemeMode.SYSTEM) {
    return ThemeMode.SYSTEM;
  }
  if (raw === ThemeMode.LIGHT) {
    return ThemeMode.LIGHT;
  }
  if (raw === ThemeMode.DARK) {
    return ThemeMode.DARK;
  }
  return fallback;
}

/** Reads `apiStyleMode`, falling back for unknown or missing values. */
export function readApiStyleMode(json: JsonObject | undefined, fallback: ApiStyleMode): ApiStyleMode {
  const raw = Json.asString(Json.get(json, 'apiStyleMode'));
  if (raw === ApiStyleMode.AUTO) {
    return ApiStyleMode.AUTO;
  }
  if (raw === ApiStyleMode.MODERN) {
    return ApiStyleMode.MODERN;
  }
  if (raw === ApiStyleMode.LEGACY) {
    return ApiStyleMode.LEGACY;
  }
  return fallback;
}

/** Reads `sortBy`, falling back for unknown or missing values. */
export function readTorrentSort(json: JsonObject | undefined, fallback: TorrentSort): TorrentSort {
  const raw = Json.asString(Json.get(json, 'sortBy'));
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
  for (const candidate of all) {
    if (candidate === raw) {
      return candidate;
    }
  }
  return fallback;
}

/** Reads `filter`, falling back for unknown or missing values. */
export function readTorrentFilter(json: JsonObject | undefined, fallback: TorrentFilter): TorrentFilter {
  const raw = Json.asString(Json.get(json, 'filter'));
  const all: TorrentFilter[] = [
    TorrentFilter.ALL,
    TorrentFilter.ACTIVE,
    TorrentFilter.DOWNLOADING,
    TorrentFilter.SEEDING,
    TorrentFilter.PAUSED,
    TorrentFilter.DOWNLOADED,
    TorrentFilter.COMPLETED,
  ];
  for (const candidate of all) {
    if (candidate === raw) {
      return candidate;
    }
  }
  return fallback;
}
