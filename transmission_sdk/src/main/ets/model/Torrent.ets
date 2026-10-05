// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Torrent models returned by `torrent_get`.
 *
 * Every property carries a sensible default so that a torrent object is always
 * safe to read, even when the requested `fields` list was partial or the server
 * predates a field. Callers that need "was this field present?" semantics can
 * request the field explicitly and compare against the documented default.
 *
 * @since 1.0.0
 */

import { Json, JsonObject, JsonValue } from '../util/Json';
import {
  FilePriority,
  IdleLimitMode,
  RatioLimitMode,
  TorrentPriority,
  TorrentStatus,
  TrackerAnnounceState,
  TrackerScrapeState,
} from './Enums';

/** One entry of a torrent's `files` array. */
export class TorrentFile {
  /** File name, relative to the torrent's download directory. */
  name: string = '';
  /** File length in bytes. */
  length: number = 0;
  /** Bytes of this file that have been downloaded. */
  bytesCompleted: number = 0;
  /** Index of the first piece that belongs to this file. */
  beginPiece: number = 0;
  /** Index of the last piece that belongs to this file. */
  endPiece: number = 0;

  /**
   * Parses one `files` entry.
   *
   * @param json wire object
   */
  static fromJson(json: JsonObject | undefined): TorrentFile {
    const file = new TorrentFile();
    file.name = Json.getString(json, 'name');
    file.length = Json.getNumber(json, 'length');
    file.bytesCompleted = Json.getNumber(json, 'bytes_completed');
    file.beginPiece = Json.getNumber(json, 'begin_piece');
    file.endPiece = Json.getNumber(json, 'end_piece');
    return file;
  }
}

/** One entry of a torrent's `file_stats` array. */
export class TorrentFileStat {
  /** Bytes of this file that have been downloaded. */
  bytesCompleted: number = 0;
  /** True when the file is scheduled for download. */
  wanted: boolean = false;
  /** File priority: `-1` low, `0` normal, `1` high. */
  priority: FilePriority = FilePriority.NORMAL;

  /**
   * Parses one `file_stats` entry.
   *
   * @param json wire object
   */
  static fromJson(json: JsonObject | undefined): TorrentFileStat {
    const stat = new TorrentFileStat();
    stat.bytesCompleted = Json.getNumber(json, 'bytes_completed');
    stat.wanted = Json.getBoolean(json, 'wanted');
    stat.priority = Json.getNumber(json, 'priority', FilePriority.NORMAL) as FilePriority;
    return stat;
  }
}

/** One entry of a torrent's `peers` array. */
export class Peer {
  /** `host:port` of the peer. */
  address: string = '';
  /** The peer's BEP 20 peer id. */
  peerId: string = '';
  /** Client name reported by the peer. */
  clientName: string = '';
  /** Port the peer is listening on. */
  port: number = 0;
  /** Bytes sent to this peer since the torrent started. */
  bytesToPeer: number = 0;
  /** Bytes received from this peer since the torrent started. */
  bytesToClient: number = 0;
  /** Current upload rate to this peer, in bytes per second. */
  rateToPeer: number = 0;
  /** Current download rate from this peer, in bytes per second. */
  rateToClient: number = 0;
  /** The peer's completion percentage, `0.0` – `1.0`. */
  progress: number = 0;
  /** Human readable flags, e.g. `"UE"`. */
  flagStr: string = '';
  /** True when we are choking the peer. */
  clientIsChoked: boolean = false;
  /** True when we are interested in the peer. */
  clientIsInterested: boolean = false;
  /** True when the peer is choking us. */
  peerIsChoked: boolean = false;
  /** True when the peer is interested in us. */
  peerIsInterested: boolean = false;
  /** True when we are downloading from the peer. */
  isDownloadingFrom: boolean = false;
  /** True when we are uploading to the peer. */
  isUploadingTo: boolean = false;
  /** True when the connection is encrypted. */
  isEncrypted: boolean = false;
  /** True when the connection was initiated by the peer. */
  isIncoming: boolean = false;
  /** True when the connection uses uTP. */
  isUtp: boolean = false;
  /** True when the peer supports BEP 55 hole punching. */
  supportsHolepunch: boolean = false;

