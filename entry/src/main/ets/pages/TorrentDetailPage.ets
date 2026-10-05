// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Torrent detail screen.
 *
 * Five tabs — Info, Files, Trackers, Peers, Options — over one `torrent_get`
 * performed by {@link TorrentDetailModel}. The page is a `NavDestination`
 * rather than an `@Entry` page: it is pushed onto the list screen's
 * `NavPathStack` and receives the torrent id through the plain `torrentId`
 * member the destination builder sets.
 *
 * Every mutation follows the same pattern: build a `TorrentSetRequest`, apply
 * it, then reload, because Transmission never echoes the resulting state.
 *
 * @since 1.0.0
 */

import { common } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import {
  FilePriority,
  IdleLimitMode,
  Peer,
  RatioLimitMode,
  Torrent,
  TorrentIds,
  TorrentPriority,
  TorrentSetRequest,
  TrackerAnnounceState,
  TrackerScrapeState,
} from 'transmission_sdk';
import { isTorrentBusy } from '../model/AppModels';
import { AppContext, describeErrorResource } from '../store/AppContext';
import { torrentStateLabel } from '../viewmodel/TorrentListModel';
import {
  formatBytes,
  formatCountOrDash,
  formatDuration,
  formatEta,
  formatPercent,
  formatPercentExact,
  formatPercentPrecise,
  formatRatio,
  formatSpeed,
  formatTimestamp,
} from '../viewmodel/Formatters';
import { TorrentDetailModel, TrackerRow } from '../viewmodel/TorrentDetailModel';
import { FileTree, TorrentFileNode, TorrentFileRow } from '../viewmodel/FileTree';
import { DetailFieldRow } from '../components/DetailFieldRow';
import { AppIcons } from '../theme/AppIcons';

/**
 * Which bottom sheet the page is showing.
 *
 * One sheet is bound to the page rather than one per feature: several
 * `bindSheet`s on the same component contend for the same slot, and the state
 * they need is the same text field anyway. The kind picks the content.
 *
 * 这两项都来自顶部的操作菜单（重命名种子、设置保存位置）；Tracker 标签页改用
 * 只读展示后，原来的「添加 / 编辑 Tracker 列表」两个面板已随之删除。
 */
enum DetailSheet {
  NONE,
  RENAME,
  LOCATION,
}

/** Index of each tab, so the top bar can ask which one is showing. */
const TAB_INFO: number = 0;
const TAB_FILES: number = 1;
const TAB_TRACKERS: number = 2;
const TAB_OPTIONS: number = 4;

/**
 * Detail screen of a single torrent.
 *
 * Not decorated with `@Entry`: the list screen owns the `Navigation` stack and
 * builds this struct from a `NavDestination` builder.
 */
@Component
export struct TorrentDetailBody {
  /** Torrent id to display; supplied by the host. */
  torrentId: number = 0;

  /** Stack this destination was pushed onto; filled in by the host's `onReady`. */
  pathStack: NavPathStack = new NavPathStack();

  /** Fetching and mutation logic, kept out of the UI by design. */
  private readonly model: TorrentDetailModel = new TorrentDetailModel();

  /**
   * 动作转发器：由 `aboutToAppear` 以闭包形式填充，标题栏菜单（`DetailActionMenu`）
   * 只认它。数据状态（`torrent` 等）留在子组件里，宿主 `TorrentDetailPage` 不随刷新
   * 重绘，菜单就不会被冲掉。
   */
  controller: DetailController = new DetailController();

  /** The torrent currently displayed, or `undefined` before the first load. */
  @State torrent: Torrent | undefined = undefined;
  /** True while any request is in flight; disables buttons that mutate state. */
  @State loading: boolean = false;
  /** Localised failure of the last call, or `undefined` when healthy. */
  @State errorResource: Resource | undefined = undefined;

  /**
   * Index of the selected tab, mirrored from the host's `currentTab`.
   *
   * Named `currentTab` rather than `tabIndex`: ArkUI's `CustomComponent` base
   * already declares `tabIndex(index)` as a universal focus attribute, and a
   * struct member may not shadow it.
   */
  @Link currentTab: number;
  /** Controller so the page could move between tabs programmatically. */
  private readonly tabsController: TabsController = new TabsController();

  /** Rows of the Files tab, in wire order; rebuilt after every load. */
  @State fileRows: TorrentFileRow[] = [];

  /**
   * The Files tab's tree, flattened depth-first for a single `ForEach`.
   *
   * ArkUI cannot recurse through a `@Builder`, so the tree is never rendered
   * directly: `FileTree.flatten` turns it into this list and every node carries
   * its own `depth` for indentation.
   */
  @State fileNodes: TorrentFileNode[] = [];

  /** Paths of the folders whose children are hidden. */
  @State collapsedFolders: string[] = [];

  /**
   * The tree `fileNodes` is flattened from.
   *
   * Deliberately not `@State`: the tree is never rendered, so re-flattening
   * `fileNodes` is what has to notify the framework.
   */
  private fileTree: TorrentFileNode[] = [];

  /**
   * Column a tree row keeps for its fold chevron.
   *
   * A file has no chevron, but reserves the same width, so the icons of a
   * folder and of its files sit on one vertical line.
   */
  private static readonly TREE_GUTTER: number = 16;
  /** Gap between the gutter, the icon and the name. */
  private static readonly TREE_GAP: number = 6;
  /** Size of a row's type icon. */
  private static readonly TREE_ICON: number = 18;

  /**
   * 信息页每个分组内容相对分组标题的缩进。
   *
   * 标题顶格、内容缩进，是让「哪几行属于同一组」一眼可辨的最省事办法 ——
   * 比给每组加边框或底色都轻。
   */
  private static readonly GROUP_INSET: number = 14;

  /** Rows of the Trackers tab, rebuilt after every load. */
  @State trackerRows: TrackerRow[] = [];
  /** True while a bottom sheet is on screen. */
  @State showSheet: boolean = false;
  /** Which sheet {@link showSheet} reveals; see {@link DetailSheet}. */
  @State sheetKind: DetailSheet = DetailSheet.NONE;
  /** Text field of the open sheet: a name, a path, or announce URLs. */
  @State sheetText: string = '';
  /** True when the location sheet should move the files already on disk. */
  @State sheetMoveFiles: boolean = false;

  /** Download limit in kB/s, as typed. */
  @State downloadLimitText: string = '0';
  /** Upload limit in kB/s, as typed. */
  @State uploadLimitText: string = '0';
  /** True when the per-torrent download limit is enforced. */
  @State downloadLimited: boolean = false;
  /** True when the per-torrent upload limit is enforced. */
  @State uploadLimited: boolean = false;
  /** Torrent bandwidth priority, bound to the three-way selector. */
  @State bandwidthPriority: TorrentPriority = TorrentPriority.NORMAL;
  /** True when pieces are downloaded in order. */
  @State sequentialDownload: boolean = false;
  /** Ratio limit mode, bound to its own selector. */
  @State ratioMode: RatioLimitMode = RatioLimitMode.GLOBAL;
  /** Ratio limit value, as typed. */
  @State ratioLimitText: string = '0';
  /** Idle limit mode, bound to its own selector. */
  @State idleMode: IdleLimitMode = IdleLimitMode.GLOBAL;
  /** Idle limit in minutes, as typed. */
  @State idleLimitText: string = '0';
  /** Queue position, as typed. */
  @State queuePositionText: string = '0';
  /** Per-torrent peer limit, as typed. */
  @State peerLimitText: string = '0';
  /** Bandwidth group name, as typed. */
  @State groupText: string = '';
  /** Comma-separated labels, as typed. */
  @State labelsText: string = '';

  /** Loads the torrent as soon as the destination is pushed. */
  /**
   * Refresh period used while this torrent is moving.
   *
   * Matches the list screen: the user's configured interval governs an idle
   * torrent, but a download or a recheck has to keep up with its own numbers.
   */
  private static readonly ACTIVE_REFRESH_SECONDS: number = 2;

  /** Handle of the periodic refresh, or `-1` when none is scheduled. */
  private refreshTimerId: number = -1;

  /**
   * False once the screen has been popped.
   *
   * A reload started just before the user navigated away finishes afterwards,
   * and would otherwise schedule a timer that nothing ever cancels.
   */
  private pageActive: boolean = false;

  aboutToAppear(): void {
    this.pageActive = true;
    // 把动作以闭包填进转发器：闭包定义在子组件方法里，可合法访问私有动作方法，
    // 而菜单（`DetailActionMenu`）只持有转发器的稳定引用，子组件刷新时不牵动菜单。
    this.controller.start = () => this.startTorrent();
    this.controller.pause = () => this.stopTorrent();
    this.controller.verify = () => this.verifyTorrent();
    this.controller.reannounce = () => this.reannounceTorrent();
    this.controller.rename = () => this.openSheet(DetailSheet.RENAME, this.currentTorrent().name);
    this.controller.setLocation = () => this.openSheet(DetailSheet.LOCATION, this.currentTorrent().downloadDir);
    this.controller.share = () => this.shareTorrent();
    this.controller.remove = () => this.confirmRemoveTorrent();
    this.controller.save = () => this.saveOptions();
    this.reload();
  }

