// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for the elapsed-duration formatter.
 *
 * `formatDuration` feeds the Runtime section of the Info tab and the countdown
 * on the Tracker cards. Its whole job is to pick the two units a number is worth
 * showing — and to keep showing something for zero, which is the case a
 * "how much longer" formatter would render as `—`.
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { formatDuration } from '../../main/ets/viewmodel/Formatters';

export default function formattersTest(): void {
  describe('formatDuration', () => {
    it('counts in seconds below a minute', () => {
      expect(formatDuration(1)).assertEqual('1s');
      expect(formatDuration(59)).assertEqual('59s');
    });

    it('pairs minutes with seconds', () => {
      // The reference layout shows the next announce as `4m 49s`.
      expect(formatDuration(289)).assertEqual('4m 49s');
    });

    it('pairs hours with minutes', () => {
      expect(formatDuration(3600)).assertEqual('1h 0m');
      expect(formatDuration(68160)).assertEqual('18h 56m');
    });

    it('pairs days with hours', () => {
      expect(formatDuration(86400)).assertEqual('1d 0h');
      expect(formatDuration(90000)).assertEqual('1d 1h');
    });

    it('truncates rather than rounds', () => {
      // A counter that rounds up would show `1m 60s` for 119.6 seconds.
      expect(formatDuration(119.6)).assertEqual('1m 59s');
    });

    it('reports zero and nonsense as `0s`', () => {
      expect(formatDuration(0)).assertEqual('0s');
      expect(formatDuration(-5)).assertEqual('0s');
      expect(formatDuration(Number.NaN)).assertEqual('0s');
      expect(formatDuration(Number.POSITIVE_INFINITY)).assertEqual('0s');
    });
  });
}
