// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Result objects of the torrent-mutating RPC methods.
 *
 * This file models:
 *
 * - {@link TorrentRenameResult}, returned by `torrent_rename_path`.
 * - {@link TorrentAddResult}, returned by `torrent_add`.
 * - {@link RecentlyActiveTorrents}, returned by `torrent_get` when the caller
 *   asks for recently-active torrents and receives the `removed` list as well.
 *
 * Because `torrent_get` can answer with either `format: "objects"` or
 * `format: "table"`, the file also exports {@link TorrentTable}, a small helper
 * that turns a table payload into ordinary key/value objects.
 *
 * @since 1.0.0
 */

import { Json, JsonArray, JsonObject } from '../util/Json';
import { Torrent } from './Torrent';

/**
 * Converts a `format: "table"` payload into an array of key/value objects.
 *
 * A table payload is `[headerRow, ...dataRows]`, where the header row holds the
 * field names and every data row holds the matching values. Header entries and
 * rows are zipped by position, so a short row simply leaves the remaining
 * columns unset.
 */
export class TorrentTable {
  /** Column names, in payload order. Empty when the payload is not a table. */
  readonly columns: string[] = [];
  /** One object per torrent row. */
  readonly rows: JsonObject[] = [];

  /** True once a header row has been seen. */
  private hasHeader: boolean = false;

  /**
   * Parses the `torrents` member of a `torrent_get` result.
   *
   * Missing, empty, object-shaped and table-shaped payloads are all accepted.
   *
   * @param json wire object holding the `torrents` member
   */
  static parse(json: JsonObject | undefined): TorrentTable {
    const table = new TorrentTable();
    const raw = Json.getArray(json, 'torrents');
    if (raw === undefined || raw.length === 0) {
      return table;
    }

    const header = Json.asArray(raw[0]);
    if (header === undefined) {
      // `format: "objects"` — every element is already a key/value object.
      for (const item of raw) {
        const asObject = Json.asObject(item);
        if (asObject !== undefined) {
          table.rows.push(asObject);
        }
      }
      return table;
    }

    // `format: "table"` — the first row names the columns.
    table.hasHeader = true;
    for (const item of header) {
      const name = Json.asString(item);
      table.columns.push(name === undefined ? '' : name);
    }
    for (let i = 1; i < raw.length; i++) {
      const row = Json.asArray(raw[i]);
      if (row === undefined) {
        continue;
      }
      table.rows.push(TorrentTable.zipRow(table.columns, row));
    }
    return table;
  }

  /** True when the payload actually carried a header row. */
  get isTable(): boolean {
    return this.hasHeader;
  }

  /**
   * Pairs `columns` with `row`, never reading past the end of either.
   *
   * @param columns header names, in payload order
   * @param row data values, in payload order
   */
  private static zipRow(columns: string[], row: JsonArray): JsonObject {
    const result: JsonObject = {};
    const length = Math.min(columns.length, row.length);
    for (let i = 0; i < length; i++) {
      const key = columns[i];
      if (key.length > 0) {
        result[key] = row[i];
      }
    }
    return result;
  }
}

/**
 * The result object of `torrent_rename_path`.
 */
export class TorrentRenameResult {
  /** Id of the renamed torrent. */
  id: number = 0;
  /** Path that was renamed. */
  path: string = '';
  /** New name of the file or directory. */
  name: string = '';

  /**
   * Parses a `torrent_rename_path` result.
   *
   * @param json wire object with canonical keys
   */
  static fromJson(json: JsonObject | undefined): TorrentRenameResult {
    const result = new TorrentRenameResult();
    result.id = Json.getNumber(json, 'id');
    result.path = Json.getString(json, 'path');
    result.name = Json.getString(json, 'name');
    return result;
  }
}

/**
 * The result object of `torrent_add`.
 *
 * Exactly one of {@link added} and {@link duplicate} is normally present: a
 * newly added torrent comes back as `torrent_added`, while a torrent that was
 * already in the session comes back as `torrent_duplicate`.
 */
export class TorrentAddResult {
  /** The newly added torrent, when the daemon accepted it. */
  added: Torrent | undefined = undefined;
  /** The pre-existing torrent that made the add a duplicate. */
  duplicate: Torrent | undefined = undefined;

  /** True when a new torrent was added. */
  get wasAdded(): boolean {
    return this.added !== undefined;
  }

  /** True when the add was rejected because the torrent already existed. */
  get wasDuplicate(): boolean {
    return this.duplicate !== undefined;
  }

  /** The added torrent, or the duplicate when nothing new was added. */
  get torrent(): Torrent | undefined {
    return this.added !== undefined ? this.added : this.duplicate;
  }

  /**
   * Parses a `torrent_add` result.
   *
   * @param json wire object with canonical keys
   */
  static fromJson(json: JsonObject | undefined): TorrentAddResult {
    const result = new TorrentAddResult();
    const added = Json.getObject(json, 'torrent_added');
    const duplicate = Json.getObject(json, 'torrent_duplicate');
    result.added = added === undefined ? undefined : Torrent.fromJson(added);
    result.duplicate = duplicate === undefined ? undefined : Torrent.fromJson(duplicate);
    return result;
  }
}

/**
 * The torrent list plus removal log returned by `torrent_get` when the caller
 * asks for recently-active torrents.
 */
export class RecentlyActiveTorrents {
  /** Torrents that changed, in payload order. */
  torrents: Torrent[] = [];
  /** Ids of torrents that were removed since the last call. */
  removed: number[] = [];

  /**
   * Parses a result that used `format: "objects"` (the default).
   *
   * @param json wire object with canonical keys
   */
  static fromObjects(json: JsonObject | undefined): RecentlyActiveTorrents {
    const result = new RecentlyActiveTorrents();
    result.torrents = RecentlyActiveTorrents.parseObjects(Json.getArray(json, 'torrents'));
    result.removed = Json.toNumberArray(Json.getArray(json, 'removed'));
    return result;
  }

  /**
   * Parses a result that used `format: "table"`.
   *
   * @param json wire object with canonical keys
   */
  static fromTable(json: JsonObject | undefined): RecentlyActiveTorrents {
    const result = new RecentlyActiveTorrents();
    result.torrents = RecentlyActiveTorrents.parseRows(TorrentTable.parse(json).rows);
    result.removed = Json.toNumberArray(Json.getArray(json, 'removed'));
    return result;
  }

  /**
   * Parses a result in either format, choosing by inspecting the payload.
   *
   * @param json wire object with canonical keys
   */
  static fromJson(json: JsonObject | undefined): RecentlyActiveTorrents {
    return TorrentTable.parse(json).isTable
      ? RecentlyActiveTorrents.fromTable(json)
      : RecentlyActiveTorrents.fromObjects(json);
  }

  /** Maps an array of torrent objects through {@link Torrent.fromJson}. */
  private static parseObjects(raw: JsonArray | undefined): Torrent[] {
    const torrents: Torrent[] = [];
    if (raw === undefined) {
      return torrents;
    }
    for (const item of raw) {
      const asObject = Json.asObject(item);
      if (asObject !== undefined) {
        torrents.push(Torrent.fromJson(asObject));
      }
    }
    return torrents;
  }

  /** Maps already-normalised table rows through {@link Torrent.fromJson}. */
  private static parseRows(rows: JsonObject[]): Torrent[] {
    const torrents: Torrent[] = [];
    for (const row of rows) {
      torrents.push(Torrent.fromJson(row));
    }
    return torrents;
  }
}
