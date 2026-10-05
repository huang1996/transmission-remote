#!/usr/bin/env node
/**
 * Regenerates `transmission_sdk/src/main/ets/compat/LegacyKeys.ets`.
 *
 * The canonical -> legacy key mapping lives in Transmission's C++ sources:
 *
 *   - `libtransmission/quark.h`   — enum order (index 0 is `TR_KEY_NONE`).
 *   - `libtransmission/quark.cc`  — the matching string table.
 *   - `libtransmission/api-compat.cc` — the `RpcKeys` table of
 *     `{ current, legacy }` quark pairs.
 *
 * Reading the real table (instead of deriving names by convention) matters:
 * the legacy API mixes kebab-case and camelCase arbitrarily, and a few keys
 * (`download_dir`, `cache_size_mib`, `is_utp`, …) are outright irregular.
 *
 * Usage:
 *   node scripts/generate-legacy-keys.mjs [path-to-transmission-checkout]
 */
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const repoRoot = path.resolve(import.meta.dirname, '..');
const transmissionRoot = process.argv[2] ?? path.resolve(repoRoot, '..', 'transmission-ref');
const libDir = path.join(transmissionRoot, 'libtransmission');
const outPath = path.join(repoRoot, 'transmission_sdk/src/main/ets/compat', 'LegacyKeys.ets');

const quarkHeader = fs.readFileSync(path.join(libDir, 'quark.h'), 'utf8');
const quarkSource = fs.readFileSync(path.join(libDir, 'quark.cc'), 'utf8');
const compatSource = fs.readFileSync(path.join(libDir, 'api-compat.cc'), 'utf8');

// --- 1. enum order -----------------------------------------------------------
const enumBody = quarkHeader.slice(quarkHeader.indexOf('enum // NOLINT(performance-enum-size)'));
const enumNames = [...enumBody.matchAll(/^\s{4}(TR_KEY_[A-Za-z0-9_]+),/gm)].map((match) => match[1]);

// --- 2. string table ---------------------------------------------------------
const arrayStart = quarkSource.indexOf('auto constexpr MyStatic = std::array<std::string_view, TR_N_KEYS>{');
const arrayEnd = quarkSource.indexOf('};', arrayStart);
const stringEntries = [...quarkSource.slice(arrayStart, arrayEnd).matchAll(/^\s{4}"((?:[^"\\]|\\.)*)"sv,/gm)].map(
  (match) => match[1].replace(/\\"/g, '"'),
);

if (enumNames.length !== stringEntries.length) {
  throw new Error(`quark.h/quark.cc out of sync: ${enumNames.length} names vs ${stringEntries.length} strings`);
}
const quarkToText = new Map(enumNames.map((name, index) => [name, stringEntries[index]]));
quarkToText.set('TR_KEY_NONE', '');

// --- 3. api-compat tables ----------------------------------------------------
function parseApiKeys(tableName) {
  const start = compatSource.indexOf(`auto constexpr ${tableName} = std::array<ApiKey`);
  if (start < 0) throw new Error(`table not found: ${tableName}`);
  const end = compatSource.indexOf('} };', start);
  const body = compatSource.slice(start, end);
  const pairs = [];
  const pattern = /\{\s*\.current\s*=\s*(TR_KEY_[A-Za-z0-9_]+)\s*,\s*\.legacy\s*=\s*(TR_KEY_[A-Za-z0-9_]+)\s*,?\s*\}/g;
  for (const match of body.matchAll(pattern)) pairs.push([match[1], match[2]]);
  return pairs;
}

const pairs = [];
const seen = new Set();
for (const [current, legacy] of parseApiKeys('RpcKeys')) {
  const canonical = quarkToText.get(current);
  const legacyText = quarkToText.get(legacy);
  if (canonical === undefined || legacyText === undefined) {
    throw new Error(`unknown quark in RpcKeys: ${current} / ${legacy}`);
  }
  if (seen.has(canonical)) continue;
  seen.add(canonical);
  pairs.push([canonical, legacyText]);
}
pairs.sort((left, right) => (left[0] < right[0] ? -1 : 1));

