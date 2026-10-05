// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Torrent operations (`torrent_*` and `queue_move_*`).
 *
 * Every method is a thin, strongly typed wrapper over one RPC method. Methods
 * that return nothing resolve to `void`; methods that return data resolve to
 * the matching class from `model/`.
 *
 * @since 1.0.0
 */

import { Json, JsonObject, JsonObjectBuilder } from '../util/Json';
import { RpcClient } from '../core/RpcClient';
import { RpcMethod } from '../constants/RpcMethods';
import { TorrentIds, TorrentGetRequest, TorrentAddRequest, TorrentSetRequest } from '../model/TorrentRequests';
import { Torrent, TorrentFile } from '../model/Torrent';
import { RecentlyActiveTorrents, TorrentAddResult, TorrentRenameResult, TorrentTable } from '../model/TorrentResults';
import { TorrentFormat } from '../model/Enums';
import { TransmissionError } from '../error/TransmissionError';

/** Default field selection used by {@link TorrentApi.get}. */
const DEFAULT_FIELDS: string[] = ['id', 'name', 'status', 'percent_done'];

/**
 * Access to the torrent subsystem.
 *
 * ```ts
 * const torrents = await client.torrents.get(new TorrentGetRequest(TorrentFields.BASIC));
 * await client.torrents.stop(TorrentIds.single(torrents[0].id));
 * ```
 */
export class TorrentApi {
  private readonly rpc: RpcClient;

  /**
   * @param rpc the shared RPC engine; normally created by `TransmissionClient`
   */
  constructor(rpc: RpcClient) {
    this.rpc = rpc;
  }

  // ---------------------------------------------------------------- reading

  /**
   * Fetches torrents in the default `objects` format.
   *
   * @param request field selection and id filter
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async get(request?: TorrentGetRequest): Promise<Torrent[]> {
    const effective = request === undefined ? new TorrentGetRequest(DEFAULT_FIELDS) : request;
    const result = await this.rpc.call(RpcMethod.TORRENT_GET, effective.toJson());
    const rows = Json.getArray(result, 'torrents');
    const torrents: Torrent[] = [];
    if (rows === undefined) {
      return torrents;
    }
    for (const row of rows) {
      torrents.push(Torrent.fromJson(Json.asObject(row)));
    }
    return torrents;
  }

  /**
   * Fetches torrents using `format: "table"`.
   *
   * The table encoding avoids repeating the key names for every torrent, which
   * makes it measurably cheaper to transfer and to parse for large sessions.
   * Use it together with {@link TorrentTable.rows} when the caller is happy to
   * work with the raw key/value objects.
   *
   * @param request field selection and id filter
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async getTable(request?: TorrentGetRequest): Promise<TorrentTable> {
    const effective = request === undefined ? new TorrentGetRequest(DEFAULT_FIELDS) : request;
    const result = await this.rpc.call(
      RpcMethod.TORRENT_GET,
      effective.format(TorrentFormat.TABLE).toJson(),
    );
    return TorrentTable.parse(result);
  }

  /**
   * Fetches the fields of one torrent, or throws when it no longer exists.
   *
   * @param id numeric id or info-hash
   * @param fields field selection
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async getOne(id: number | string, fields?: string[]): Promise<Torrent | undefined> {
    const request = new TorrentGetRequest(fields === undefined ? DEFAULT_FIELDS : fields).ids(TorrentIds.single(id));
    const torrents = await this.get(request);
    return torrents.length === 0 ? undefined : torrents[0];
  }

  /**
   * Fetches torrents plus the list of torrents that disappeared since the last
   * `recently_active` query.
   *
   * @param request field selection; its id filter is forced to
   *        {@link TorrentIds.RECENTLY_ACTIVE}
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async getRecentlyActive(request?: TorrentGetRequest): Promise<RecentlyActiveTorrents> {
    const effective = request === undefined ? new TorrentGetRequest() : request;
    effective.ids(TorrentIds.RECENTLY_ACTIVE);
    const result = await this.rpc.call(RpcMethod.TORRENT_GET, effective.toJson());
    return RecentlyActiveTorrents.fromJson(result);
  }

  /**
   * Fetches the file list of one torrent.
   *
   * @param id numeric id or info-hash
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async getFiles(id: number | string): Promise<TorrentFile[]> {
    const torrent = await this.getOne(id, ['id', 'files']);
    return torrent === undefined ? [] : torrent.files;
  }

  /**
   * Counts how many torrents the session holds.
   *
   * Requests a single cheap field, so it is safe to poll.
   *
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async count(): Promise<number> {
    const torrents = await this.get(new TorrentGetRequest(['id']));
    return torrents.length;
  }

  // ---------------------------------------------------------------- actions

  /**
   * Starts torrents.
   *
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async start(ids: TorrentIds = TorrentIds.ALL): Promise<void> {
    await this.perform(RpcMethod.TORRENT_START, ids);
  }

  /**
   * Starts torrents immediately, disregarding queue position.
   *
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async startNow(ids: TorrentIds = TorrentIds.ALL): Promise<void> {
    await this.perform(RpcMethod.TORRENT_START_NOW, ids);
  }

  /**
   * Stops torrents.
   *
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async stop(ids: TorrentIds = TorrentIds.ALL): Promise<void> {
    await this.perform(RpcMethod.TORRENT_STOP, ids);
  }

  /**
   * Verifies local data of torrents.
   *
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async verify(ids: TorrentIds = TorrentIds.ALL): Promise<void> {
    await this.perform(RpcMethod.TORRENT_VERIFY, ids);
  }

  /**
   * Re-announces to trackers now.
   *
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async reannounce(ids: TorrentIds = TorrentIds.ALL): Promise<void> {
    await this.perform(RpcMethod.TORRENT_REANNOUNCE, ids);
  }

  /**
   * Moves torrents to the top of the queue.
   *
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async moveToTop(ids: TorrentIds = TorrentIds.ALL): Promise<void> {
    await this.perform(RpcMethod.QUEUE_MOVE_TOP, ids);
  }

  /**
   * Moves torrents one position up in the queue.
   *
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async moveUp(ids: TorrentIds = TorrentIds.ALL): Promise<void> {
    await this.perform(RpcMethod.QUEUE_MOVE_UP, ids);
  }

  /**
   * Moves torrents one position down in the queue.
   *
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async moveDown(ids: TorrentIds = TorrentIds.ALL): Promise<void> {
    await this.perform(RpcMethod.QUEUE_MOVE_DOWN, ids);
  }

  /**
   * Moves torrents to the bottom of the queue.
   *
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async moveToBottom(ids: TorrentIds = TorrentIds.ALL): Promise<void> {
    await this.perform(RpcMethod.QUEUE_MOVE_BOTTOM, ids);
  }

  // ------------------------------------------------------------- mutators

  /**
   * Adds a torrent.
   *
   * @param request a request built with {@link TorrentAddRequest}
   * @returns the added torrent, or the pre-existing duplicate
   * @throws TransmissionError when the request carries neither `filename` nor
   *         `metainfo`
   */
  async add(request: TorrentAddRequest): Promise<TorrentAddResult> {
    const params = request.toJson();
    if (Json.get(params, 'filename') === undefined && Json.get(params, 'metainfo') === undefined) {
      throw TransmissionError.configuration('torrent_add requires either `filename` or `metainfo`');
    }
    const result = await this.rpc.call(RpcMethod.TORRENT_ADD, params);
    return TorrentAddResult.fromJson(result);
  }

