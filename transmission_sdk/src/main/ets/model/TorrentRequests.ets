// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Building blocks for `torrent_*` requests.
 *
 * The classes here are small fluent builders. They exist so that call sites read
 * like the RPC specification, and so that "only send what the caller set" is
 * enforced in one place instead of being repeated at every call site.
 *
 * @since 1.0.0
 */

import { Json, JsonArray, JsonObject, JsonObjectBuilder, JsonValue } from '../util/Json';
import { Base64 } from '../util/Base64';
import { IdleLimitMode, RatioLimitMode, TorrentFormat, TorrentPriority } from './Enums';
import { Torrent } from './Torrent';

/** A torrent may be addressed by its transient numeric id or its info-hash. */
export type TorrentId = number | string;

/**
 * The `ids` argument shared by every `torrent_*` method.
 *
 * ```ts
 * client.torrents.start(TorrentIds.of([42, 'a1b2…']));
 * client.torrents.start(TorrentIds.RECENTLY_ACTIVE);
 * client.torrents.start(TorrentIds.ALL);
 * ```
 */
export class TorrentIds {
  /** Every torrent (the `ids` argument is omitted on the wire). */
  static readonly ALL: TorrentIds = new TorrentIds(undefined);
  /** Torrents that have been active recently. */
  static readonly RECENTLY_ACTIVE: TorrentIds = new TorrentIds('recently_active');

  private readonly value: JsonValue | undefined;

  private constructor(value: JsonValue | undefined) {
    this.value = value;
  }

  /** Addresses an explicit list of numeric ids and/or info-hashes. */
  static of(ids: TorrentId[]): TorrentIds {
    return new TorrentIds(ids.slice() as JsonArray);
  }

  /** Addresses a single torrent. */
  static single(id: TorrentId): TorrentIds {
    return new TorrentIds([id] as JsonArray);
  }

  /** Addresses torrents by info-hash. */
  static ofHashes(hashes: string[]): TorrentIds {
    return new TorrentIds(hashes.slice() as JsonArray);
  }

  /** Addresses torrents by numeric id. */
  static ofNumbers(ids: number[]): TorrentIds {
    return new TorrentIds(ids.slice() as JsonArray);
  }

  /** True when every torrent is addressed. */
  get isAll(): boolean {
    return this.value === undefined;
  }

  /** True when the recently-active pseudo-id is used. */
  get isRecentlyActive(): boolean {
    return this.value === 'recently_active';
  }

  /** Number of addressed torrents; `0` for {@link ALL}. */
  get size(): number {
    const array = Json.asArray(this.value);
    return array === undefined ? 0 : array.length;
  }

  /**
   * Wire representation.
   *
   * @returns `undefined` for {@link ALL}, meaning the key must be omitted
   */
  toJson(): JsonValue | undefined {
    return this.value;
  }

  /** Adds the `ids` argument to `builder` unless every torrent is addressed. */
  applyTo(builder: JsonObjectBuilder): JsonObjectBuilder {
    if (this.value !== undefined) {
      builder.set('ids', this.value);
    }
    return builder;
  }

  /** `"all"`, `"recently_active"` or `"<n> ids"`, for diagnostics. */
  toString(): string {
    if (this.isAll) {
      return 'all';
    }
    if (this.isRecentlyActive) {
      return 'recently_active';
    }
    return `${this.size} ids`;
  }
}

/**
 * Ready-made `torrent_get` / `session_get` field selections.
 *
 * Requesting fewer fields is the single most effective way to speed up
 * `torrent_get`, so the SDK ships a few sensible presets.
 */
export class TorrentFields {
  /** Enough to render a compact torrent list. */
  static readonly BASIC: string[] = [
    'id',
    'name',
    'status',
    'percent_done',
    'rate_download',
    'rate_upload',
    'eta',
    'total_size',
    'left_until_done',
    'upload_ratio',
    'error',
    'error_string',
    'is_finished',
    'is_stalled',
    'queue_position',
    'download_dir',
    'labels',
    'hash_string',
  ];

