// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * View model of the torrent detail screen.
 *
 * All five tabs are fed by a single `torrent_get`, so the fetch, the mutation
 * and the row shaping live here: the page copies the result into `@State` and
 * never assembles an RPC request itself. That split is the intended way to use
 * the SDK from the sample application, and it keeps the SDK objects testable
 * without an ArkUI runtime.
 *
 * @since 1.0.0
 */

import {
  Torrent,
  TorrentGetRequest,
  TorrentIds,
  TorrentSetRequest,
  Tracker,
  TrackerAnnounceState,
  TrackerScrapeState,
  TrackerStat,
  TransmissionClient,
} from 'transmission_sdk';
import { AppContext, describeErrorResource } from '../store/AppContext';

/** One tracker of the Trackers tab, joined with its statistics. */
export class TrackerRow {
  /** Tracker id, used to find the matching statistics entry. */
  id: number = 0;
  /** Announce URL as stored in the torrent. */
  announce: string = '';
  /** Host reported by the server, or derived from the announce URL. */
  host: string = '';
  /** Tier the tracker belongs to; lower tiers are announced to first. */
  tier: number = 0;
  /** True when a `tracker_stats` entry with the same id was found. */
  hasStat: boolean = false;
  /** Announce state reported by `tracker_stats`. */
  announceState: TrackerAnnounceState = TrackerAnnounceState.INACTIVE;
  /** Scrape state reported by `tracker_stats`. */
  scrapeState: TrackerScrapeState = TrackerScrapeState.INACTIVE;
  /** Unix timestamp of the last announce. */
  lastAnnounce: number = 0;
  /** Unix timestamp of the next announce. */
  nextAnnounce: number = 0;
  /** Unix timestamp of the last scrape; the Trackers tab counts down from it. */
  lastScrape: number = 0;
  /** Seeders reported by the tracker, or `-1` when unknown. */
  seeders: number = -1;
  /** Leechers reported by the tracker, or `-1` when unknown. */
  leechers: number = -1;
  /** Completed downloads reported by the tracker, or `-1` when unknown. */
  downloads: number = -1;
}

/** Drives the torrent detail screen. */
export class TorrentDetailModel {
  /** The torrent last loaded, or `undefined` before the first success. */
  torrent: Torrent | undefined = undefined;
  /** True while a request is in flight, so the page can disable its buttons. */
  loading: boolean = false;
  /** Localised failure of the most recent call; cleared on every new attempt. */
  errorResource: Resource | undefined = undefined;

  /**
   * An all-defaults torrent handed to the UI before the first load completes.
   *
   * ArkUI builders always have to describe a complete tree, and TypeScript does
   * not narrow a `@State` union inside a separate `@Builder` method; rendering
   * this instance keeps the builders free of `undefined` checks.
   */
  static readonly EMPTY: Torrent = new Torrent();

  /** Fields the detail screen needs. */
  static readonly FIELDS: string[] = [
    // Identity and metadata.
    'id',
    'hash_string',
    'name',
    'comment',
    'creator',
    'magnet_link',
    'download_dir',
    'group',
    'labels',
    // Timestamps rendered by the Info tab.
    'activity_date',
    'added_date',
    'date_created',
    'edit_date',
    'done_date',
    'start_date',
    // Lifecycle and health.
    'status',
    'error',
    'error_string',
    'is_finished',
    'is_private',
    'is_stalled',
    'bandwidth_priority',
    // Sizes and transfer totals.
    'total_size',
    'left_until_done',
    'size_when_done',
    'downloaded_ever',
    'uploaded_ever',
    'have_valid',
    'have_unchecked',
    'corrupt_ever',
    'desired_available',
    // Progress fractions.
    'percent_done',
    'percent_complete',
    'metadata_percent_complete',
    'recheck_progress',
    'upload_ratio',
    // Rates and durations.
    'rate_download',
    'rate_upload',
    'eta',
    'eta_idle',
    'seconds_downloading',
    'seconds_seeding',
    // Peer summary and the peer list itself.
    'peers_connected',
    'max_connected_peers',
    'peer_limit',
    'peers_getting_from_us',
    'peers_sending_to_us',
    'webseeds_sending_to_us',
    'peers_from',
    'peers',
    // Per-torrent speed limits, used by the Options tab.
    'download_limit',
    'download_limited',
    'upload_limit',
    'upload_limited',
    'honors_session_limits',
    // Seeding limits, used by the Options tab.
    'seed_idle_limit',
    'seed_idle_mode',
    'seed_ratio_limit',
    'seed_ratio_mode',
    // Queueing.
    'queue_position',
    'sequential_download',
    'sequential_download_from_piece',
    // File metadata and its transient state.
    'file_count',
    'files',
    'file_stats',
    // Pieces.
    'piece_count',
    'piece_size',
    // Trackers.
    'trackers',
    'tracker_list',
    'tracker_stats',
    // Webseeds.
    'webseeds_ex',
  ];

