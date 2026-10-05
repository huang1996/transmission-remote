#!/usr/bin/env node
/**
 * Regenerates `transmission_sdk/src/main/ets/constants/RpcFields.ets`.
 *
 * The field names are scraped from the tables in Transmission's
 * `docs/rpc-spec.md` so that the SDK can never silently drift from the
 * documented wire format.
 *
 * Usage:
 *   node scripts/generate-rpc-fields.mjs [path-to-transmission-checkout]
 *
 * Defaults to `../transmission-ref`. The generated file is committed, so this
 * script only needs to run when bumping to a new Transmission release.
 */
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const repoRoot = path.resolve(import.meta.dirname, '..');
const transmissionRoot = process.argv[2] ?? path.resolve(repoRoot, '..', 'transmission-ref');
const specPath = path.join(transmissionRoot, 'docs', 'rpc-spec.md');
const outPath = path.join(repoRoot, 'transmission_sdk/src/main/ets/constants', 'RpcFields.ets');

const spec = fs.readFileSync(specPath, 'utf8');
const lines = spec.split('\n');

/** Returns the slice of `lines` between the first line matching `start` and the next matching `end`. */
function sliceBetween(start, end) {
  const from = lines.findIndex((line) => line.includes(start));
  if (from < 0) throw new Error(`start marker not found: ${start}`);
  const to = lines.findIndex((line, index) => index > from && line.includes(end));
  if (to < 0) throw new Error(`end marker not found: ${end}`);
  return lines.slice(from, to);
}

/** Extracts the first `code` span of every markdown table row in `rows`. */
function tableKeys(rows) {
  const keys = [];
  for (const row of rows) {
    const match = /^\|\s*`([a-z0-9_]+)`/.exec(row);
    if (match && !keys.includes(match[1])) keys.push(match[1]);
  }
  return keys;
}

const tables = {
  torrentKeys: tableKeys(sliceBetween('| `activity_date` |', '`availability`: An array')),
  fileKeys: tableKeys(sliceBetween('`files`: array of objects', 'Files are returned')),
  fileStatKeys: tableKeys(sliceBetween('`file_stats`:', '`peers`: an array')),
  peerKeys: tableKeys(sliceBetween('`peers`: an array', '`peers_from`:')),
  peerFromKeys: tableKeys(sliceBetween('`peers_from`:', '`pieces`: A bitfield')),
  trackerKeys: tableKeys(sliceBetween('`trackers`: array of objects', '`tracker_stats`: array')),
  trackerStatKeys: tableKeys(sliceBetween('`tracker_stats`: array', '`webseeds_ex`:')),
  webseedKeys: tableKeys(sliceBetween('`webseeds_ex`:', '`wanted`: An array')),
  sessionKeys: tableKeys(sliceBetween('| `alt_speed_down` |', '`units`: an object containing')),
  sessionStatKeys: tableKeys(sliceBetween('`active_torrent_count`', 'A stats object contains')),
  statsEntryKeys: tableKeys(sliceBetween('| `uploaded_bytes`', '### 4.3')),
  groupKeys: tableKeys(sliceBetween('A bandwidth group description object has', '## 5 Protocol versions')),
};

/** snake_case -> SCREAMING_SNAKE_CASE. */
function constantName(key) {
  return key.toUpperCase();
}

function emitEnum(typeName, summary, hint, keys) {
  const out = [];
  out.push('/**');
  out.push(` * ${summary}`);
  out.push(' *');
  out.push(' * Wire values are the canonical snake_case names introduced in Transmission 4.1.0.');
  out.push(' * The compatibility layer translates them automatically for older servers.');
  if (hint) {
    out.push(' *');
    out.push(` * ${hint}`);
  }
  out.push(' *');
  out.push(' * @since 1.0.0');
  out.push(' */');
  out.push(`export enum ${typeName} {`);
  for (const key of keys) {
    out.push(`  /** \`${key}\` */`);
    out.push(`  ${constantName(key)} = '${key}',`);
  }
  out.push('}');
  return out.join('\n');
}

const header = [
  '// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only',
  '// GENERATED from the Transmission sources - see LICENSE.',
  '',
  '/**',
  ' * Field names accepted by the Transmission RPC API.',
  ' *',
  ' * GENERATED FILE - DO NOT EDIT BY HAND.',
  ' *',
  ' * Source of truth: the tables in `docs/rpc-spec.md` of the Transmission repository',
  ' * (the modern / snake_case API). Regenerate with',
  ' * `node scripts/generate-rpc-fields.mjs`.',
  ' *',
  ' * @since 1.0.0',
  ' */',
  '',
].join('\n');

const body = [
  emitEnum('TorrentField', 'Keys accepted by `torrent_get` and `torrent_set`.', '', tables.torrentKeys),
  emitEnum('TorrentFileField', 'Keys of the `files` entries returned by `torrent_get`.', '', tables.fileKeys),
  emitEnum('TorrentFileStatField', 'Keys of the `file_stats` entries returned by `torrent_get`.', '', tables.fileStatKeys),
  emitEnum('PeerField', 'Keys of the `peers` entries returned by `torrent_get`.', '', tables.peerKeys),
  emitEnum('PeerSourceField', 'Keys of the `peers_from` object returned by `torrent_get`.', '', tables.peerFromKeys),
  emitEnum('TrackerField', 'Keys of the `trackers` entries returned by `torrent_get`.', '', tables.trackerKeys),
  emitEnum('TrackerStatField', 'Keys of the `tracker_stats` entries returned by `torrent_get`.', '', tables.trackerStatKeys),
  emitEnum('WebseedField', 'Keys of the `webseeds_ex` entries returned by `torrent_get`.', '', tables.webseedKeys),
  emitEnum('SessionField', 'Keys accepted by `session_get` and `session_set`.', '', tables.sessionKeys),
  emitEnum('SessionStatField', 'Keys returned by `session_stats`.', '', tables.sessionStatKeys),
  emitEnum('SessionStatsEntryField', 'Keys of the `cumulative_stats` / `current_stats` objects.', '', tables.statsEntryKeys),
  emitEnum('BandwidthGroupField', 'Keys accepted by `group_set` and returned by `group_get`.', '', tables.groupKeys),
].join('\n\n');

fs.writeFileSync(outPath, `${header}${body}\n`);
const counts = Object.entries(tables)
  .map(([name, keys]) => `${name}=${keys.length}`)
  .join(' ');
console.log(`wrote ${path.relative(repoRoot, outPath)} (${counts})`);
