// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Enumerations of the Transmission RPC API.
 *
 * The numeric values match `libtransmission/transmission.h` exactly, so they can
 * be sent on the wire without translation.
 *
 * @since 1.0.0
 */

/**
 * Lifecycle state of a torrent.
 *
 * Mirrors `tr_status_t`.
 */
export enum TorrentStatus {
  /** The torrent is stopped. */
  STOPPED = 0,
  /** The torrent is queued to verify its local data. */
  QUEUED_TO_VERIFY = 1,
  /** The torrent is verifying its local data. */
  VERIFYING = 2,
  /** The torrent is queued to download. */
  QUEUED_TO_DOWNLOAD = 3,
  /** The torrent is downloading. */
  DOWNLOADING = 4,
  /** The torrent is queued to seed. */
  QUEUED_TO_SEED = 5,
  /** The torrent is seeding. */
  SEEDING = 6,
}

/** True when `status` means the torrent is actively transferring or about to. */
export function isTorrentActive(status: TorrentStatus): boolean {
  return (
    status === TorrentStatus.DOWNLOADING ||
    status === TorrentStatus.SEEDING ||
    status === TorrentStatus.QUEUED_TO_DOWNLOAD ||
    status === TorrentStatus.QUEUED_TO_SEED ||
    status === TorrentStatus.VERIFYING ||
    status === TorrentStatus.QUEUED_TO_VERIFY
  );
}

/** True when `status` means the torrent has stopped entirely. */
export function isTorrentStopped(status: TorrentStatus): boolean {
  return status === TorrentStatus.STOPPED;
}

/**
 * Torrent bandwidth priority.
 *
 * Mirrors `tr_priority_t`.
 */
export enum TorrentPriority {
  /** Low priority. */
  LOW = -1,
  /** Normal priority. */
  NORMAL = 0,
  /** High priority. */
  HIGH = 1,
}

/** File-level priority used by `torrent_set`'s `priority_*` arrays. */
export enum FilePriority {
  /** Do not download the file. */
  LOW = -1,
  /** Download the file normally. */
  NORMAL = 0,
  /** Download the file before lower-priority files. */
  HIGH = 1,
}

/**
 * Seeding-inactivity limit mode.
 *
 * Mirrors `tr_idlelimit`.
 */
export enum IdleLimitMode {
  /** Use the session-wide default. */
  GLOBAL = 0,
  /** Use the per-torrent `seed_idle_limit`. */
  SINGLE = 1,
  /** Never stop seeding because of inactivity. */
  UNLIMITED = 2,
}

/**
 * Seeding-ratio limit mode.
 *
 * Mirrors `tr_ratiolimit`.
 */
export enum RatioLimitMode {
  /** Use the session-wide default. */
  GLOBAL = 0,
  /** Use the per-torrent `seed_ratio_limit`. */
  SINGLE = 1,
  /** Seed forever. */
  UNLIMITED = 2,
}

/**
 * Announce state of a tracker.
 *
 * Mirrors `tr_tracker_announce_state`.
 */
export enum TrackerAnnounceState {
  /** Idle; the next announce is scheduled. */
  INACTIVE = 0,
  /** Waiting for the announce interval to elapse. */
  WAITING = 1,
  /** An announce is queued. */
  QUEUED = 2,
  /** An announce is in flight. */
  ACTIVE = 3,
}

/**
 * Scrape state of a tracker.
 *
 * Mirrors `tr_tracker_scrape_state`.
 */
export enum TrackerScrapeState {
  /** Idle; the next scrape is scheduled. */
  INACTIVE = 0,
  /** A scrape is queued. */
  QUEUED = 1,
  /** A scrape is in flight. */
  ACTIVE = 2,
}

/**
 * Peer encryption policy (`session_get`/`session_set`'s `encryption`).
 *
 * The legacy API spells {@link ALLOWED} as `"tolerated"`; the compatibility
 * layer converts the value transparently.
 */
export enum EncryptionMode {
  /** Only accept encrypted peers. */
  REQUIRED = 'required',
  /** Prefer encrypted peers, fall back to plaintext. */
  PREFERRED = 'preferred',
  /** Accept both, preferring plaintext. */
  ALLOWED = 'allowed',
}

/** Preferred transport protocols (`session_get`/`session_set`'s `preferred_transports`). */
export enum TransportProtocol {
  /** Micro Transport Protocol over UDP. */
  UTP = 'utp',
  /** TCP. */
  TCP = 'tcp',
}

/** Shape of the `torrents` array returned by `torrent_get`. */
export enum TorrentFormat {
  /** An array of key/value objects (default, easiest to consume). */
  OBJECTS = 'objects',
  /** A header row of keys followed by one row per torrent (smaller, faster). */
  TABLE = 'table',
}

/** IP protocol selection for `port_test`. */
export enum IpProtocol {
  /** Test the IPv4 listener. */
  IPV4 = 'ipv4',
  /** Test the IPv6 listener. */
  IPV6 = 'ipv6',
}

/**
 * Reads a numeric enum value defensively.
 *
 * Transmission occasionally adds new members, so an unknown number must not
 * break parsing.
 *
 * @param value raw wire value
 * @param fallback value returned when `value` is unknown or malformed
 */
export function parseEnum<T extends number>(value: number | undefined, allowed: T[], fallback: T): T {
  if (value === undefined) {
    return fallback;
  }
  for (const candidate of allowed) {
    if (candidate === value) {
      return candidate;
    }
  }
  return fallback;
}
