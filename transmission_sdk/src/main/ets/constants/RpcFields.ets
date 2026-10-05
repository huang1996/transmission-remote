// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// GENERATED from the Transmission sources - see LICENSE.

/**
 * Field names accepted by the Transmission RPC API.
 *
 * GENERATED FILE - DO NOT EDIT BY HAND.
 *
 * Source of truth: the tables in `docs/rpc-spec.md` of the Transmission repository
 * (the modern / snake_case API). Regenerate with
 * `node scripts/generate-rpc-fields.mjs`.
 *
 * @since 1.0.0
 */
/**
 * Keys accepted by `torrent_get` and `torrent_set`.
 *
 * Wire values are the canonical snake_case names introduced in Transmission 4.1.0.
 * The compatibility layer translates them automatically for older servers.
 *
 * @since 1.0.0
 */
export enum TorrentField {
  /** `activity_date` */
  ACTIVITY_DATE = 'activity_date',
  /** `added_date` */
  ADDED_DATE = 'added_date',
  /** `availability` */
  AVAILABILITY = 'availability',
  /** `bandwidth_priority` */
  BANDWIDTH_PRIORITY = 'bandwidth_priority',
  /** `bytes_completed` */
  BYTES_COMPLETED = 'bytes_completed',
  /** `comment` */
  COMMENT = 'comment',
  /** `corrupt_ever` */
  CORRUPT_EVER = 'corrupt_ever',
  /** `creator` */
  CREATOR = 'creator',
  /** `date_created` */
  DATE_CREATED = 'date_created',
  /** `desired_available` */
  DESIRED_AVAILABLE = 'desired_available',
  /** `done_date` */
  DONE_DATE = 'done_date',
  /** `download_dir` */
  DOWNLOAD_DIR = 'download_dir',
  /** `downloaded_ever` */
  DOWNLOADED_EVER = 'downloaded_ever',
  /** `download_limit` */
  DOWNLOAD_LIMIT = 'download_limit',
  /** `download_limited` */
  DOWNLOAD_LIMITED = 'download_limited',
  /** `edit_date` */
  EDIT_DATE = 'edit_date',
  /** `error` */
  ERROR = 'error',
  /** `error_string` */
  ERROR_STRING = 'error_string',
  /** `eta` */
  ETA = 'eta',
  /** `eta_idle` */
  ETA_IDLE = 'eta_idle',
  /** `file_count` */
  FILE_COUNT = 'file_count',
  /** `files` */
  FILES = 'files',
  /** `file_stats` */
  FILE_STATS = 'file_stats',
  /** `group` */
  GROUP = 'group',
  /** `hash_string` */
  HASH_STRING = 'hash_string',
  /** `have_unchecked` */
  HAVE_UNCHECKED = 'have_unchecked',
  /** `have_valid` */
  HAVE_VALID = 'have_valid',
  /** `honors_session_limits` */
  HONORS_SESSION_LIMITS = 'honors_session_limits',
  /** `id` */
  ID = 'id',
  /** `is_finished` */
  IS_FINISHED = 'is_finished',
  /** `is_private` */
  IS_PRIVATE = 'is_private',
  /** `is_stalled` */
  IS_STALLED = 'is_stalled',
  /** `labels` */
  LABELS = 'labels',
  /** `left_until_done` */
  LEFT_UNTIL_DONE = 'left_until_done',
  /** `magnet_link` */
  MAGNET_LINK = 'magnet_link',
  /** `manual_announce_time` */
  MANUAL_ANNOUNCE_TIME = 'manual_announce_time',
  /** `max_connected_peers` */
  MAX_CONNECTED_PEERS = 'max_connected_peers',
  /** `metadata_percent_complete` */
  METADATA_PERCENT_COMPLETE = 'metadata_percent_complete',
  /** `name` */
  NAME = 'name',
  /** `peer_limit` */
  PEER_LIMIT = 'peer_limit',
  /** `peers` */
  PEERS = 'peers',
  /** `peers_connected` */
  PEERS_CONNECTED = 'peers_connected',
  /** `peers_from` */
  PEERS_FROM = 'peers_from',
  /** `peers_getting_from_us` */
  PEERS_GETTING_FROM_US = 'peers_getting_from_us',
  /** `peers_sending_to_us` */
  PEERS_SENDING_TO_US = 'peers_sending_to_us',
  /** `percent_complete` */
  PERCENT_COMPLETE = 'percent_complete',
  /** `percent_done` */
  PERCENT_DONE = 'percent_done',
  /** `pieces` */
  PIECES = 'pieces',
  /** `piece_count` */
  PIECE_COUNT = 'piece_count',
  /** `piece_size` */
  PIECE_SIZE = 'piece_size',
  /** `priorities` */
  PRIORITIES = 'priorities',
  /** `primary_mime_type` */
  PRIMARY_MIME_TYPE = 'primary_mime_type',
  /** `queue_position` */
  QUEUE_POSITION = 'queue_position',
  /** `rate_download` */
  RATE_DOWNLOAD = 'rate_download',
  /** `rate_upload` */
  RATE_UPLOAD = 'rate_upload',
  /** `recheck_progress` */
  RECHECK_PROGRESS = 'recheck_progress',
  /** `seconds_downloading` */
  SECONDS_DOWNLOADING = 'seconds_downloading',
  /** `seconds_seeding` */
  SECONDS_SEEDING = 'seconds_seeding',
  /** `seed_idle_limit` */
  SEED_IDLE_LIMIT = 'seed_idle_limit',
  /** `seed_idle_mode` */
  SEED_IDLE_MODE = 'seed_idle_mode',
  /** `seed_ratio_limit` */
  SEED_RATIO_LIMIT = 'seed_ratio_limit',
  /** `seed_ratio_mode` */
  SEED_RATIO_MODE = 'seed_ratio_mode',
  /** `sequential_download` */
  SEQUENTIAL_DOWNLOAD = 'sequential_download',
  /** `sequential_download_from_piece` */
  SEQUENTIAL_DOWNLOAD_FROM_PIECE = 'sequential_download_from_piece',
  /** `size_when_done` */
  SIZE_WHEN_DONE = 'size_when_done',
  /** `start_date` */
  START_DATE = 'start_date',
  /** `status` */
  STATUS = 'status',
  /** `torrent_file` */
  TORRENT_FILE = 'torrent_file',
  /** `total_size` */
  TOTAL_SIZE = 'total_size',
  /** `trackers` */
  TRACKERS = 'trackers',
  /** `tracker_list` */
  TRACKER_LIST = 'tracker_list',
  /** `tracker_stats` */
  TRACKER_STATS = 'tracker_stats',
  /** `uploaded_ever` */
  UPLOADED_EVER = 'uploaded_ever',
  /** `upload_limit` */
  UPLOAD_LIMIT = 'upload_limit',
  /** `upload_limited` */
  UPLOAD_LIMITED = 'upload_limited',
  /** `upload_ratio` */
  UPLOAD_RATIO = 'upload_ratio',
  /** `wanted` */
  WANTED = 'wanted',
  /** `webseeds` */
  WEBSEEDS = 'webseeds',
  /** `webseeds_ex` */
  WEBSEEDS_EX = 'webseeds_ex',
  /** `webseeds_sending_to_us` */
  WEBSEEDS_SENDING_TO_US = 'webseeds_sending_to_us',
}

