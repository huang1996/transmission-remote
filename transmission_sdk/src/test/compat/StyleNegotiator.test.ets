// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for dialect negotiation.
 *
 * Negotiation is what lets one SDK version drive both Transmission 4.1.0+ and
 * everything older. The rules under test are:
 *
 * - the `X-Transmission-Rpc-Version` header decides when present,
 * - its absence means "older than 4.1.0",
 * - a `METHOD_NOT_FOUND` reply is the fallback signal,
 * - a pinned mode never changes its mind.
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { StyleNegotiator } from '../../main/ets/compat/StyleNegotiator';
import { ApiStyle, ApiStyleMode } from '../../main/ets/compat/ApiStyle';
import { LegacyCodec, ModernCodec } from '../../main/ets/compat/RpcCodec';
import { JsonObject } from '../../main/ets/util/Json';
import { RpcVersion } from '../../main/ets/util/Semver';

export default function styleNegotiatorTest(): void {
  describe('StyleNegotiator initial state', () => {
    it('starts modern in AUTO mode, because 4.1.0+ dominates', () => {
      const negotiator = new StyleNegotiator(ApiStyleMode.AUTO);
      expect(negotiator.currentStyle).assertEqual(ApiStyle.MODERN);
      expect(negotiator.isAuto).assertTrue();
      expect(negotiator.serverVersion === undefined).assertTrue();
    });

    it('honours pinned modes from the start', () => {
      expect(new StyleNegotiator(ApiStyleMode.LEGACY).currentStyle).assertEqual(ApiStyle.LEGACY);
      expect(new StyleNegotiator(ApiStyleMode.LEGACY).isAuto).assertFalse();
      expect(new StyleNegotiator(ApiStyleMode.MODERN).currentStyle).assertEqual(ApiStyle.MODERN);
      expect(new StyleNegotiator(ApiStyleMode.MODERN).isAuto).assertFalse();
    });

    it('defaults to AUTO', () => {
      expect(new StyleNegotiator().styleMode).assertEqual(ApiStyleMode.AUTO);
    });

    it('hands out the codec matching the current style', () => {
      expect(new StyleNegotiator(ApiStyleMode.MODERN).codec()).assertEqual(ModernCodec.instance());
      expect(new StyleNegotiator(ApiStyleMode.LEGACY).codec()).assertEqual(LegacyCodec.instance());
    });
  });

  describe('StyleNegotiator version header', () => {
    it('selects modern for 6.0.0 and above', () => {
      const negotiator = new StyleNegotiator(ApiStyleMode.AUTO);
      expect(negotiator.observeVersionHeader('6.0.0')).assertFalse();
      expect(negotiator.currentStyle).assertEqual(ApiStyle.MODERN);
      expect(negotiator.serverVersion?.toString()).assertEqual('6.0.0');

      const newer = new StyleNegotiator(ApiStyleMode.AUTO);
      newer.observeVersionHeader('6.1.0');
      expect(newer.currentStyle).assertEqual(ApiStyle.MODERN);
    });

    it('selects legacy for a header below 6.0.0', () => {
      const negotiator = new StyleNegotiator(ApiStyleMode.AUTO);
      expect(negotiator.observeVersionHeader('5.3.0')).assertTrue();
      expect(negotiator.currentStyle).assertEqual(ApiStyle.LEGACY);
      expect(negotiator.serverVersion?.toString()).assertEqual('5.3.0');
    });

    it('treats a missing header as a pre-4.1.0 server', () => {
      const negotiator = new StyleNegotiator(ApiStyleMode.AUTO);
      expect(negotiator.observeVersionHeader(undefined)).assertTrue();
      expect(negotiator.currentStyle).assertEqual(ApiStyle.LEGACY);
      expect(negotiator.serverVersion === undefined).assertTrue();
    });

    it('ignores the header when the mode is pinned', () => {
      const pinnedModern = new StyleNegotiator(ApiStyleMode.MODERN);
      expect(pinnedModern.observeVersionHeader(undefined)).assertFalse();
      expect(pinnedModern.currentStyle).assertEqual(ApiStyle.MODERN);

      const pinnedLegacy = new StyleNegotiator(ApiStyleMode.LEGACY);
      expect(pinnedLegacy.observeVersionHeader('6.1.0')).assertFalse();
      expect(pinnedLegacy.currentStyle).assertEqual(ApiStyle.LEGACY);
      expect(pinnedLegacy.serverVersion?.toString()).assertEqual('6.1.0');
    });
  });

  describe('StyleNegotiator session payload', () => {
    it('learns the version from rpc_version_semver', () => {
      const negotiator = new StyleNegotiator(ApiStyleMode.AUTO);
      const settings: JsonObject = {};
      settings['rpc_version_semver'] = '5.3.0';
      expect(negotiator.observeSessionFields(settings)).assertTrue();
      expect(negotiator.currentStyle).assertEqual(ApiStyle.LEGACY);
      expect(negotiator.serverVersion?.toString()).assertEqual('5.3.0');
    });

    it('keeps modern for a 6.x server', () => {
      const negotiator = new StyleNegotiator(ApiStyleMode.AUTO);
      const settings: JsonObject = {};
      settings['rpc_version_semver'] = '6.1.0';
      expect(negotiator.observeSessionFields(settings)).assertFalse();
      expect(negotiator.currentStyle).assertEqual(ApiStyle.MODERN);
    });

    it('falls back to the deprecated integer counter', () => {
      const legacy = new StyleNegotiator(ApiStyleMode.AUTO);
      const legacySettings: JsonObject = {};
      legacySettings['rpc_version'] = 17;
      expect(legacy.observeSessionFields(legacySettings)).assertTrue();
      expect(legacy.currentStyle).assertEqual(ApiStyle.LEGACY);

      const modern = new StyleNegotiator(ApiStyleMode.AUTO);
      const modernSettings: JsonObject = {};
      modernSettings['rpc_version'] = 18;
      expect(modern.observeSessionFields(modernSettings)).assertFalse();
      expect(modern.currentStyle).assertEqual(ApiStyle.MODERN);
      expect(modern.serverVersion?.toString()).assertEqual('6.0.0');
    });

    it('prefers the semver field when both are present', () => {
      const negotiator = new StyleNegotiator(ApiStyleMode.AUTO);
      const settings: JsonObject = {};
      settings['rpc_version_semver'] = '6.1.0';
      settings['rpc_version'] = 18;
      negotiator.observeSessionFields(settings);
      expect(negotiator.serverVersion?.toString()).assertEqual('6.1.0');
    });

    it('changes nothing when the payload carries no version', () => {
      const negotiator = new StyleNegotiator(ApiStyleMode.AUTO);
      const settings: JsonObject = {};
      settings['version'] = '4.1.0 (abc)';
      expect(negotiator.observeSessionFields(settings)).assertFalse();
      expect(negotiator.currentStyle).assertEqual(ApiStyle.MODERN);
      expect(negotiator.serverVersion === undefined).assertTrue();
    });

    it('is safe with undefined and with unknown integers', () => {
      const negotiator = new StyleNegotiator(ApiStyleMode.AUTO);
      expect(negotiator.observeSessionFields(undefined)).assertFalse();
      const settings: JsonObject = {};
      settings['rpc_version'] = 999;
      expect(negotiator.observeSessionFields(settings)).assertFalse();
      expect(negotiator.serverVersion === undefined).assertTrue();
    });
  });

  describe('StyleNegotiator method-not-found fallback', () => {
    it('downgrades once in AUTO mode', () => {
      const negotiator = new StyleNegotiator(ApiStyleMode.AUTO);
      expect(negotiator.observeMethodNotFound()).assertTrue();
      expect(negotiator.currentStyle).assertEqual(ApiStyle.LEGACY);
      // A second report must not report another change, or the caller would
      // retry forever.
      expect(negotiator.observeMethodNotFound()).assertFalse();
    });

    it('never downgrades a pinned modern client', () => {
      const negotiator = new StyleNegotiator(ApiStyleMode.MODERN);
      expect(negotiator.observeMethodNotFound()).assertFalse();
      expect(negotiator.currentStyle).assertEqual(ApiStyle.MODERN);
    });
  });

  describe('StyleNegotiator listener', () => {
    it('fires only when the dialect actually changes', () => {
      const observed: ApiStyle[] = [];
      const observedVersions: string[] = [];
      const listener = (style: ApiStyle, version: RpcVersion | undefined): void => {
        observed.push(style);
        observedVersions.push(version === undefined ? 'none' : version.toString());
      };
      const negotiator = new StyleNegotiator(ApiStyleMode.AUTO, listener);

      // Already modern: no change, no notification.
      negotiator.observeVersionHeader('6.0.0');
      expect(observed.length).assertEqual(0);

      negotiator.observeVersionHeader(undefined);
      expect(observed.length).assertEqual(1);
      expect(observed[0]).assertEqual(ApiStyle.LEGACY);

      // Idempotent: still legacy, so no further notification.
      negotiator.observeVersionHeader(undefined);
      expect(observed.length).assertEqual(1);
    });
  });

  describe('StyleNegotiator reset', () => {
    it('forgets a negotiated result and starts over', () => {
      const negotiator = new StyleNegotiator(ApiStyleMode.AUTO);
      negotiator.observeVersionHeader(undefined);
      expect(negotiator.currentStyle).assertEqual(ApiStyle.LEGACY);

      negotiator.reset();
      expect(negotiator.currentStyle).assertEqual(ApiStyle.MODERN);
      expect(negotiator.serverVersion === undefined).assertTrue();
    });

    it('returns a pinned client to its pinned style', () => {
      const negotiator = new StyleNegotiator(ApiStyleMode.LEGACY);
      negotiator.observeVersionHeader('6.1.0');
      negotiator.reset();
      expect(negotiator.currentStyle).assertEqual(ApiStyle.LEGACY);
    });
  });

  describe('StyleNegotiator isolation', () => {
    it('does not leak the negotiated style between clients', () => {
      const first = new StyleNegotiator(ApiStyleMode.AUTO);
      first.observeVersionHeader(undefined);
      expect(first.currentStyle).assertEqual(ApiStyle.LEGACY);

      const second = new StyleNegotiator(ApiStyleMode.AUTO);
      expect(second.currentStyle).assertEqual(ApiStyle.MODERN);
      expect(second.serverVersion === undefined).assertTrue();
    });
  });
}
