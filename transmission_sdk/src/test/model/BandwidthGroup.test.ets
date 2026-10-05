// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for the `group_get` bandwidth-group model.
 *
 * `group_get` answers with a `group` array; a daemon that has never been given
 * a bandwidth group answers with an empty array or omits the key entirely, and
 * both must decode to an empty list.
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { Json, JsonArray, JsonObject } from '../../main/ets/util/Json';
import { BandwidthGroup } from '../../main/ets/model/BandwidthGroup';

/** One fully populated `group` entry. */
function groupJson(): JsonObject {
  const json: JsonObject = {};
  json['name'] = 'media';
  json['honors_session_limits'] = true;
  json['speed_limit_down'] = 2048;
  json['speed_limit_down_enabled'] = true;
  json['speed_limit_up'] = 512;
  json['speed_limit_up_enabled'] = false;
  return json;
}

export default function bandwidthGroupTest(): void {
  describe('BandwidthGroup.fromJson', () => {
    it('reads every canonical field', () => {
      const group = BandwidthGroup.fromJson(groupJson());
      expect(group.name).assertEqual('media');
      expect(group.honorsSessionLimits).assertTrue();
      expect(group.speedLimitDown).assertEqual(2048);
      expect(group.speedLimitDownEnabled).assertTrue();
      expect(group.speedLimitUp).assertEqual(512);
      expect(group.speedLimitUpEnabled).assertFalse();
    });

    it('returns safe defaults for an undefined payload', () => {
      const group = BandwidthGroup.fromJson(undefined);
      expect(group.name).assertEqual('');
      expect(group.honorsSessionLimits).assertFalse();
      expect(group.speedLimitDown).assertEqual(0);
      expect(group.speedLimitDownEnabled).assertFalse();
      expect(group.speedLimitUp).assertEqual(0);
      expect(group.speedLimitUpEnabled).assertFalse();
    });

    it('ignores unknown keys', () => {
      const json = groupJson();
      json['future_field'] = 'x';
      expect(BandwidthGroup.fromJson(json).name).assertEqual('media');
    });
  });

  describe('BandwidthGroup.listFromJson', () => {
    it('parses every entry of the group array', () => {
      const second: JsonObject = {};
      second['name'] = 'backup';
      second['speed_limit_up'] = 64;
      second['speed_limit_up_enabled'] = true;
      const json: JsonObject = {};
      json['group'] = [groupJson(), second] as JsonArray;
      const groups = BandwidthGroup.listFromJson(json);
      expect(groups.length).assertEqual(2);
      expect(groups[0].name).assertEqual('media');
      expect(groups[0].speedLimitDown).assertEqual(2048);
      expect(groups[1].name).assertEqual('backup');
      expect(groups[1].speedLimitUp).assertEqual(64);
      expect(groups[1].speedLimitUpEnabled).assertTrue();
    });

    it('returns an empty list when the group key is missing', () => {
      expect(BandwidthGroup.listFromJson(Json.emptyObject() as JsonObject).length).assertEqual(0);
      expect(BandwidthGroup.listFromJson(undefined).length).assertEqual(0);
    });

    it('returns an empty list for an empty group array', () => {
      const json: JsonObject = {};
      json['group'] = [] as JsonArray;
      expect(BandwidthGroup.listFromJson(json).length).assertEqual(0);
    });

    it('skips malformed entries instead of throwing', () => {
      const json: JsonObject = {};
      json['group'] = [groupJson(), 5, 'nope', null] as JsonArray;
      const groups = BandwidthGroup.listFromJson(json);
      expect(groups.length).assertEqual(1);
      expect(groups[0].name).assertEqual('media');
    });
  });
}