/**
 * Keys of the `files` entries returned by `torrent_get`.
 *
 * Wire values are the canonical snake_case names introduced in Transmission 4.1.0.
 * The compatibility layer translates them automatically for older servers.
 *
 * @since 1.0.0
 */
export enum TorrentFileField {
  /** `bytes_completed` */
  BYTES_COMPLETED = 'bytes_completed',
  /** `length` */
  LENGTH = 'length',
  /** `name` */
  NAME = 'name',
  /** `begin_piece` */
  BEGIN_PIECE = 'begin_piece',
  /** `end_piece` */
  END_PIECE = 'end_piece',
}

/**
 * Keys of the `file_stats` entries returned by `torrent_get`.
 *
 * Wire values are the canonical snake_case names introduced in Transmission 4.1.0.
 * The compatibility layer translates them automatically for older servers.
 *
 * @since 1.0.0
 */
export enum TorrentFileStatField {
  /** `bytes_completed` */
  BYTES_COMPLETED = 'bytes_completed',
  /** `wanted` */
  WANTED = 'wanted',
  /** `priority` */
  PRIORITY = 'priority',
}

/**
 * Keys of the `peers` entries returned by `torrent_get`.
 *
 * Wire values are the canonical snake_case names introduced in Transmission 4.1.0.
 * The compatibility layer translates them automatically for older servers.
 *
 * @since 1.0.0
 */
