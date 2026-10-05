// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * One label/value row of a detail screen's definition list.
 *
 * ## Why this is a component and not a `@Builder`
 *
 * It used to be `@Builder fieldRow(label: Resource, value: string)`, called as
 * `this.fieldRow($r('…'), formatBytes(this.currentTorrent().downloadedEver))`.
 * ArkUI passes `@Builder` arguments **by value**, and a state change does not
 * refresh UI built from such an argument. The rows were therefore rendered once
 * — while the torrent was still loading and every field held its default — and
 * never again.
 *
 * A component with `@Prop` parameters does not have that restriction: `@Prop` is
 * a one-way sync from the parent, so the row follows the torrent. The list screen
 * relies on the same mechanism via `TorrentRowView`.
 *
 * @since 1.0.0
 */
@Component
export struct DetailFieldRow {
  /** Row label, e.g. "Downloaded". */
  @Prop label: Resource = $r('app.string.common_unknown');

  /**
   * Row value.
   *
   * A plain string in most cases, or a string resource when the value is itself
   * localised — a torrent state such as "Seeding", for instance.
   */
  @Prop value: ResourceStr = '';

  /** Renders the value in the danger colour, for failure messages. */
  @Prop danger: boolean = false;

  /**
   * Renders the value in the accent colour.
   *
   * Used for the magnet link, which is the one value on the Info tab the user
   * might want to recognise as a link rather than as prose. It is not tappable:
   * the row is a definition list, and a link inside it would have to open a
   * browser, which is a decision the screen does not otherwise make.
   */
  @Prop accent: boolean = false;

  /** Colour of the value, chosen from the row's two flags. */
  private valueColor(): ResourceColor {
    if (this.danger) {
      return $r('app.color.danger');
    }
    return this.accent ? $r('app.color.accent') : $r('app.color.text_primary');
  }

  build(): void {
    Row() {
      Text(this.label)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .width(90);
      Text(this.value)
        .fontSize(13)
        .fontColor(this.valueColor())
        .layoutWeight(1);
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: 6, bottom: 6 });
  }
}
