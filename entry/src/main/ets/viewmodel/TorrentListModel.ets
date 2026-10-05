// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * The torrent list: fetching, filtering, sorting and display formatting.
 *
 * Keeping this out of the page means the list rules (what "active" means, how
 * each sort key breaks ties) are testable and readable in one place, and the
 * page stays a description of the layout.
 *
 * @since 1.0.0
 */

import {
  AppSettings,
  isTorrentBusy,
  TorrentFilter,
  TorrentSort,
} from '../model/AppModels';
import {
  Torrent,
  TorrentFields,
  TorrentGetRequest,
  TorrentIds,
  TorrentStatus,
  TransmissionClient,
  TransmissionError,
} from 'transmission_sdk';
import {
  formatBytes,
  formatPercent,
  formatPercentExact,
  formatRatio,
  formatSpeed,
} from './Formatters';

/**
 * Fields the list and the drawers need.
 *
 * `TorrentFields.PROGRESS` already covers every sort key and every value shown
 * on a row, and deliberately excludes `files`, `peers` and `trackers`: those
 * collections dominate the response size and are only fetched by the detail
 * screen.
 */
export const LIST_FIELDS: string[] = TorrentFields.PROGRESS;

/** One torrent, pre-formatted for the list. */
export class TorrentRow {
  /** Torrent id, used for actions and navigation. */
  id: number = 0;
  /** Display name; falls back to the info-hash for a magnet without metadata. */
  name: string = '';
  /** Info-hash, shown as the subtitle while metadata is still missing. */
  hash: string = '';
  /** Numeric status, used to pick the state label. */
  status: TorrentStatus = TorrentStatus.STOPPED;
  /** Completion, `0..1`. */
  progress: number = 0;
  /** Completion as a percentage string. */
  progressLabel: string = '0%';
  /**
   * Value for the progress bar, `0..1`.
   *
   * While a torrent is being verified this is the *recheck* progress rather than
   * the completion, because that is the only thing moving.
   */
  barValue: number = 0;
  /**
   * The bar's own value with two decimals, e.g. `75.06%`.
   *
   * Which fraction that is depends on {@link isVerifying}: the recheck while
   * verifying, the completion otherwise.
   */
  barPercentLabel: string = '0.00%';
  /** True while the torrent is verifying its local data. */
  isVerifying: boolean = false;
  /** True while the torrent is actively downloading. */
  isDownloading: boolean = false;
  /** Total size. */
  sizeLabel: string = '';
  /**
   * Total uploaded, i.e. what this torrent has contributed.
   *
   * The reference UI pairs it with the share ratio; the download total is
   * already implied by the size and the progress bar.
   */
  uploadedLabel: string = '';
  /** Share ratio. */
  ratioLabel: string = '0.00';
  /** Current download rate. */
  downSpeedLabel: string = '';
  /** Current upload rate. */
  upSpeedLabel: string = '';
  /** True when the torrent is transferring and the pause button makes sense. */
  isRunning: boolean = false;
  /** True when the server reported a torrent-level error. */
  hasError: boolean = false;
  /** Progress bar colour token, already resolved to a resource. */
  progressColor: Resource = $r('app.color.progress_fill');
}

/** Maps a torrent status onto a localised label. */
export function torrentStateLabel(status: TorrentStatus): Resource {
  switch (status) {
    case TorrentStatus.STOPPED:
      return $r('app.string.state_stopped');
    case TorrentStatus.QUEUED_TO_VERIFY:
      return $r('app.string.state_queued_verify');
    case TorrentStatus.VERIFYING:
      return $r('app.string.state_verifying');
    case TorrentStatus.QUEUED_TO_DOWNLOAD:
      return $r('app.string.state_queued_download');
    case TorrentStatus.DOWNLOADING:
      return $r('app.string.state_downloading');
    case TorrentStatus.QUEUED_TO_SEED:
      return $r('app.string.state_queued_seed');
    case TorrentStatus.SEEDING:
      return $r('app.string.state_seeding');
    default:
      return $r('app.string.state_finished');
  }
}

