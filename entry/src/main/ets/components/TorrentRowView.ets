// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * One row of the torrent list.
 *
 * Layout follows the reference design: the name and its metadata, the two
 * transfer rates, and a full-width progress bar. There is deliberately no
 * leading button — the round pause/resume control that used to sit here was the
 * only per-torrent command in the row, and it cost 56dp of list width; start and
 * pause now live on the swipe actions instead.
 *
 * The row is a pure presentation component — it owns no state and performs no
 * RPC. The swipe actions live on the enclosing `ListItem`, and taps are reported
 * through {@link TorrentRowView.onTap}.
 *
 * Tapping and long-pressing are handled as a single exclusive gesture group
 * rather than `onClick` plus a gesture: with both registered independently a
 * long press also fires the click on release, which would open the detail screen
 * every time a selection is started.
 *
 * @since 1.0.0
 */

import { TorrentRow } from '../viewmodel/TorrentListModel';
import { AppIcons } from '../theme/AppIcons';

@Component
export struct TorrentRowView {
  /** Torrent to render. `@Prop` so a refreshed row replaces the old one. */
  @Prop row: TorrentRow = new TorrentRow();

  /** True while this row is part of the current multi-selection. */
  @Prop selected: boolean = false;

  /** Invoked when the row is tapped. */
  onTap: (row: TorrentRow) => void = () => {};

  /** Invoked when the row is long-pressed, which starts a multi-selection. */
  onLongPress: (row: TorrentRow) => void = () => {};

  build(): void {
    Column({ space: 4 }) {
      Text(this.row.name)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%');

      Row() {
        Text(this.row.sizeLabel)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'));
        Blank();
        Text(this.row.downSpeedLabel)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'));
        SymbolGlyph(AppIcons.DOWNLOAD)
          .fontSize(13)
          .fontColor([$r('app.color.success')]);
      }
      .width('100%');

      Row() {
        Text($r('app.string.list_uploaded_ratio', this.row.uploadedLabel, this.row.ratioLabel))
          .fontSize(13)
          .fontColor($r('app.color.text_tertiary'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        Text(this.row.upSpeedLabel)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'));
        SymbolGlyph(AppIcons.UPLOAD)
          .fontSize(13)
          .fontColor([$r('app.color.danger')]);
      }
      .width('100%');

      this.progressBar();

      this.statusCaption();
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .backgroundColor(this.selected ? $r('app.color.selected_row') : $r('app.color.surface'))
    .borderRadius(10)
    .borderWidth(this.selected ? 1 : 0)
    .borderColor($r('app.color.accent'))
    .gesture(
      GestureGroup(
        GestureMode.Exclusive,
        LongPressGesture({ repeat: false, duration: 500 })
          .onAction(() => {
            this.onLongPress(this.row);
          }),
        TapGesture({ count: 1 })
          .onAction(() => {
            this.onTap(this.row);
          }),
      ),
    );
  }

  /**
   * The line under the progress bar.
   *
   * Only shown while something is moving — a finished torrent needs no caption,
   * because a full green bar already says everything.
   *
   * Takes no parameter on purpose: a `@Builder` argument is passed by value and
   * does not refresh on a state change, so the caption reads the row directly.
   */
  @Builder
  statusCaption(): void {
    if (this.row.isVerifying || this.row.isDownloading) {
      // The message is chosen inline rather than through a second, parameterised
      // builder: an argument that derives from a state variable (`this.row.…`)
      // is exactly the case ArkUI does not refresh.
      Text(
        this.row.isVerifying
          ? $r('app.string.state_verifying_progress', this.row.barPercentLabel)
          : $r('app.string.state_downloading_progress', this.row.barPercentLabel),
      )
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%');
    }
  }

  /** Full-width progress bar, tinted by the torrent's state. */
  @Builder
  progressBar(): void {
    Stack({ alignContent: Alignment.Start }) {
      Row()
        .width('100%')
        .height(3)
        .borderRadius(2)
        .backgroundColor($r('app.color.progress_track'));

      Row()
        .width(`${Math.max(2, Math.round(this.row.barValue * 100))}%`)
        .height(3)
        .borderRadius(2)
        .backgroundColor(this.row.progressColor);
    }
    .width('100%')
    .height(3)
    .margin({ top: 4 });
  }
}
