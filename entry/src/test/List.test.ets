// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Local unit-test entry point for the sample application.
 *
 * DevEco Studio discovers `entry/src/test/List.test.ets` and calls its default
 * export to register the suites. The host harness does not use this file — it
 * globs `*.test.ets` under `entry/src/test` directly — so both runners execute
 * exactly the same tests.
 *
 * Only the ArkUI-free layers are covered here: `model/` and the parts of
 * `viewmodel/` that contain no markup. The screens themselves are verified by
 * `scripts/lint-arkts.mjs` and by building in DevEco Studio.
 *
 * @since 1.0.0
 */

import appModelsTest from './model/AppModels.test';
import fileTreeTest from './viewmodel/FileTree.test';
import formattersTest from './viewmodel/Formatters.test';
import torrentListModelTest from './viewmodel/TorrentListModel.test';

/** Registers every suite with the hypium runner. */
export default function testsuite(): void {
  appModelsTest();
  torrentListModelTest();
  fileTreeTest();
  formattersTest();
}
