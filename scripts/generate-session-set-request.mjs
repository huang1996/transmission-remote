#!/usr/bin/env node
/**
 * Regenerates
 * `transmission_sdk/src/main/ets/model/SessionSetRequest.ets`.
 *
 * `session_set` accepts every *mutable* session setting (section 4.1.1 of
 * `docs/rpc-spec.md`). Hand-writing ~50 fluent setters invites drift, so they
 * are generated from the same table that produces `constants/RpcFields.ets`.
 *
 * Usage:
 *   node scripts/generate-session-set-request.mjs [path-to-transmission-checkout]
 */
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const repoRoot = path.resolve(import.meta.dirname, '..');
const transmissionRoot = process.argv[2] ?? path.resolve(repoRoot, '..', 'transmission-ref');
const specPath = path.join(transmissionRoot, 'docs', 'rpc-spec.md');
const outPath = path.join(repoRoot, 'transmission_sdk/src/main/ets/model', 'SessionSetRequest.ets');

/** Settings that `session_set` refuses, per section 4.1.1. */
const READ_ONLY = new Set([
  'blocklist_size',
  'config_dir',
  'rpc_version_minimum',
  'rpc_version_semver',
  'rpc_version',
  'session_id',
  'tcp_enabled',
  'units',
  'version',
]);

/** Deprecated settings the SDK deliberately does not expose as setters. */
const DEPRECATED = new Set(['cache_size_mib', 'download_dir_free_space', 'utp_enabled', 'tcp_enabled']);

const spec = fs.readFileSync(specPath, 'utf8');
const lines = spec.split('\n');
const start = lines.findIndex((line) => line.includes('| `alt_speed_down` |'));
const end = lines.findIndex((line, index) => index > start && line.includes('`units`: an object containing'));

const settings = [];
for (const row of lines.slice(start, end)) {
  const match = /^\|\s*`([a-z0-9_]+)`\s*\|\s*([^|]+?)\s*\|/.exec(row);
  if (!match) continue;
  const key = match[1];
  const wireType = match[2];
  if (READ_ONLY.has(key) || DEPRECATED.has(key)) continue;
  settings.push({ key, wireType });
}

/** snake_case -> lowerCamelCase. */
function camel(key) {
  return key.replace(/_([a-z0-9])/g, (_, char) => char.toUpperCase());
}

/** PascalCase, for the JSDoc summary. */
function pascal(key) {
  const value = camel(key);
  return value.charAt(0).toUpperCase() + value.slice(1);
}

/** Maps a documented wire type onto a TypeScript parameter type. */
function tsType(setting) {
  switch (setting.wireType) {
    case 'boolean':
      return 'boolean';
    case 'string':
      return 'string';
    case 'string[]':
      return 'TransportProtocol[]';
    case 'double':
    case 'integer':
    case 'number':
      return 'number';
    default:
      throw new Error(`unhandled wire type "${setting.wireType}" for ${setting.key}`);
  }
}

const header = `// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// GENERATED from the Transmission sources - see LICENSE.

/**
 * Request of the \`session_set\` method.
 *
 * GENERATED FILE - DO NOT EDIT BY HAND.
 *
 * Source of truth: section 4.1.1 of \`docs/rpc-spec.md\` in the Transmission
 * repository. Regenerate with \`node scripts/generate-session-set-request.mjs\`.
 *
 * Only the setters that are called end up on the wire: Transmission applies a
 * setting only when its key is present, so untouched settings keep their value.
 *
 * \`\`\`ts
 * await client.session.set(
 *   new SessionSetRequest()
 *     .downloadDir('/srv/media')
 *     .speedLimitDownEnabled(true)
 *     .speedLimitDown(2048),
 * );
 * \`\`\`
 *
 * @since 1.0.0
 */

import { Json, JsonObject, JsonObjectBuilder, JsonValue } from '../util/Json';
import { EncryptionMode, TransportProtocol } from './Enums';
`;

const body = [];
body.push('export class SessionSetRequest {');
body.push('  private readonly params: JsonObjectBuilder = new JsonObjectBuilder();');
body.push('');
body.push('  /** True when at least one setting has been provided. */');
body.push('  get hasChanges(): boolean {');
body.push('    return !Json.isEmpty(this.params.build());');
body.push('  }');
body.push('');
body.push('  /** Number of settings that will be sent. */');
body.push('  get size(): number {');
body.push('    return Json.keys(this.params.build()).length;');
body.push('  }');
body.push('');
body.push('  /**');
body.push('   * Sets a raw setting by its canonical wire name.');
body.push('   *');
body.push('   * Escape hatch for settings this class does not model; prefer the typed');
body.push('   * setters below so that typos are caught at compile time.');
body.push('   */');
body.push('  setRaw(key: string, value: JsonValue): SessionSetRequest {');
body.push('    this.params.set(key, value);');
body.push('    return this;');
body.push('  }');
body.push('');

for (const setting of settings) {
  const type = tsType(setting);
  const method = camel(setting.key);
  const isEncryption = setting.key === 'encryption';
  const paramType = isEncryption ? 'EncryptionMode' : type;
  body.push('  /**');
  body.push(`   * ${pascal(setting.key)}${setting.wireType === 'string[]' ? ' (preference order)' : ''}.`);
  body.push('   *');
  body.push(`   * Wire key: \`${setting.key}\`.`);
  body.push('   */');
  body.push(`  ${method}(value: ${paramType}): SessionSetRequest {`);
  if (setting.wireType === 'string[]') {
    body.push('    const encoded: string[] = [];');
    body.push('    for (const protocol of value) {');
    body.push('      encoded.push(protocol);');
    body.push('    }');
    body.push(`    this.params.setAlways('${setting.key}', encoded);`);
  } else {
    body.push(`    this.params.setAlways('${setting.key}', value);`);
  }
  body.push('    return this;');
  body.push('  }');
  body.push('');
}

body.push('  /** Serialises the request into RPC parameters. */');
body.push('  toJson(): JsonObject {');
body.push('    return this.params.build();');
body.push('  }');
body.push('}');

fs.writeFileSync(outPath, `${header}\n${body.join('\n')}\n`);
console.log(`wrote ${path.relative(repoRoot, outPath)} (${settings.length} setters)`);