  /**
   * Parses one `peers` entry.
   *
   * @param json wire object
   */
  static fromJson(json: JsonObject | undefined): Peer {
    const peer = new Peer();
    peer.address = Json.getString(json, 'address');
    peer.peerId = Json.getString(json, 'peer_id');
    peer.clientName = Json.getString(json, 'client_name');
    peer.port = Json.getNumber(json, 'port');
    peer.bytesToPeer = Json.getNumber(json, 'bytes_to_peer');
    peer.bytesToClient = Json.getNumber(json, 'bytes_to_client');
    peer.rateToPeer = Json.getNumber(json, 'rate_to_peer');
    peer.rateToClient = Json.getNumber(json, 'rate_to_client');
    peer.progress = Json.getNumber(json, 'progress');
    peer.flagStr = Json.getString(json, 'flag_str');
    peer.clientIsChoked = Json.getBoolean(json, 'client_is_choked');
    peer.clientIsInterested = Json.getBoolean(json, 'client_is_interested');
    peer.peerIsChoked = Json.getBoolean(json, 'peer_is_choked');
    peer.peerIsInterested = Json.getBoolean(json, 'peer_is_interested');
    peer.isDownloadingFrom = Json.getBoolean(json, 'is_downloading_from');
    peer.isUploadingTo = Json.getBoolean(json, 'is_uploading_to');
    peer.isEncrypted = Json.getBoolean(json, 'is_encrypted');
    peer.isIncoming = Json.getBoolean(json, 'is_incoming');
    peer.isUtp = Json.getBoolean(json, 'is_utp');
    peer.supportsHolepunch = Json.getBoolean(json, 'supports_holepunch');
    return peer;
  }
}

/** The `peers_from` object, describing how peers were discovered. */
export class PeerSources {
  /** Peers discovered through the peer cache. */
  fromCache: number = 0;
  /** Peers discovered through DHT. */
  fromDht: number = 0;
  /** Peers discovered through BEP 55 hole punching. */
  fromHolepunch: number = 0;
  /** Peers that connected to us. */
  fromIncoming: number = 0;
  /** Peers discovered through local peer discovery. */
  fromLpd: number = 0;
  /** Peers discovered through LTEP. */
  fromLtep: number = 0;
  /** Peers discovered through PEX. */
  fromPex: number = 0;
  /** Peers discovered through trackers. */
  fromTracker: number = 0;

  /** Sum of every discovery source. */
  get total(): number {
    return (
      this.fromCache +
      this.fromDht +
      this.fromHolepunch +
      this.fromIncoming +
      this.fromLpd +
      this.fromLtep +
      this.fromPex +
      this.fromTracker
    );
  }

  /**
   * Parses a `peers_from` object.
   *
   * @param json wire object
   */
  static fromJson(json: JsonObject | undefined): PeerSources {
    const sources = new PeerSources();
    sources.fromCache = Json.getNumber(json, 'from_cache');
    sources.fromDht = Json.getNumber(json, 'from_dht');
    sources.fromHolepunch = Json.getNumber(json, 'from_holepunch');
    sources.fromIncoming = Json.getNumber(json, 'from_incoming');
    sources.fromLpd = Json.getNumber(json, 'from_lpd');
    sources.fromLtep = Json.getNumber(json, 'from_ltep');
    sources.fromPex = Json.getNumber(json, 'from_pex');
    sources.fromTracker = Json.getNumber(json, 'from_tracker');
    return sources;
  }
}

/** One entry of a torrent's `trackers` array. */
export class Tracker {
  /** Numeric tracker id. */
  id: number = 0;
  /** Announce URL. */
  announce: string = '';
  /** Scrape URL. */
  scrape: string = '';
  /** Human readable site name, when known. */
  siteName: string = '';
  /** Tier the tracker belongs to; lower tiers are tried first. */
  tier: number = 0;

  /**
   * Parses one `trackers` entry.
   *
   * @param json wire object
   */
  static fromJson(json: JsonObject | undefined): Tracker {
    const tracker = new Tracker();
    tracker.id = Json.getNumber(json, 'id');
    tracker.announce = Json.getString(json, 'announce');
    tracker.scrape = Json.getString(json, 'scrape');
    tracker.siteName = Json.getString(json, 'sitename');
    tracker.tier = Json.getNumber(json, 'tier');
    return tracker;
  }
}

