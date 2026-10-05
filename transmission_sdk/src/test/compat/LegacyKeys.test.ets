// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for the generated canonical -> legacy key table.
 *
 * The table is scraped from `libtransmission/api-compat.cc`, so these tests
 * guard two different failure modes: that the generated file is complete, and
 * that the irregular mappings every client gets wrong are present.
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { LegacyKeys } from '../../main/ets/compat/LegacyKeys';

/** Asserts a canonical -> legacy mapping in both directions. */
function assertMapping(canonical: string, legacy: string): void {
  expect(LegacyKeys.toLegacy(canonical)).assertEqual(legacy);
  expect(LegacyKeys.toCanonical(legacy)).assertEqual(canonical);
}

export default function legacyKeysTest(): void {
  describe('LegacyKeys coverage', () => {
    it('maps the whole RpcKeys table', () => {
      expect(LegacyKeys.size).assertEqual(212);
      expect(LegacyKeys.canonicalKeys().length).assertEqual(212);
    });

    it('keeps the canonical keys unique and sorted', () => {
      const keys = LegacyKeys.canonicalKeys();
      let sorted = true;
      for (let i = 1; i < keys.length; i++) {
        if (keys[i - 1] >= keys[i]) {
          sorted = false;
        }
      }
      expect(sorted).assertTrue();
    });

    it('recognises mapped names and rejects everything else', () => {
      expect(LegacyKeys.hasMapping('percent_done')).assertTrue();
      expect(LegacyKeys.hasMapping('percentDone')).assertFalse();
      expect(LegacyKeys.hasMapping('not_a_real_key')).assertFalse();
      expect(LegacyKeys.toLegacy('not_a_real_key')).assertUndefined();
      expect(LegacyKeys.toCanonical('not-a-real-key')).assertUndefined();
    });

    it('omits the keys whose spelling never changes', () => {
      // The upstream table only lists keys that actually differ; unchanged keys
      // are handled by KeyConverter's fallback, which is covered separately.
      expect(LegacyKeys.toLegacy('name')).assertUndefined();
      expect(LegacyKeys.toLegacy('status')).assertUndefined();
      expect(LegacyKeys.toLegacy('trackers')).assertUndefined();
      expect(LegacyKeys.size).assertEqual(212);
    });
  });

  describe('LegacyKeys mechanical mappings', () => {
    it('converts camelCase legacy keys', () => {
      assertMapping('percent_done', 'percentDone');
      assertMapping('rate_download', 'rateDownload');
      assertMapping('upload_ratio', 'uploadRatio');
      assertMapping('hash_string', 'hashString');
      assertMapping('is_finished', 'isFinished');
      assertMapping('peers_connected', 'peersConnected');
      assertMapping('file_stats', 'fileStats');
      assertMapping('added_date', 'addedDate');
    });

    it('converts kebab-case legacy keys', () => {
      assertMapping('alt_speed_down', 'alt-speed-down');
      assertMapping('peer_limit_global', 'peer-limit-global');
      assertMapping('speed_limit_down', 'speed-limit-down');
      assertMapping('rpc_version_semver', 'rpc-version-semver');
      assertMapping('delete_local_data', 'delete-local-data');
      assertMapping('seed_queue_size', 'seed-queue-size');
    });

    it('maps the keys that only look like identity mappings', () => {
      // The legacy API is inconsistent even between sibling keys: `file_count`
      // is kebab-case while `piece_count` is camelCase.
      assertMapping('file_count', 'file-count');
      assertMapping('piece_count', 'pieceCount');
      assertMapping('error_string', 'errorString');
      assertMapping('download_limited', 'downloadLimited');
      assertMapping('webseeds_sending_to_us', 'webseedsSendingToUs');
    });
  });

  describe('LegacyKeys irregular mappings', () => {
    it('handles the keys whose legacy spelling cannot be derived', () => {
      assertMapping('cache_size_mib', 'cache-size-mb');
      assertMapping('is_utp', 'isUTP');
      assertMapping('seed_ratio_limit', 'seedRatioLimit');
      assertMapping('seed_ratio_limited', 'seedRatioLimited');
      assertMapping('bandwidth_priority', 'bandwidthPriority');
    });

    it('maps download_dir, whose correct spelling depends on context', () => {
      // The table resolves to the kebab-case form; `KeyConverter` overrides it
      // with camelCase for torrent_get / torrent_set. See KeyConversion tests.
      expect(LegacyKeys.toLegacy('download_dir')).assertEqual('download-dir');
      expect(LegacyKeys.toCanonical('download-dir')).assertEqual('download_dir');
      // `downloadDir` is context dependent, so the table alone cannot resolve it.
      expect(LegacyKeys.toCanonical('downloadDir')).assertUndefined();
    });

    it('maps the session keys that changed spelling entirely', () => {
      assertMapping('cache_size_mib', 'cache-size-mb');
      assertMapping('idle_seeding_limit', 'idle-seeding-limit');
      assertMapping('idle_seeding_limit_enabled', 'idle-seeding-limit-enabled');
      assertMapping('start_added_torrents', 'start-added-torrents');
    });
  });
}
