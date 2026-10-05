// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * HarmonyOS implementation of {@link Logger}, backed by `@ohos.hilog`.
 *
 * @since 1.0.0
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { AbstractLogger, LogLevel } from '../util/Logger';

/** `hilog` domain used by the SDK. */
const DOMAIN: number = 0x0d5d;

/** `hilog` tag used by the SDK. */
const TAG: string = 'TransmissionSDK';

/**
 * Routes SDK diagnostics to the HarmonyOS system log.
 *
 * ```ts
 * const client = new TransmissionClientBuilder()
 *   .url('http://192.168.1.10:9091/transmission/rpc')
 *   .logger(new HilogLogger(LogLevel.DEBUG))
 *   .build();
 * ```
 */
export class HilogLogger extends AbstractLogger {
  /**
   * @param minLevel lowest severity that is emitted
   */
  constructor(minLevel: LogLevel = LogLevel.WARN) {
    super(minLevel);
  }

  protected write(level: LogLevel, tag: string, message: string): void {
    const label = `${TAG}/${tag}`;
    switch (level) {
      case LogLevel.DEBUG:
        hilog.debug(DOMAIN, label, '%{public}s', message);
        break;
      case LogLevel.INFO:
        hilog.info(DOMAIN, label, '%{public}s', message);
        break;
      case LogLevel.WARN:
        hilog.warn(DOMAIN, label, '%{public}s', message);
        break;
      default:
        hilog.error(DOMAIN, label, '%{public}s', message);
        break;
    }
  }
}