/** One entry of a torrent's `tracker_stats` array. */
export class TrackerStat {
  /** Numeric tracker id. */
  id: number = 0;
  /** Announce URL. */
  announce: string = '';
  /** Scrape URL. */
  scrape: string = '';
  /** Host name of the tracker. */
  host: string = '';
  /** Human readable site name, when known. */
  siteName: string = '';
  /** Tier the tracker belongs to. */
  tier: number = 0;
  /** True when this tracker is a backup for its tier. */
  isBackup: boolean = false;
  /** Announce state. */
  announceState: TrackerAnnounceState = TrackerAnnounceState.INACTIVE;
  /** Scrape state. */
  scrapeState: TrackerScrapeState = TrackerScrapeState.INACTIVE;
  /** True when the tracker has been announced to at least once. */
  hasAnnounced: boolean = false;
  /** True when the tracker has been scraped at least once. */
  hasScraped: boolean = false;
  /** Unix timestamp of the last announce. */
  lastAnnounceTime: number = 0;
  /** Unix timestamp of the last announce attempt. */
  lastAnnounceStartTime: number = 0;
  /** True when the last announce succeeded. */
  lastAnnounceSucceeded: boolean = false;
  /** True when the last announce timed out. */
  lastAnnounceTimedOut: boolean = false;
  /** Result message of the last announce. */
  lastAnnounceResult: string = '';
  /** Number of peers the tracker reported during the last announce. */
  lastAnnouncePeerCount: number = 0;
  /** Unix timestamp of the last scrape. */
  lastScrapeTime: number = 0;
  /** Unix timestamp of the last scrape attempt. */
  lastScrapeStartTime: number = 0;
  /** True when the last scrape succeeded. */
  lastScrapeSucceeded: boolean = false;
  /** True when the last scrape timed out. */
  lastScrapeTimedOut: boolean = false;
  /** Result message of the last scrape. */
  lastScrapeResult: string = '';
  /** Unix timestamp of the next announce. */
  nextAnnounceTime: number = 0;
  /** Unix timestamp of the next scrape. */
  nextScrapeTime: number = 0;
  /** Seeders reported by the tracker. */
  seederCount: number = -1;
  /** Leechers reported by the tracker. */
  leecherCount: number = -1;
  /** Completed downloads reported by the tracker. */
  downloadCount: number = -1;

  /**
   * Parses one `tracker_stats` entry.
   *
   * @param json wire object
   */
  static fromJson(json: JsonObject | undefined): TrackerStat {
    const stat = new TrackerStat();
    stat.id = Json.getNumber(json, 'id');
    stat.announce = Json.getString(json, 'announce');
    stat.scrape = Json.getString(json, 'scrape');
    stat.host = Json.getString(json, 'host');
    stat.siteName = Json.getString(json, 'sitename');
    stat.tier = Json.getNumber(json, 'tier');
    stat.isBackup = Json.getBoolean(json, 'is_backup');
    stat.announceState = Json.getNumber(json, 'announce_state') as TrackerAnnounceState;
    stat.scrapeState = Json.getNumber(json, 'scrape_state') as TrackerScrapeState;
    stat.hasAnnounced = Json.getBoolean(json, 'has_announced');
    stat.hasScraped = Json.getBoolean(json, 'has_scraped');
    stat.lastAnnounceTime = Json.getNumber(json, 'last_announce_time');
    stat.lastAnnounceStartTime = Json.getNumber(json, 'last_announce_start_time');
    stat.lastAnnounceSucceeded = Json.getBoolean(json, 'last_announce_succeeded');
    stat.lastAnnounceTimedOut = Json.getBoolean(json, 'last_announce_timed_out');
    stat.lastAnnounceResult = Json.getString(json, 'last_announce_result');
    stat.lastAnnouncePeerCount = Json.getNumber(json, 'last_announce_peer_count');
    stat.lastScrapeTime = Json.getNumber(json, 'last_scrape_time');
    stat.lastScrapeStartTime = Json.getNumber(json, 'last_scrape_start_time');
    stat.lastScrapeSucceeded = Json.getBoolean(json, 'last_scrape_succeeded');
    stat.lastScrapeTimedOut = Json.getBoolean(json, 'last_scrape_timed_out');
    stat.lastScrapeResult = Json.getString(json, 'last_scrape_result');
    stat.nextAnnounceTime = Json.getNumber(json, 'next_announce_time');
    stat.nextScrapeTime = Json.getNumber(json, 'next_scrape_time');
    stat.seederCount = Json.getNumber(json, 'seeder_count', -1);
    stat.leecherCount = Json.getNumber(json, 'leecher_count', -1);
    stat.downloadCount = Json.getNumber(json, 'download_count', -1);
    return stat;
  }
}

