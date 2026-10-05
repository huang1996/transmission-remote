// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Server management: the saved-server list and the editor for one profile.
 *
 * A single destination hosts both modes so that adding a server never leaves
 * the Servers screen; `editing` decides which half of the screen `build()`
 * renders. The list is copied from {@link AppContext} into local `@State` after
 * every mutation, because `AppContext` is intentionally not observable.
 *
 * 行上的操作方式与种子列表保持一致：左滑露出「编辑 / 删除」，长按进入多选，
 * 多选时标题栏右侧出现删除图标。之前是长按直接删除 —— 一个既不好发现、又
 * 没有确认余地的组合。
 *
 * @since 1.0.0
 */

import { TransmissionClientBuilder } from 'transmission_sdk';
import { ServerProfile } from '../model/AppModels';
import { AppContext, describeErrorResource } from '../store/AppContext';
import { AppIcons } from '../theme/AppIcons';
import { SwipeActionButton } from '../components/SwipeActionButton';

/** Port offered for a brand new profile. */
const DEFAULT_PORT: string = '9091';
/** RPC path offered for a brand new profile. */
const DEFAULT_RPC_PATH: string = '/transmission/rpc';
/** Toast lifetime in milliseconds. */
const TOAST_DURATION: number = 2500;

/** The saved servers and the editor for one of them. */
@Component
export struct ServersPage {
  /** Stack this destination was pushed onto; refreshed by `onReady`. */
  pathStack: NavPathStack = new NavPathStack();

  /**
   * True opens the editor immediately instead of the saved-server list.
   *
   * Set by the home screen when the application has no server at all, so the
   * user lands on the form rather than on an empty list.
   */
  startInEdit: boolean = false;

  /** Snapshot of `AppContext.servers`, kept in step after each mutation. */
  @State servers: ServerProfile[] = [];
  /** Id of the active profile, used to highlight one row. */
  @State activeServerId: string = '';
  /** False renders the list, true renders the editor. */
  @State editing: boolean = false;
  /** True when the editor was opened for a profile that already exists. */
  @State editingExisting: boolean = false;
  /** True while the throwaway test client is connecting. */
  @State testing: boolean = false;

  /**
   * 多选模式：长按任意一行进入，此后点击行是勾选而不是切换服务器。
   *
   * 与种子列表同一套约定 —— 长按进入、点行勾选、勾选清空后自动退出。
   */
  @State selectionMode: boolean = false;

  /**
   * 已勾选的服务器 id。
   *
   * 整体替换而不是原地 push：ArkUI 观察的是赋值，往已有数组里 push 不会触发
   * 刷新。
   */
  @State selectedIds: string[] = [];

  @State editId: string = '';
  @State editName: string = '';
  @State editHost: string = '';
  @State editPort: string = DEFAULT_PORT;
  @State editPath: string = DEFAULT_RPC_PATH;
  @State editSecure: boolean = false;
  @State editUsername: string = '';
  @State editPassword: string = '';

  aboutToAppear(): void {
    this.reloadServers();
    if (this.startInEdit && this.servers.length === 0) {
      this.startEdit(undefined);
    }
  }

  build(): void {
    NavDestination() {
      if (this.editing) {
        this.buildEditor();
      } else {
        this.buildList();
      }
    }
    .title(this.editing
      ? $r('app.string.page_title_server_edit')
      : $r('app.string.page_title_servers'))
    .menus(this.headerMenus())
    .backgroundColor($r('app.color.app_background'))
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }

  // ------------------------------------------------------------------ list

  /**
   * 标题栏右侧：多选时才出现的删除图标。
   *
   * 只在有意义的时候占位 —— 平时这一侧是空的，标题栏保持干净。
   */
  @Builder
  headerMenus(): void {
    Row() {
      if (this.selectionMode) {
        Stack() {
          SymbolGlyph(AppIcons.DELETE)
            .fontSize(20)
            .fontColor([$r('app.color.danger')]);
        }
        .width(40)
        .height(40)
        .onClick(() => {
          this.confirmDeleteSelected();
        });
      }
    }
  }