  /** Progress-oriented selection, useful for detail screens. */
  static readonly PROGRESS: string[] = [
    'id',
    'name',
    'hash_string',
    'status',
    'percent_done',
    'percent_complete',
    'metadata_percent_complete',
    'recheck_progress',
    'eta',
    'eta_idle',
    'rate_download',
    'rate_upload',
    'downloaded_ever',
    'uploaded_ever',
    'have_valid',
    'have_unchecked',
    'corrupt_ever',
    'left_until_done',
    'size_when_done',
    'total_size',
    'upload_ratio',
    'seconds_downloading',
    'seconds_seeding',
    'peers_connected',
    'peers_sending_to_us',
    'peers_getting_from_us',
    'webseeds_sending_to_us',
    'added_date',
    'activity_date',
    'done_date',
    'start_date',
    'download_dir',
    'is_private',
    'is_stalled',
    'is_finished',
    'bandwidth_priority',
    'queue_position',
    'download_limit',
    'download_limited',
    'upload_limit',
    'upload_limited',
    'honors_session_limits',
    'seed_ratio_limit',
    'seed_ratio_mode',
    'seed_idle_limit',
    'seed_idle_mode',
    'sequential_download',
  ];

  /** Every field used by {@link Torrent}, including the expensive nested ones. */
  static readonly DETAILED: string[] = [
    ...TorrentFields.PROGRESS,
    'comment',
    'creator',
    'date_created',
    'edit_date',
    'magnet_link',
    'primary_mime_type',
    'file_count',
    'piece_count',
    'piece_size',
    'files',
    'file_stats',
    'trackers',
    'tracker_stats',
    'tracker_list',
    'peers',
    'peers_from',
    'webseeds_ex',
    'labels',
    'group',
    'max_connected_peers',
    'peer_limit',
    'desired_available',
  ];

  private constructor() {
    // Static-only utility class.
  }
}

/**
 * Request of the `torrent_get` method.
 *
 * ```ts
 * const request = new TorrentGetRequest(TorrentFields.BASIC)
 *   .ids(TorrentIds.RECENTLY_ACTIVE);
 * const torrents = await client.torrents.get(request);
 * ```
 */
export class TorrentGetRequest {
  private idsValue: TorrentIds = TorrentIds.ALL;
  private readonly fieldsValue: string[];
  private formatValue: TorrentFormat = TorrentFormat.OBJECTS;

  /**
   * @param fields fields to request; defaults to {@link TorrentFields.BASIC}
   */
  constructor(fields: string[] = TorrentFields.BASIC) {
    this.fieldsValue = fields.slice();
  }

  /** Restricts the query to `ids`. */
  ids(ids: TorrentIds): TorrentGetRequest {
    this.idsValue = ids;
    return this;
  }

  /** Replaces the field selection. */
  fields(fields: string[]): TorrentGetRequest {
    this.fieldsValue.length = 0;
    for (const field of fields) {
      this.fieldsValue.push(field);
    }
    return this;
  }

  /** Appends one field to the selection. */
  addField(field: string): TorrentGetRequest {
    if (!this.fieldsValue.includes(field)) {
      this.fieldsValue.push(field);
    }
    return this;
  }

  /** Appends several fields to the selection. */
  addFields(fields: string[]): TorrentGetRequest {
    for (const field of fields) {
      this.addField(field);
    }
    return this;
  }

  /** Chooses the response encoding. */
  format(format: TorrentFormat): TorrentGetRequest {
    this.formatValue = format;
    return this;
  }

  /** The addressed torrents. */
  get idsValueOrAll(): TorrentIds {
    return this.idsValue;
  }

  /** The requested fields, as a copy. */
  get fieldsList(): string[] {
    return this.fieldsValue.slice();
  }

  /** The requested response encoding. */
  get formatMode(): TorrentFormat {
    return this.formatValue;
  }