export enum PeerField {
  /** `address` */
  ADDRESS = 'address',
  /** `bytes_to_client` */
  BYTES_TO_CLIENT = 'bytes_to_client',
  /** `bytes_to_peer` */
  BYTES_TO_PEER = 'bytes_to_peer',
  /** `client_is_choked` */
  CLIENT_IS_CHOKED = 'client_is_choked',
  /** `client_is_interested` */
  CLIENT_IS_INTERESTED = 'client_is_interested',
  /** `client_name` */
  CLIENT_NAME = 'client_name',
  /** `flag_str` */
  FLAG_STR = 'flag_str',
  /** `is_downloading_from` */
  IS_DOWNLOADING_FROM = 'is_downloading_from',
  /** `is_encrypted` */
  IS_ENCRYPTED = 'is_encrypted',
  /** `is_incoming` */
  IS_INCOMING = 'is_incoming',
  /** `is_uploading_to` */
  IS_UPLOADING_TO = 'is_uploading_to',
  /** `is_utp` */
  IS_UTP = 'is_utp',
  /** `peer_id` */
  PEER_ID = 'peer_id',
  /** `peer_is_choked` */
  PEER_IS_CHOKED = 'peer_is_choked',
  /** `peer_is_interested` */
  PEER_IS_INTERESTED = 'peer_is_interested',
  /** `port` */
  PORT = 'port',
  /** `progress` */
  PROGRESS = 'progress',
  /** `rate_to_client` */
  RATE_TO_CLIENT = 'rate_to_client',
  /** `rate_to_peer` */
  RATE_TO_PEER = 'rate_to_peer',
  /** `supports_holepunch` */
  SUPPORTS_HOLEPUNCH = 'supports_holepunch',
}

/**
 * Keys of the `peers_from` object returned by `torrent_get`.
 *
 * Wire values are the canonical snake_case names introduced in Transmission 4.1.0.
 * The compatibility layer translates them automatically for older servers.
 *
 * @since 1.0.0
 */
export enum PeerSourceField {
  /** `from_cache` */
  FROM_CACHE = 'from_cache',
  /** `from_dht` */
  FROM_DHT = 'from_dht',
  /** `from_holepunch` */
  FROM_HOLEPUNCH = 'from_holepunch',
  /** `from_incoming` */
  FROM_INCOMING = 'from_incoming',
  /** `from_lpd` */
  FROM_LPD = 'from_lpd',
  /** `from_ltep` */
  FROM_LTEP = 'from_ltep',
  /** `from_pex` */
  FROM_PEX = 'from_pex',
  /** `from_tracker` */
  FROM_TRACKER = 'from_tracker',
}

/**
 * Keys of the `trackers` entries returned by `torrent_get`.
 *
 * Wire values are the canonical snake_case names introduced in Transmission 4.1.0.
 * The compatibility layer translates them automatically for older servers.
 *
 * @since 1.0.0
 */
export enum TrackerField {
  /** `announce` */
  ANNOUNCE = 'announce',
  /** `id` */
  ID = 'id',
  /** `scrape` */
  SCRAPE = 'scrape',
  /** `sitename` */
  SITENAME = 'sitename',
  /** `tier` */
  TIER = 'tier',
}

/**
 * Keys of the `tracker_stats` entries returned by `torrent_get`.
 *
 * Wire values are the canonical snake_case names introduced in Transmission 4.1.0.
 * The compatibility layer translates them automatically for older servers.
 *
 * @since 1.0.0
 */
