// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for RPC version parsing and the semver/integer translation table.
 *
 * The negotiation logic depends entirely on this mapping: `6.0.0` is the
 * boundary at which Transmission started speaking JSON-RPC 2.0, and older
 * servers only report the deprecated integer counter.
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { RpcVersion, RpcVersions } from '../../main/ets/util/Semver';

export default function semverTest(): void {
  describe('RpcVersion parsing', () => {
    it('parses a plain semver string', () => {
      const version = RpcVersion.parse('6.0.0');
      expect(version === undefined).assertFalse();
      if (version !== undefined) {
        expect(version.major).assertEqual(6);
        expect(version.minor).assertEqual(0);
        expect(version.patch).assertEqual(0);
        expect(version.toString()).assertEqual('6.0.0');
      }
    });

    it('ignores pre-release and build suffixes', () => {
      const preRelease = RpcVersion.parse('6.1.0-dev');
      expect(preRelease === undefined ? 'none' : preRelease.toString()).assertEqual('6.1.0');
      const withBuild = RpcVersion.parse('4.1.0+20240101');
      expect(withBuild === undefined ? 'none' : withBuild.toString()).assertEqual('4.1.0');
    });

    it('accepts the format Transmission uses for the full version string', () => {
      const version = RpcVersion.parse('4.1.0 (ae226418eb)');
      expect(version === undefined ? 'none' : version.toString()).assertEqual('4.1.0');
    });

    it('zero-fills missing components', () => {
      const short = RpcVersion.parse('6');
      expect(short === undefined ? 'none' : short.toString()).assertEqual('6.0.0');
      const partial = RpcVersion.parse('6.1');
      expect(partial === undefined ? 'none' : partial.toString()).assertEqual('6.1.0');
    });

    it('returns undefined for absent or non-numeric input', () => {
      expect(RpcVersion.parse(undefined) === undefined).assertTrue();
      expect(RpcVersion.parse('') === undefined).assertTrue();
      expect(RpcVersion.parse('abc') === undefined).assertTrue();
      expect(RpcVersion.parse('  ') === undefined).assertTrue();
    });
  });

  describe('RpcVersion comparison', () => {
    it('orders components numerically, not lexically', () => {
      const ten = new RpcVersion(6, 10, 0);
      const two = new RpcVersion(6, 2, 0);
      expect(ten.compareTo(two)).assertLarger(0);
      expect(two.compareTo(ten)).assertLess(0);
      expect(two.compareTo(new RpcVersion(6, 2, 0))).assertEqual(0);
    });

    it('treats missing components as zero', () => {
      expect(new RpcVersion(6).equals(new RpcVersion(6, 0, 0))).assertTrue();
      expect(new RpcVersion(6, 0, 1).isAtLeast(new RpcVersion(6))).assertTrue();
    });

    it('implements isAtLeast, isBelow and equals', () => {
      const fiveThree = RpcVersions.V5_3_0;
      const six = RpcVersions.V6_0_0;
      expect(six.isAtLeast(fiveThree)).assertTrue();
      expect(fiveThree.isBelow(six)).assertTrue();
      expect(fiveThree.isAtLeast(six)).assertFalse();
      expect(fiveThree.equals(RpcVersion.parse('5.3.0'))).assertTrue();
      expect(fiveThree.equals(undefined)).assertFalse();
    });
  });

  describe('RpcVersions translation table', () => {
    it('maps the documented integer counter to semver', () => {
      expect(RpcVersions.fromInteger(1)?.toString()).assertEqual('1.0.0');
      expect(RpcVersions.fromInteger(5)?.toString()).assertEqual('2.0.0');
      expect(RpcVersions.fromInteger(16)?.toString()).assertEqual('5.2.0');
      expect(RpcVersions.fromInteger(17)?.toString()).assertEqual('5.3.0');
      expect(RpcVersions.fromInteger(18)?.toString()).assertEqual('6.0.0');
    });

    it('rejects unknown integers instead of guessing', () => {
      expect(RpcVersions.fromInteger(0) === undefined).assertTrue();
      expect(RpcVersions.fromInteger(999) === undefined).assertTrue();
      expect(RpcVersions.fromInteger(undefined) === undefined).assertTrue();
      expect(RpcVersions.fromInteger(Number.NaN) === undefined).assertTrue();
    });

    it('agrees with the highest known integer', () => {
      expect(RpcVersions.MAXIMUM_KNOWN_INTEGER).assertEqual(18);
    });

    it('treats 6.0.0 as the JSON-RPC boundary', () => {
      expect(RpcVersions.supportsJsonRpc(RpcVersions.V5_3_0)).assertFalse();
      expect(RpcVersions.supportsJsonRpc(RpcVersions.V6_0_0)).assertTrue();
      expect(RpcVersions.supportsJsonRpc(new RpcVersion(7, 0, 0))).assertTrue();
      expect(RpcVersions.supportsJsonRpc(undefined)).assertFalse();
    });
  });
}
