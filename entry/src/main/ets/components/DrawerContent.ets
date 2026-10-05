// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * The navigation drawer.
 *
 * Mirrors the reference design: the server list on top, then the torrent
 * filter with live counts, then the sort key and direction, and a footer with
 * the options entry point and the server's free space.
 *
 * Appearance is deliberately absent: the night-mode switch that used to sit in
 * the footer duplicated *Options → Appearance*, which offers all three states
 * (`SYSTEM`, `LIGHT`, `DARK`) where the switch could only ever express two.
 *
 * The drawer is a pure presentation component. It takes primitives (which ArkUI
 * observes reliably) plus callbacks, and never touches the SDK itself.
 *
 * @since 1.0.0
 */

import { ServerProfile, TorrentFilter, TorrentSort } from '../model/AppModels';
import { AppIcons } from '../theme/AppIcons';
import {
  ALL_FILTERS,
  ALL_SORTS,
  torrentFilterLabel,
  torrentSortLabel,
} from '../viewmodel/TorrentListModel';

@Component
export struct DrawerContent {
  /** Saved servers, in display order. */
  @Prop servers: ServerProfile[] = [];
  /** Id of the selected server. */
  @Prop activeServerId: string = '';
  /** Currently selected filter. */
  @Prop filter: TorrentFilter = TorrentFilter.ALL;
  /** Currently selected sort key. */
  @Prop sortBy: TorrentSort = TorrentSort.QUEUE;
  /** True when the sort runs ascending. */
  @Prop sortAscending: boolean = true;
  /** Torrent count per filter, aligned with `ALL_FILTERS`. */
  @Prop filterCounts: number[] = [];
  /** Pre-formatted free space of the server's download directory. */
  @Prop freeSpaceLabel: string = '';

  /**
   * Whether the sort key list is unfolded.
   *
   * Twelve sort keys make this the tallest section in the drawer, so it starts
   * expanded — matching the reference layout — and can be folded away to reach
   * the footer without scrolling.
   */
  @State sortExpanded: boolean = false;

  /** Switch the active server. */
  onSelectServer: (serverId: string) => void = () => {};
  /** Open the server manager, where servers can be added, edited or removed. */
  onManageServers: () => void = () => {};
  /** Pick a filter. */
  onSelectFilter: (filter: TorrentFilter) => void = () => {};
  /** Pick a sort key. */
  onSelectSort: (sort: TorrentSort) => void = () => {};
  /** Flip the sort direction. */
  onToggleDirection: () => void = () => {};
  /** Open the options screen. */
  onOpenSettings: () => void = () => {};
  /** Open the about screen. */
  onOpenAbout: () => void = () => {};
  /** Re-query the server's free space. */
  onRefreshFreeSpace: () => void = () => {};

