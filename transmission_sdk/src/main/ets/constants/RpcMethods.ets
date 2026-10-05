// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Canonical RPC method names.
 *
 * The values are the snake_case names used by Transmission >= 4.1.0
 * (JSON-RPC 2.0). The legacy bespoke API uses the kebab-case form of the very
 * same names, which {@link legacyMethodName} derives — every method follows the
 * rule, so no lookup table is required.
 *
 * @since 1.0.0
 */

/** Every method understood by Transmission's RPC server. */
export enum RpcMethod {
  /** Start one or more torrents. */
  TORRENT_START = 'torrent_start',
  /** Start torrents immediately, disregarding queue position. */
  TORRENT_START_NOW = 'torrent_start_now',
  /** Stop one or more torrents. */
  TORRENT_STOP = 'torrent_stop',
  /** Verify local data of one or more torrents. */
  TORRENT_VERIFY = 'torrent_verify',
  /** Re-announce to trackers now. */
  TORRENT_REANNOUNCE = 'torrent_reannounce',
  /** Read torrent properties. */
  TORRENT_GET = 'torrent_get',
  /** Mutate torrent properties. */
  TORRENT_SET = 'torrent_set',
  /** Add a torrent by URL, magnet link or base64 metainfo. */
  TORRENT_ADD = 'torrent_add',
  /** Remove one or more torrents. */
  TORRENT_REMOVE = 'torrent_remove',
  /** Move a torrent's content to a new location. */
  TORRENT_SET_LOCATION = 'torrent_set_location',
  /** Rename a file or directory inside a torrent. */
  TORRENT_RENAME_PATH = 'torrent_rename_path',
  /** Move torrents to the top of the queue. */
  QUEUE_MOVE_TOP = 'queue_move_top',
  /** Move torrents one position up in the queue. */
  QUEUE_MOVE_UP = 'queue_move_up',
  /** Move torrents one position down in the queue. */
  QUEUE_MOVE_DOWN = 'queue_move_down',
  /** Move torrents to the bottom of the queue. */
  QUEUE_MOVE_BOTTOM = 'queue_move_bottom',
  /** Read session settings. */
  SESSION_GET = 'session_get',
  /** Mutate session settings. */
  SESSION_SET = 'session_set',
  /** Read session transfer statistics. */
  SESSION_STATS = 'session_stats',
  /** Ask the session to shut down. */
  SESSION_CLOSE = 'session_close',
  /** Update the IP blocklist from `blocklist_url`. */
  BLOCKLIST_UPDATE = 'blocklist_update',
  /** Test whether the peer port is reachable from the internet. */
  PORT_TEST = 'port_test',
  /** Query free space in a directory. */
  FREE_SPACE = 'free_space',
  /** Read bandwidth groups. */
  GROUP_GET = 'group_get',
  /** Create or mutate a bandwidth group. */
  GROUP_SET = 'group_set',
}

/** All method values, in declaration order. */
export const ALL_RPC_METHODS: RpcMethod[] = [
  RpcMethod.TORRENT_START,
  RpcMethod.TORRENT_START_NOW,
  RpcMethod.TORRENT_STOP,
  RpcMethod.TORRENT_VERIFY,
  RpcMethod.TORRENT_REANNOUNCE,
  RpcMethod.TORRENT_GET,
  RpcMethod.TORRENT_SET,
  RpcMethod.TORRENT_ADD,
  RpcMethod.TORRENT_REMOVE,
  RpcMethod.TORRENT_SET_LOCATION,
  RpcMethod.TORRENT_RENAME_PATH,
  RpcMethod.QUEUE_MOVE_TOP,
  RpcMethod.QUEUE_MOVE_UP,
  RpcMethod.QUEUE_MOVE_DOWN,
  RpcMethod.QUEUE_MOVE_BOTTOM,
  RpcMethod.SESSION_GET,
  RpcMethod.SESSION_SET,
  RpcMethod.SESSION_STATS,
  RpcMethod.SESSION_CLOSE,
  RpcMethod.BLOCKLIST_UPDATE,
  RpcMethod.PORT_TEST,
  RpcMethod.FREE_SPACE,
  RpcMethod.GROUP_GET,
  RpcMethod.GROUP_SET,
];

/** True when `method` is known to the SDK. */
export function isKnownRpcMethod(method: string): boolean {
  return ALL_RPC_METHODS.some((candidate) => candidate === method);
}
