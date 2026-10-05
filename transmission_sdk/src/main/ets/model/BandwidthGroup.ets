// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Bandwidth groups returned by `group_get`.
 *
 * A bandwidth group collects torrents that share speed limits independent of
 * the session-wide ones. `group_get` returns the groups in a `group` array.
 *
 * @since 1.0.0
 */

import { Json, JsonObject } from '../util/Json';

/**
 * One entry of `group_get`'s `group` array.
 */
export class BandwidthGroup {
  /** Group name. */
  name: string = '';
  /** True when the group honours the session-wide speed limits instead of its own. */
  honorsSessionLimits: boolean = false;
  /** Download speed limit, in kB/s. */
  speedLimitDown: number = 0;
  /** True when {@link speedLimitDown} is honoured. */
  speedLimitDownEnabled: boolean = false;
  /** Upload speed limit, in kB/s. */
  speedLimitUp: number = 0;
  /** True when {@link speedLimitUp} is honoured. */
  speedLimitUpEnabled: boolean = false;

  /**
   * Parses one `group` entry.
   *
   * @param json wire object with canonical keys
   */
  static fromJson(json: JsonObject | undefined): BandwidthGroup {
    const group = new BandwidthGroup();
    group.name = Json.getString(json, 'name');
    group.honorsSessionLimits = Json.getBoolean(json, 'honors_session_limits');
    group.speedLimitDown = Json.getNumber(json, 'speed_limit_down');
    group.speedLimitDownEnabled = Json.getBoolean(json, 'speed_limit_down_enabled');
    group.speedLimitUp = Json.getNumber(json, 'speed_limit_up');
    group.speedLimitUpEnabled = Json.getBoolean(json, 'speed_limit_up_enabled');
    return group;
  }

  /**
   * Parses every entry of a `group_get` result's `group` array.
   *
   * @param json wire object with canonical keys
   */
  static listFromJson(json: JsonObject | undefined): BandwidthGroup[] {
    const raw = Json.getArray(json, 'group');
    const groups: BandwidthGroup[] = [];
    if (raw === undefined) {
      return groups;
    }
    for (const item of raw) {
      const asObject = Json.asObject(item);
      if (asObject !== undefined) {
        groups.push(BandwidthGroup.fromJson(asObject));
      }
    }
    return groups;
  }
}