/** One entry of a torrent's `webseeds_ex` array. */
export class Webseed {
  /** Base URL of the webseed. */
  url: string = '';
  /** True when data is currently being fetched from this webseed. */
  isDownloading: boolean = false;
  /** Current download rate, in bytes per second. */
  downloadBytesPerSecond: number = 0;

  /**
   * Parses one `webseeds_ex` entry.
   *
   * @param json wire object
   */
  static fromJson(json: JsonObject | undefined): Webseed {
    const webseed = new Webseed();
    webseed.url = Json.getString(json, 'url');
    webseed.isDownloading = Json.getBoolean(json, 'is_downloading');
    webseed.downloadBytesPerSecond = Json.getNumber(json, 'download_bytes_per_second');
    return webseed;
  }
}

/**
 * A torrent as reported by `torrent_get`.
 *
 * Only the fields listed in the request are guaranteed to be meaningful; the
 * rest keep their defaults.
 */
export class Torrent {
  /** Torrent id. Not stable across daemon restarts — use {@link hashString}. */
  id: number = 0;
  /** Lower-case hex info-hash. */
  hashString: string = '';
  /** Display name. */
  name: string = '';
  /** Comment embedded in the metainfo. */
  comment: string = '';
  /** Creator string embedded in the metainfo. */
  creator: string = '';
  /** `magnet:` URI for this torrent. */
  magnetLink: string = '';
  /** Base64-encoded `.torrent` metainfo. */
  torrentFile: string = '';
  /** Primary MIME type of the torrent's content. */
  primaryMimeType: string = '';
  /** Directory the torrent's content is stored in. */
  downloadDir: string = '';
  /** Bandwidth group this torrent belongs to. */
  group: string = '';
  /** User-assigned labels. */
  labels: string[] = [];

  /** Unix timestamp of the last transfer activity. */
  activityDate: number = 0;
  /** Unix timestamp when the torrent was added. */
  addedDate: number = 0;
  /** Unix timestamp when the torrent was created. */
  dateCreated: number = 0;
  /** Unix timestamp of the last metainfo edit. */
  editDate: number = 0;
  /** Unix timestamp when the torrent finished downloading. */
  doneDate: number = 0;
  /** Unix timestamp when the torrent was started. */
  startDate: number = 0;
  /** Unix timestamp of the last manual announce. **Deprecated by Transmission.** */
  manualAnnounceTime: number = 0;

  /** Lifecycle state. */
  status: TorrentStatus = TorrentStatus.STOPPED;
  /** Error code, `0` when healthy. */
  error: number = 0;
  /** Human readable error message. */
  errorString: string = '';
  /** True once the download has completed. */
  isFinished: boolean = false;
  /** True when the torrent is private (DHT/PEX/LPD disabled). */
  isPrivate: boolean = false;
  /** True when the torrent counts as stalled. */
  isStalled: boolean = false;
  /** Torrent bandwidth priority. */
  bandwidthPriority: TorrentPriority = TorrentPriority.NORMAL;

  /** Total size of the torrent, in bytes. */
  totalSize: number = 0;
  /** Bytes left to download. */
  leftUntilDone: number = 0;
  /** Size of the content once complete, in bytes. */
  sizeWhenDone: number = 0;
  /** Bytes downloaded since the torrent was added. */
  downloadedEver: number = 0;
  /** Bytes uploaded since the torrent was added. */
  uploadedEver: number = 0;
  /** Bytes of verified data. */
  haveValid: number = 0;
  /** Bytes present but not yet verified. */
  haveUnchecked: number = 0;
  /** Bytes that failed verification. */
  corruptEver: number = 0;
  /** Bytes available from connected peers, or `-1` when unknown. */
  desiredAvailable: number = 0;

