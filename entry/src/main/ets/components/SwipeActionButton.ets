// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * 左滑露出的一个操作按钮。
 *
 * 圈形托盘里放图标、下面跟一行小字。**只有托盘填色**，整条左滑区保持中性
 * 底色 —— 否则一滑动就在列表上刷出一块告警色，比它承载的信息响得多。
 *
 * 抽成组件是因为列表页和服务器页都要用它：同一套视觉如果在两处各写一遍，
 * 改一处忘一处只是时间问题（本工程已经因为「同一个名字写两遍」踩过坑）。
 *
 * @since 1.0.0
 */

import { AppIcons } from '../theme/AppIcons';

@Component
export struct SwipeActionButton {
  /** 托盘里的图标。 */
  @Prop icon: Resource = AppIcons.CHECK;
  /** 图标下方的说明文字。 */
  @Prop label: Resource = $r('app.string.common_ok');
  /** 托盘底色与文字颜色。 */
  @Prop color: Resource = $r('app.color.accent');
  /** 点击回调，由调用方决定做什么。 */
  onTap: () => void = () => {};

  build(): void {
    Column({ space: 2 }) {
      Stack() {
        SymbolGlyph(this.icon)
          .fontSize(16)
          .fontColor([$r('app.color.text_on_accent')]);
      }
      .width(32)
      .height(32)
      .borderRadius(16)
      .backgroundColor(this.color);

      Text(this.label)
        .fontSize(10)
        .fontColor(this.color)
        .maxLines(1);
    }
    .justifyContent(FlexAlign.Center)
    .width(58)
    .height('100%')
    .onClick(() => {
      this.onTap();
    });
  }
}