  /**
   * Fetches one torrent with every field the detail screen renders.
   *
   * Failures are reported through {@link errorResource} rather than thrown, so
   * the calling page can stay a straight-line `then` chain.
   *
   * @param torrentId id of the torrent to display
   * @returns the torrent, or `undefined` when the call failed
   */
  async load(torrentId: number): Promise<Torrent | undefined> {
    this.loading = true;
    this.errorResource = undefined;
    try {
      const client = AppContext.get().requireClient();
      const request = new TorrentGetRequest(TorrentDetailModel.FIELDS).ids(TorrentIds.single(torrentId));
      const torrents = await client.torrents.get(request);
      if (torrents.length === 0) {
        // The torrent disappeared between navigation and this call, e.g. it was
        // removed from another client. Show a protocol failure instead of a
        // screen full of default values.
        this.torrent = undefined;
        this.errorResource = $r('app.string.error_protocol');
        return undefined;
      }
      const torrent: Torrent = torrents[0];
      this.torrent = torrent;
      return torrent;
    } catch (error) {
      this.torrent = undefined;
      this.errorResource = describeErrorResource(error);
      return undefined;
    } finally {
      this.loading = false;
    }
  }

  /**
   * Applies a prepared `torrent_set` request to one torrent.
   *
   * The ids are forced here so a caller cannot accidentally mutate every
   * torrent by forgetting to address one.
   *
   * @param torrentId id of the torrent to change
   * @param request the settings to apply
   * @returns true when the server accepted the request
   */
  async apply(torrentId: number, request: TorrentSetRequest): Promise<boolean> {
    try {
      const client = AppContext.get().requireClient();
      await client.torrents.set(request.ids(TorrentIds.single(torrentId)));
      // The list behind this screen shows the torrent too.
      AppContext.get().notifyChanged();
      return true;
    } catch (error) {
      this.errorResource = describeErrorResource(error);
      return false;
    }
  }

  /**
   * Re-reads the torrent after a mutation.
   *
   * Transmission does not echo the new state, so applying a setting is always
   * followed by a `torrent_get` to show what the daemon actually accepted.
   *
   * @param torrentId id of the torrent to re-read
   */
  async reload(torrentId: number): Promise<Torrent | undefined> {
    return this.load(torrentId);
  }

  /**
   * Renames a file or directory inside the torrent.
   *
   * @param torrentId id of the torrent
   * @param path current path of the file or directory
   * @param name new name
   * @returns true when the rename succeeded
   */
  async renamePath(torrentId: number, path: string, name: string): Promise<boolean> {
    try {
      const client = AppContext.get().requireClient();
      await client.torrents.renamePath(torrentId, path, name);
      AppContext.get().notifyChanged();
      return true;
    } catch (error) {
      this.errorResource = describeErrorResource(error);
      return false;
    }
  }

  /** Resumes one torrent. */
  async start(torrentId: number): Promise<boolean> {
    return this.runOnOne(torrentId, (client: TransmissionClient, ids: TorrentIds) => client.torrents.start(ids));
  }

  /** Pauses one torrent. */
  async stop(torrentId: number): Promise<boolean> {
    return this.runOnOne(torrentId, (client: TransmissionClient, ids: TorrentIds) => client.torrents.stop(ids));
  }

  /** Queues a recheck of the local data. */
  async verify(torrentId: number): Promise<boolean> {
    return this.runOnOne(torrentId, (client: TransmissionClient, ids: TorrentIds) => client.torrents.verify(ids));
  }