  /** Download completion, `0.0` – `1.0`. */
  percentDone: number = 0;
  /** Download completion including unwanted files, `0.0` – `1.0`. */
  percentComplete: number = 0;
  /** Metainfo download completion for magnet links, `0.0` – `1.0`. */
  metadataPercentComplete: number = 0;
  /** Verify progress of the current recheck, `0.0` – `1.0`. */
  recheckProgress: number = 0;
  /** Upload/download ratio. */
  uploadRatio: number = 0;

  /** Current download rate, in bytes per second. */
  rateDownload: number = 0;
  /** Current upload rate, in bytes per second. */
  rateUpload: number = 0;
  /** Seconds until the download completes, or `-1` when unknown. */
  eta: number = -1;
  /** Seconds until the torrent is idle, or `-1` when unknown. */
  etaIdle: number = -1;
  /** Total seconds spent downloading. */
  secondsDownloading: number = 0;
  /** Total seconds spent seeding. */
  secondsSeeding: number = 0;

  /** Number of connected peers. */
  peersConnected: number = 0;
  /** Maximum number of peers for this torrent. */
  maxConnectedPeers: number = 0;
  /** Configured peer limit. */
  peerLimit: number = 0;
  /** Peers we are downloading from. */
  peersGettingFromUs: number = 0;
  /** Peers we are uploading to. */
  peersSendingToUs: number = 0;
  /** Webseeds we are downloading from. */
  webseedsSendingToUs: number = 0;
  /** How peers were discovered. */
  peersFrom: PeerSources = new PeerSources();
  /** Connected peers. Requires the `peers` field. */
  peers: Peer[] = [];

  /** Download speed limit in kB/s. */
  downloadLimit: number = 0;
  /** True when {@link downloadLimit} is honoured. */
  downloadLimited: boolean = false;
  /** Upload speed limit in kB/s. */
  uploadLimit: number = 0;
  /** True when {@link uploadLimit} is honoured. */
  uploadLimited: boolean = false;
  /** True when session-wide limits apply to this torrent. */
  honorsSessionLimits: boolean = false;

  /** Number of minutes of seeding inactivity before the torrent stops. */
  seedIdleLimit: number = 0;
  /** Which seeding-inactivity rule applies. */
  seedIdleMode: IdleLimitMode = IdleLimitMode.GLOBAL;
  /** Seeding ratio limit. */
  seedRatioLimit: number = 0;
  /** Which seeding-ratio rule applies. */
  seedRatioMode: RatioLimitMode = RatioLimitMode.GLOBAL;

  /** Position in the download/seed queue. */
  queuePosition: number = 0;
  /** True when pieces are downloaded in order. */
  sequentialDownload: boolean = false;
  /** First piece downloaded in sequential mode. */
  sequentialDownloadFromPiece: number = 0;

  /** Number of files in the torrent. */
  fileCount: number = 0;
  /** File metadata. Requires the `files` field. */
  files: TorrentFile[] = [];
  /** Per-file transient state. Requires the `file_stats` field. */
  fileStats: TorrentFileStat[] = [];

  /** Number of pieces in the torrent. */
  pieceCount: number = 0;
  /** Size of each piece, in bytes. */
  pieceSize: number = 0;
  /** Base64-encoded bitfield of the pieces we already have. */
  pieces: string = '';
  /** Per-piece availability, or `-1` for pieces we already have. */
  availability: number[] = [];
  /** Per-file completion, in bytes. */
  bytesCompleted: number[] = [];
  /** Per-file download flags. */
  wanted: boolean[] = [];
  /** Per-file priorities. */
  priorities: number[] = [];

  /** Trackers of this torrent. */
  trackers: Tracker[] = [];
  /** Announce URLs, one per line, blank lines between tiers. */
  trackerList: string = '';
  /** Tracker statistics. */
  trackerStats: TrackerStat[] = [];
  /** **Deprecated** webseed URLs. Prefer {@link webseedsEx}. */
  webseeds: string[] = [];
  /** Webseeds of this torrent. */
  webseedsEx: Webseed[] = [];