/** Maps a filter onto a localised label. */
export function torrentFilterLabel(filter: TorrentFilter): Resource {
  switch (filter) {
    case TorrentFilter.ACTIVE:
      return $r('app.string.filter_active');
    case TorrentFilter.DOWNLOADING:
      return $r('app.string.filter_downloading');
    case TorrentFilter.SEEDING:
      return $r('app.string.filter_seeding');
    case TorrentFilter.PAUSED:
      return $r('app.string.filter_paused');
    case TorrentFilter.DOWNLOADED:
      return $r('app.string.filter_downloaded');
    case TorrentFilter.COMPLETED:
      return $r('app.string.filter_completed');
    default:
      return $r('app.string.filter_all');
  }
}

/** Maps a sort key onto a localised label. */
export function torrentSortLabel(sort: TorrentSort): Resource {
  switch (sort) {
    case TorrentSort.ACTIVITY:
      return $r('app.string.sort_activity');
    case TorrentSort.ADDED_DATE:
      return $r('app.string.sort_added_date');
    case TorrentSort.LAST_ACTIVITY:
      return $r('app.string.sort_last_activity');
    case TorrentSort.NAME:
      return $r('app.string.sort_name');
    case TorrentSort.PROGRESS:
      return $r('app.string.sort_progress');
    case TorrentSort.SIZE:
      return $r('app.string.sort_size');
    case TorrentSort.STATE:
      return $r('app.string.sort_state');
    case TorrentSort.ETA:
      return $r('app.string.sort_eta');
    case TorrentSort.RATIO:
      return $r('app.string.sort_ratio');
    case TorrentSort.DOWNLOAD_SPEED:
      return $r('app.string.sort_download_speed');
    case TorrentSort.UPLOAD_SPEED:
      return $r('app.string.sort_upload_speed');
    default:
      return $r('app.string.sort_queue');
  }
}

/** Every filter, in the order the drawer lists them. */
export const ALL_FILTERS: TorrentFilter[] = [
  TorrentFilter.ALL,
  TorrentFilter.ACTIVE,
  TorrentFilter.DOWNLOADING,
  TorrentFilter.SEEDING,
  TorrentFilter.PAUSED,
  TorrentFilter.DOWNLOADED,
  TorrentFilter.COMPLETED,
];