  /**
   * Adds a torrent from a URL, local path or magnet link.
   *
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async addFromUri(uri: string): Promise<TorrentAddResult> {
    return this.add(TorrentAddRequest.fromFilename(uri));
  }

  /**
   * Adds a torrent from a magnet link.
   *
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async addMagnet(magnetLink: string): Promise<TorrentAddResult> {
    return this.add(TorrentAddRequest.fromMagnet(magnetLink));
  }

  /**
   * Adds a torrent from raw `.torrent` bytes.
   *
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async addFromBytes(bytes: Uint8Array): Promise<TorrentAddResult> {
    return this.add(TorrentAddRequest.fromBytes(bytes));
  }

  /**
   * Removes torrents.
   *
   * @param ids torrents to remove
   * @param deleteLocalData when true the downloaded files are deleted too
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async remove(ids: TorrentIds, deleteLocalData: boolean = false): Promise<void> {
    const builder = new JsonObjectBuilder();
    ids.applyTo(builder);
    builder.setAlways('delete_local_data', deleteLocalData);
    await this.rpc.call(RpcMethod.TORRENT_REMOVE, builder.build());
  }

  /**
   * Applies changes to torrents.
   *
   * @param request a request built with {@link TorrentSetRequest}
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async set(request: TorrentSetRequest): Promise<void> {
    await this.rpc.call(RpcMethod.TORRENT_SET, request.toJson());
  }

  /**
   * Moves a torrent's content to a new location.
   *
   * @param ids torrents to move
   * @param location new location
   * @param move when false, Transmission searches `location` for existing data
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async setLocation(ids: TorrentIds, location: string, move: boolean = false): Promise<void> {
    const builder = new JsonObjectBuilder();
    ids.applyTo(builder);
    builder.setAlways('location', location);
    builder.setAlways('move', move);
    await this.rpc.call(RpcMethod.TORRENT_SET_LOCATION, builder.build());
  }

  /**
   * Renames a file or directory inside a torrent.
   *
   * @param id the torrent; exactly one torrent may be addressed
   * @param path current path of the file or folder
   * @param name new name
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  async renamePath(id: number | string, path: string, name: string): Promise<TorrentRenameResult> {
    const builder = new JsonObjectBuilder();
    TorrentIds.single(id).applyTo(builder);
    builder.setAlways('path', path);
    builder.setAlways('name', name);
    const result = await this.rpc.call(RpcMethod.TORRENT_RENAME_PATH, builder.build());
    return TorrentRenameResult.fromJson(result);
  }

  /**
   * Invokes a torrent action that only takes `ids`.
   *
   * @throws TransmissionError on any transport, HTTP, protocol or RPC failure
   */
  private async perform(method: RpcMethod, ids: TorrentIds): Promise<void> {
    const builder = new JsonObjectBuilder();
    ids.applyTo(builder);
    const params: JsonObject = builder.build();
    await this.rpc.call(method, params);
  }
}