  /** Stops the timer and releases the (potentially large) torrent object. */
  aboutToDisappear(): void {
    this.pageActive = false;
    this.stopAutoRefresh();
    this.model.torrent = undefined;
  }

  build(): void {
    Column() {
      this.detailHeader()
      Tabs({ barPosition: BarPosition.Start, index: this.currentTab, controller: this.tabsController }) {
        TabContent() {
          this.infoTab()
        }
        .tabBar(this.tabBar(TAB_INFO, $r('app.string.detail_tab_info')))

        TabContent() {
          this.filesTab()
        }
        .tabBar(this.tabBar(TAB_FILES, $r('app.string.detail_tab_files')))

        TabContent() {
          this.trackersTab()
        }
        .tabBar(this.tabBar(TAB_TRACKERS, $r('app.string.detail_tab_trackers')))

        TabContent() {
          this.peersTab()
        }
        .tabBar(this.tabBar(3, $r('app.string.detail_tab_peers')))

        TabContent() {
          this.optionsTab()
        }
        .tabBar(this.tabBar(TAB_OPTIONS, $r('app.string.detail_tab_options')))
      }
      // `barMode(Scrollable)` keeps five labels readable on a phone; the
      // default swipe gesture between pages is deliberately left enabled, so
      // the tabs are reachable by tap and by swipe.
      .barMode(BarMode.Scrollable)
      .barHeight(48)
      .layoutWeight(1)
      .onChange((index: number) => {
        this.currentTab = index;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
    // One sheet for the whole page; `sheetKind` picks what it contains.
    // The options stay on one line: a lone `height:` on its own line inside
    // the struct trips the linter's member-name rule, which cannot tell an
    // option object from a component field.
    .bindSheet($$this.showSheet, this.sheetContent(), { height: SheetSize.MEDIUM })
  }

  // ------------------------------------------------------------- data flow

  /**
   * The current failure message.
   *
   * A method rather than a direct `Text(this.errorResource)` because the
   * builder cannot narrow an `@State` field's type across its own boundary.
   *
   * @returns the failure to show, or a generic one
   */
  private errorText(): Resource {
    return this.errorResource === undefined ? $r('app.string.error_protocol') : this.errorResource;
  }

  /**
   * Reloads the torrent and refreshes every editable field.
   *
   * `TorrentDetailModel.load` never rejects, so the extra `catch` only keeps an
   * unexpected failure from becoming an unhandled promise.
   */
  private reload(syncForm: boolean = true): void {
    if (syncForm) {
      this.loading = true;
    }
    this.model
      .load(this.torrentId)
      .then((torrent: Torrent | undefined) => {
        this.torrent = torrent;
        this.errorResource = this.model.errorResource;
        if (torrent !== undefined) {
          this.syncDisplay(torrent);
          if (syncForm) {
            this.syncFormFields(torrent);
          }
        }
      })
      .catch((error: Object) => {
        this.errorResource = describeErrorResource(error);
      })
      .finally(() => {
        this.loading = false;
        this.restartAutoRefresh();
      });
  }

  /**
   * Applies a request, then reloads so the UI shows what the daemon accepted.
   *
   * @param request prepared `torrent_set` request
   * @param notifySaved true to show the "saved" toast (all Options-tab edits)
   */
  private applyRequest(request: TorrentSetRequest, notifySaved: boolean): void {
    this.loading = true;
    this.model
      .apply(this.torrentId, request)
      .then((ok: boolean) => {
        if (!ok) {
          this.errorResource = this.model.errorResource;
          this.loading = false;
          return;
        }
        if (notifySaved) {
          this.toast($r('app.string.options_saved'));
        }
        this.reload();
      })
      .catch((error: Object) => {
        this.errorResource = describeErrorResource(error);
        this.loading = false;
      });
  }

  /**
   * Refreshes the rows that render live torrent state.
   *
   * Runs on every reload, including the periodic ones, because the Files and
   * Trackers tabs show numbers that move on their own.
   *
   * @param torrent the freshly loaded torrent
   */
  private syncDisplay(torrent: Torrent): void {
    this.fileRows = FileTree.buildRows(torrent);
    this.fileTree = FileTree.build(this.fileRows);
    this.refreshFileNodes();
    this.trackerRows = TorrentDetailModel.buildTrackerRows(torrent);
  }

  /**
   * Copies a freshly loaded torrent into every editable field.
   *
   * An Option field that is not re-seeded here would silently show the previous
   * torrent's value after a navigation, or a stale value after a failed edit.
   *
   * Deliberately kept out of the periodic refresh: rewriting a half-typed speed
   * limit every couple of seconds would make the Options tab unusable. It runs
   * when the screen opens, when the user retries, and after a change has been
   * applied — the moments when the server's values are what should be shown.
   *
   * @param torrent the freshly loaded torrent
   */
  private syncFormFields(torrent: Torrent): void {
    this.downloadLimitText = `${torrent.downloadLimit}`;
    this.uploadLimitText = `${torrent.uploadLimit}`;
    this.downloadLimited = torrent.downloadLimited;
    this.uploadLimited = torrent.uploadLimited;
    this.bandwidthPriority = torrent.bandwidthPriority;
    this.sequentialDownload = torrent.sequentialDownload;
    this.ratioMode = torrent.seedRatioMode;
    this.ratioLimitText = `${torrent.seedRatioLimit}`;
    this.idleMode = torrent.seedIdleMode;
    this.idleLimitText = `${torrent.seedIdleLimit}`;
    this.queuePositionText = `${torrent.queuePosition}`;
    this.peerLimitText = `${torrent.peerLimit}`;
    this.groupText = torrent.group;
    this.labelsText = torrent.labels.join(', ');
  }

  /**
   * (Re)plans the periodic refresh.
   *
   * Called after every load, because whether the torrent is moving may have
   * just changed.
   */
  private restartAutoRefresh(): void {
    this.stopAutoRefresh();
    if (!this.pageActive) {
      return;
    }
    const torrent = this.torrent;
    const busy = torrent !== undefined && isTorrentBusy(torrent.status);
    const seconds = busy
      ? TorrentDetailBody.ACTIVE_REFRESH_SECONDS
      : AppContext.get().settings.refreshIntervalSeconds;
    if (seconds <= 0) {
      return;
    }
    this.refreshTimerId = setInterval(() => {
      // `false`: refresh the numbers, leave the form alone.
      this.reload(false);
    }, seconds * 1000);
  }

  /** Cancels the periodic refresh. */
  private stopAutoRefresh(): void {
    if (this.refreshTimerId !== -1) {
      clearInterval(this.refreshTimerId);
      this.refreshTimerId = -1;
    }
  }

  // -------------------------------------------------------------- helpers

  /**
   * The torrent being displayed, or an all-defaults stand-in.
   *
   * TypeScript does not carry a `torrent !== undefined` narrowing from `build`
   * into a separate `@Builder`, so every builder reads the torrent through this
   * accessor instead of guarding the union itself.
   */
  private currentTorrent(): Torrent {
    return this.torrent === undefined ? TorrentDetailModel.EMPTY : this.torrent;
  }

  /** Renders a non-empty string, or the em dash used for unknown values. */
  private orDash(value: string): string {
    return value.length > 0 ? value : '—';
  }

  /** Colour of a progress bar: green when done, red on error, accent otherwise. */
  private progressColor(): Resource {
    const torrent = this.currentTorrent();
    if (torrent.error !== 0 || torrent.errorString.length > 0) {
      return $r('app.color.progress_fill_error');
    }
    return torrent.isFinished ? $r('app.color.progress_fill_done') : $r('app.color.progress_fill');
  }

  /** Localises a tracker announce state. */
  private announceStateLabel(state: TrackerAnnounceState): Resource {
    switch (state) {
      case TrackerAnnounceState.ACTIVE:
        return $r('app.string.trackers_state_active');
      case TrackerAnnounceState.QUEUED:
        return $r('app.string.trackers_state_queued');
      case TrackerAnnounceState.WAITING:
        return $r('app.string.trackers_state_waiting');
      default:
        return $r('app.string.trackers_state_inactive');
    }
  }

  /** Localises a tracker scrape state, using the same mapping as announce. */
  private scrapeStateLabel(state: TrackerScrapeState): Resource {
    switch (state) {
      case TrackerScrapeState.ACTIVE:
        return $r('app.string.trackers_state_active');
      case TrackerScrapeState.QUEUED:
        return $r('app.string.trackers_state_queued');
      default:
        return $r('app.string.trackers_state_inactive');
    }
  }

  /** The two transfer rates of the header: download first, then upload. */
  private speedSummary(): string {
    const torrent = this.currentTorrent();
    return `${formatSpeed(torrent.rateDownload)} · ${formatSpeed(torrent.rateUpload)}`;
  }

  /**
   * The `peers_from` breakdown as one compact line.
   *
   * The source names (DHT, PEX, LPD, LTEP, …) are protocol proper nouns rather
   * than translatable UI copy, and the catalogue has no resource for them, so
   * they are rendered verbatim next to their counts.
   */
  private peersFromText(): string {
    const sources = this.currentTorrent().peersFrom;
    const parts: string[] = [];
    this.appendSource(parts, 'DHT', sources.fromDht);
    this.appendSource(parts, 'PEX', sources.fromPex);
    this.appendSource(parts, 'LPD', sources.fromLpd);
    this.appendSource(parts, 'LTEP', sources.fromLtep);
    this.appendSource(parts, 'cache', sources.fromCache);
    this.appendSource(parts, 'tracker', sources.fromTracker);
    this.appendSource(parts, 'incoming', sources.fromIncoming);
    this.appendSource(parts, 'holepunch', sources.fromHolepunch);
    return parts.length === 0 ? '—' : parts.join(' · ');
  }

  /** Appends `name count` when the count is meaningful. */
  private appendSource(parts: string[], name: string, value: number): void {
    if (value > 0) {
      parts.push(`${name} ${value}`);
    }
  }


  /** Parses a non-negative integer field, treating junk as `0`. */
  private parseIntOrZero(text: string): number {
    const value = Number.parseInt(text, 10);
    return Number.isNaN(value) || value < 0 ? 0 : value;
  }

  /** Parses a non-negative decimal field, treating junk as `0`. */
  private parseFloatOrZero(text: string): number {
    const value = Number.parseFloat(text);
    return Number.isNaN(value) || value < 0 ? 0 : value;
  }

  /** Shows a short toast through the component-scoped prompt action. */
  private toast(message: Resource | string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
  }

  // ------------------------------------------------------------- sheets

  /**
   * Opens one of the bottom sheets, seeded with the value it edits.
   *
   * @param kind which sheet to show
   * @param text initial content of its field
   */
  private openSheet(kind: DetailSheet, text: string): void {
    this.sheetKind = kind;
    this.sheetText = text;
    this.sheetMoveFiles = false;
    this.showSheet = true;
  }

  /** Heading of the open sheet. */
  private sheetTitle(): Resource {
    return this.sheetKind === DetailSheet.RENAME
      ? $r('app.string.action_rename')
      : $r('app.string.action_set_location');
  }

  /** Placeholder of the open sheet's field. */
  private sheetPlaceholder(): Resource {
    return this.sheetKind === DetailSheet.RENAME
      ? $r('app.string.action_rename_hint')
      : $r('app.string.action_location_hint');
  }

  /** The one sheet the page binds, filled according to {@link sheetKind}. */
  @Builder
  sheetContent(): void {
    Column({ space: 12 }) {
      Text(this.sheetTitle())
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%');

      TextInput({ text: this.sheetText, placeholder: this.sheetPlaceholder() })
        .width('100%')
        .onChange((value: string) => {
          this.sheetText = value;
        });

      if (this.sheetKind === DetailSheet.LOCATION) {
        Row({ space: 8 }) {
          Text($r('app.string.action_location_move'))
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1);
          Checkbox()
            .select(this.sheetMoveFiles)
            .selectedColor($r('app.color.accent'))
            .onChange((checked: boolean) => {
              this.sheetMoveFiles = checked;
            });
        }
        .width('100%');
      }

      Row({ space: 10 }) {
        Button($r('app.string.common_cancel'))
          .layoutWeight(1)
          .height(44)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.surface_alt'))
          .onClick(() => {
            this.showSheet = false;
          });
        Button($r('app.string.common_save'))
          .layoutWeight(1)
          .height(44)
          .fontColor($r('app.color.text_on_accent'))
          .backgroundColor($r('app.color.accent'))
          .onClick(() => {
            this.saveSheet();
          });
      }
      .width('100%');
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 16 })
    .alignItems(HorizontalAlign.Start);
  }

  /** Applies whatever the open sheet was editing. */
  private saveSheet(): void {
    const text = this.sheetText.trim();
    if (this.sheetKind === DetailSheet.RENAME) {
      if (text.length === 0) {
        this.toast($r('app.string.action_rename_empty'));
        return;
      }
      this.showSheet = false;
      this.applyRequest(new TorrentSetRequest(TorrentIds.single(this.torrentId)).name(text), true);
      return;
    }
    if (this.sheetKind === DetailSheet.LOCATION) {
      if (text.length === 0) {
        this.toast($r('app.string.action_location_empty'));
        return;
      }
      const move = this.sheetMoveFiles;
      this.showSheet = false;
      this.loading = true;
      this.model
        .setLocation(this.torrentId, text, move)
        .then((ok: boolean) => {
          this.finishAction(ok, $r('app.string.options_saved'));
        })
        .catch((error: Object) => {
          this.failAction(error);
        });
    }
  }

  // ------------------------------------------------------------- actions

  /** Resumes this torrent. */
  private startTorrent(): void {
    this.loading = true;
    this.model
      .start(this.torrentId)
      .then((ok: boolean) => {
        this.finishAction(ok, $r('app.string.action_requested'));
      })
      .catch((error: Object) => {
        this.failAction(error);
      });
  }

  /** Pauses this torrent. */
  private stopTorrent(): void {
    this.loading = true;
    this.model
      .stop(this.torrentId)
      .then((ok: boolean) => {
        this.finishAction(ok, $r('app.string.action_requested'));
      })
      .catch((error: Object) => {
        this.failAction(error);
      });
  }

  /** Queues a recheck of the local data. */
  private verifyTorrent(): void {
    this.loading = true;
    this.model
      .verify(this.torrentId)
      .then((ok: boolean) => {
        this.finishAction(ok, $r('app.string.list_verify_requested'));
      })
      .catch((error: Object) => {
        this.failAction(error);
      });
  }

  /** Asks the trackers for more peers right now. */
  private reannounceTorrent(): void {
    this.loading = true;
    this.model
      .reannounce(this.torrentId)
      .then((ok: boolean) => {
        this.finishAction(ok, $r('app.string.list_reannounce_requested'));
      })
      .catch((error: Object) => {
        this.failAction(error);
      });
  }

  /**
   * Hands the magnet link to the system share sheet.
   *
   * The magnet link is what identifies a torrent to somebody else — the
   * `.torrent` file is usually not on this device — so that is what is shared.
   */
  private shareTorrent(): void {
    const torrent = this.currentTorrent();
    if (torrent.magnetLink.length === 0) {
      this.toast($r('app.string.action_share_failed'));
      return;
    }
    const record: systemShare.SharedRecord = {
      utd: 'text/plain',
      content: torrent.magnetLink,
      title: torrent.name,
    };
    const options: systemShare.ShareControllerOptions = {
      selectionMode: systemShare.SelectionMode.SINGLE,
    };
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const controller = new systemShare.ShareController(new systemShare.SharedData(record));
    controller
      .show(context, options)
      .catch((error: Object) => {
        this.errorResource = describeErrorResource(error);
        this.toast($r('app.string.action_share_failed'));
      });
  }

  /**
   * Asks whether to remove the torrent with or without its files.
   *
   * `showAlertDialog` offers exactly two actions, which is one fewer than the
   * three outcomes (cancel, remove, remove and delete) — so cancelling is the
   * primary button and the two destructive choices take the secondary.
   * Deleting the data is the one that needs the longer label.
   */
  private confirmRemoveTorrent(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.list_delete_confirm_title'),
      message: $r('app.string.list_delete_confirm_message'),
      primaryButton: {
        value: $r('app.string.list_swipe_remove'),
        action: () => {
          this.removeTorrent(false);
        },
      },
      secondaryButton: {
        value: $r('app.string.common_delete'),
        action: () => {
          this.removeTorrent(true);
        },
      },
    });
  }

  /** Removes the torrent and leaves the screen, which has nothing left to show. */
  private removeTorrent(deleteData: boolean): void {
    this.loading = true;
    this.model
      .remove(this.torrentId, deleteData)
      .then((ok: boolean) => {
        if (!ok) {
          this.errorResource = this.model.errorResource;
          this.loading = false;
          return;
        }
        this.pathStack.pop();
      })
      .catch((error: Object) => {
        this.failAction(error);
      });
  }

  /**
   * Common tail of an action: report it and reload, or surface the failure.
   *
   * @param ok whether the model call succeeded
   * @param done toast to show when it did
   */
  private finishAction(ok: boolean, done: Resource): void {
    if (!ok) {
      this.errorResource = this.model.errorResource;
      this.loading = false;
      return;
    }
    this.toast(done);
    this.reload();
  }

  /** Common failure tail of an action. */
  private failAction(error: Object): void {
    this.errorResource = describeErrorResource(error);
    this.loading = false;
  }

  // ------------------------------------------------------------- tab bars

  /** Custom tab-bar entry; the active tab is tinted with the accent colour. */
  @Builder
  tabBar(index: number, label: Resource): void {
    Column() {
      Text(label)
        .fontSize(13)
        .fontColor(this.currentTab === index ? $r('app.color.accent') : $r('app.color.text_secondary'))
        .fontWeight(this.currentTab === index ? FontWeight.Medium : FontWeight.Normal)
        .padding({ left: 14, right: 14 });
    }
    .height(48)
    .justifyContent(FlexAlign.Center);
  }

  // ---------------------------------------------------------------- header

  /** Compact header: error banner, name, big progress bar, state and rates. */
  @Builder
  detailHeader(): void {
    Column({ space: 6 }) {
      if (this.errorResource !== undefined) {
        this.errorBanner()
      }
      Text(this.currentTorrent().name.length > 0 ? this.currentTorrent().name : $r('app.string.common_unknown'))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%');
      Progress({ value: Math.max(2,Math.round(this.currentTorrent().percentDone * 100)), total: 100, type: ProgressType.Linear })
        .color(this.progressColor())
        .backgroundColor($r('app.color.progress_track'))
        .width('100%');
      Row({ space: 12 }) {
        Text(torrentStateLabel(this.currentTorrent().status))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'));
        Text(formatPercentExact(this.currentTorrent().percentDone))
          .fontSize(12)
          .fontColor($r('app.color.accent'));
        // 下载速率：绿色箭头图标 + 速度（内联，确保随数据刷新；@Builder 包装会让
        // 速率文字在父组件重绘时不更新，导致数值卡住）。
        Row({ space: 2 }) {
          SymbolGlyph(AppIcons.DOWNLOAD)
            .fontSize(12)
            .fontColor([Color.Green]);
          Text(formatSpeed(this.currentTorrent().rateDownload))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'));
        }
        // 上传速率：红色箭头图标 + 速度。
        Row({ space: 2 }) {
          SymbolGlyph(AppIcons.UPLOAD)
            .fontSize(12)
            .fontColor([Color.Red]);
          Text(formatSpeed(this.currentTorrent().rateUpload))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'));
        }
      }
      .width('100%');
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.surface'));
  }

  /** Failure strip with a retry affordance. */
  @Builder
  errorBanner(): void {
    Row({ space: 8 }) {
      Text(this.errorText())
        .fontSize(12)
        .fontColor($r('app.color.danger'))
        .layoutWeight(1);
      Button($r('app.string.common_retry'))
        .fontSize(12)
        .height(28)
        .onClick(() => {
          this.reload();
        });
    }
    .width('100%')
    .padding(8)
    .borderRadius(8)
    .backgroundColor($r('app.color.surface_alt'));
  }

  // -------------------------------------------------------------- builders

  /** Centred placeholder used by the tabs that can legitimately be empty. */
  @Builder
  emptyHint(message: Resource): void {
    Column() {
      Text(message)
        .fontSize(13)
        .fontColor($r('app.color.text_tertiary'));
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center);
  }

  /** Small coloured chip, used for the peer flags. */
  @Builder
  chip(label: Resource): void {
    Text(label)
      .fontSize(10)
      .fontColor($r('app.color.accent'))
      .backgroundColor($r('app.color.accent_soft'))
      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
      .borderRadius(4);
  }

  /** Section caption of the Options tab. */
  @Builder
  sectionHeader(title: Resource): void {
    Text(title)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
      .margin({ top: 8, bottom: 2 });
  }

  /**
   * 信息页的分组标题。
   *
   * 比选项页的 {@link sectionHeader} 更重、更黑，因为这里的分组是内容的主
   * 结构：一眼扫过去要能立刻分出「种子信息 / 传输 / 日期 / 运行时间」四块，
   * 而选项页的标题只是长列表里的小节。
   *
   * @param title 分组名
   * @param first 是否为本页第一组；第一组紧接标签栏，不需要那么大的上间距
   */
  @Builder
  groupHeader(title: Resource, first: boolean): void {
    Text(title)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.text_primary'))
      .width('100%')
      .margin({ top: first ? 2 : 28, bottom: 4 });
  }

  // ------------------------------------------------------------- Info tab

  /**
   * 信息页：四组定义列表，按「描述的是什么」分组。
   *
   * 之所以分组，是因为这些字段回答的是四个互不相关的问题 —— 这份种子是
   * 什么、传得怎么样、经历过什么、跑了多久 —— 而三十行平铺的列表哪一个都
   * 答不出来。
   *
   * 状态刻意不放进来：标签栏上方的摘要里已经有它了，再摆一行只是重复。
   */
  @Builder
  infoTab(): void {
    Scroll() {
      Column() {
        this.torrentInfoGroup()
        this.transferInfoGroup()
        this.dateInfoGroup()
        this.runtimeInfoGroup()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
  }

  /** 「种子信息」组：这份种子是什么。 */
  @Builder
  torrentInfoGroup(): void {
    Column() {
      this.groupHeader($r('app.string.info_section_torrent'), true)
      DetailFieldRow({ label: $r('app.string.info_field_total_size'), value: this.sizeWithPieces() })
      DetailFieldRow({ label: $r('app.string.detail_field_location'), value: this.orDash(this.currentTorrent().downloadDir) })
      DetailFieldRow({ label: $r('app.string.detail_field_privacy'), value: this.privacyText() })
      DetailFieldRow({ label: $r('app.string.detail_field_creator'), value: this.orDash(this.currentTorrent().creator) })
      DetailFieldRow({ label: $r('app.string.detail_field_created'), value: formatTimestamp(this.currentTorrent().dateCreated) })
      DetailFieldRow({ label: $r('app.string.detail_field_comment'), value: this.orDash(this.currentTorrent().comment) })
      DetailFieldRow({
        label: $r('app.string.info_field_magnet'),
        value: this.orDash(this.currentTorrent().magnetLink),
        accent: true,
      })
      DetailFieldRow({ label: $r('app.string.detail_field_hash'), value: this.orDash(this.currentTorrent().hashString) })
      DetailFieldRow({ label: $r('app.string.detail_field_labels'), value: this.orDash(this.currentTorrent().labels.join(', ')) })
      DetailFieldRow({ label: $r('app.string.detail_field_group'), value: this.orDash(this.currentTorrent().group) })
    }
    .width('100%')
    .padding({ left: TorrentDetailBody.GROUP_INSET });
  }

  /** 「传输」组：这一份传得怎么样。 */
  @Builder
  transferInfoGroup(): void {
    Column() {
      this.groupHeader($r('app.string.info_section_transfer'), false)
      DetailFieldRow({ label: $r('app.string.info_field_total_downloaded'), value: this.totalDownloadedText() })
      DetailFieldRow({ label: $r('app.string.detail_field_uploaded'), value: this.uploadedText() })
      DetailFieldRow({ label: $r('app.string.info_field_availability'), value: this.availabilityText() })
      DetailFieldRow({ label: $r('app.string.info_field_average_speed'), value: this.averageSpeedText() })
      DetailFieldRow({ label: $r('app.string.info_field_current_speed'), value: this.speedSummary() })
      DetailFieldRow({ label: $r('app.string.detail_field_eta'), value: formatEta(this.currentTorrent().eta) })
      DetailFieldRow({ label: $r('app.string.detail_field_peers'), value: formatCountOrDash(this.currentTorrent().peersConnected) })
      DetailFieldRow({ label: $r('app.string.detail_field_trackers'), value: formatCountOrDash(this.currentTorrent().trackers.length) })
      if (this.currentTorrent().errorString.length > 0) {
        DetailFieldRow({ label: $r('app.string.detail_field_error'), value: this.currentTorrent().errorString, danger: true })
      }
    }
    .width('100%')
    .padding({ left: TorrentDetailBody.GROUP_INSET });
  }

  /** 「日期」组：这份种子经历过什么。 */
  @Builder
  dateInfoGroup(): void {
    Column() {
      this.groupHeader($r('app.string.info_section_dates'), false)
      DetailFieldRow({ label: $r('app.string.detail_field_added'), value: formatTimestamp(this.currentTorrent().addedDate) })
      DetailFieldRow({ label: $r('app.string.detail_field_started'), value: formatTimestamp(this.currentTorrent().startDate) })
      DetailFieldRow({ label: $r('app.string.detail_field_finished'), value: formatTimestamp(this.currentTorrent().doneDate) })
      DetailFieldRow({ label: $r('app.string.detail_field_last_activity'), value: formatTimestamp(this.currentTorrent().activityDate) })
    }
    .width('100%')
    .padding({ left: TorrentDetailBody.GROUP_INSET });
  }

  /** 「运行时间」组：真正在下载和做种上花了多久。 */
  @Builder
  runtimeInfoGroup(): void {
    Column() {
      this.groupHeader($r('app.string.info_section_runtime'), false)
      DetailFieldRow({
        label: $r('app.string.info_runtime_downloaded'),
        value: formatDuration(this.currentTorrent().secondsDownloading),
      })
      DetailFieldRow({
        label: $r('app.string.info_runtime_seeded'),
        value: formatDuration(this.currentTorrent().secondsSeeding),
      })
    }
    .width('100%')
    .padding({ left: TorrentDetailBody.GROUP_INSET });
  }

  /** Total size, followed by the piece geometry when the server sent it. */
  private sizeWithPieces(): ResourceStr {
    const torrent = this.currentTorrent();
    if (torrent.pieceSize <= 0 || torrent.pieceCount <= 0) {
      return formatBytes(torrent.totalSize);
    }
    return $r(
      'app.string.info_size_with_pieces',
      formatBytes(torrent.totalSize),
      `${torrent.pieceCount}`,
      formatBytes(torrent.pieceSize),
    );
  }

  /** Bytes downloaded since the torrent was added, with how far that is. */
  private totalDownloadedText(): ResourceStr {
    const torrent = this.currentTorrent();
    return $r(
      'app.string.info_downloaded_with_percent',
      formatBytes(torrent.downloadedEver),
      formatPercentExact(torrent.percentDone),
    );
  }

  /** Bytes uploaded, with the share ratio they represent. */
  private uploadedText(): ResourceStr {
    const torrent = this.currentTorrent();
    return $r(
      'app.string.info_uploaded_with_ratio',
      formatBytes(torrent.uploadedEver),
      formatRatio(torrent.uploadRatio),
    );
  }

  /** Public or private torrent. */
  private privacyText(): Resource {
    return this.currentTorrent().isPrivate
      ? $r('app.string.detail_field_privacy')
      : $r('app.string.detail_field_public');
  }

  /**
   * How much of the torrent the swarm can supply, relative to its full size.
   *
   * Transmission reports availability as a byte count (`desired_available`),
   * which means nothing on its own, so it is shown as the percentage the
   * reference UI shows.
   */
  private availabilityText(): string {
    const torrent = this.currentTorrent();
    if (torrent.totalSize <= 0) {
      return '—';
    }
    return formatPercentPrecise(torrent.desiredAvailable / torrent.totalSize);
  }

  /**
   * Average download rate over the time actually spent downloading.
   *
   * Divided by `secondsDownloading` rather than by wall-clock age: a torrent
   * that sat paused for a week did not average its bytes over that week.
   */
  private averageSpeedText(): string {
    const torrent = this.currentTorrent();
    if (torrent.secondsDownloading <= 0) {
      return formatSpeed(0);
    }
    return formatSpeed(torrent.downloadedEver / torrent.secondsDownloading);
  }

  // ------------------------------------------------------------ Files tab

  /**
   * Files tab: one row per file, grouped into a folder tree.
   *
   * Wanted/not-wanted is decided with a checkbox on each row instead of the
   * three-way priority picker that used to be here: "should this file be
   * downloaded at all" is the decision people actually make in this list, and
   * a folder's checkbox has to mean something for the whole subtree.
   *
   * Progress is written out rather than drawn. A bar per row was unreadable at
   * this density, and the reference layout shows the byte counts instead, which
   * also leaves the name room to wrap.
   */
  @Builder
  filesTab(): void {
    Column() {
      if (this.fileNodes.length === 0) {
        this.emptyHint($r('app.string.common_none'))
      } else {
        List({ space: 1 }) {
          ForEach(
            this.fileNodes,
            (node: TorrentFileNode) => {
              ListItem() {
                this.fileNodeRow(node)
              }
            },
            (node: TorrentFileNode) => this.fileNodeKey(node),
          )
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
  }

  /**
   * Rebuilds the flattened display list from the tree and the collapse set.
   *
   * Cheap enough to run on every collapse toggle: it walks the node objects it
   * already holds and allocates one array.
   */
  private refreshFileNodes(): void {
    this.fileNodes = FileTree.flatten(this.fileTree, this.collapsedFolders);
  }

  /**
   * Replaces the flat rows and everything derived from them.
   *
   * The tree is rebuilt rather than patched — it is a handful of objects, and
   * rebuilding is what guarantees a folder's aggregates can never disagree with
   * the rows they summarise.
   */
  private setFileRows(rows: TorrentFileRow[]): void {
    this.fileRows = rows;
    this.fileTree = FileTree.build(rows);
    this.refreshFileNodes();
    this.applyFileSelection();
  }

  /** True when the folder at `path` is collapsed. */
  private isCollapsed(path: string): boolean {
    return this.collapsedFolders.indexOf(path) >= 0;
  }

  /** Expands or collapses one folder. */
  private toggleFolder(path: string): void {
    const next: string[] = [];
    let found = false;
    for (const value of this.collapsedFolders) {
      if (value === path) {
        found = true;
      } else {
        next.push(value);
      }
    }
    if (!found) {
      next.push(path);
    }
    this.collapsedFolders = next;
    this.refreshFileNodes();
  }

  /**
   * 树节点的 `ForEach` 键。
   *
   * 键里放的是这一行**真正渲染出来的**每一个派生值，而不是原始字段：`ForEach`
   * 只在键变化时重绘，所以复选框的选中态、名字、写出来的进度（已下载/总大小）
   * 和折叠状态都必须进键，否则改了模型这一行还是旧样子。
   */
  private fileNodeKey(node: TorrentFileNode): string {
    return `${node.path}-${node.isComplete}-${node.allPendingWanted}-`
      + `${node.bytesCompleted}-${node.length}-${this.isCollapsed(node.path)}`;
  }

  /**
   * 目录树的一行。
   *
   * 文件夹和文件共用一套排版 —— 复选框、图标、名字、写出来的进度 —— 所以两者
   * 落在同一条竖线上。区别只在文件夹多一个折叠箭头，以及点击的行为：文件夹折叠，
   * 文件没得折。
   *
   * 复选框的状态由此处决定的两条规则控制：**已经下载完成的文件打勾且锁住**
   * （它的字节已经在服务器上了，勾或不勾都不会改变什么），**未完成的文件可勾可
   * 取消**，勾上表示要下载。文件夹按同一口径汇总它子树里未完成的那部分。
   */
  @Builder
  fileNodeRow(node: TorrentFileNode): void {
    Row({ space: TorrentDetailBody.TREE_GAP }) {
      Checkbox()
        .select(node.isComplete || node.allPendingWanted)
        .selectedColor($r('app.color.accent'))
        .enabled(node.checkable)
        .onChange((checked: boolean) => {
          this.setSubtreeWanted(node, checked);
        });

      if (node.collapsible) {
        SymbolGlyph(this.isCollapsed(node.path) ? AppIcons.CHEVRON_RIGHT : AppIcons.CHEVRON_DOWN)
          .fontSize(14)
          .fontColor([$r('app.color.icon')])
          .width(TorrentDetailBody.TREE_GUTTER);
      }

      SymbolGlyph(this.fileIcon(node))
        .fontSize(TorrentDetailBody.TREE_ICON)
        .fontColor([$r('app.color.icon')])
        // A file has no chevron, so it carries the gutter as a left margin
        // instead — plus the gap the chevron would have had after it, or its
        // icon would sit six points left of a folder's.
        .margin({ left: node.collapsible ? 0 : TorrentDetailBody.TREE_GUTTER + TorrentDetailBody.TREE_GAP });

      Column({ space: 2 }) {
        Text(node.name)
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%');
        Text(this.progressText(node))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .width('100%');
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1);
    }
    .width('100%')
    .padding({ left: 8 + node.depth * 16, right: 12, top: 10, bottom: 10 })
    .backgroundColor(node.isFolder ? $r('app.color.surface_alt') : $r('app.color.surface'))
    .onClick(() => {
      if (node.collapsible) {
        this.toggleFolder(node.path);
      }
    });
  }

  /**
   * 一行的图标：文件夹用文件夹图标，文件按扩展名分类。
   *
   * 先判文件夹：{@link FileKind} 里没有文件夹这一档，因为 `isFolder` 已经
   * 回答了这个问题，而文件夹也没有扩展名可供分类。
   */
  private fileIcon(node: TorrentFileNode): Resource {
    return node.isFolder ? AppIcons.FOLDER : AppIcons.forFileKind(node.kind);
  }

  /**
   * Written-out progress of a row, e.g. `1.2 GB of 2.4 GB (50%)`.
   *
   * `progressPercent` is a 0..100 number while `formatPercent` wants a 0..1
   * fraction, hence the division — the one place the two conventions meet.
   */
  private progressText(node: TorrentFileNode): ResourceStr {
    return $r(
      'app.string.files_progress',
      formatBytes(node.bytesCompleted),
      formatBytes(node.length),
      formatPercentExact(node.progressPercent / 100),
    );
  }

  /**
   * 把一个文件、或一个文件夹下面的所有文件，标成要下载或不要下载。
   *
   * 这是文件夹复选框的含义，也是目录树要带 `fileCount` 的原因：一次点击必须
   * 触达它下面的每一个文件，不管有多深。随后的请求按文件在 `Torrent.files` 里
   * 的下标寻址而不是按路径，这正是 {@link FileTree.leafIndices} 返回的东西。
   *
   * **已经下载完成的文件会被跳过**：这一行的复选框是锁住的，如果级联还能改到
   * 它，「文件夹解锁 → 取消勾选 → 又把已下完的文件标记成不下载」就会绕过锁。
   * 文件夹自身的复选框也只在还有未完成文件时可动，所以这条跳过不会让点击落空。
   */
  private setSubtreeWanted(node: TorrentFileNode, wanted: boolean): void {
    const targets = new Set<number>();
    for (const index of FileTree.leafIndices(node)) {
      targets.add(index);
    }
    const next: TorrentFileRow[] = [];
    for (const row of this.fileRows) {
      const copy = row.copy();
      if (targets.has(row.index) && !row.isComplete) {
        copy.wanted = wanted;
        // "Do not download" is priority low on the wire, so the two always move
        // together; the inverse restores a normal priority.
        copy.priority = wanted ? FilePriority.NORMAL : FilePriority.LOW;
      }
      next.push(copy);
    }
    this.setFileRows(next);
  }

  /**
   * Sends the whole file selection as one `torrent_set`.
   *
   * The five index arrays are recomputed from scratch on every change and are
   * disjoint by construction. That is what makes the request valid: Transmission
   * rejects a request that names the same file in more than one of
   * `files_wanted`, `files_unwanted`, `priority_high`, `priority_low` and
   * `priority_normal`, so an index is emitted exactly once, into the list that
   * matches its current state.
   */
  private applyFileSelection(): void {
    if (this.fileRows.length === 0) {
      return;
    }
    const wanted: number[] = [];
    const unwanted: number[] = [];
    const high: number[] = [];
    const low: number[] = [];
    const normal: number[] = [];
    for (const row of this.fileRows) {
      if (!row.wanted) {
        unwanted.push(row.index);
      } else if (row.priority === FilePriority.HIGH) {
        wanted.push(row.index);
        high.push(row.index);
      } else if (row.priority === FilePriority.LOW) {
        wanted.push(row.index);
        low.push(row.index);
      } else {
        wanted.push(row.index);
        normal.push(row.index);
      }
    }
    const request = new TorrentSetRequest(TorrentIds.single(this.torrentId))
      .filesWanted(wanted)
      .filesUnwanted(unwanted)
      .priorityHigh(high)
      .priorityLow(low)
      .priorityNormal(normal);
    this.applyRequest(request, false);
  }

  // --------------------------------------------------------- Trackers tab

  /**
   * Tracker 标签页：一张卡片一个汇报地址，纯展示。
   *
   * 这一页不提供任何编辑入口 —— 增删 Tracker 会改变种子的再分发拓扑，属于
   * 发布者的决定而不是远程客户端的日常操作，误触的代价远高于省下的那几次
   * 点击。要看的是「连上了谁、还剩多久汇报、抓取到多少种子」，所以这里只留
   * 读的部分。
   */
  @Builder
  trackersTab(): void {
    Column({ space: 8 }) {
      if (this.trackerRows.length === 0) {
        this.emptyHint($r('app.string.common_none'))
      } else {
        List({ space: 1 }) {
          ForEach(
            this.trackerRows,
            (row: TrackerRow) => {
              ListItem() {
                this.trackerCard(row)
              }
            },
            (row: TrackerRow) => `${row.id}-${row.announce}`,
          )
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: 8 })
    .backgroundColor($r('app.color.app_background'))
  }

  /**
   * 单张 Tracker 卡片：汇报主机名作标题，层级摆在对面，下面是它上报的数据。
   *
   * 按参考布局的排法（两列标题 + 定义列表），而不是把原始 announce URL 摆在
   * 最前面：人认得出的是主机名，而完整 URL 在这个宽度下根本读不了。
   *
   * 服务端没抓取过抓取统计的 Tracker 三项计数都是 `-1`，格式化后会显示成
   * `—`，而不是一个会误导人的 0。
   */
  @Builder
  trackerCard(row: TrackerRow): void {
    Column({ space: 2 }) {
      Row({ space: 6 }) {
        Text(row.host.length > 0 ? row.host : this.orDash(row.announce))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1);
        // Transmission 的层级从 0 开始编号，人是从 1 开始数的。
        Text($r('app.string.trackers_level', `${row.tier + 1}`))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'));
      }
      .width('100%');

      DetailFieldRow({ label: $r('app.string.trackers_last_update'), value: formatTimestamp(row.lastAnnounce) });
      DetailFieldRow({ label: $r('app.string.trackers_next_update'), value: this.nextAnnounceText(row) });
      DetailFieldRow({ label: $r('app.string.trackers_last_scrape'), value: formatTimestamp(row.lastScrape) });
      DetailFieldRow({ label: $r('app.string.trackers_announce_state'), value: this.announceStateLabel(row.announceState) });
      DetailFieldRow({ label: $r('app.string.trackers_scrape_state'), value: this.scrapeStateLabel(row.scrapeState) });
      DetailFieldRow({ label: $r('app.string.trackers_seeds'), value: formatCountOrDash(row.seeders) });
      DetailFieldRow({ label: $r('app.string.trackers_peers'), value: formatCountOrDash(row.leechers) });
      DetailFieldRow({ label: $r('app.string.trackers_downloaded'), value: formatCountOrDash(row.downloads) });
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.surface'));
  }

  /**
   * Time until the next announce, as a duration.
   *
   * A countdown rather than the timestamp the field holds: "in 4m 49s" is what
   * the number is for, and the absolute time would be a second timestamp right
   * next to the one above it.
   */
  private nextAnnounceText(row: TrackerRow): string {
    if (row.nextAnnounce <= 0) {
      return '—';
    }
    return formatDuration(row.nextAnnounce - Date.now() / 1000);
  }

  // ------------------------------------------------------------ Peers tab

  /** Peers tab: the discovery breakdown followed by the connected peers. */
  @Builder
  peersTab(): void {
    Column({ space: 6 }) {
      this.peersFromSummary()
      if (this.currentTorrent().peers.length === 0) {
        this.emptyHint($r('app.string.common_none'))
      } else {
        List({ space: 1 }) {
          ForEach(
            this.currentTorrent().peers,
            (peer: Peer) => {
              ListItem() {
                this.peerCard(peer)
              }
            },
            (peer: Peer) => `${peer.address}-${peer.port}`,
          )
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
  }

  /** Compact summary of how the connected peers were discovered. */
  @Builder
  peersFromSummary(): void {
    Column({ space: 4 }) {
      Row({ space: 6 }) {
        Text($r('app.string.detail_field_peers'))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'));
        Text(formatCountOrDash(this.currentTorrent().peersFrom.total))
          .fontSize(12)
          .fontColor($r('app.color.text_primary'));
      }
      .width('100%');
      Text(this.peersFromText())
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))
        .width('100%');
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.surface'));
  }

  /** One peer: address, client, progress, both rates, flags and small chips. */
  @Builder
  peerCard(peer: Peer): void {
    Column({ space: 4 }) {
      Row({ space: 6 }) {
        Text(this.orDash(peer.address))
          .fontSize(13)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1);
        if (peer.isEncrypted) {
          this.chip($r('app.string.peers_encrypted'))
        }
        if (peer.isIncoming) {
          this.chip($r('app.string.peers_incoming'))
        }
      }
      .width('100%');
      DetailFieldRow({ label: $r('app.string.peers_client'), value: this.orDash(peer.clientName) });
      DetailFieldRow({ label: $r('app.string.peers_progress'), value: formatPercentPrecise(peer.progress) });
      DetailFieldRow({ label: $r('app.string.peers_down'), value: formatSpeed(peer.rateToClient) });
      DetailFieldRow({ label: $r('app.string.peers_up'), value: formatSpeed(peer.rateToPeer) });
      // The flags are protocol shorthand (`U`, `E`, `D`, …) that Transmission
      // documents verbatim and that the catalogue has no resources for, so they
      // are rendered as plain text through the ordinary field row.
      DetailFieldRow({ label: $r('app.string.peers_flags'), value: this.orDash(peer.flagStr) });
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.surface'));
  }

  // ---------------------------------------------------------- Options tab

  /**
   * Options tab: every per-torrent setting, as a flat list of rows.
   *
   * Flat, and saved once: the tab used to carry an Apply button on most rows and
   * a switch on two, so one torrent's settings occupied seven request surfaces
   * and there was no way to see what was pending. Now every row edits local
   * state and the Save button in the title bar commits the lot, which means what
   * is on screen is either the server's state or one pending change — never a
   * mix of the two.
   *
   * Booleans are checkboxes rather than switches because that is what they are:
   * two options, one of which is chosen.
   */
  @Builder
  optionsTab(): void {
    Scroll() {
      Column({ space: 10 }) {
        this.sectionHeader($r('app.string.options_transfer'))
        this.limitRow(true)
        this.limitRow(false)

        this.sectionHeader($r('app.string.options_priority'))
        this.priorityRow()
        this.sequentialRow()

        this.sectionHeader($r('app.string.options_seeding'))
        this.modeRow($r('app.string.options_ratio_mode'), true)
        this.valueRow($r('app.string.options_ratio_limit'), true)
        this.modeRow($r('app.string.options_idle_mode'), false)
        this.valueRow($r('app.string.options_idle_limit'), false)

        this.sectionHeader($r('app.string.options_other'))
        this.textRow($r('app.string.options_queue_position'), true)
        this.textRow($r('app.string.options_peer_limit'), false)
        this.groupRow()
        this.labelsRow()
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
  }

  /**
   * One speed-limit row: label, numeric field, its unit and its enable checkbox.
   *
   * 数字后面跟单位，因为 `downloadLimit` / `uploadLimit` 是裸整数，光看「8192」
   * 分不出是字节还是千字节。Transmission 一律按 KB/s 计，所以单位是常量。
   */
  @Builder
  limitRow(isDownload: boolean): void {
    Row({ space: 8 }) {
      Text(isDownload ? $r('app.string.options_download_limit') : $r('app.string.options_upload_limit'))
        .fontSize(13)
        .fontColor($r('app.color.text_primary'))
        .width(112);
      TextInput({ text: isDownload ? this.downloadLimitText : this.uploadLimitText })
        .type(InputType.Number)
        .layoutWeight(1)
        .onChange((value: string) => {
          if (isDownload) {
            this.downloadLimitText = value;
          } else {
            this.uploadLimitText = value;
          }
        });
      Text($r('app.string.options_speed_unit'))
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'));
      Checkbox()
        .select(isDownload ? this.downloadLimited : this.uploadLimited)
        .selectedColor($r('app.color.accent'))
        .onChange((checked: boolean) => {
          if (isDownload) {
            this.downloadLimited = checked;
          } else {
            this.uploadLimited = checked;
          }
        });
    }
    .width('100%');
  }

  /** Three-way bandwidth-priority selector. */
  @Builder
  priorityRow(): void {
    Row({ space: 8 }) {
      Text($r('app.string.options_priority'))
        .fontSize(13)
        .fontColor($r('app.color.text_primary'))
        .width(112);
      Select(this.priorityOptions())
        .selected(this.priorityIndex())
        .value(this.priorityLabel())
        .layoutWeight(1)
        .enabled(!this.loading)
        .onSelect((index: number) => {
          this.bandwidthPriority = index === 0
            ? TorrentPriority.LOW
            : index === 1 ? TorrentPriority.NORMAL : TorrentPriority.HIGH;
        });
    }
    .width('100%');
  }

  /** Sequential-download checkbox. */
  @Builder
  sequentialRow(): void {
    Row() {
      Text($r('app.string.options_sequential'))
        .fontSize(13)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1);
      Checkbox()
        .select(this.sequentialDownload)
        .selectedColor($r('app.color.accent'))
        .onChange((checked: boolean) => {
          this.sequentialDownload = checked;
        });
    }
    .width('100%');
  }

  /**
   * Mode selector shared by the ratio and idle limits.
   *
   * @param label field label
   * @param isRatio true for the ratio mode, false for the idle mode
   */
  @Builder
  modeRow(label: Resource, isRatio: boolean): void {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(13)
        .fontColor($r('app.color.text_primary'))
        .width(112);
      Select(this.modeOptions())
        .selected(isRatio ? this.ratioMode : this.idleMode)
        .value(isRatio ? this.ratioModeLabel() : this.idleModeLabel())
        .layoutWeight(1)
        .enabled(!this.loading)
        .onSelect((index: number) => {
          if (isRatio) {
            this.ratioMode = index === 0
              ? RatioLimitMode.GLOBAL
              : index === 1 ? RatioLimitMode.SINGLE : RatioLimitMode.UNLIMITED;
          } else {
            this.idleMode = index === 0
              ? IdleLimitMode.GLOBAL
              : index === 1 ? IdleLimitMode.SINGLE : IdleLimitMode.UNLIMITED;
          }
        });
    }
    .width('100%');
  }

  /**
   * Numeric value of the seeding limits.
   *
   * @param label field label
   * @param isRatio true for the ratio value, false for the idle minutes
   */
  @Builder
  valueRow(label: Resource, isRatio: boolean): void {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(13)
        .fontColor($r('app.color.text_primary'))
        .width(112);
      TextInput({ text: isRatio ? this.ratioLimitText : this.idleLimitText })
        .type(InputType.Number)
        .layoutWeight(1)
        .onChange((value: string) => {
          if (isRatio) {
            this.ratioLimitText = value;
          } else {
            this.idleLimitText = value;
          }
        });
    }
    .width('100%');
  }

  /**
   * Integer field of the queue and peer settings.
   *
   * @param label field label
   * @param isQueuePosition true for the queue position, false for the peer limit
   */
  @Builder
  textRow(label: Resource, isQueuePosition: boolean): void {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(13)
        .fontColor($r('app.color.text_primary'))
        .width(112);
      TextInput({ text: isQueuePosition ? this.queuePositionText : this.peerLimitText })
        .type(InputType.Number)
        .layoutWeight(1)
        .onChange((value: string) => {
          if (isQueuePosition) {
            this.queuePositionText = value;
          } else {
            this.peerLimitText = value;
          }
        });
    }
    .width('100%');
  }

  /** Bandwidth group field. */
  @Builder
  groupRow(): void {
    Row({ space: 8 }) {
      Text($r('app.string.options_group'))
        .fontSize(13)
        .fontColor($r('app.color.text_primary'))
        .width(112);
      TextInput({ text: this.groupText })
        .layoutWeight(1)
        .onChange((value: string) => {
          this.groupText = value;
        });
    }
    .width('100%');
  }

  /** Comma-separated labels field. */
  @Builder
  labelsRow(): void {
    Row({ space: 8 }) {
      Text($r('app.string.options_labels'))
        .fontSize(13)
        .fontColor($r('app.color.text_primary'))
        .width(112);
      TextInput({ text: this.labelsText, placeholder: $r('app.string.options_labels_hint') })
        .layoutWeight(1)
        .onChange((value: string) => {
          this.labelsText = value;
        });
    }
    .width('100%');
  }

  /** Labels of the three bandwidth priorities, in selector order. */
  private priorityOptions(): SelectOption[] {
    const options: SelectOption[] = [
      { value: $r('app.string.options_priority_low') },
      { value: $r('app.string.options_priority_normal') },
      { value: $r('app.string.options_priority_high') },
    ];
    return options;
  }

  /** Selector index of the current bandwidth priority. */
  private priorityIndex(): number {
    if (this.bandwidthPriority === TorrentPriority.LOW) {
      return 0;
    }
    return this.bandwidthPriority === TorrentPriority.HIGH ? 2 : 1;
  }

  /** Selector label of the current bandwidth priority. */
  private priorityLabel(): Resource {
    if (this.bandwidthPriority === TorrentPriority.LOW) {
      return $r('app.string.options_priority_low');
    }
    return this.bandwidthPriority === TorrentPriority.HIGH
      ? $r('app.string.options_priority_high')
      : $r('app.string.options_priority_normal');
  }

  /** Global / custom / unlimited labels shared by the two mode selectors. */
  private modeOptions(): SelectOption[] {
    const options: SelectOption[] = [
      { value: $r('app.string.options_mode_global') },
      { value: $r('app.string.options_mode_single') },
      { value: $r('app.string.options_mode_unlimited') },
    ];
    return options;
  }

  /** Selector label of the current ratio mode. */
  private ratioModeLabel(): Resource {
    if (this.ratioMode === RatioLimitMode.SINGLE) {
      return $r('app.string.options_mode_single');
    }
    return this.ratioMode === RatioLimitMode.UNLIMITED
      ? $r('app.string.options_mode_unlimited')
      : $r('app.string.options_mode_global');
  }

  /** Selector label of the current idle mode. */
  private idleModeLabel(): Resource {
    if (this.idleMode === IdleLimitMode.SINGLE) {
      return $r('app.string.options_mode_single');
    }
    return this.idleMode === IdleLimitMode.UNLIMITED
      ? $r('app.string.options_mode_unlimited')
      : $r('app.string.options_mode_global');
  }

  /**
   * Applies every Options field in one `torrent_set`.
   *
   * One request for the tab rather than one per row: the fields describe a
   * single torrent's settings, and a half-applied set is a state nobody asked
   * for. Transmission drops the fields a release does not know, and the reload
   * that follows shows what actually stuck — so a rejected field surfaces as the
   * server's old value coming back, not as silence.
   */
  private saveOptions(): void {
    const request = new TorrentSetRequest(TorrentIds.single(this.torrentId))
      .downloadLimited(this.downloadLimited)
      .downloadLimit(this.parseIntOrZero(this.downloadLimitText))
      .uploadLimited(this.uploadLimited)
      .uploadLimit(this.parseIntOrZero(this.uploadLimitText))
      .bandwidthPriority(this.bandwidthPriority)
      .sequentialDownload(this.sequentialDownload)
      .seedRatioMode(this.ratioMode)
      .seedRatioLimit(this.parseFloatOrZero(this.ratioLimitText))
      .seedIdleMode(this.idleMode)
      .seedIdleLimit(this.parseIntOrZero(this.idleLimitText))
      .queuePosition(this.parseIntOrZero(this.queuePositionText))
      .peerLimit(this.parseIntOrZero(this.peerLimitText))
      .group(this.groupText.trim())
      .labels(TorrentDetailBody.splitLabels(this.labelsText));
    this.applyRequest(request, true);
  }

  /** Non-empty, trimmed labels of the comma-separated field. */
  private static splitLabels(text: string): string[] {
    const out: string[] = [];
    for (const part of text.split(',')) {
      const trimmed = part.trim();
      if (trimmed.length > 0) {
        out.push(trimmed);
      }
    }
    return out;
  }
}

/**
 * 种子详情页右上角的「更多」菜单，挂在宿主 `TorrentDetailPage` 标题栏的 `.menus()` 里。
 *
 * 关键：本组件在标题栏宿主里，而数据刷新只重绘 `TorrentDetailBody`，所以本组件的
 * `bindMenu` 不会被自动刷新重新绑定，菜单在刷新期间稳定。展开状态用 `@Link open` 接到
 * 宿主的 `@State detailMenuOpen`；八个动作经 `controller` 的稳定引用调用，不依赖任何会
 * 随刷新变化的东西。
 *
 * API 12 下 `Menu` 没有 `.show()` / `onOpenChange`，所以用 `bindMenu(isShow, array,
 * options)` 这一布尔可控重载，显隐由 `open` 决定。
 *
 * @since 1.0.0
 */
@Component
struct DetailActionMenu {
  /** 动作转发器：菜单项点击后调用其稳定引用（由 `TorrentDetailBody` 在 `aboutToAppear` 填充）。 */
  controller: DetailController = new DetailController();

  /**
   * 菜单是否展开。用 `@Link` 接到宿主的 `@State detailMenuOpen`。
   *
   * 宿主不随数据刷新重绘，所以这份状态只在用户点开 / 关闭菜单时变化，`bindMenu`
   * 不会被刷新冲掉。
   */
  @Link open: boolean;

  build(): void {
    Stack() {
      SymbolGlyph(AppIcons.MORE)
        .fontSize(20)
        .fontColor([$r('app.color.icon')]);
    }
    .width(40)
    .height(40)
    .onClick(() => {
      this.open = !this.open;
    })
    .bindMenu(
      this.open,
      [
        {
          value: $r('app.string.action_start'),
          action: () => {
            this.open = false;
            this.controller.start();
          },
        },
        {
          value: $r('app.string.action_pause'),
          action: () => {
            this.open = false;
            this.controller.pause();
          },
        },
        {
          value: $r('app.string.action_verify'),
          action: () => {
            this.open = false;
            this.controller.verify();
          },
        },
        {
          value: $r('app.string.action_reannounce'),
          action: () => {
            this.open = false;
            this.controller.reannounce();
          },
        },
        {
          value: $r('app.string.action_rename'),
          action: () => {
            this.open = false;
            this.controller.rename();
          },
        },
        {
          value: $r('app.string.action_set_location'),
          action: () => {
            this.open = false;
            this.controller.setLocation();
          },
        },
        {
          value: $r('app.string.action_share'),
          action: () => {
            this.open = false;
            this.controller.share();
          },
        },
        {
          value: $r('app.string.action_remove'),
          action: () => {
            this.open = false;
            this.controller.remove();
          },
        },
      ],
      {
        onDisappear: (): void => {
          this.open = false;
        },
      },
    );
  }
}

/**
 * 动作转发器：把「种子操作菜单」的八个动作（以及选项页保存）从数据子组件
 * `TorrentDetailBody` 透传给标题栏的 `DetailActionMenu`。
 *
 * 之所以需要这一层：菜单挂在 `NavDestination` 标题栏（宿主 `TorrentDetailPage`），而动作
 * 要操作的数据（`torrent` 等）在子组件 `TorrentDetailBody` 里。若让菜单直接持有数据子
 * 组件的引用，就得把一堆私有方法暴露成 public。改由子组件在 `aboutToAppear` 里把动作以闭包
 * 形式填进本类的字段，菜单只认本类的稳定引用，子组件刷新时不牵动菜单。
 */
class DetailController {
  start: () => void = () => {};
  pause: () => void = () => {};
  verify: () => void = () => {};
  reannounce: () => void = () => {};
  rename: () => void = () => {};
  setLocation: () => void = () => {};
  share: () => void = () => {};
  remove: () => void = () => {};
  save: () => void = () => {};
}

/**
 * 宿主：只承载 `NavDestination` 与右上角菜单。
 *
 * 之前「自动刷新会冲掉菜单」的根因：数据状态（`torrent` 等）和 `.menus()` 同在一个
 * `NavDestination` 组件里，刷新改写 `@State torrent` 触发整页重绘、连带重建 `menus`
 * 子树、把 `bindMenu` 重新绑定，已打开的菜单被强制收起。
 *
 * 解法是把会频繁变化的数据状态全部下放到子组件 `TorrentDetailBody`，本宿主只持有
 * `detailMenuOpen` / `currentTab` / `pathStack` 这几样「几乎不变」的状态。自动刷新只
 * 重绘 `TorrentDetailBody`，本宿主不重绘，`.menus()` 不重跑，菜单因此稳定；而下载信息
 * 照样在子组件里刷新。
 *
 * @since 1.0.0
 */
@Component
export struct TorrentDetailPage {
  /** Torrent id; supplied by the destination builder. */
  torrentId: number = 0;

  /** Stack this destination was pushed onto; filled in by `onReady`. */
  @State pathStack: NavPathStack = new NavPathStack();

  /** Index of the selected tab, mirrored from the body. */
  @State currentTab: number = 0;

  /** 右上角操作菜单是否展开。 */
  @State detailMenuOpen: boolean = false;

  /** 把子组件的动作转交给菜单，避免菜单宿主随数据刷新重绘。 */
  private readonly controller: DetailController = new DetailController();

  build(): void {
    NavDestination() {
      TorrentDetailBody({
        torrentId: this.torrentId,
        pathStack: this.pathStack,
        currentTab: $currentTab,
        controller: this.controller,
      })
    }
    .title($r('app.string.page_title_detail'))
    .menus(this.headerMenus())
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }

  @Builder
  headerMenus(): void {
    Row({ space: 2 }) {
      // 菜单固定在第 0 位：切标签页时 `if (currentTab === TAB_OPTIONS)` 的开合会改变
      // Row 的子节点数量，若菜单在其后才会出现，位置会随之前后移动、导致子组件被重建。
      // 放在 if 之前即可让它的位置恒定复用。
      DetailActionMenu({ open: $detailMenuOpen, controller: this.controller })
      if (this.currentTab === TAB_OPTIONS) {
        // 用图标而不是「保存」二字：这一侧的空间和 ⋮ 共用，两个中文字会把
        // 菜单挤到边缘。图标取「保存到文件」那一颗，而不是勾号 —— 勾号读起来
        // 像「已经存好了」，而这里的含义是「去提交」。
        this.iconAction(AppIcons.SAVE, () => {
          this.saveOptions();
        });
      }
    }
  }

  /** 顶栏风格的小图标按钮，盒子就是点击热区。 */
  @Builder
  iconAction(icon: Resource, action: () => void): void {
    Stack() {
      SymbolGlyph(icon)
        .fontSize(20)
        .fontColor([$r('app.color.icon')]);
    }
    .width(40)
    .height(40)
    .onClick(() => {
      action();
    });
  }

  /** 提交选项页的全部改动。 */
  private saveOptions(): void {
    this.controller.save();
  }
}