  /** Serialises the request into RPC parameters. */
  toJson(): JsonObject {
    const builder = new JsonObjectBuilder();
    this.idsValue.applyTo(builder);
    builder.setAlways('fields', this.fieldsValue.slice() as JsonArray);
    builder.setAlways('format', this.formatValue);
    return builder.build();
  }
}

/**
 * Request of the `torrent_add` method.
 *
 * Either {@link filename} or {@link metainfo} must be provided.
 */
export class TorrentAddRequest {
  private readonly params: JsonObjectBuilder = new JsonObjectBuilder();

  /** Creates an empty request. */
  static create(): TorrentAddRequest {
    return new TorrentAddRequest();
  }

  /** Adds a torrent from a URL, a local path or a magnet link. */
  static fromFilename(filename: string): TorrentAddRequest {
    return new TorrentAddRequest().filename(filename);
  }

  /** Adds a torrent from a magnet link. */
  static fromMagnet(magnetLink: string): TorrentAddRequest {
    return new TorrentAddRequest().filename(magnetLink);
  }

  /** Adds a torrent from raw `.torrent` bytes, base64-encoding them. */
  static fromBytes(bytes: Uint8Array): TorrentAddRequest {
    return new TorrentAddRequest().metainfoBytes(bytes);
  }

  /** Adds a torrent from an already base64-encoded metainfo blob. */
  static fromMetainfo(base64Metainfo: string): TorrentAddRequest {
    return new TorrentAddRequest().metainfo(base64Metainfo);
  }

  /** Filename, URL or magnet link of the torrent to add. */
  filename(value: string): TorrentAddRequest {
    this.params.set('filename', value);
    return this;
  }

  /** Base64-encoded `.torrent` content. */
  metainfo(base64Metainfo: string): TorrentAddRequest {
    this.params.set('metainfo', base64Metainfo);
    return this;
  }

  /** Base64-encodes `bytes` and uses them as the metainfo payload. */
  metainfoBytes(bytes: Uint8Array): TorrentAddRequest {
    return this.metainfo(Base64.encodeBytes(bytes));
  }

  /** Directory to download into; defaults to the session's `download_dir`. */
  downloadDir(path: string): TorrentAddRequest {
    this.params.set('download_dir', path);
    return this;
  }

  /** Cookies sent when fetching `filename` from a URL. */
  cookies(cookies: string): TorrentAddRequest {
    this.params.set('cookies', cookies);
    return this;
  }

  /** Labels to assign to the new torrent. */
  labels(labels: string[]): TorrentAddRequest {
    this.params.setArray('labels', labels.slice() as JsonArray);
    return this;
  }

  /** When true the torrent is added stopped. */
  paused(paused: boolean): TorrentAddRequest {
    this.params.setBoolean('paused', paused);
    return this;
  }

  /** Maximum number of peers. */
  peerLimit(limit: number): TorrentAddRequest {
    this.params.setNumber('peer_limit', limit);
    return this;
  }

  /** Torrent bandwidth priority. */
  bandwidthPriority(priority: TorrentPriority): TorrentAddRequest {
    this.params.setNumber('bandwidth_priority', priority);
    return this;
  }

  /** Indices of the files to download. */
  filesWanted(indices: number[]): TorrentAddRequest {
    this.params.setArray('files_wanted', indices.slice() as JsonArray);
    return this;
  }

  /** Indices of the files to skip. */
  filesUnwanted(indices: number[]): TorrentAddRequest {
    this.params.setArray('files_unwanted', indices.slice() as JsonArray);
    return this;
  }

  /** Indices of the files to give high priority. */
  priorityHigh(indices: number[]): TorrentAddRequest {
    this.params.setArray('priority_high', indices.slice() as JsonArray);
    return this;
  }

  /** Indices of the files to give low priority. */
  priorityLow(indices: number[]): TorrentAddRequest {
    this.params.setArray('priority_low', indices.slice() as JsonArray);
    return this;
  }

  /** Indices of the files to give normal priority. */
  priorityNormal(indices: number[]): TorrentAddRequest {
    this.params.setArray('priority_normal', indices.slice() as JsonArray);
    return this;
  }

