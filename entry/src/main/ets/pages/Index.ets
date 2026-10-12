// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * The torrent list — the application's home screen.
 *
 * Layout follows the reference design: a top action bar, a drawer that slides
 * over the list, the list itself with swipe-to-reveal actions, a floating add
 * button, and a bottom status bar carrying the total transfer rates.
 *
 * All protocol work is delegated: `AppContext` owns the connection and
 * `TorrentListModel` owns filtering, sorting and formatting, so this file is
 * mostly layout and event wiring.
 *
 * @since 1.0.0
 */

import { common } from '@kit.AbilityKit';
import { FreeSpace, TorrentIds, TransmissionClient, TransmissionError } from 'transmission_sdk';
import { AppSettings, ServerProfile, ThemeMode, TorrentFilter, TorrentSort } from '../model/AppModels';
import { AddMethod, AddParam, DetailParam, RouteName, ServerParam } from '../model/NavParams';
import { ALL_FILTERS, TorrentListModel, TorrentRow, torrentFilterLabel } from '../viewmodel/TorrentListModel';
import { formatBytes, formatSpeed } from '../viewmodel/Formatters';
import { AppContext, describeErrorResource } from '../store/AppContext';
import { CompletionNotifier } from '../viewmodel/CompletionNotifier';
import { AppIcons } from '../theme/AppIcons';
import { ThemeManager } from '../theme/ThemeManager';
import { DrawerContent } from '../components/DrawerContent';
import { TorrentRowView } from '../components/TorrentRowView';
import { SwipeActionButton } from '../components/SwipeActionButton';
import { TorrentDetailPage } from './TorrentDetailPage';
import { AddTorrentPage } from './AddTorrentPage';
import { ServersPage } from './ServersPage';
import { SettingsPage } from './SettingsPage';
import { AboutPage } from './AboutPage';

@Entry
@Component
struct Index {
  // ------------------------------------------------------------ appearance
  @State themeMode: ThemeMode = ThemeMode.SYSTEM;

  // --------------------------------------------------------------- servers
  @State servers: ServerProfile[] = [];
  @State activeServerId: string = '';
  @State activeServerName: string = '';

  // ------------------------------------------------------------------ list
  @State rows: TorrentRow[] = [];
  @State filterCounts: number[] = [];
  @State filter: TorrentFilter = TorrentFilter.ALL;
  @State sortBy: TorrentSort = TorrentSort.QUEUE;
  @State sortAscending: boolean = true;
  @State totalDown: string = '0.0 KB/s';
  @State totalUp: string = '0.0 KB/s';

  // ------------------------------------------------------------------ view
  @State showDrawer: boolean = false;
  @State showAddFab: boolean = true;
  @State fabExpanded: boolean = false;
  @State searchActive: boolean = false;
  @State searchText: string = '';
  @State refreshing: boolean = false;
  @State statusMessage: Resource | undefined = $r('app.string.status_no_server');
  @State freeSpaceLabel: string = '';

  // -------------------------------------------------------------- selection
  /**
   * True while several torrents are acted on together.
   *
   * Long-pressing a row enters the mode and selects it; from then on a tap
   * toggles membership instead of opening the detail screen.
   */
  @State selectionMode: boolean = false;

  /**
   * Ids of the selected torrents.
   *
   * Always replaced rather than mutated: ArkUI observes an assignment, not a
   * `push` into an existing array.
   */
  @State selectedIds: number[] = [];

  /**
   * Mirrors {@link AppContext}'s change counter, so a screen that mutates
   * something can tell this one to re-read even though the store itself is not
   * observable and `pushPath` returns no completion callback.
   *
   * The literal must stay equal to `AppContext.REVISION_KEY`; an ArkUI
   * decorator argument has to be a compile-time constant, so a constant
   * reference cannot be used here.
   */
  @StorageLink('dataRevision') @Watch('onDataChanged') dataRevision: number = 0;

  /**
   * Key of the search field, so it can be focused the moment it appears.
   *
   * ArkUI focuses by id rather than by controller, and the field only exists
   * while `searchActive` is true.
   */
  private static readonly SEARCH_FIELD_ID: string = 'torrentSearchField';

  /**
   * Refresh period used while at least one torrent is moving.
   *
   * The user's own interval is honoured for an idle list, but a download or a
   * recheck has to keep up with its progress bar even when the list is set to
   * manual refresh only.
   */
  private static readonly ACTIVE_REFRESH_SECONDS: number = 2;

  /** Width of the navigation drawer. */
  private static readonly DRAWER_WIDTH: number = 280;