  @Builder
  buildList(): void {
    Column() {
      if (this.selectionMode) {
        this.selectionBar()
      }

      if (this.servers.length === 0) {
        this.buildEmptyState();
      } else {
        List({ space: 8 }) {
          ForEach(this.servers, (profile: ServerProfile) => {
            ListItem() {
              this.buildServerRow(profile);
            }
            .swipeAction({ end: this.rowActions(profile), edgeEffect: SwipeEdgeEffect.Spring })
          }, (profile: ServerProfile) => `${profile.id}-${this.isSelected(profile.id)}`);
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 8 });
      }

      Row() {
        Button($r('app.string.drawer_add_server'))
          .width('100%')
          .height(44)
          .fontColor($r('app.color.text_on_accent'))
          .backgroundColor($r('app.color.fab_background'))
          .onClick(() => {
            this.startEdit(undefined);
          });
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 12 });
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 多选时列表上方的一行：已选数量与退出入口。
   *
   * 退出放在这里而不是标题栏，是因为标题栏左侧被返回按钮占着，而右侧已经
   * 是删除按钮 —— 再说「取消」本就是内容区的事。
   */
  @Builder
  selectionBar(): void {
    Row({ space: 8 }) {
      Text($r('app.string.selection_count', `${this.selectedIds.length}`))
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'));
      Blank();
      Text($r('app.string.common_cancel'))
        .fontSize(13)
        .fontColor($r('app.color.accent'))
        .onClick(() => {
          this.exitSelection();
        });
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 8, bottom: 2 });
  }

  /** 左滑露出的操作。 */
  @Builder
  rowActions(profile: ServerProfile): void {
    Row() {
      SwipeActionButton({
        icon: AppIcons.EDIT,
        label: $r('app.string.common_edit'),
        color: $r('app.color.accent'),
        onTap: () => {
          this.startEdit(profile);
        },
      });
      SwipeActionButton({
        icon: AppIcons.DELETE,
        label: $r('app.string.common_delete'),
        color: $r('app.color.danger'),
        onTap: () => {
          this.confirmDelete(profile);
        },
      });
    }
    .margin({left: -20})
    .height('100%')
    .padding({ left: 24, right: 4 })
    .backgroundColor($r('app.color.surface_alt'));
  }

  @Builder
  buildEmptyState(): void {
    Column({ space: 6 }) {
      Text($r('app.string.servers_empty'))
        .fontSize(16)
        .fontColor($r('app.color.text_primary'));
      Text($r('app.string.servers_empty_hint'))
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'));
    }
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  /**
   * 一行服务器：名称与地址，整行可点。
   *
   * 行内不再放「编辑」按钮 —— 它已经挪到左滑里了，而一行上同时存在两个
   * 编辑入口只会让人犹豫点哪个。
   */
  @Builder
  buildServerRow(profile: ServerProfile): void {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text(profile.displayName)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(profile.id === this.activeServerId && !this.selectionMode
            ? $r('app.color.accent')
            : $r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        Text(profile.endpoint)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1);
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1);
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor(this.rowBackground(profile))
    .onClick(() => {
      this.handleRowTap(profile);
    })
    .gesture(
      LongPressGesture({ repeat: false })
        .onAction(() => {
          this.handleRowLongPress(profile);
        })
    )
  }

  /**
   * 行的底色。
   *
   * 多选时高亮「已勾选」，平时高亮「当前生效」—— 同一个令牌表示两种含义
   * 会互相干扰，所以多选期间让「当前生效」那一层先让位。
   */
  private rowBackground(profile: ServerProfile): Resource {
    if (this.selectionMode) {
      return this.isSelected(profile.id) ? $r('app.color.selected_row') : $r('app.color.surface');
    }
    return profile.id === this.activeServerId ? $r('app.color.selected_row') : $r('app.color.surface');
  }

  // ---------------------------------------------------------------- editor

  @Builder
  buildEditor(): void {
    Scroll() {
      Column({ space: 14 }) {
        Column({ space: 6 }) {
          Text($r('app.string.servers_name'))
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width('100%');
          TextInput({ text: this.editName, placeholder: $r('app.string.servers_name_hint') })
            .height(44)
            .onChange((value: string) => {
              this.editName = value;
            });
        }
        .width('100%')

        Column({ space: 6 }) {
          Text($r('app.string.servers_host'))
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width('100%');
          TextInput({ text: this.editHost, placeholder: $r('app.string.servers_host_hint') })
            .height(44)
            .onChange((value: string) => {
              this.editHost = value;
            });
        }
        .width('100%')

        Column({ space: 6 }) {
          Text($r('app.string.servers_port'))
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width('100%');
          TextInput({ text: this.editPort, placeholder: $r('app.string.servers_port') })
            .type(InputType.Number)
            .height(44)
            .onChange((value: string) => {
              this.editPort = value;
            });
        }
        .width('100%')

        Column({ space: 6 }) {
          Text($r('app.string.servers_path'))
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width('100%');
          TextInput({ text: this.editPath, placeholder: $r('app.string.servers_path_hint') })
            .height(44)
            .onChange((value: string) => {
              this.editPath = value;
            });
        }
        .width('100%')

        Row({ space: 12 }) {
          Column({ space: 2 }) {
            Text($r('app.string.servers_secure'))
              .fontSize(15)
              .fontColor($r('app.color.text_primary'));
            Text($r('app.string.servers_secure_desc'))
              .fontSize(12)
              .fontColor($r('app.color.text_tertiary'));
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1);

          Toggle({ type: ToggleType.Switch, isOn: this.editSecure })
            .selectedColor($r('app.color.accent'))
            .onChange((isOn: boolean) => {
              this.editSecure = isOn;
            });
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .borderRadius(12)
        .backgroundColor($r('app.color.surface'))

        Column({ space: 6 }) {
          Text($r('app.string.servers_username'))
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width('100%');
          TextInput({ text: this.editUsername, placeholder: $r('app.string.servers_username_hint') })
            .height(44)
            .onChange((value: string) => {
              this.editUsername = value;
            });
        }
        .width('100%')

        Column({ space: 6 }) {
          Text($r('app.string.servers_password'))
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width('100%');
          TextInput({ text: this.editPassword, placeholder: $r('app.string.servers_password_hint') })
            .type(InputType.Password)
            .height(44)
            .onChange((value: string) => {
              this.editPassword = value;
            });
        }
        .width('100%')

        Button(this.testing
          ? $r('app.string.servers_testing')
          : $r('app.string.servers_test'))
          .width('100%')
          .height(44)
          .enabled(!this.testing)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.surface_alt'))
          .onClick(() => {
            this.testConnection();
          });

        Row({ space: 10 }) {
          Button($r('app.string.common_cancel'))
            .layoutWeight(1)
            .height(44)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.surface_alt'))
            .onClick(() => {
              this.cancelEdit();
            });
          Button($r('app.string.common_save'))
            .layoutWeight(1)
            .height(44)
            .fontColor($r('app.color.text_on_accent'))
            .backgroundColor($r('app.color.accent'))
            .onClick(() => {
              this.saveProfile();
            });
        }
        .width('100%');
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 24 });
    }
    .width('100%')
    .height('100%');
  }

  // --------------------------------------------------------------- actions

  /** Copies the shared server list into local state for rendering. */
  private reloadServers(): void {
    const app = AppContext.get();
    this.servers = app.servers.slice();
    this.activeServerId = app.activeServerId;
    this.pruneSelection();
  }

  // ------------------------------------------------------------- selection

  /** 某个服务器是否已勾选。 */
  private isSelected(serverId: string): boolean {
    return this.selectedIds.indexOf(serverId) >= 0;
  }

  /** 点击一行：多选时勾选，否则切换服务器并返回。 */
  private handleRowTap(profile: ServerProfile): void {
    if (this.selectionMode) {
      this.toggleSelected(profile.id);
      return;
    }
    this.chooseServer(profile);
  }

  /** 长按一行：进入多选并顺手勾上它。 */
  private handleRowLongPress(profile: ServerProfile): void {
    if (!this.selectionMode) {
      this.selectionMode = true;
    }
    if (!this.isSelected(profile.id)) {
      this.toggleSelected(profile.id);
    }
  }

  /** 加入或移出勾选集合。 */
  private toggleSelected(serverId: string): void {
    const next: string[] = [];
    let removed = false;
    for (const value of this.selectedIds) {
      if (value === serverId) {
        removed = true;
      } else {
        next.push(value);
      }
    }
    if (!removed) {
      next.push(serverId);
    }
    this.selectedIds = next;
    // 一个都不剩时自动退出多选，省掉一次「取消」。
    if (next.length === 0) {
      this.selectionMode = false;
    }
  }

  /** 退出多选并清空勾选。 */
  private exitSelection(): void {
    this.selectionMode = false;
    this.selectedIds = [];
  }

  /** 丢掉已不存在的勾选项。 */
  private pruneSelection(): void {
    if (this.selectedIds.length === 0) {
      return;
    }
    const next: string[] = [];
    for (const id of this.selectedIds) {
      for (const profile of this.servers) {
        if (profile.id === id) {
          next.push(id);
          break;
        }
      }
    }
    this.selectedIds = next;
    if (next.length === 0) {
      this.selectionMode = false;
    }
  }

  /** 删除前确认，并把要删的数量摆出来。 */
  private confirmDeleteSelected(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.servers_delete_confirm'),
      message: $r('app.string.selection_count', `${this.selectedIds.length}`),
      primaryButton: {
        value: $r('app.string.common_cancel'),
        action: () => {},
      },
      secondaryButton: {
        value: $r('app.string.common_delete'),
        action: () => {
          this.deleteSelected();
        },
      },
    });
  }

  /** 删掉所有勾选的服务器。 */
  private deleteSelected(): void {
    const ids = this.selectedIds.slice();
    this.exitSelection();
    this.removeNext(ids, 0);
  }

  /**
   * 逐个删除。
   *
   * 串行而不是 `Promise.all`：几笔删除写的是同一份偏好存储，并发写没有
   * 顺序保证，而这里慢一点完全无所谓。
   */
  private removeNext(ids: string[], index: number): void {
    if (index >= ids.length) {
      this.reloadServers();
      return;
    }
    AppContext.get()
      .removeServer(ids[index])
      .then(() => {
        this.removeNext(ids, index + 1);
      })
      .catch((error: Object) => {
        // 中途失败就停手并刷新，让列表反映真正落盘的结果。
        this.showToast(describeErrorResource(error));
        this.reloadServers();
      });
  }

  /**
   * Opens the editor.
   *
   * @param existing profile to edit, or `undefined` for a blank one
   */
  private startEdit(existing: ServerProfile | undefined): void {
    // 左滑在多选期间同样可用，所以这里显式收掉多选，避免退出编辑后还停在
    // 一个没有人记得进入过的多选状态里。
    this.exitSelection();
    if (existing === undefined) {
      this.editId = AppContext.newServerId();
      this.editName = '';
      this.editHost = '';
      this.editPort = DEFAULT_PORT;
      this.editPath = DEFAULT_RPC_PATH;
      this.editSecure = false;
      this.editUsername = '';
      this.editPassword = '';
      this.editingExisting = false;
    } else {
      this.editId = existing.id;
      this.editName = existing.name;
      this.editHost = existing.host;
      this.editPort = `${existing.port}`;
      this.editPath = existing.path;
      this.editSecure = existing.secure;
      this.editUsername = existing.username;
      this.editPassword = existing.password;
      this.editingExisting = true;
    }
    this.testing = false;
    this.editing = true;
  }

  /** Leaves the editor without touching persisted state. */
  private cancelEdit(): void {
    this.testing = false;
    this.editing = false;
  }

  /** Parses the port field, returning `-1` when it is unusable. */
  private parsePort(): number {
    const port = Number.parseInt(this.editPort.trim(), 10);
    if (Number.isNaN(port) || port < 1 || port > 65535) {
      return -1;
    }
    return port;
  }

  /** Builds a profile from the current form values. */
  private buildProfile(port: number): ServerProfile {
    const profile = new ServerProfile();
    const path = this.editPath.trim();
    profile.id = this.editId;
    profile.name = this.editName.trim();
    profile.host = this.editHost.trim();
    profile.port = port;
    profile.path = path.length > 0 ? path : DEFAULT_RPC_PATH;
    profile.secure = this.editSecure;
    profile.username = this.editUsername.trim();
    profile.password = this.editPassword;
    return profile;
  }

  /** Validates the form and persists the profile. */
  private async saveProfile(): Promise<void> {
    if (this.editHost.trim().length === 0) {
      this.showToast($r('app.string.servers_invalid_host'));
      return;
    }
    const port = this.parsePort();
    if (port < 0) {
      this.showToast($r('app.string.servers_invalid_port'));
      return;
    }

    const app = AppContext.get();
    const wasEmpty = app.servers.length === 0;
    const profile = this.buildProfile(port);
    try {
      await app.saveServer(profile);
      if (wasEmpty) {
        await app.selectServer(profile.id);
      }
    } catch (error) {
      this.showToast(describeErrorResource(error as Object));
      return;
    }

    if (this.editingExisting) {
      this.pathStack.pop();
      return;
    }
    this.editing = false;
    this.reloadServers();
  }

  /** Activates a saved profile and returns to the previous screen. */
  private async chooseServer(profile: ServerProfile): Promise<void> {
    try {
      await AppContext.get().selectServer(profile.id);
    } catch (error) {
      this.showToast(describeErrorResource(error as Object));
    }
    this.pathStack.pop();
  }

  /** 删除前确认。 */
  private confirmDelete(profile: ServerProfile): void {
    this.exitSelection();
    this.getUIContext().showAlertDialog({
      title: $r('app.string.servers_delete_confirm'),
      message: profile.displayName,
      primaryButton: {
        value: $r('app.string.common_cancel'),
        action: () => {},
      },
      secondaryButton: {
        value: $r('app.string.common_delete'),
        action: () => {
          this.deleteServer(profile);
        },
      },
    });
  }

  /** Removes a profile and refreshes the list. */
  private deleteServer(profile: ServerProfile): void {
    AppContext.get().removeServer(profile.id)
      .then(() => {
        this.reloadServers();
      })
      .catch((error: Object) => {
        this.showToast(describeErrorResource(error));
      });
  }

  /**
   * Tries the unsaved form against the server with a throwaway client.
   *
   * The shared client and the persisted state are deliberately untouched: a
   * failed experiment must not disconnect a working session.
   */
  private async testConnection(): Promise<void> {
    if (this.editHost.trim().length === 0) {
      this.showToast($r('app.string.servers_invalid_host'));
      return;
    }
    const port = this.parsePort();
    if (port < 0) {
      this.showToast($r('app.string.servers_invalid_port'));
      return;
    }

    const profile = this.buildProfile(port);
    this.testing = true;
    const builder = new TransmissionClientBuilder().url(profile.url).timeout(8000);
    if (profile.username.length > 0) {
      builder.credentials(profile.username, profile.password);
    }
    const client = builder.build();
    try {
      await client.connect();
      this.showToast($r('app.string.servers_test_ok'));
    } catch (error) {
      this.showToast(describeErrorResource(error as Object));
    } finally {
      client.close();
      this.testing = false;
    }
  }

  /** Shows a short toast through the component-scoped prompt action. */
  private showToast(message: Resource): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: TOAST_DURATION });
  }
}