  /**
   * Parses a torrent object.
   *
   * @param json wire object with canonical keys
   */
  static fromJson(json: JsonObject | undefined): Torrent {
    const torrent = new Torrent();
    if (json === undefined) {
      return torrent;
    }

    torrent.id = Json.getNumber(json, 'id');
    torrent.hashString = Json.getString(json, 'hash_string');
    torrent.name = Json.getString(json, 'name');
    torrent.comment = Json.getString(json, 'comment');
    torrent.creator = Json.getString(json, 'creator');
    torrent.magnetLink = Json.getString(json, 'magnet_link');
    torrent.torrentFile = Json.getString(json, 'torrent_file');
    torrent.primaryMimeType = Json.getString(json, 'primary_mime_type');
    torrent.downloadDir = Json.getString(json, 'download_dir');
    torrent.group = Json.getString(json, 'group');
    torrent.labels = Json.getStringArray(json, 'labels');

    torrent.activityDate = Json.getNumber(json, 'activity_date');
    torrent.addedDate = Json.getNumber(json, 'added_date');
    torrent.dateCreated = Json.getNumber(json, 'date_created');
    torrent.editDate = Json.getNumber(json, 'edit_date');
    torrent.doneDate = Json.getNumber(json, 'done_date');
    torrent.startDate = Json.getNumber(json, 'start_date');
    torrent.manualAnnounceTime = Json.getNumber(json, 'manual_announce_time');

    torrent.status = Json.getNumber(json, 'status', TorrentStatus.STOPPED) as TorrentStatus;
    torrent.error = Json.getNumber(json, 'error');
    torrent.errorString = Json.getString(json, 'error_string');
    torrent.isFinished = Json.getBoolean(json, 'is_finished');
    torrent.isPrivate = Json.getBoolean(json, 'is_private');
    torrent.isStalled = Json.getBoolean(json, 'is_stalled');
    torrent.bandwidthPriority = Json.getNumber(json, 'bandwidth_priority', TorrentPriority.NORMAL) as TorrentPriority;

    torrent.totalSize = Json.getNumber(json, 'total_size');
    torrent.leftUntilDone = Json.getNumber(json, 'left_until_done');
    torrent.sizeWhenDone = Json.getNumber(json, 'size_when_done');
    torrent.downloadedEver = Json.getNumber(json, 'downloaded_ever');
    torrent.uploadedEver = Json.getNumber(json, 'uploaded_ever');
    torrent.haveValid = Json.getNumber(json, 'have_valid');
    torrent.haveUnchecked = Json.getNumber(json, 'have_unchecked');
    torrent.corruptEver = Json.getNumber(json, 'corrupt_ever');
    torrent.desiredAvailable = Json.getNumber(json, 'desired_available');

    torrent.percentDone = Json.getNumber(json, 'percent_done');
    torrent.percentComplete = Json.getNumber(json, 'percent_complete');
    torrent.metadataPercentComplete = Json.getNumber(json, 'metadata_percent_complete');
    torrent.recheckProgress = Json.getNumber(json, 'recheck_progress');
    torrent.uploadRatio = Json.getNumber(json, 'upload_ratio');

    torrent.rateDownload = Json.getNumber(json, 'rate_download');
    torrent.rateUpload = Json.getNumber(json, 'rate_upload');
    torrent.eta = Json.getNumber(json, 'eta', -1);
    torrent.etaIdle = Json.getNumber(json, 'eta_idle', -1);
    torrent.secondsDownloading = Json.getNumber(json, 'seconds_downloading');
    torrent.secondsSeeding = Json.getNumber(json, 'seconds_seeding');

    torrent.peersConnected = Json.getNumber(json, 'peers_connected');
    torrent.maxConnectedPeers = Json.getNumber(json, 'max_connected_peers');
    torrent.peerLimit = Json.getNumber(json, 'peer_limit');
    torrent.peersGettingFromUs = Json.getNumber(json, 'peers_getting_from_us');
    torrent.peersSendingToUs = Json.getNumber(json, 'peers_sending_to_us');
    torrent.webseedsSendingToUs = Json.getNumber(json, 'webseeds_sending_to_us');
    torrent.peersFrom = PeerSources.fromJson(Json.getObject(json, 'peers_from'));
    torrent.peers = Torrent.parseArray(json, 'peers', Peer.fromJson);

    torrent.downloadLimit = Json.getNumber(json, 'download_limit');
    torrent.downloadLimited = Json.getBoolean(json, 'download_limited');
    torrent.uploadLimit = Json.getNumber(json, 'upload_limit');
    torrent.uploadLimited = Json.getBoolean(json, 'upload_limited');
    torrent.honorsSessionLimits = Json.getBoolean(json, 'honors_session_limits');

    torrent.seedIdleLimit = Json.getNumber(json, 'seed_idle_limit');
    torrent.seedIdleMode = Json.getNumber(json, 'seed_idle_mode', IdleLimitMode.GLOBAL) as IdleLimitMode;
    torrent.seedRatioLimit = Json.getNumber(json, 'seed_ratio_limit');
    torrent.seedRatioMode = Json.getNumber(json, 'seed_ratio_mode', RatioLimitMode.GLOBAL) as RatioLimitMode;

    torrent.queuePosition = Json.getNumber(json, 'queue_position');
    torrent.sequentialDownload = Json.getBoolean(json, 'sequential_download');
    torrent.sequentialDownloadFromPiece = Json.getNumber(json, 'sequential_download_from_piece');

    torrent.fileCount = Json.getNumber(json, 'file_count');
    torrent.files = Torrent.parseArray(json, 'files', TorrentFile.fromJson);
    torrent.fileStats = Torrent.parseArray(json, 'file_stats', TorrentFileStat.fromJson);

    torrent.pieceCount = Json.getNumber(json, 'piece_count');
    torrent.pieceSize = Json.getNumber(json, 'piece_size');
    torrent.pieces = Json.getString(json, 'pieces');
    torrent.availability = Json.toNumberArray(Json.getArray(json, 'availability'));
    torrent.bytesCompleted = Json.toNumberArray(Json.getArray(json, 'bytes_completed'));
    torrent.wanted = Torrent.parseBooleanArray(Json.getArray(json, 'wanted'));
    torrent.priorities = Json.toNumberArray(Json.getArray(json, 'priorities'));

    torrent.trackers = Torrent.parseArray(json, 'trackers', Tracker.fromJson);
    torrent.trackerList = Json.getString(json, 'tracker_list');
    torrent.trackerStats = Torrent.parseArray(json, 'tracker_stats', TrackerStat.fromJson);
    torrent.webseeds = Json.getStringArray(json, 'webseeds');
    torrent.webseedsEx = Torrent.parseArray(json, 'webseeds_ex', Webseed.fromJson);

    return torrent;
  }