export enum TrackerStatField {
  /** `announce` */
  ANNOUNCE = 'announce',
  /** `announce_state` */
  ANNOUNCE_STATE = 'announce_state',
  /** `download_count` */
  DOWNLOAD_COUNT = 'download_count',
  /** `downloader_count` */
  DOWNLOADER_COUNT = 'downloader_count',
  /** `has_announced` */
  HAS_ANNOUNCED = 'has_announced',
  /** `has_scraped` */
  HAS_SCRAPED = 'has_scraped',
  /** `host` */
  HOST = 'host',
  /** `id` */
  ID = 'id',
  /** `is_backup` */
  IS_BACKUP = 'is_backup',
  /** `last_announce_peer_count` */
  LAST_ANNOUNCE_PEER_COUNT = 'last_announce_peer_count',
  /** `last_announce_result` */
  LAST_ANNOUNCE_RESULT = 'last_announce_result',
  /** `last_announce_start_time` */
  LAST_ANNOUNCE_START_TIME = 'last_announce_start_time',
  /** `last_announce_succeeded` */
  LAST_ANNOUNCE_SUCCEEDED = 'last_announce_succeeded',
  /** `last_announce_time` */
  LAST_ANNOUNCE_TIME = 'last_announce_time',
  /** `last_announce_timed_out` */
  LAST_ANNOUNCE_TIMED_OUT = 'last_announce_timed_out',
  /** `last_scrape_result` */
  LAST_SCRAPE_RESULT = 'last_scrape_result',
  /** `last_scrape_start_time` */
  LAST_SCRAPE_START_TIME = 'last_scrape_start_time',
  /** `last_scrape_succeeded` */
  LAST_SCRAPE_SUCCEEDED = 'last_scrape_succeeded',
  /** `last_scrape_time` */
  LAST_SCRAPE_TIME = 'last_scrape_time',
  /** `last_scrape_timed_out` */
  LAST_SCRAPE_TIMED_OUT = 'last_scrape_timed_out',
  /** `leecher_count` */
  LEECHER_COUNT = 'leecher_count',
  /** `next_announce_time` */
  NEXT_ANNOUNCE_TIME = 'next_announce_time',
  /** `next_scrape_time` */
  NEXT_SCRAPE_TIME = 'next_scrape_time',
  /** `scrape` */
  SCRAPE = 'scrape',
  /** `scrape_state` */
  SCRAPE_STATE = 'scrape_state',
  /** `seeder_count` */
  SEEDER_COUNT = 'seeder_count',
  /** `sitename` */
  SITENAME = 'sitename',
  /** `tier` */
  TIER = 'tier',
}

/**
 * Keys of the `webseeds_ex` entries returned by `torrent_get`.
 *
 * Wire values are the canonical snake_case names introduced in Transmission 4.1.0.
 * The compatibility layer translates them automatically for older servers.
 *
 * @since 1.0.0
 */
export enum WebseedField {
  /** `url` */
  URL = 'url',
  /** `is_downloading` */
  IS_DOWNLOADING = 'is_downloading',
  /** `download_bytes_per_second` */
  DOWNLOAD_BYTES_PER_SECOND = 'download_bytes_per_second',
}

/**
 * Keys accepted by `session_get` and `session_set`.
 *
 * Wire values are the canonical snake_case names introduced in Transmission 4.1.0.
 * The compatibility layer translates them automatically for older servers.
 *
 * @since 1.0.0
 */
