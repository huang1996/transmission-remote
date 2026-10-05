// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Local unit-test entry point for DevEco Studio.
 *
 * DevEco discovers `src/test/List.test.ets` and calls its default export to
 * register every suite. The host harness in `scripts/run-tests.mjs` does not use
 * this file — it globs `*.test.ets` directly — so the two runners always execute
 * exactly the same tests.
 *
 * Run from DevEco Studio with *Run > Test*, or from the command line with
 * `npm test` (see the repository README).
 *
 * @since 1.0.0
 */

import jsonTest from './util/Json.test';
import base64Test from './util/Base64.test';
import semverTest from './util/Semver.test';
import bencodeTest from './util/Bencode.test';
import loggerTest from './util/Logger.test';

import transmissionErrorTest from './error/TransmissionError.test';

import legacyKeysTest from './compat/LegacyKeys.test';
import keyConversionTest from './compat/KeyConversion.test';
import rpcCodecTest from './compat/RpcCodec.test';
import styleNegotiatorTest from './compat/StyleNegotiator.test';

import transmissionConfigTest from './core/TransmissionConfig.test';
import rpcClientTest from './core/RpcClient.test';
import rpcBatchTest from './core/RpcBatch.test';

import torrentTest from './model/Torrent.test';
import torrentRequestsTest from './model/TorrentRequests.test';
import torrentResultsTest from './model/TorrentResults.test';
import sessionSettingsTest from './model/SessionSettings.test';
import sessionSetRequestTest from './model/SessionSetRequest.test';
import sessionStatsTest from './model/SessionStats.test';
import bandwidthGroupTest from './model/BandwidthGroup.test';
import systemInfoTest from './model/SystemInfo.test';
import metainfoTest from './model/Metainfo.test';

import torrentApiTest from './api/TorrentApi.test';
import sessionApiTest from './api/SessionApi.test';
import systemApiTest from './api/SystemApi.test';
import bandwidthGroupApiTest from './api/BandwidthGroupApi.test';

import transmissionClientTest from './client/TransmissionClient.test';

/** Registers every suite with the hypium runner. */
export default function testsuite(): void {
  // Utilities and errors.
  jsonTest();
  base64Test();
  semverTest();
  bencodeTest();
  loggerTest();
  transmissionErrorTest();

  // Protocol compatibility.
  legacyKeysTest();
  keyConversionTest();
  rpcCodecTest();
  styleNegotiatorTest();

  // RPC engine.
  transmissionConfigTest();
  rpcClientTest();
  rpcBatchTest();

  // Models.
  torrentTest();
  torrentRequestsTest();
  torrentResultsTest();
  sessionSettingsTest();
  sessionSetRequestTest();
  sessionStatsTest();
  bandwidthGroupTest();
  systemInfoTest();
  metainfoTest();

  // Services.
  torrentApiTest();
  sessionApiTest();
  systemApiTest();
  bandwidthGroupApiTest();

  // End-to-end.
  transmissionClientTest();
}
