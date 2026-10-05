// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * 关于页面：这个软件是什么、有哪几块能力、与哪些服务端版本能对上、按什么许可分发，
 * 以及当前这份构建的版本信息。
 *
 * 版本号是**运行期**从包信息里读的，不是写死的常量。app.json5 里那份 versionName
 * 是构建期的唯一来源，如果这里再抄一份，改版本时就得记得改两处，而漏掉的那一次
 * 恰好会出现在最不该出错的地方 —— 一个专门用来告诉人家版本号的页面。
 *
 * 读包信息是可能失败的（它标了 `@throws`），所以整体包在 try 里，读不到就退回
 * `—`：关于页不该因为一次系统调用失败变成空白。
 *
 * @since 1.0.0
 */

import { bundleManager } from '@kit.AbilityKit';
import { AppIcons } from '../theme/AppIcons';
import { DetailFieldRow } from '../components/DetailFieldRow';

/** 读不到包信息时用的占位符。 */
const UNKNOWN: string = '—';

/** 一份构建的身份信息，取自系统而不是源码里的常量。 */
class BuildInfo {
  /** 包名，例如 `huangtao.hmapp.transmissionremote`。 */
  bundleName: string = UNKNOWN;
  /** 对外可见的版本名，例如 `1.0.0`。 */
  versionName: string = UNKNOWN;
  /** 单调递增的版本号，例如 `1000000`。 */
  versionCode: string = UNKNOWN;
  /** 目标 API 版本，例如 `26`。 */
  targetApi: string = UNKNOWN;
}

/** 读取当前这份构建的身份信息；任何一项读不到都留成占位符。 */
function readBuildInfo(): BuildInfo {
  const info = new BuildInfo();
  try {
    const bundle = bundleManager.getBundleInfoForSelfSync(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT,
    );
    info.bundleName = bundle.name;
    info.versionName = bundle.versionName;
    info.versionCode = `${bundle.versionCode}`;
    info.targetApi = `API ${bundle.targetVersion}`;
  } catch (error) {
    console.warn('Transmission: could not read the bundle info for the about screen');
  }
  return info;
}

@Component
export struct AboutPage {
  /** 本页被推入的导航栈；由 `onReady` 回填。 */
  pathStack: NavPathStack = new NavPathStack();

  private info: BuildInfo = readBuildInfo();

  build(): void {
    NavDestination() {
      Scroll() {
        Column({ space: 20 }) {
          this.identityCard();
          this.introCard();
          this.featuresCard();
          this.compatibilityCard();
          this.licenseCard();

          // Text($r('app.string.about_copyright'))
          //   .fontSize(12)
          //   .fontColor($r('app.color.text_tertiary'))
          //   .width('100%')
          //   .textAlign(TextAlign.Center);
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 28 });
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Auto)
    }
    .title($r('app.string.page_title_about'))
    .backgroundColor($r('app.color.app_background'))
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }

  // -------------------------------------------------------------- 卡片

  /**
   * 顶部：图标、名称、版本。
   *
   * 名称直接取 `EntryAbility_label` —— 那是桌面和应用信息里显示的那一个字符串。
   * 不再另建一条同名文案，否则改名时就有两处要记得改。
   */
  @Builder
  identityCard(): void {
    Column({ space: 10 }) {
      Image($r('app.media.app_icon_foreground'))
        .width(72)
        .height(72)
        .borderRadius(18);
      Text($r('app.string.EntryAbility_label'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'));
      Text($r('app.string.about_version', this.info.versionName, this.info.versionCode))
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'));
    }
    .width('100%')
    .padding({ top: 16, bottom: 8 })
    .alignItems(HorizontalAlign.Center);
  }

  /** 简介：一段文字讲清「它是什么、数据经不经过云端」。 */
  @Builder
  introCard(): void {
    Column({ space: 8 }) {
      this.sectionTitle($r('app.string.about_intro_title'));
      Text($r('app.string.about_intro'))
        .fontSize(14)
        .lineHeight(22)
        .fontColor($r('app.color.text_primary'))
        .width('100%');
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .borderRadius(12)
    .backgroundColor($r('app.color.surface'));
  }

  /** 功能：每条一行图标 + 标题 + 说明。 */
  @Builder
  featuresCard(): void {
    Column({ space: 12 }) {
      this.sectionTitle($r('app.string.about_features_title'));
      this.featureRow(
        AppIcons.DOWNLOAD,
        $r('app.string.about_feature_torrents'),
        $r('app.string.about_feature_torrents_desc'),
      );
      this.featureRow(
        AppIcons.FILE,
        $r('app.string.about_feature_files'),
        $r('app.string.about_feature_files_desc'),
      );
      this.featureRow(
        AppIcons.INFO,
        $r('app.string.about_feature_detail'),
        $r('app.string.about_feature_detail_desc'),
      );
      this.featureRow(
        AppIcons.SERVER,
        $r('app.string.about_feature_servers'),
        $r('app.string.about_feature_servers_desc'),
      );
      this.featureRow(
        AppIcons.THEME,
        $r('app.string.about_feature_appearance'),
        $r('app.string.about_feature_appearance_desc'),
      );
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .borderRadius(12)
    .backgroundColor($r('app.color.surface'));
  }

  /** 兼容性：接口协议与系统版本各一段。 */
  @Builder
  compatibilityCard(): void {
    Column({ space: 8 }) {
      this.sectionTitle($r('app.string.about_compat_title'));
      Text($r('app.string.about_compat_rpc'))
        .fontSize(14)
        .lineHeight(22)
        .fontColor($r('app.color.text_primary'))
        .width('100%');
      Text($r('app.string.about_compat_platform'))
        .fontSize(14)
        .lineHeight(22)
        .fontColor($r('app.color.text_primary'))
        .width('100%');
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .borderRadius(12)
    .backgroundColor($r('app.color.surface'));
  }

  /** 开源许可：SPDX 标识符单独一行，说明另起一段。 */
  @Builder
  licenseCard(): void {
    Column({ space: 8 }) {
      this.sectionTitle($r('app.string.about_license_title'));
      Text($r('app.string.about_license_value'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%');
      Text($r('app.string.about_license_note'))
        .fontSize(13)
        .lineHeight(20)
        .fontColor($r('app.color.text_secondary'))
        .width('100%');
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .borderRadius(12)
    .backgroundColor($r('app.color.surface'));
  }


  // -------------------------------------------------------------- 部件

  /** 卡片里的小节标题。 */
  @Builder
  sectionTitle(title: Resource): void {
    Text(title)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.text_secondary'))
      .width('100%');
  }

  /** 一条功能：左侧图标，右侧标题与说明。 */
  @Builder
  featureRow(icon: Resource, title: Resource, description: Resource): void {
    Row({ space: 10 }) {
      SymbolGlyph(icon)
        .fontSize(18)
        .fontColor([$r('app.color.accent')])
        .width(24);
      Column({ space: 2 }) {
        Text(title)
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .width('100%');
        Text(description)
          .fontSize(12)
          .lineHeight(18)
          .fontColor($r('app.color.text_secondary'))
          .width('100%');
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1);
    }
    .width('100%')
    .alignItems(VerticalAlign.Top);
  }
}