export enum SessionField {
  /** `alt_speed_down` */
  ALT_SPEED_DOWN = 'alt_speed_down',
  /** `alt_speed_enabled` */
  ALT_SPEED_ENABLED = 'alt_speed_enabled',
  /** `alt_speed_time_begin` */
  ALT_SPEED_TIME_BEGIN = 'alt_speed_time_begin',
  /** `alt_speed_time_day` */
  ALT_SPEED_TIME_DAY = 'alt_speed_time_day',
  /** `alt_speed_time_enabled` */
  ALT_SPEED_TIME_ENABLED = 'alt_speed_time_enabled',
  /** `alt_speed_time_end` */
  ALT_SPEED_TIME_END = 'alt_speed_time_end',
  /** `alt_speed_up` */
  ALT_SPEED_UP = 'alt_speed_up',
  /** `anti_brute_force_enabled` */
  ANTI_BRUTE_FORCE_ENABLED = 'anti_brute_force_enabled',
  /** `blocklist_enabled` */
  BLOCKLIST_ENABLED = 'blocklist_enabled',
  /** `blocklist_size` */
  BLOCKLIST_SIZE = 'blocklist_size',
  /** `blocklist_url` */
  BLOCKLIST_URL = 'blocklist_url',
  /** `cache_size_mib` */
  CACHE_SIZE_MIB = 'cache_size_mib',
  /** `config_dir` */
  CONFIG_DIR = 'config_dir',
  /** `default_trackers` */
  DEFAULT_TRACKERS = 'default_trackers',
  /** `dht_enabled` */
  DHT_ENABLED = 'dht_enabled',
  /** `download_dir` */
  DOWNLOAD_DIR = 'download_dir',
  /** `download_dir_free_space` */
  DOWNLOAD_DIR_FREE_SPACE = 'download_dir_free_space',
  /** `download_queue_enabled` */
  DOWNLOAD_QUEUE_ENABLED = 'download_queue_enabled',
  /** `download_queue_size` */
  DOWNLOAD_QUEUE_SIZE = 'download_queue_size',
  /** `encryption` */
  ENCRYPTION = 'encryption',
  /** `idle_seeding_limit` */
  IDLE_SEEDING_LIMIT = 'idle_seeding_limit',
  /** `idle_seeding_limit_enabled` */
  IDLE_SEEDING_LIMIT_ENABLED = 'idle_seeding_limit_enabled',
  /** `incomplete_dir` */
  INCOMPLETE_DIR = 'incomplete_dir',
  /** `incomplete_dir_enabled` */
  INCOMPLETE_DIR_ENABLED = 'incomplete_dir_enabled',
  /** `lpd_enabled` */
  LPD_ENABLED = 'lpd_enabled',
  /** `peer_limit_global` */
  PEER_LIMIT_GLOBAL = 'peer_limit_global',
  /** `peer_limit_per_torrent` */
  PEER_LIMIT_PER_TORRENT = 'peer_limit_per_torrent',
  /** `peer_port_random_on_start` */
  PEER_PORT_RANDOM_ON_START = 'peer_port_random_on_start',
  /** `peer_port` */
  PEER_PORT = 'peer_port',
  /** `pex_enabled` */
  PEX_ENABLED = 'pex_enabled',
  /** `port_forwarding_enabled` */
  PORT_FORWARDING_ENABLED = 'port_forwarding_enabled',
  /** `preferred_transports` */
  PREFERRED_TRANSPORTS = 'preferred_transports',
  /** `queue_stalled_enabled` */
  QUEUE_STALLED_ENABLED = 'queue_stalled_enabled',
  /** `queue_stalled_minutes` */
  QUEUE_STALLED_MINUTES = 'queue_stalled_minutes',
  /** `rename_partial_files` */
  RENAME_PARTIAL_FILES = 'rename_partial_files',
  /** `reqq` */
  REQQ = 'reqq',
  /** `rpc_version_minimum` */
  RPC_VERSION_MINIMUM = 'rpc_version_minimum',
  /** `rpc_version_semver` */
  RPC_VERSION_SEMVER = 'rpc_version_semver',
  /** `rpc_version` */
  RPC_VERSION = 'rpc_version',
  /** `script_torrent_added_enabled` */
  SCRIPT_TORRENT_ADDED_ENABLED = 'script_torrent_added_enabled',
  /** `script_torrent_added_filename` */
  SCRIPT_TORRENT_ADDED_FILENAME = 'script_torrent_added_filename',
  /** `script_torrent_done_enabled` */
  SCRIPT_TORRENT_DONE_ENABLED = 'script_torrent_done_enabled',
  /** `script_torrent_done_filename` */
  SCRIPT_TORRENT_DONE_FILENAME = 'script_torrent_done_filename',
  /** `script_torrent_done_seeding_enabled` */
  SCRIPT_TORRENT_DONE_SEEDING_ENABLED = 'script_torrent_done_seeding_enabled',
  /** `script_torrent_done_seeding_filename` */
  SCRIPT_TORRENT_DONE_SEEDING_FILENAME = 'script_torrent_done_seeding_filename',
  /** `seed_queue_enabled` */
  SEED_QUEUE_ENABLED = 'seed_queue_enabled',
  /** `seed_queue_size` */
  SEED_QUEUE_SIZE = 'seed_queue_size',
  /** `seed_ratio_limit` */
  SEED_RATIO_LIMIT = 'seed_ratio_limit',
  /** `seed_ratio_limited` */
  SEED_RATIO_LIMITED = 'seed_ratio_limited',
  /** `sequential_download` */
  SEQUENTIAL_DOWNLOAD = 'sequential_download',
  /** `session_id` */
  SESSION_ID = 'session_id',
  /** `speed_limit_down` */
  SPEED_LIMIT_DOWN = 'speed_limit_down',
  /** `speed_limit_down_enabled` */
  SPEED_LIMIT_DOWN_ENABLED = 'speed_limit_down_enabled',
  /** `speed_limit_up` */
  SPEED_LIMIT_UP = 'speed_limit_up',
  /** `speed_limit_up_enabled` */
  SPEED_LIMIT_UP_ENABLED = 'speed_limit_up_enabled',
  /** `start_added_torrents` */
  START_ADDED_TORRENTS = 'start_added_torrents',
  /** `tcp_enabled` */
  TCP_ENABLED = 'tcp_enabled',
  /** `trash_original_torrent_files` */
  TRASH_ORIGINAL_TORRENT_FILES = 'trash_original_torrent_files',
  /** `units` */
  UNITS = 'units',
  /** `utp_enabled` */
  UTP_ENABLED = 'utp_enabled',
  /** `version` */
  VERSION = 'version',
}