  /** Downloads pieces in order. */
  sequentialDownload(enabled: boolean): TorrentAddRequest {
    this.params.setBoolean('sequential_download', enabled);
    return this;
  }

  /** First piece to download when sequential download is enabled. */
  sequentialDownloadFromPiece(piece: number): TorrentAddRequest {
    this.params.setNumber('sequential_download_from_piece', piece);
    return this;
  }

  /** True when the request carries the mandatory `filename` or `metainfo`. */
  get isComplete(): boolean {
    return this.params.has('filename') || this.params.has('metainfo');
  }

  /** Serialises the request into RPC parameters. */
  toJson(): JsonObject {
    return this.params.build();
  }
}

/**
 * Request of the `torrent_set` method.
 *
 * Only the setters that are called end up on the wire; Transmission applies a
 * field only when it is present, so untouched settings keep their value.
 */
export class TorrentSetRequest {
  private readonly params: JsonObjectBuilder = new JsonObjectBuilder();
  private readonly idsValue: TorrentIds;

  /**
   * @param ids torrents to mutate; defaults to {@link TorrentIds.ALL}
   */
  constructor(ids: TorrentIds = TorrentIds.ALL) {
    this.idsValue = ids;
  }

  /** Changes the addressed torrents. */
  ids(ids: TorrentIds): TorrentSetRequest {
    return new TorrentSetRequest(ids).copyOf(this);
  }

  /** Torrent bandwidth priority. */
  bandwidthPriority(priority: TorrentPriority): TorrentSetRequest {
    this.params.setNumber('bandwidth_priority', priority);
    return this;
  }

  /** Download speed limit in kB/s. */
  downloadLimit(kilobytesPerSecond: number): TorrentSetRequest {
    this.params.setNumber('download_limit', kilobytesPerSecond);
    return this;
  }

  /** Enables or disables the download speed limit. */
  downloadLimited(enabled: boolean): TorrentSetRequest {
    this.params.setBoolean('download_limited', enabled);
    return this;
  }

  /** Upload speed limit in kB/s. */
  uploadLimit(kilobytesPerSecond: number): TorrentSetRequest {
    this.params.setNumber('upload_limit', kilobytesPerSecond);
    return this;
  }

  /** Enables or disables the upload speed limit. */
  uploadLimited(enabled: boolean): TorrentSetRequest {
    this.params.setBoolean('upload_limited', enabled);
    return this;
  }

  /** Whether session-wide speed limits apply to these torrents. */
  honorsSessionLimits(enabled: boolean): TorrentSetRequest {
    this.params.setBoolean('honors_session_limits', enabled);
    return this;
  }

  /** Indices of the files to download. An empty array means "all files". */
  filesWanted(indices: number[]): TorrentSetRequest {
    this.params.setAlways('files_wanted', indices.slice() as JsonArray);
    return this;
  }

  /** Indices of the files to skip. An empty array means "no files". */
  filesUnwanted(indices: number[]): TorrentSetRequest {
    this.params.setAlways('files_unwanted', indices.slice() as JsonArray);
    return this;
  }

  /** Indices of the files to give high priority. */
  priorityHigh(indices: number[]): TorrentSetRequest {
    this.params.setAlways('priority_high', indices.slice() as JsonArray);
    return this;
  }

  /** Indices of the files to give low priority. */
  priorityLow(indices: number[]): TorrentSetRequest {
    this.params.setAlways('priority_low', indices.slice() as JsonArray);
    return this;
  }

  /** Indices of the files to give normal priority. */
  priorityNormal(indices: number[]): TorrentSetRequest {
    this.params.setAlways('priority_normal', indices.slice() as JsonArray);
    return this;
  }

  /** Replaces the torrent's label list. */
  labels(labels: string[]): TorrentSetRequest {
    this.params.setAlways('labels', labels.slice() as JsonArray);
    return this;
  }

  /** Bandwidth group name; an empty string removes the torrent from its group. */
  group(name: string): TorrentSetRequest {
    this.params.setAlways('group', name);
    return this;
  }