  /**
   * Scrim fade, shared by the drawer and the add button.
   *
   * The animation is attached to the effect rather than left to an ambient
   * `animateTo`: both scrims are inserted and removed by an `if`, and an effect
   * that carries its own animation runs wherever it is used.
   */
  private static readonly FADE: TransitionEffect =
    TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.FastOutSlowIn });

  /**
   * Drawer entrance and exit: a slide in from beyond the left edge.
   *
   * The offset is deliberately larger than {@link Index.DRAWER_WIDTH}, so the
   * panel starts fully off screen and no sliver shows through.
   */
  private static readonly SLIDE_FROM_LEFT: TransitionEffect =
    TransitionEffect.translate({ x: -320 }).animation({ duration: 240, curve: Curve.FastOutSlowIn });

  /** Entrance and exit of the add button's two chips. */
  private static readonly RISE: TransitionEffect =
    TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: 8 }))
      // Anchored at the bottom-right corner of the chip, which is where the
      // button sits, so the chips read as unfolding *out of the button* rather
      // than sliding in from the corner of the screen.
      .combine(TransitionEffect.scale({ x: 0.5, y: 0.5, centerX: '100%', centerY: '100%' }))
      .animation({ duration: 200, curve: Curve.FastOutSlowIn });

  private readonly pathStack: NavPathStack = new NavPathStack();
  private readonly listModel: TorrentListModel = new TorrentListModel();
  private refreshTimerId: number = -1;

  // ------------------------------------------------------------- lifecycle

  aboutToAppear(): void {
    this.bootstrap();
  }

  aboutToDisappear(): void {
    this.stopAutoRefresh();
  }

  /**
   * Loads persisted state, connects when a server is configured, and starts the
   * refresh timer.
   *
   * Every failure is reported in the status line rather than thrown: a home
   * screen has nowhere to propagate an exception to.
   */
  private bootstrap(): void {
    const app = AppContext.get();
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;

    app
      .load(context)
      .then(() => {
        this.servers = app.servers.slice();
        this.activeServerId = app.activeServerId;
        this.applySettings(app.settings);
        const server = app.activeServer;
        this.activeServerName = server === undefined ? '' : server.displayName;
        ThemeManager.apply(context, app.settings.themeMode);
        this.restartAutoRefresh();

        if (server === undefined) {
          // Nothing to show yet, so go straight to the server editor rather
          // than presenting an empty list the user cannot act on.
          this.statusMessage = $r('app.string.status_no_server');
          this.openServersPage(true);
          return undefined;
        }
        this.statusMessage = $r('app.string.status_connecting');
        return app.connect().catch((error:object) => {
          this.statusMessage = describeErrorResource(error);
          this.logFailure(error);
        });
      })
      .then(() => {
        if (app.activeServer === undefined) {
          return undefined;
        }
        this.statusMessage = undefined;
        this.loadFreeSpace();
        return this.refresh();
      })
      .catch((error: Object) => {
        this.statusMessage = describeErrorResource(error);
        this.logFailure(error);
      });
  }

  /** Copies the persisted list preferences into the observable state. */
  private applySettings(settings: AppSettings): void {
    this.filter = settings.filter;
    this.sortBy = settings.sortBy;
    this.sortAscending = settings.sortAscending;
    this.showAddFab = settings.showAddFab;
    this.themeMode = settings.themeMode;
  }

  // ---------------------------------------------------------------- refresh

  /** Reloads the torrent list and the derived totals. */
  private async refresh(): Promise<void> {
    this.loadFreeSpace();
    const app = AppContext.get();
    const client = app.activeClient;
    if (client === undefined) {
      return;
    }
    const ok = await this.listModel.load(client, app.settings);
    this.rows = this.listModel.rows;
    this.totalDown = formatSpeed(this.listModel.totalDownloadRate);
    this.totalUp = formatSpeed(this.listModel.totalUploadRate);
    this.rebuildCounts();
    this.pruneSelection();
    if (ok) {
      this.statusMessage = undefined;
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await CompletionNotifier.observe(context, this.listModel.torrents, app.settings.notificationsEnabled, this.activeServerName);
    } else if (this.listModel.lastError !== undefined) {
      this.statusMessage = describeErrorResource(this.listModel.lastError);
    }
    // Whether anything is moving may have just changed, so re-plan the timer.
    this.restartAutoRefresh();
  }

  /** Copies the per-filter counts out of the model into an observable array. */
  private rebuildCounts(): void {
    const counts: number[] = [];
    for (const value of ALL_FILTERS) {
      counts.push(this.listModel.count(value));
    }
    this.filterCounts = counts;
  }

  /**
   * (Re)plans the next automatic refresh.
   *
   * Two periods exist: the one the user configured, and a faster one used while
   * something is actually transferring. The latter is what keeps a recheck's
   * percentage and progress bar moving.
   */
  private restartAutoRefresh(): void {
    this.stopAutoRefresh();
    const active = this.listModel.hasActiveTorrents;
    const seconds = active
      ? Index.ACTIVE_REFRESH_SECONDS
      : AppContext.get().settings.refreshIntervalSeconds;
    if (seconds <= 0) {
      return;
    }
    this.refreshTimerId = setInterval(() => {
      // A pushed screen is on top and drives its own refresh; polling here as
      // well would double the request rate for no visible benefit.
      if (this.pathStack.size() > 0) {
        return;
      }
      this.refresh();
    }, seconds * 1000);
  }

  /** Cancels the refresh timer. */
  private stopAutoRefresh(): void {
    if (this.refreshTimerId !== -1) {
      clearInterval(this.refreshTimerId);
      this.refreshTimerId = -1;
    }
  }

  // ------------------------------------------------------------------ build

  build(): void {
    Navigation(this.pathStack) {
      Stack({ alignContent: Alignment.TopStart }) {
        Column() {
          this.topBar();

          // The add button lives in a stack around the *list* rather than
          // around the whole screen: the bottom bar is chrome that belongs to
          // the window, and a button anchored to the screen's bottom edge would
          // sit on top of it.
          Stack({ alignContent: Alignment.BottomEnd }) {
            this.listArea();

            // Tapping the scrim collapses the add button, the same way the
            // drawer is dismissed. It is inserted *before* the button, so the
            // button and its two chips still receive their own taps — only the
            // area around them is caught.
            if (this.fabExpanded) {
              Column()
                .width('100%')
                .height('100%')
                .backgroundColor($r('app.color.scrim'))
                .transition(Index.FADE)
                .onClick(() => {
                  this.fabExpanded = false;
                });
            }

            if (this.showAddFab && this.servers.length > 0) {
              this.floatingButton();
            }
          }
          .width('100%')
          .layoutWeight(1);

          this.bottomBar();
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.app_background'));

        // The drawer is drawn last, so its own scrim covers the add button too.
        if (this.showDrawer) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor($r('app.color.scrim'))
            .transition(Index.FADE)
            .onClick(() => {
              this.closeDrawer();
            });

          // Wrapped rather than given the attributes directly: a custom
          // component does not accept width or height from its call site.
          Column() {
            DrawerContent({
              servers: this.servers,
              activeServerId: this.activeServerId,
              filter: this.filter,
              sortBy: this.sortBy,
              sortAscending: this.sortAscending,
              filterCounts: this.filterCounts,
              freeSpaceLabel: this.freeSpaceLabel,
              onSelectServer: (serverId: string) => {
                this.switchServer(serverId);
              },
              onManageServers: () => {
                this.closeDrawer();
                this.openServersPage(false);
              },
              onSelectFilter: (value: TorrentFilter) => {
                this.setFilter(value);
              },
              onSelectSort: (value: TorrentSort) => {
                this.setSort(value);
              },
              onToggleDirection: () => {
                this.toggleSortDirection();
              },
              onOpenSettings: () => {
                this.closeDrawer();
                this.openSettingsPage();
              },
              onOpenAbout: () => {
                this.closeDrawer();
                this.openAboutPage();
              },
              onRefreshFreeSpace: () => {
                this.loadFreeSpace();
              },
            })
          }
          .width(Index.DRAWER_WIDTH)
          .height('100%')
          .transition(Index.SLIDE_FROM_LEFT);
        }
      }
      .width('100%')
      .height('100%');
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.pageMap)
  }

  /**
   * Registers every pushable screen.
   *
   * `param` arrives untyped from `pushPath`, so each branch casts it to the
   * class the caller pushed.
   */
  @Builder
  pageMap(name: string, param: object) {
    if (name === RouteName.DETAIL) {
      TorrentDetailPage({ torrentId: (param as DetailParam).torrentId })
    } else if (name === RouteName.ADD) {
      AddTorrentPage({ pathStack: this.pathStack, initialMethod: (param as AddParam).method })
    } else if (name === RouteName.SERVERS) {
      ServersPage({ pathStack: this.pathStack, startInEdit: (param as ServerParam).startInEdit })
    } else if (name === RouteName.SETTINGS) {
      SettingsPage({ pathStack: this.pathStack })
    } else if (name === RouteName.ABOUT) {
      AboutPage({ pathStack: this.pathStack })
    }
  }

  /**
   * Reacts to a change announced by another screen.
   *
   * Settings may have moved, and the server may even be a different one, so the
   * preferences are re-applied before the store is re-read.
   */
  onDataChanged(): void {
    this.applySettings(AppContext.get().settings);
    this.restartAutoRefresh();
    this.syncFromStore();
  }

  // --------------------------------------------------------------- routing

  /**
   * Opens the server screen and re-reads the store when it is dismissed.
   *
   * `pushPath` resolves when the pushed destination is popped, which is exactly
   * the moment the saved servers may have changed. Re-reading there is what
   * keeps the drawer's server section in step with an add or a delete: the
   * store is intentionally not observable, so nothing pushes the change on us.
   *
   * @param startInEdit true to open the editor instead of the saved-server list
   */
  private openServersPage(startInEdit: boolean): void {
    this.pathStack.pushPath({ name: RouteName.SERVERS, param: new ServerParam(startInEdit) });
  }

  /** Opens the options screen. */
  private openSettingsPage(): void {
    this.pathStack.pushPath({ name: RouteName.SETTINGS });
  }

  /** Opens the about screen. */
  private openAboutPage(): void {
    this.pathStack.pushPath({ name: RouteName.ABOUT });
  }

  /**
   * Re-reads `AppContext` after a destination was popped and reacts to it.
   *
   * A different server means the list on screen belongs to the previous one, so
   * the client has to reconnect before the next refresh.
   */
  private syncFromStore(): void {
    const app = AppContext.get();
    const previousServerId = this.activeServerId;

    this.servers = app.servers.slice();
    this.activeServerId = app.activeServerId;
    const server = app.activeServer;
    this.activeServerName = server === undefined ? '' : server.displayName;

    if (server === undefined) {
      this.rows = [];
      this.filterCounts = [];
      this.freeSpaceLabel = '';
      this.statusMessage = $r('app.string.status_no_server');
      return;
    }
    if (this.activeServerId !== previousServerId || !app.isConnected) {
      this.connectAndRefresh();
    } else {
      this.refresh();
    }
  }

  /** Connects to the active server and reloads the list. */
  private connectAndRefresh(): void {
    const app = AppContext.get();
    this.statusMessage = $r('app.string.status_connecting');
    app
      .connect()
      .then(() => {
        this.statusMessage = undefined;
        this.loadFreeSpace();
        return this.refresh();
      })
      .catch((error: Object) => {
        this.statusMessage = describeErrorResource(error);
        this.logFailure(error);
      });
  }

  // ---------------------------------------------------------------- top bar

  @Builder
  topBar(): void {
    if (this.searchActive) {
      this.searchBar();
    } else if (this.selectionMode) {
      this.selectionBar();
    } else {
      Row({ space: 4 }) {
        this.iconButton(AppIcons.MENU, () => {
          if (this.showDrawer) {
            this.closeDrawer();
          } else {
            this.openDrawer();
          }
        });

        // Capped rather than `layoutWeight(1)`: a long server name used to
        // stretch this block across the bar and squeeze the actions beside it.
        Column({ space: 1 }) {
          Text(this.activeServerName.length > 0 ? this.activeServerName : $r('app.string.status_no_server'))
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
          Text(torrentFilterLabel(this.filter))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'));
        }
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ maxWidth: '56%' })
        .onClick(() => {
          this.openDrawer();
        });

        Blank();

        this.iconButton(AppIcons.SEARCH, () => {
          this.openSearch();
        });
      }
      .width('100%')
      .height(56)
      .padding({ left: 4, right: 4 })
      .backgroundColor($r('app.color.top_bar_background'));
    }
  }

  /**
   * Top bar shown while several torrents are selected.
   *
   * The whole-session buttons that used to sit in the top bar — start and pause
   * over *every* torrent — are exactly the commands that need a selection to be
   * meaningful, so they appear here and act on the selection instead.
   */
  @Builder
  selectionBar(): void {
    Row({ space: 4 }) {
      this.iconButton(AppIcons.CLOSE, () => {
        this.exitSelection();
      });

      Text($r('app.string.selection_count', `${this.selectedIds.length}`))
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });

      Blank();

      this.iconButton(AppIcons.RESUME, () => {
        this.startSelected();
      });
      this.iconButton(AppIcons.PAUSE, () => {
        this.stopSelected();
      });
      this.iconButton(AppIcons.DELETE, () => {
        this.confirmRemoveSelected();
      });
      this.selectionMenu();
    }
    .width('100%')
    .height(56)
    .padding({ left: 4, right: 4 })
    .backgroundColor($r('app.color.top_bar_background'));
  }

  /** Search field that replaces the title bar while active. */
  @Builder
  searchBar(): void {
    Row({ space: 4 }) {
      Search({ value: this.searchText, placeholder: $r('app.string.common_search') })
        .id(Index.SEARCH_FIELD_ID)
        .layoutWeight(1)
        .height(40)
        .backgroundColor($r('app.color.surface_alt'))
        .placeholderColor($r('app.color.text_tertiary'))
        .textFont({ size: 15 })
        .onChange((value: string) => {
          this.searchText = value;
        })
        .onAppear(() => {
          // Focusing the field opens the soft keyboard, so tapping the search
          // button is enough to start typing.
          try {
            this.getUIContext().getFocusController().requestFocus(Index.SEARCH_FIELD_ID);
          } catch (error) {
            this.statusMessage = describeErrorResource(error);
            this.logFailure(error);
          }
        });
      this.iconButton(AppIcons.CLOSE, () => {
        this.searchActive = false;
        this.searchText = '';
      });
    }
    .width('100%')
    .height(56)
    .padding({ left: 8, right: 4 })
    .backgroundColor($r('app.color.top_bar_background'));
  }

  /**
   * Overflow menu of the selection bar — the only overflow menu the list has.
   *
   * 这颗按钮只在多选时出现。菜单里的三条（全选 / 校验 / 重新汇报）都需要一个
   * 明确的作用对象，而「全选」本身就是进入多选的入口，没有选中项时无意义；
   * 原来的「选项」入口已由抽屉承担，所以非多选态不再留一个只剩一项的 ⋮。
   *
   * Re-announce lives here rather than on the swipe actions: three swipe buttons
   * keep the revealed strip narrow, and selecting one row and re-announcing it is
   * the same number of taps as swiping used to be.
   */
  @Builder
  selectionMenu(): void {
    Stack() {
      SymbolGlyph(AppIcons.MORE)
        .fontSize(20)
        .fontColor([$r('app.color.icon')]);
    }
    .width(40)
    .height(40)
    .bindMenu([
        {
          value: $r('app.string.selection_select_all'),
          action: () => {
            this.selectAllVisible();
          },
        },
        {
          value: $r('app.string.list_swipe_verify'),
          action: () => {
            this.verifySelected();
          },
        },
        {
          value: $r('app.string.list_swipe_reannounce'),
          action: () => {
            this.reannounceSelected();
          },
        },
      ]);
  }

  /** Square, borderless glyph button used across the top bar. */
  @Builder
  iconButton(icon: Resource, action: () => void): void {
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

  // -------------------------------------------------------------- list area

  @Builder
  listArea(): void {
    Column() {
      if (this.servers.length === 0) {
        this.noServerState();
      } else if (this.visibleRows().length === 0) {
        this.emptyState();
      } else {
        Refresh({ refreshing: $$this.refreshing }) {
          List({ space: 8 }) {
            ForEach(
              this.visibleRows(),
              (row: TorrentRow) => {
                ListItem() {
                  TorrentRowView({
                    row: row,
                    selected: this.isSelected(row.id),
                    onTap: (item: TorrentRow) => {
                      this.handleRowTap(item);
                    },
                    onLongPress: (item: TorrentRow) => {
                      this.handleRowLongPress(item);
                    },
                  })
                }
                .swipeAction({ end: this.rowActions(row), edgeEffect: SwipeEdgeEffect.Spring })
              },
              // The key embeds everything the row renders. A key of just the
              // id lets ArkUI reuse the component without re-rendering it, so
              // a progress bar or a status caption would freeze at the value
              // it was first built with.
              (row: TorrentRow) =>
                `${row.id}-${row.status}-${Math.round(row.barValue * 100)}-${row.downSpeedLabel}-${row.upSpeedLabel}-${this.isSelected(row.id)}`,
            );
          }
          .width('100%')
          .height('100%')
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .scrollBar(BarState.Off);
        }
        .layoutWeight(1)
        .width('100%')
        .onRefreshing(() => {
          this.refreshing = true;
          this.refresh().finally(() => {
            this.refreshing = false;
          });
        });
      }

      if (this.statusMessage !== undefined && this.servers.length > 0) {
        this.statusLine();
      }
    }
    .width('100%')
    .height('100%');
  }

  /** Rows after the local search box has been applied. */
  private visibleRows(): TorrentRow[] {
    if (this.searchText.length === 0) {
      return this.rows;
    }
    const needle = this.searchText.toLowerCase();
    const matches: TorrentRow[] = [];
    for (const row of this.rows) {
      if (row.name.toLowerCase().includes(needle) || row.hash.toLowerCase().includes(needle)) {
        matches.push(row);
      }
    }
    return matches;
  }

  /**
   * Shown when no server has been configured.
   *
   * Deliberately reachable rather than redirecting on every return: the user
   * must be able to back out of the server editor without being pushed straight
   * back into it, so the editor is offered as a button instead.
   */
  @Builder
  noServerState(): void {
    Column({ space: 10 }) {
      SymbolGlyph(AppIcons.SERVER)
        .fontSize(48)
        .fontColor([$r('app.color.text_tertiary')]);
      Text($r('app.string.servers_empty'))
        .fontSize(15)
        .fontColor($r('app.color.text_secondary'));
      Text($r('app.string.servers_empty_hint'))
        .fontSize(13)
        .fontColor($r('app.color.text_tertiary'));
      Button($r('app.string.drawer_add_server'))
        .fontSize(15)
        .height(40)
        .margin({ top: 8 })
        .backgroundColor($r('app.color.accent'))
        .fontColor($r('app.color.text_on_accent'))
        .onClick(() => {
          this.openServersPage(true);
        });
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  emptyState(): void {
    Column({ space: 8 }) {
      SymbolGlyph(AppIcons.FILE)
        .fontSize(48)
        .fontColor([$r('app.color.text_tertiary')]);
      Text(this.searchText.length > 0 ? $r('app.string.list_empty_filtered') : $r('app.string.list_empty'))
        .fontSize(15)
        .fontColor($r('app.color.text_secondary'));
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center);
  }

  /** One-line status under the list, e.g. a connection failure. */
  @Builder
  statusLine(): void {
    Text(this.statusMessage)
      .fontSize(12)
      .fontColor($r('app.color.danger'))
      .width('100%')
      .padding({ left: 16, right: 16, top: 4, bottom: 4 })
      .maxLines(2);
  }

  // -------------------------------------------------------------- swipe end

  /**
   * Buttons revealed by swiping a row to the left.
   *
   * Three actions keep the revealed strip narrow so the list keeps most of its
   * width: open-detail is a plain row tap, and re-announce moved to the overflow
   * menu (select the row, then re-announce the selection).
   *
   * Start versus pause picks its icon with an `if` rather than a ternary
   * argument — a `@Builder` argument is passed by value, and the linter rejects
   * one derived from state (`builder-value-param`).
   */
  @Builder
  rowActions(row: TorrentRow): void {
    Row() {
      if (row.isRunning) {
        SwipeActionButton({
          icon: AppIcons.PAUSE,
          label: $r('app.string.list_swipe_pause'),
          color: $r('app.color.accent'),
          onTap: () => {
            this.toggleTorrent(row);
          },
        });
      } else {
        SwipeActionButton({
          icon: AppIcons.RESUME,
          label: $r('app.string.list_swipe_start'),
          color: $r('app.color.success'),
          onTap: () => {
            this.toggleTorrent(row);
          },
        });
      }
      SwipeActionButton({
        icon: AppIcons.VERIFY,
        label: $r('app.string.list_swipe_verify'),
        color: $r('app.color.warning'),
        onTap: () => {
          this.verifyOne(row.id);
        },
      });
      // Labelled "Remove", not "Delete data": the confirmation that follows keeps
      // the downloaded files, so the old label promised something it did not do.
      SwipeActionButton({
        icon: AppIcons.DELETE,
        label: $r('app.string.list_swipe_remove'),
        color: $r('app.color.danger'),
        onTap: () => {
          this.confirmRemove(row);
        },
      });
    }
    .margin({left: -10})
    .height('100%')
    .zIndex(-1)
    .padding({ left: 14, right: 4 })
    .backgroundColor($r('app.color.surface_alt'));
  }

  // ------------------------------------------------------------- bottom bar

  /**
   * Status bar under the list.
   *
   * The server's remaining disk space stays on the left; the session's total
   * rates moved to the right, where they read as a summary rather than as a
   * prefix to the free-space figure. Search used to live at the far right of
   * this row and now sits in the top bar.
   */
  @Builder
  bottomBar(): void {
    Row({ space: 6 }) {
      SymbolGlyph(AppIcons.STORAGE)
        .fontSize(16)
        .fontColor([$r('app.color.icon')]);
      Text(this.freeSpaceLabel.length > 0 ? this.freeSpaceLabel : '…')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'));

      Blank();

      SymbolGlyph(AppIcons.DOWNLOAD)
        .fontSize(14)
        .fontColor([$r('app.color.success')]);
      Text(this.totalDown)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'));
      SymbolGlyph(AppIcons.UPLOAD)
        .fontSize(14)
        .fontColor([$r('app.color.danger')]);
      Text(this.totalUp)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'));
    }
    .width('100%')
    .height(44)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.bottom_bar_background'));
  }

  // -------------------------------------------------------------------- FAB

  /** Expandable floating action button for adding torrents. */
  @Builder
  floatingButton(): void {
    Column({ space: 10 }) {
      if (this.fabExpanded) {
        this.fabAction(AppIcons.FILE, $r('app.string.add_method_file'), () => {
          this.collapseFabAndPush(AddMethod.FILE);
        });
        this.fabAction(AppIcons.LINK, $r('app.string.add_method_link'), () => {
          this.collapseFabAndPush(AddMethod.LINK);
        });
      }
      Button() {
        SymbolGlyph(AppIcons.PLUS)
          .fontSize(22)
          .fontColor([$r('app.color.text_on_accent')])
          // A plus turned 45° is a cross, and rotating one glyph is what makes
          // the change animate: swapping two glyphs would be a replacement,
          // which cannot be interpolated.
          .rotate({ angle: this.fabExpanded ? 45 : 0 });
      }
      .width(56)
      .height(56)
      .borderRadius(28)
      .backgroundColor($r('app.color.fab_background'))
      .onClick(() => {
        // `animateTo` is what animates the rotation; the chips carry their own
        // transition, so they animate whether or not this is the entry point.
        this.getUIContext().animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => {
          this.fabExpanded = !this.fabExpanded;
        });
      });
    }
    .alignItems(HorizontalAlign.End)
    .margin({ right: 20, bottom: 20 });
  }

  /** One of the labelled chips above the floating button. */
  @Builder
  fabAction(icon: Resource, label: Resource, action: () => void): void {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(14)
        .fontColor($r('app.color.text_primary'))
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .borderRadius(6)
        .backgroundColor($r('app.color.fab_label_background'));
      Stack() {
        SymbolGlyph(icon)
          .fontSize(20)
          .fontColor([$r('app.color.text_on_accent')]);
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .backgroundColor($r('app.color.fab_background'));
    }
    .transition(Index.RISE)
    .onClick(() => {
      action();
    });
  }

  /** Collapses the floating button and opens the add screen. */
  private collapseFabAndPush(method: AddMethod): void {
    this.fabExpanded = false;
    this.pathStack.pushPath({ name: RouteName.ADD, param: new AddParam(method) });
  }

  // ---------------------------------------------------------------- commands

  /**
   * Shows the search field and puts the caret in it.
   *
   * The focus request itself happens in the field's `onAppear`, which is the
   * first moment the component exists.
   */
  private openSearch(): void {
    this.searchActive = true;
  }

  /** Opens the detail screen for one torrent. */
  private openDetail(torrentId: number): void {
    this.pathStack.pushPath({ name: RouteName.DETAIL, param: new DetailParam(torrentId) });
    // The detail screen reports its own mutations through `AppContext`.
  }

  // -------------------------------------------------------------- selection

  /** True when `id` is part of the current selection. */
  private isSelected(id: number): boolean {
    return this.selectedIds.indexOf(id) >= 0;
  }

  /**
   * Handles a row tap.
   *
   * Inside a selection a tap toggles membership; otherwise it opens the detail
   * screen, which is what the row has to keep doing now that the swipe strip no
   * longer carries an edit button.
   */
  private handleRowTap(row: TorrentRow): void {
    if (this.selectionMode) {
      this.toggleSelected(row.id);
    } else {
      this.openDetail(row.id);
    }
  }

  /** Long-pressing a row enters selection mode; inside it, it toggles. */
  private handleRowLongPress(row: TorrentRow): void {
    if (this.selectionMode) {
      this.toggleSelected(row.id);
      return;
    }
    this.selectionMode = true;
    this.selectedIds = [row.id];
  }

  /** Adds or removes one id, and leaves the mode when the last one goes. */
  private toggleSelected(id: number): void {
    const next: number[] = [];
    let found = false;
    for (const value of this.selectedIds) {
      if (value === id) {
        found = true;
      } else {
        next.push(value);
      }
    }
    if (!found) {
      next.push(id);
    }
    this.selectedIds = next;
    if (next.length === 0) {
      this.exitSelection();
    }
  }

  /** Leaves selection mode. */
  private exitSelection(): void {
    this.selectionMode = false;
    this.selectedIds = [];
  }

  /** Selects every torrent the current filter and search box show. */
  private selectAllVisible(): void {
    const ids: number[] = [];
    for (const row of this.visibleRows()) {
      ids.push(row.id);
    }
    this.selectedIds = ids;
    if (ids.length === 0) {
      this.exitSelection();
    }
  }

  /**
   * Drops selected ids that are no longer in the list.
   *
   * A refresh can pull a torrent out from under the selection — this client may
   * have just removed it, or another one did — and a batch built from a stale id
   * fails as a whole.
   */
  private pruneSelection(): void {
    if (!this.selectionMode) {
      return;
    }
    const present: number[] = [];
    for (const row of this.rows) {
      if (this.isSelected(row.id)) {
        present.push(row.id);
      }
    }
    if (present.length === this.selectedIds.length) {
      return;
    }
    this.selectedIds = present;
    if (present.length === 0) {
      this.exitSelection();
    }
  }

  /** Runs a command against the selection, then refreshes. */
  private runSelectionCommand(run: (client: TransmissionClient, ids: TorrentIds) => Promise<void>): void {
    if (this.selectedIds.length === 0) {
      return;
    }
    const ids = TorrentIds.ofNumbers(this.selectedIds.slice());
    this.runCommand((client: TransmissionClient) => run(client, ids));
  }

  /** Resumes every selected torrent. */
  private startSelected(): void {
    this.runSelectionCommand((client: TransmissionClient, ids: TorrentIds) => client.torrents.start(ids));
  }

  /** Pauses every selected torrent. */
  private stopSelected(): void {
    this.runSelectionCommand((client: TransmissionClient, ids: TorrentIds) => client.torrents.stop(ids));
  }

  /** Verifies every selected torrent. */
  private verifySelected(): void {
    if (this.selectedIds.length === 0) {
      return;
    }
    this.runSelectionCommand((client: TransmissionClient, ids: TorrentIds) => client.torrents.verify(ids));
    this.toast($r('app.string.list_verify_requested'));
  }

  /** Re-announces every selected torrent. */
  private reannounceSelected(): void {
    if (this.selectedIds.length === 0) {
      return;
    }
    this.runSelectionCommand((client: TransmissionClient, ids: TorrentIds) => client.torrents.reannounce(ids));
    this.toast($r('app.string.list_reannounce_requested'));
  }

  /** Asks before removing the selection. */
  private confirmRemoveSelected(): void {
    if (this.selectedIds.length === 0) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: $r('app.string.list_remove_confirm_title'),
      message: $r('app.string.list_remove_confirm_message'),
      primaryButton: {
        value: $r('app.string.common_cancel'),
        action: () => {},
      },
      secondaryButton: {
        value: $r('app.string.common_remove'),
        fontColor: $r('app.color.danger'),
        action: () => {
          this.removeSelected();
        },
      },
    });
  }

  /** Removes the selection, keeping the downloaded data. */
  private removeSelected(): void {
    const client = AppContext.get().activeClient;
    if (client === undefined || this.selectedIds.length === 0) {
      return;
    }
    const ids = TorrentIds.ofNumbers(this.selectedIds.slice());
    client.torrents
      .remove(ids, false)
      .then(() => {
        this.exitSelection();
        return this.refresh();
      })
      .catch((error: Object) => {
        this.statusMessage = describeErrorResource(error);
        this.logFailure(error);
      });
  }

  /** Pauses or resumes one torrent, then refreshes. */
  private toggleTorrent(row: TorrentRow): void {
    const client = AppContext.get().activeClient;
    if (client === undefined) {
      return;
    }
    const ids = TorrentIds.single(row.id);
    const action = row.isRunning ? client.torrents.stop(ids).catch((error: object) => {
      this.statusMessage = describeErrorResource(error);
      this.logFailure(error);
    }) : client.torrents.start(ids).catch((error: object) => {
      this.statusMessage = describeErrorResource(error);
      this.logFailure(error);
    });
    action
      .then(() => {
        return this.refresh();
      })
      .catch((error: Object) => {
        this.statusMessage = describeErrorResource(error);
        this.logFailure(error);
      });
  }

  /**
   * Verifies one torrent.
   *
   * The toast matters: a recheck is queued rather than started instantly, so
   * without it the tap looks like it did nothing until the list happens to
   * refresh.
   */
  private verifyOne(torrentId: number): void {
    this.runCommand((client: TransmissionClient) => client.torrents.verify(TorrentIds.single(torrentId)).catch((error:object) => {
      this.statusMessage = describeErrorResource(error);
      this.logFailure(error);
    }));
    this.toast($r('app.string.list_verify_requested'));
  }

  /** Shows a short confirmation. */
  private toast(message: Resource): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 1500 });
    } catch (error) {
      this.statusMessage = describeErrorResource(error);
      this.logFailure(error);
    }
  }

  /** Runs a session-wide command and refreshes afterwards. */
  private runCommand(command: (client: TransmissionClient) => Promise<void>): void {
    const client = AppContext.get().activeClient;
    if (client === undefined) {
      return;
    }
    command(client)
      .then(() => {
        return this.refresh();
      })
      .catch((error: Object) => {
        this.statusMessage = describeErrorResource(error);
        this.logFailure(error);
      });
  }

  /** Asks before removing a torrent. */
  private confirmRemove(row: TorrentRow): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.list_remove_confirm_title'),
      message: $r('app.string.list_remove_confirm_message'),
      primaryButton: {
        value: $r('app.string.common_cancel'),
        action: () => {},
      },
      secondaryButton: {
        value: $r('app.string.common_remove'),
        fontColor: $r('app.color.danger'),
        action: () => {
          this.removeTorrent(row.id, false);
        },
      },
    });
  }

  /** Removes a torrent, optionally deleting its data. */
  private removeTorrent(torrentId: number, deleteData: boolean): void {
    const client = AppContext.get().activeClient;
    if (client === undefined) {
      return;
    }
    client.torrents
      .remove(TorrentIds.single(torrentId), deleteData)
      .then(() => {
        return this.refresh();
      })
      .catch((error: Object) => {
        this.statusMessage = describeErrorResource(error);
        this.logFailure(error);
      });
  }

  // --------------------------------------------------------- drawer commands

  /** Switches the active server and reloads everything. */
  private switchServer(serverId: string): void {
    this.closeDrawer();
    const app = AppContext.get();
    this.statusMessage = $r('app.string.status_connecting');
    app
      .selectServer(serverId)
      .then(() => {
        this.servers = app.servers.slice();
        this.activeServerId = app.activeServerId;
        const server = app.activeServer;
        this.activeServerName = server === undefined ? '' : server.displayName;
        this.statusMessage = undefined;
        this.freeSpaceLabel = '';
        this.loadFreeSpace();
        return this.refresh();
      })
      .catch((error: Object) => {
        this.statusMessage = describeErrorResource(error);
        this.logFailure(error);
      });
  }

  /** Applies a filter and persists it. */
  private setFilter(value: TorrentFilter): void {
    this.filter = value;
    const app = AppContext.get();
    app.settings.filter = value;
    this.listModel.recompute(app.settings);
    this.rows = this.listModel.rows;
    app.saveSettings();
  }

  /** Applies a sort key and persists it. */
  private setSort(value: TorrentSort): void {
    this.sortBy = value;
    const app = AppContext.get();
    app.settings.sortBy = value;
    this.listModel.recompute(app.settings);
    this.rows = this.listModel.rows;
    app.saveSettings();
  }

  /** Flips the sort direction and persists it. */
  private toggleSortDirection(): void {
    this.sortAscending = !this.sortAscending;
    const app = AppContext.get();
    app.settings.sortAscending = this.sortAscending;
    this.listModel.recompute(app.settings);
    this.rows = this.listModel.rows;
    app.saveSettings();
  }

  /**
   * Opens the drawer, fetching the free-space figure the first time.
   *
   * Free space is a server-side disk query, so it is only asked for when the
   * drawer is actually shown and only until a value is known; tapping the row
   * refreshes it on demand.
   */
  private openDrawer(): void {
    // The add button would otherwise stay expanded underneath the drawer's
    // scrim, and reopening it after the drawer closes would show a stale state.
    this.fabExpanded = false;
    this.showDrawer = true;
    if (this.freeSpaceLabel.length === 0 && this.servers.length > 0) {
      this.loadFreeSpace();
    }
  }

  /** Closes the drawer. */
  private closeDrawer(): void {
    this.showDrawer = false;
  }

  /** Asks the server how much space the default download directory has left. */
  private loadFreeSpace(): void {
    const client = AppContext.get().activeClient;
    if (client === undefined) {
      return;
    }
    client.session
      .get(['download_dir'])
      .then((settings) => {
        const dir = settings.downloadDir;
        if (dir.length === 0) {
          return undefined;
        }
        return client.system.freeSpace(dir).catch((error: object) => {
          // 剩余空间是次要信息：查询失败（例如服务端 download-dir 指向了不存在的目录，
          // free_space 会返回 RPC 5 / "No such file or directory"）时只降级显示为「—」，
          // 绝不能写 statusMessage —— 那会用一个次要错误盖掉正常的连接状态，
          // 让人误以为连不上服务器。
          this.logFailure(error);
          return undefined;
        });
      })
      .then((space: FreeSpace | undefined) => {
        this.freeSpaceLabel = space === undefined ? '—' : formatBytes(space.sizeBytes);
      })
      .catch((error: Object) => {
        this.freeSpaceLabel = '—';
        this.logFailure(error);
      });
  }

  /** Logs a failure so it is visible in the device log without a second toast. */
  private logFailure(error: Object): void {
    if (error instanceof TransmissionError) {
      console.warn(`Transmission: ${error.kind} — ${error.fullMessage}`);
    }
  }
}
