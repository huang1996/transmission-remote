/**
 * Application entry point of the sample app.
 *
 * @since 1.0.0
 */

import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { ThemeManager } from '../theme/ThemeManager';

const DOMAIN: number = 0x0000;
const TAG: string = 'TransmissionSample';

/** Hosts the sample UI. */
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // Applying the stored appearance before the first frame avoids a flash of
    // the wrong palette on a cold start.
    ThemeManager.applyPersisted(this.context);
    hilog.info(DOMAIN, TAG, '%{public}s', 'ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'failed to load the content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, '%{public}s', 'content loaded');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'ability onBackground');
  }
}