  /** True when the torrent is actively downloading or seeding. */
  get isActive(): boolean {
    return this.status === TorrentStatus.DOWNLOADING || this.status === TorrentStatus.SEEDING;
  }

  /** True when the torrent has been fully downloaded. */
  get isComplete(): boolean {
    return this.percentDone >= 1;
  }

  /** Bytes per second transferred in both directions. */
  get totalRate(): number {
    return this.rateDownload + this.rateUpload;
  }

  /** Reads an array field and maps every element through `parse`. */
  private static parseArray<T>(json: JsonObject, key: string, parse: (item: JsonObject) => T): T[] {
    const raw = Json.getArray(json, key);
    const result: T[] = [];
    if (raw === undefined) {
      return result;
    }
    for (const item of raw) {
      const asObject = Json.asObject(item);
      if (asObject !== undefined) {
        result.push(parse(asObject));
      }
    }
    return result;
  }

  /** Reads a `wanted` array, tolerating the legacy `0`/`1` encoding. */
  private static parseBooleanArray(raw: JsonValue[] | undefined): boolean[] {
    const result: boolean[] = [];
    if (raw === undefined) {
      return result;
    }
    for (const item of raw) {
      const asBoolean = Json.asLooseBoolean(item);
      if (asBoolean !== undefined) {
        result.push(asBoolean);
      }
    }
    return result;
  }
}