  build(): void {
    Scroll() {
      Column({ space: 0 }) {
        this.serverSection();
        this.divider();
        this.filterSection();
        this.divider();
        this.sortSection();
        this.divider();
        this.footerSection();
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start);
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.drawer_background'));
  }

  /** Section heading, matching the muted small caps of the reference UI. */
  @Builder
  sectionTitle(title: Resource): void {
    Text(title)
      .fontSize(13)
      .fontColor($r('app.color.text_tertiary'))
      .padding({ left: 16, right: 16, top: 16, bottom: 8 });
  }

  /** Hairline separator between drawer sections. */
  @Builder
  divider(): void {
    Divider()
      .strokeWidth(1)
      .color($r('app.color.divider'))
      .margin({ top: 8 });
  }

  // -------------------------------------------------------------- servers

  @Builder
  serverSection(): void {
    Column() {
      this.sectionTitle($r('app.string.drawer_servers'));

      ForEach(
        this.servers,
        (server: ServerProfile) => {
          this.serverRow(server);
        },
        (server: ServerProfile) => server.id,
      );

      if (this.servers.length === 0) {
        Text($r('app.string.servers_empty_hint'))
          .fontSize(13)
          .fontColor($r('app.color.text_tertiary'))
          .padding({ left: 16, right: 16, top: 4, bottom: 8 });
      }

      this.actionRow(AppIcons.SERVER, $r('app.string.drawer_manage_servers'), () => {
        this.onManageServers();
      });
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  /** One selectable server. */
  @Builder
  serverRow(server: ServerProfile): void {
    Column({ space: 2 }) {
      Text(server.displayName)
        .fontSize(15)
        .fontColor(server.id === this.activeServerId ? $r('app.color.accent') : $r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
      Text(server.endpoint)
        .fontSize(12)
        .fontColor($r('app.color.text_tertiary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .backgroundColor(server.id === this.activeServerId ? $r('app.color.selected_row') : Color.Transparent)
    .onClick(() => {
      this.onSelectServer(server.id);
    });
  }

  // --------------------------------------------------------------- filter

  @Builder
  filterSection(): void {
    Column() {
      this.sectionTitle($r('app.string.drawer_filter'));

      ForEach(
        ALL_FILTERS,
        (filter: TorrentFilter, index: number) => {
          this.filterRow(filter, index);
        },
        (filter: TorrentFilter) => `filter-${filter}`,
      );
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  /** One filter, with the number of torrents it would show. */
  @Builder
  filterRow(filter: TorrentFilter, index: number): void {
    Row() {
      Text(torrentFilterLabel(filter))
        .fontSize(15)
        .fontColor(filter === this.filter ? $r('app.color.accent') : $r('app.color.text_primary'))
        .fontWeight(filter === this.filter ? FontWeight.Medium : FontWeight.Normal)
        .layoutWeight(1);
      Text(`${this.countAt(index)}`)
        .fontSize(14)
        .fontColor($r('app.color.text_tertiary'));
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .onClick(() => {
      this.onSelectFilter(filter);
    });
  }

  // ----------------------------------------------------------------- sort

  @Builder
  sortSection(): void {
    Column() {
      // The whole heading row folds the section, which is what the chevron
      // promises. The direction control is a separate row below it.
      Row() {
        Text($r('app.string.drawer_sort'))
          .fontSize(13)
          .fontColor($r('app.color.text_tertiary'))
          .layoutWeight(1);
        SymbolGlyph(this.sortExpanded ? AppIcons.CHEVRON_UP : AppIcons.CHEVRON_DOWN)
          .fontSize(15)
          .fontColor([$r('app.color.icon')])
          .padding({ left: 8, right: 8 });
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 8 })
      .onClick(() => {
        this.sortExpanded = !this.sortExpanded;
      });

      if (this.sortExpanded) {
        this.directionRow();

        ForEach(
          ALL_SORTS,
          (sort: TorrentSort) => {
            this.sortRow(sort);
          },
          (sort: TorrentSort) => `sort-${sort}`,
        );
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  /** Flips between ascending and descending order. */
  @Builder
  directionRow(): void {
    Row({ space: 6 }) {
      Text(this.sortAscending ? $r('app.string.drawer_sort_ascending') : $r('app.string.drawer_sort_descending'))
        .fontSize(14)
        .fontColor($r('app.color.accent'))
        .layoutWeight(1);
      SymbolGlyph(this.sortAscending ? AppIcons.CHEVRON_UP : AppIcons.CHEVRON_DOWN)
        .fontSize(14)
        .fontColor([$r('app.color.accent')]);
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 8 })
    .onClick(() => {
      this.onToggleDirection();
    });
  }

  /** One sort key, highlighted when active. */
  @Builder
  sortRow(sort: TorrentSort): void {
    Row() {
      Text(torrentSortLabel(sort))
        .fontSize(15)
        .fontColor(sort === this.sortBy ? $r('app.color.text_on_accent') : $r('app.color.text_primary'))
        .layoutWeight(1);
      if (sort === this.sortBy) {
        SymbolGlyph(AppIcons.CHECK)
          .fontSize(13)
          .fontColor([$r('app.color.text_on_accent')]);
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .margin({ left: 8, right: 8, top: 2, bottom: 2 })
    .borderRadius(6)
    .backgroundColor(sort === this.sortBy ? $r('app.color.accent') : Color.Transparent)
    .onClick(() => {
      this.onSelectSort(sort);
    });
  }

  // --------------------------------------------------------------- footer

  @Builder
  footerSection(): void {
    Column() {
      this.actionRow(AppIcons.SETTINGS, $r('app.string.drawer_settings'), () => {
        this.onOpenSettings();
      });

      Row() {
        SymbolGlyph(AppIcons.STORAGE)
          .fontSize(18)
          .fontColor([$r('app.color.icon')])
          .width(28);
        Text($r('app.string.drawer_free_space'))
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1);
        Text(this.freeSpaceLabel.length > 0 ? this.freeSpaceLabel : '…')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'));
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .onClick(() => {
        this.onRefreshFreeSpace();
      });

      // 抽屉的最后一行。关于页是最没有「下一步」的去处，所以它排在所有入口
      // 之后；底部的留白也从可用空间那一行挪到了这里，让它自己收尾。
      Row() {
        SymbolGlyph(AppIcons.INFO)
          .fontSize(18)
          .fontColor([$r('app.color.icon')])
          .width(28);
        Text($r('app.string.drawer_about'))
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1);
        SymbolGlyph(AppIcons.CHEVRON_RIGHT)
          .fontSize(16)
          .fontColor([$r('app.color.text_tertiary')]);
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 24 })
      .onClick(() => {
        this.onOpenAbout();
      });
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  /** Generic icon + label + optional trailing chevron row. */
  @Builder
  actionRow(icon: Resource, label: Resource, action: () => void): void {
    Row() {
      SymbolGlyph(icon)
        .fontSize(18)
        .fontColor([$r('app.color.icon')])
        .width(28);
      Text(label)
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1);
      SymbolGlyph(AppIcons.CHEVRON_RIGHT)
        .fontSize(16)
        .fontColor([$r('app.color.text_tertiary')]);
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .onClick(() => {
      action();
    });
  }

  /** Safe read of the filter count array. */
  private countAt(index: number): number {
    return index >= 0 && index < this.filterCounts.length ? this.filterCounts[index] : 0;
  }
}