// --- 4. emit -----------------------------------------------------------------
const out = [];
out.push('// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only');
out.push('// GENERATED from the Transmission sources - see LICENSE.');
out.push('');
out.push('/**');
out.push(' * Canonical (Transmission >= 4.1.0, snake_case) to legacy (Transmission < 4.1.0,');
out.push(' * mixed kebab-case / camelCase) RPC key mapping.');
out.push(' *');
out.push(' * GENERATED FILE - DO NOT EDIT BY HAND.');
out.push(' *');
out.push(' * Source of truth: the `RpcKeys` table in `libtransmission/api-compat.cc` of the');
out.push(' * Transmission repository, resolved through the quark string table in');
out.push(' * `libtransmission/quark.cc`. Regenerate with');
out.push(' * `node scripts/generate-legacy-keys.mjs`.');
out.push(' *');
out.push(' * The legacy API mixes naming styles, so the mapping cannot be derived from the');
out.push(' * canonical name alone; the table below is exhaustive for RPC traffic.');
out.push(' *');
out.push(' * @since 1.0.0');
out.push(' */');
out.push('');
out.push('/** A single `[canonical, legacy]` key pair. */');
out.push('type LegacyKeyPair = [string, string];');
out.push('');
out.push('/** Every RPC key understood by the compatibility layer. */');
out.push('const LEGACY_RPC_KEY_PAIRS: LegacyKeyPair[] = [');
for (const [canonical, legacy] of pairs) {
  out.push(`  ['${canonical}', '${legacy}'],`);
}
out.push('];');
out.push('');
out.push('/**');
out.push(' * Bidirectional lookup between canonical and legacy RPC key names.');
out.push(' *');
out.push(' * Lookups are O(1) `Map` reads, so key conversion stays cheap even for');
out.push(' * `torrent_get` responses containing thousands of nested objects.');
out.push(' */');
out.push('export class LegacyKeys {');
out.push('  private static readonly TO_LEGACY: Map<string, string> = LegacyKeys.buildToLegacy();');
out.push('  private static readonly TO_CANONICAL: Map<string, string> = LegacyKeys.buildToCanonical();');
out.push('');
out.push('  private constructor() {');
out.push('    // Static-only utility class.');
out.push('  }');
out.push('');
out.push('  private static buildToLegacy(): Map<string, string> {');
out.push('    const map = new Map<string, string>();');
out.push('    for (const pair of LEGACY_RPC_KEY_PAIRS) {');
out.push('      map.set(pair[0], pair[1]);');
out.push('    }');
out.push('    return map;');
out.push('  }');
out.push('');
out.push('  private static buildToCanonical(): Map<string, string> {');
out.push('    const map = new Map<string, string>();');
out.push('    for (const pair of LEGACY_RPC_KEY_PAIRS) {');
out.push('      if (!map.has(pair[1])) {');
out.push('        map.set(pair[1], pair[0]);');
out.push('      }');
out.push('    }');
out.push('    return map;');
out.push('  }');
out.push('');
out.push('  /** Number of mapped keys. */');
out.push('  static get size(): number {');
out.push('    return LEGACY_RPC_KEY_PAIRS.length;');
out.push('  }');
out.push('');
out.push('  /**');
out.push('   * Translates a canonical key into its legacy spelling.');
out.push('   *');
out.push('   * @returns the legacy name, or `undefined` when the key only exists in the');
out.push('   *          modern API (for example a field added after Transmission 4.1.0).');
out.push('   */');
out.push('  static toLegacy(canonical: string): string | undefined {');
out.push('    return LegacyKeys.TO_LEGACY.get(canonical);');
out.push('  }');
out.push('');
out.push('  /**');
out.push('   * Translates a legacy key into its canonical spelling.');
out.push('   *');
out.push('   * @returns the canonical name, or `undefined` when the key is not part of the');
out.push('   *          compatibility table.');
out.push('   */');
out.push('  static toCanonical(legacy: string): string | undefined {');
out.push('    return LegacyKeys.TO_CANONICAL.get(legacy);');
out.push('  }');
out.push('');
out.push('  /**');
out.push('   * True when `key` is a canonical name whose spelling differs between the two');
out.push('   * dialects.');
out.push('   *');
out.push('   * Keys that are spelled identically in both dialects (`name`, `status`, ...)');
out.push('   * are deliberately absent from the table, so they report `false`. Callers that');
out.push('   * just want a translated key should combine this with a fallback, which is');
out.push('   * exactly what `KeyConverter.convertKey` does.');
out.push('   */');
out.push('  static hasMapping(key: string): boolean {');
out.push('    return LegacyKeys.TO_LEGACY.has(key);');
out.push('  }');
out.push('');
out.push('  /** Every canonical key, in alphabetical order. */');
out.push('  static canonicalKeys(): string[] {');
out.push('    return Array.from(LegacyKeys.TO_LEGACY.keys());');
out.push('  }');
out.push('}');
out.push('');

fs.writeFileSync(outPath, out.join('\n'));
console.log(`wrote ${path.relative(repoRoot, outPath)} (${pairs.length} key pairs)`);