/** Every sort key, in the order the drawer lists them. */
export const ALL_SORTS: TorrentSort[] = [
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

/**
 * True when `torrent` belongs in a list filtered by `filter`.
 *
 * The reference UI distinguishes two "done" filters, so this does too:
 * `DOWNLOADED` means every wanted byte is present, `COMPLETED` additionally
 * requires that the torrent is no longer downloading.
 */
export function matchesFilter(torrent: Torrent, filter: TorrentFilter): boolean {
  switch (filter) {
    case TorrentFilter.ACTIVE:
      return torrent.status === TorrentStatus.DOWNLOADING || torrent.status === TorrentStatus.SEEDING;
    case TorrentFilter.DOWNLOADING:
      return (
        torrent.status === TorrentStatus.DOWNLOADING ||
        torrent.status === TorrentStatus.QUEUED_TO_DOWNLOAD ||
        torrent.status === TorrentStatus.VERIFYING ||
        torrent.status === TorrentStatus.QUEUED_TO_VERIFY
      );
    case TorrentFilter.SEEDING:
      return torrent.status === TorrentStatus.SEEDING || torrent.status === TorrentStatus.QUEUED_TO_SEED;
    case TorrentFilter.PAUSED:
      return torrent.status === TorrentStatus.STOPPED;
    case TorrentFilter.DOWNLOADED:
      return torrent.isFinished;
    case TorrentFilter.COMPLETED:
      return torrent.isFinished && torrent.status !== TorrentStatus.DOWNLOADING;
    default:
      return true;
  }
}

/** Number of torrents a filter would show. */
export function countForFilter(torrents: Torrent[], filter: TorrentFilter): number {
  let count = 0;
  for (const torrent of torrents) {
    if (matchesFilter(torrent, filter)) {
      count++;
    }
  }
  return count;
}

/**
 * Reads the value a sort key orders by.
 *
 * `eta` and `queue_position` need care: Transmission reports `-1` for "unknown"
 * on both, and sorting unknown values first would push brand-new torrents to
 * the top of an ETA sort.
 */
function sortKeyOf(torrent: Torrent, sort: TorrentSort): number {
  switch (sort) {
    case TorrentSort.ACTIVITY:
      return torrent.activityDate;
    case TorrentSort.ADDED_DATE:
      return torrent.addedDate;
    case TorrentSort.LAST_ACTIVITY:
      return torrent.activityDate;
    case TorrentSort.PROGRESS:
      return torrent.percentDone;
    case TorrentSort.SIZE:
      return torrent.totalSize;
    case TorrentSort.STATE:
      return torrent.status;
    case TorrentSort.ETA:
      return torrent.eta < 0 ? Number.MAX_SAFE_INTEGER : torrent.eta;
    case TorrentSort.RATIO:
      return torrent.uploadRatio;
    case TorrentSort.DOWNLOAD_SPEED:
      return torrent.rateDownload;
    case TorrentSort.UPLOAD_SPEED:
      return torrent.rateUpload;
    case TorrentSort.QUEUE:
      return torrent.queuePosition;
    default:
      return 0;
  }
}

/**
 * Returns a sorted copy of `torrents`.
 *
 * Ties always fall back to the queue position so that the list does not shuffle
 * between two polls when many torrents share a value (every paused torrent has
 * the same progress, for example).
 */
export function sortTorrents(torrents: Torrent[], sort: TorrentSort, ascending: boolean): Torrent[] {
  const copy: Torrent[] = torrents.slice();
  const direction = ascending ? 1 : -1;
  copy.sort((left: Torrent, right: Torrent): number => {
    let result = 0;
    if (sort === TorrentSort.NAME) {
      const a = left.name.length > 0 ? left.name : left.hashString;
      const b = right.name.length > 0 ? right.name : right.hashString;
      result = a < b ? -1 : a > b ? 1 : 0;
    } else {
      const a = sortKeyOf(left, sort);
      const b = sortKeyOf(right, sort);
      result = a < b ? -1 : a > b ? 1 : 0;
    }
    if (result === 0) {
      return left.queuePosition - right.queuePosition;
    }
    return result * direction;
  });
  return copy;
}

/** Builds the display row for one torrent. */
export function toRow(torrent: Torrent): TorrentRow {
  const row = new TorrentRow();
  row.id = torrent.id;
  row.hash = torrent.hashString;
  row.name = torrent.name.length > 0 ? torrent.name : torrent.hashString;
  row.status = torrent.status;
  const verifying = torrent.status === TorrentStatus.VERIFYING;
  row.isVerifying = verifying;
  row.progress = torrent.percentDone;
  row.progressLabel = formatPercent(torrent.percentDone);
  row.isDownloading = torrent.status === TorrentStatus.DOWNLOADING;
  row.barValue = verifying ? torrent.recheckProgress : torrent.percentDone;
  row.barPercentLabel = formatPercentExact(row.barValue);
  row.sizeLabel = formatBytes(torrent.totalSize);
  row.uploadedLabel = formatBytes(torrent.uploadedEver);
  row.ratioLabel = formatRatio(torrent.uploadRatio);
  row.downSpeedLabel = formatSpeed(torrent.rateDownload);
  row.upSpeedLabel = formatSpeed(torrent.rateUpload);
  row.isRunning =
    torrent.status === TorrentStatus.DOWNLOADING ||
    torrent.status === TorrentStatus.SEEDING ||
    torrent.status === TorrentStatus.QUEUED_TO_DOWNLOAD ||
    torrent.status === TorrentStatus.QUEUED_TO_SEED;
  row.hasError = torrent.error !== 0 || torrent.errorString.length > 0;
  row.progressColor = verifying
    ? $r('app.color.progress_fill_verify')
    : row.hasError
      ? $r('app.color.progress_fill_error')
      : torrent.isFinished
        ? $r('app.color.progress_fill_done')
        : $r('app.color.progress_fill');
  return row;
}

/**
 * Loads, filters and sorts the torrent list.
 *
 * The model holds the raw `Torrent[]` as well as the display rows so that
 * changing a filter or sort key never needs another round trip.
 */
export class TorrentListModel {
  /** Raw torrents as returned by the server. */
  torrents: Torrent[] = [];
  /** Rows to render, already filtered and sorted. */
  rows: TorrentRow[] = [];
  /** Torrent count per filter, for the drawer badges. */
  counts: Map<TorrentFilter, number> = new Map<TorrentFilter, number>();
  /**
   * The failure of the last load, or `undefined` on success.
   *
   * Deliberately the raw error rather than a `Resource`: mapping it to a
   * user-facing message is the page's job, and keeping the store out of this
   * file is what lets the filter and sort logic be unit-tested on the host.
   */
  lastError: Error | undefined = undefined;
  /** True while a load is in flight. */
  loading: boolean = false;

  /**
   * Fetches the list.
   *
   * @param client connected SDK client
   * @param settings current filter and sort
   * @returns true on success
   */
  async load(client: TransmissionClient, settings: AppSettings): Promise<boolean> {
    this.loading = true;
    this.lastError = undefined;
    try {
      const request = new TorrentGetRequest(LIST_FIELDS).ids(TorrentIds.ALL);
      this.torrents = await client.torrents.get(request);
      this.recompute(settings);
      return true;
    } catch (error) {
      // ArkTS gives a catch parameter no static type; `tsc` calls it `unknown`.
      // Both are satisfied by narrowing through `Error`.
      const failure = error as Error;
      this.lastError = failure;
      if (failure instanceof TransmissionError) {
        console.warn(`torrent list load failed: ${failure.fullMessage}`);
      }
      return false;
    } finally {
      this.loading = false;
    }
  }

  /** Re-applies the filter and sort without contacting the server. */
  recompute(settings: AppSettings): void {
    this.counts = new Map<TorrentFilter, number>();
    for (const filter of ALL_FILTERS) {
      this.counts.set(filter, countForFilter(this.torrents, filter));
    }
    const matching: Torrent[] = [];
    for (const torrent of this.torrents) {
      if (matchesFilter(torrent, settings.filter)) {
        matching.push(torrent);
      }
    }
    const sorted = sortTorrents(matching, settings.sortBy, settings.sortAscending);
    const rows: TorrentRow[] = [];
    for (const torrent of sorted) {
      rows.push(toRow(torrent));
    }
    this.rows = rows;
  }

  /** Number of torrents matching `filter`. */
  count(filter: TorrentFilter): number {
    const value = this.counts.get(filter);
    return value === undefined ? 0 : value;
  }

  /**
   * True when at least one torrent is moving.
   *
   * Drives the automatic refresh: a static list does not need polling, but a
   * downloading or verifying one has to keep up with its progress bar.
   */
  get hasActiveTorrents(): boolean {
    for (const torrent of this.torrents) {
      if (isTorrentBusy(torrent.status)) {
        return true;
      }
    }
    return false;
  }

  /** Total download rate across every torrent, in bytes per second. */
  get totalDownloadRate(): number {
    let total = 0;
    for (const torrent of this.torrents) {
      total += torrent.rateDownload;
    }
    return total;
  }

  /** Total upload rate across every torrent, in bytes per second. */
  get totalUploadRate(): number {
    let total = 0;
    for (const torrent of this.torrents) {
      total += torrent.rateUpload;
    }
    return total;
  }
}