/**
 * Keys returned by `session_stats`.
 *
 * Wire values are the canonical snake_case names introduced in Transmission 4.1.0.
 * The compatibility layer translates them automatically for older servers.
 *
 * @since 1.0.0
 */
export enum SessionStatField {
  /** `active_torrent_count` */
  ACTIVE_TORRENT_COUNT = 'active_torrent_count',
  /** `download_speed` */
  DOWNLOAD_SPEED = 'download_speed',
  /** `paused_torrent_count` */
  PAUSED_TORRENT_COUNT = 'paused_torrent_count',
  /** `torrent_count` */
  TORRENT_COUNT = 'torrent_count',
  /** `upload_speed` */
  UPLOAD_SPEED = 'upload_speed',
  /** `cumulative_stats` */
  CUMULATIVE_STATS = 'cumulative_stats',
  /** `current_stats` */
  CURRENT_STATS = 'current_stats',
}

/**
 * Keys of the `cumulative_stats` / `current_stats` objects.
 *
 * Wire values are the canonical snake_case names introduced in Transmission 4.1.0.
 * The compatibility layer translates them automatically for older servers.
 *
 * @since 1.0.0
 */
export enum SessionStatsEntryField {
  /** `uploaded_bytes` */
  UPLOADED_BYTES = 'uploaded_bytes',
  /** `downloaded_bytes` */
  DOWNLOADED_BYTES = 'downloaded_bytes',
  /** `files_added` */
  FILES_ADDED = 'files_added',
  /** `seconds_active` */
  SECONDS_ACTIVE = 'seconds_active',
  /** `session_count` */
  SESSION_COUNT = 'session_count',
}

/**
 * Keys accepted by `group_set` and returned by `group_get`.
 *
 * Wire values are the canonical snake_case names introduced in Transmission 4.1.0.
 * The compatibility layer translates them automatically for older servers.
 *
 * @since 1.0.0
 */
export enum BandwidthGroupField {
  /** `honors_session_limits` */
  HONORS_SESSION_LIMITS = 'honors_session_limits',
  /** `name` */
  NAME = 'name',
  /** `speed_limit_down` */
  SPEED_LIMIT_DOWN = 'speed_limit_down',
  /** `speed_limit_down_enabled` */
  SPEED_LIMIT_DOWN_ENABLED = 'speed_limit_down_enabled',
  /** `speed_limit_up` */
  SPEED_LIMIT_UP = 'speed_limit_up',
  /** `speed_limit_up_enabled` */
  SPEED_LIMIT_UP_ENABLED = 'speed_limit_up_enabled',
}