  /** Asks the trackers for more peers right now. */
  async reannounce(torrentId: number): Promise<boolean> {
    return this.runOnOne(torrentId, (client: TransmissionClient, ids: TorrentIds) => client.torrents.reannounce(ids));
  }

  /**
   * Removes the torrent, optionally with the files it downloaded.
   *
   * @param torrentId id of the torrent
   * @param deleteLocalData true to delete the downloaded files on the server
   */
  async remove(torrentId: number, deleteLocalData: boolean): Promise<boolean> {
    return this.runOnOne(
      torrentId,
      (client: TransmissionClient, ids: TorrentIds) => client.torrents.remove(ids, deleteLocalData),
    );
  }

  /**
   * Moves a torrent's content to another directory.
   *
   * @param torrentId id of the torrent
   * @param location new download directory
   * @param move true to move the files that are already on disk
   */
  async setLocation(torrentId: number, location: string, move: boolean): Promise<boolean> {
    return this.runOnOne(
      torrentId,
      (client: TransmissionClient, ids: TorrentIds) => client.torrents.setLocation(ids, location, move),
    );
  }

  /**
   * Runs an id-only torrent command and announces the change.
   *
   * All six commands share this shape: address one torrent, await, tell the list
   * screen that something moved. Only the failure handling differs from a direct
   * call, and it differs once, here.
   */
  private async runOnOne(
    torrentId: number,
    run: (client: TransmissionClient, ids: TorrentIds) => Promise<void>,
  ): Promise<boolean> {
    try {
      const client = AppContext.get().requireClient();
      await run(client, TorrentIds.single(torrentId));
      AppContext.get().notifyChanged();
      return true;
    } catch (error) {
      this.errorResource = describeErrorResource(error);
      return false;
    }
  }

  /**
   * Joins `trackers` with the `tracker_stats` entry that shares its id.
   *
   * The two arrays are not guaranteed to be aligned, so they are matched by id
   * rather than by position.
   *
   * @param torrent the loaded torrent
   */
  static buildTrackerRows(torrent: Torrent): TrackerRow[] {
    const rows: TrackerRow[] = [];
    for (const tracker of torrent.trackers) {
      const typed: Tracker = tracker;
      const row = new TrackerRow();
      row.id = typed.id;
      row.announce = typed.announce;
      row.tier = typed.tier;
      row.host = TorrentDetailModel.hostOf(typed.announce);
      const stat = TorrentDetailModel.findTrackerStat(torrent, typed.id);
      if (stat !== undefined) {
        row.hasStat = true;
        if (stat.host.length > 0) {
          row.host = stat.host;
        }
        row.announceState = stat.announceState;
        row.scrapeState = stat.scrapeState;
        row.lastAnnounce = stat.lastAnnounceTime;
        row.nextAnnounce = stat.nextAnnounceTime;
        row.lastScrape = stat.lastScrapeTime;
        row.seeders = stat.seederCount;
        row.leechers = stat.leecherCount;
        row.downloads = stat.downloadCount;
      }
      rows.push(row);
    }
    return rows;
  }

  /**
   * Finds the statistics entry of one tracker.
   *
   * @param torrent the loaded torrent
   * @param trackerId id to look for
   */
  private static findTrackerStat(torrent: Torrent, trackerId: number): TrackerStat | undefined {
    for (const stat of torrent.trackerStats) {
      const typed: TrackerStat = stat;
      if (typed.id === trackerId) {
        return typed;
      }
    }
    return undefined;
  }

  /**
   * Extracts `host:port` from an announce URL.
   *
   * Written by hand because ArkTS does not allow regular expression literals.
   *
   * @param announceUrl e.g. `https://tracker.example.org:443/announce`
   */
  private static hostOf(announceUrl: string): string {
    const schemeEnd = announceUrl.indexOf('://');
    const start = schemeEnd >= 0 ? schemeEnd + 3 : 0;
    const rest = announceUrl.substring(start);
    const slash = rest.indexOf('/');
    return slash >= 0 ? rest.substring(0, slash) : rest;
  }
}