  /** New location of the torrent's content. */
  location(path: string): TorrentSetRequest {
    this.params.set('location', path);
    return this;
  }

  /**
   * Renames the torrent.
   *
   * `name` is part of the `torrent-set` table in Transmission's RPC spec, but
   * it is dropped silently by releases that predate it, so a caller that cares
   * has to reload to see whether the change stuck.
   *
   * An empty name is ignored rather than sent: the daemon treats it as a no-op
   * at best and as a rename to the empty string at worst.
   */
  name(value: string): TorrentSetRequest {
    this.params.setNonEmpty('name', value);
    return this;
  }

  /** Maximum number of peers. */
  peerLimit(limit: number): TorrentSetRequest {
    this.params.setNumber('peer_limit', limit);
    return this;
  }

  /** Position in the queue, `0` being the front. */
  queuePosition(position: number): TorrentSetRequest {
    this.params.setNumber('queue_position', position);
    return this;
  }

  /** Minutes of seeding inactivity before the torrent stops. */
  seedIdleLimit(minutes: number): TorrentSetRequest {
    this.params.setNumber('seed_idle_limit', minutes);
    return this;
  }

  /** Which seeding-inactivity rule applies. */
  seedIdleMode(mode: IdleLimitMode): TorrentSetRequest {
    this.params.setNumber('seed_idle_mode', mode);
    return this;
  }

  /** Seeding ratio limit. */
  seedRatioLimit(ratio: number): TorrentSetRequest {
    this.params.setNumber('seed_ratio_limit', ratio);
    return this;
  }

  /** Which seeding-ratio rule applies. */
  seedRatioMode(mode: RatioLimitMode): TorrentSetRequest {
    this.params.setNumber('seed_ratio_mode', mode);
    return this;
  }

  /** Downloads pieces in order. */
  sequentialDownload(enabled: boolean): TorrentSetRequest {
    this.params.setBoolean('sequential_download', enabled);
    return this;
  }

  /** First piece to download when sequential download is enabled. */
  sequentialDownloadFromPiece(piece: number): TorrentSetRequest {
    this.params.setNumber('sequential_download_from_piece', piece);
    return this;
  }

  /** Replaces the whole tracker list (announce URLs, blank line between tiers). */
  trackerList(announceUrls: string): TorrentSetRequest {
    this.params.setAlways('tracker_list', announceUrls);
    return this;
  }

  /** **Deprecated by Transmission:** prefer {@link trackerList}. */
  trackerAdd(urls: string[]): TorrentSetRequest {
    this.params.setArray('tracker_add', urls.slice() as JsonArray);
    return this;
  }

  /** **Deprecated by Transmission:** prefer {@link trackerList}. */
  trackerRemove(ids: number[]): TorrentSetRequest {
    this.params.setArray('tracker_remove', ids.slice() as JsonArray);
    return this;
  }

  /** **Deprecated by Transmission:** prefer {@link trackerList}. */
  trackerReplace(pairs: number[][]): TorrentSetRequest {
    const flat: JsonArray = [];
    for (const pair of pairs) {
      flat.push(pair.slice() as JsonArray);
    }
    this.params.setArray('tracker_replace', flat);
    return this;
  }

  /** True when at least one setting has been provided. */
  get hasChanges(): boolean {
    return !Json.isEmpty(this.params.build());
  }

  /** Serialises the request into RPC parameters. */
  toJson(): JsonObject {
    const builder = new JsonObjectBuilder();
    this.idsValue.applyTo(builder);
    const changes = this.params.build();
    for (const key of Json.keys(changes)) {
      builder.set(key, changes[key]);
    }
    return builder.build();
  }

  /** Copies accumulated settings onto a fresh instance with different ids. */
  private copyOf(source: TorrentSetRequest): TorrentSetRequest {
    const changes = source.params.build();
    for (const key of Json.keys(changes)) {
      this.params.set(key, changes[key]);
    }
    return this;
  }
}

/** Convenience alias so callers can spell out the parsed model type. */
export type TorrentList = Torrent[];
