// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * 添加种子：从链接添加，或从本地 `.torrent` 文件添加。
 *
 * 选到文件后会在本地解析出种子内的文件列表，按目录树展示并允许逐项勾选，
 * 未勾选的文件通过在添加请求里带上 `files_wanted` / `files_unwanted` 的下标
 * 直接跳过 —— 这样服务端从始至终只见过一次添加请求，不会先加进来再改。
 *
 * 入口是列表页的浮动按钮（它决定初始方式），以及溢出菜单（固定从链接开始）。
 *
 * @since 1.0.0
 */

import { common } from '@kit.AbilityKit';
import { Metainfo, TorrentAddResult, TransmissionClient } from 'transmission_sdk';
import { AddMethod } from '../model/NavParams';
import { AppContext, describeErrorResource } from '../store/AppContext';
import { AddTorrentHelper, PickedTorrent } from '../viewmodel/AddTorrentHelper';
import { FileTree, TorrentFileNode, TorrentFileRow } from '../viewmodel/FileTree';
import { formatBytes } from '../viewmodel/Formatters';
import { AppIcons } from '../theme/AppIcons';

/** 目录树行的折叠箭头槽位宽度；文件行留同样宽的空档以对齐图标。 */
const TREE_GUTTER: number = 16;
/** 箭头槽位、图标与名称之间的间隔。 */
const TREE_GAP: number = 6;
/** 类型图标的尺寸。 */
const TREE_ICON: number = 18;
/** 每一层嵌套的缩进。 */
const TREE_INDENT: number = 14;

@Component
export struct AddTorrentPage {
  /** 导航栈，用于成功后关闭本页。 */
  pathStack: NavPathStack = new NavPathStack();

  /** 调用方希望初始选中的输入方式，由目标页构造器设置。 */
  initialMethod: AddMethod = AddMethod.LINK;

  @State method: AddMethod = AddMethod.LINK;
  @State link: string = '';
  @State downloadDir: string = '';
  @State paused: boolean = false;
  @State pickedName: string = '';
  @State busy: boolean = false;

  /**
   * 解析出的目录树，已深度优先扁平化成一行一个节点。
   *
   * ArkUI 的 `@Builder` 不能递归，所以树从不直接渲染：`FileTree.flatten`
   * 把它摊平成单个 `ForEach` 能走的列表，缩进靠每个节点自带的 `depth`。
   */
  @State fileNodes: TorrentFileNode[] = [];

  /** 勾选状态的事实来源，顺序与种子内 `files` 一致。 */
  @State fileRows: TorrentFileRow[] = [];

  /** 已折叠的目录路径。 */
  @State collapsedFolders: string[] = [];

  /** 已勾选的文件数与字节数，用于头部摘要。 */
  @State wantedCount: number = 0;
  @State wantedSize: number = 0;

  /** 选中的 `.torrent` 原始字节，提交时原样上传。 */
  private pickedBytes: Uint8Array | undefined = undefined;

  /** {@link fileNodes} 所摊平的那棵树；不参与渲染，故不是 `@State`。 */
  private fileTree: TorrentFileNode[] = [];

  aboutToAppear(): void {
    this.method = this.initialMethod;
    this.loadServerDirectory();
    if (this.method === AddMethod.FILE) {
      // 浮动按钮的「文件」入口意味着用户已经选好了方式，直接拉起选择器，
      // 不必再问一遍。
      this.chooseFile();
    }
  }

  build(): void {
    NavDestination() {
      Column({ space: 12 }) {
        this.methodSelector();

        if (this.method === AddMethod.LINK) {
          this.linkField();
        } else {
          this.fileField();
        }

        // 目录树占据中间的全部剩余高度并自行滚动，其余控件固定在上下两端。
        if (this.method === AddMethod.FILE && this.fileNodes.length > 0) {
          this.filesSection();
        }

        Column({ space: 12 }) {
          this.directoryField();
          this.pausedSwitch();
          this.submitButton();
        }
        .width('100%');
      }
      .width('100%')
      .height('100%')
      .padding(16);
    }
    .title($r('app.string.page_title_add'))
    .backgroundColor($r('app.color.app_background'))
  }

  /** 在链接与文件两种输入之间切换的分段控件。 */
  @Builder
  methodSelector(): void {
    Row() {
      this.methodTab(AddMethod.LINK, $r('app.string.add_method_link'));
      this.methodTab(AddMethod.FILE, $r('app.string.add_method_file'));
    }
    .width('100%')
    .padding(3)
    .borderRadius(8)
    .backgroundColor($r('app.color.surface_alt'));
  }

  /** {@link methodSelector} 的一段。 */
  @Builder
  methodTab(value: AddMethod, label: Resource): void {
    Text(label)
      .fontSize(15)
      .fontColor(this.method === value ? $r('app.color.text_on_accent') : $r('app.color.text_secondary'))
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(34)
      .borderRadius(6)
      .backgroundColor(this.method === value ? $r('app.color.accent') : Color.Transparent)
      .onClick(() => {
        this.method = value;
      });
  }

  /** 磁力链接或 URL 输入框。 */
  @Builder
  linkField(): void {
    TextInput({ text: this.link, placeholder: $r('app.string.add_link_hint') })
      .type(InputType.Normal)
      .enterKeyType(EnterKeyType.Done)
      .backgroundColor($r('app.color.surface'))
      .fontColor($r('app.color.text_primary'))
      .placeholderColor($r('app.color.text_tertiary'))
      .height(48)
      .width('100%')
      .onChange((value: string) => {
        this.link = value;
      });
  }

  /** 文件选择入口；选中后这里同时显示文件名与文件数。 */
  @Builder
  fileField(): void {
    Row({ space: 12 }) {
      SymbolGlyph(AppIcons.FILE)
        .fontSize(22)
        .fontColor([$r('app.color.icon')]);
      Column({ space: 2 }) {
        Text(this.pickedName.length > 0 ? this.pickedName : $r('app.string.add_pick_file'))
          .fontSize(15)
          .fontColor(this.pickedName.length > 0 ? $r('app.color.text_primary') : $r('app.color.accent'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        if (this.pickedName.length === 0) {
          Text($r('app.string.add_no_file'))
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'));
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1);
    }
    .width('100%')
    .padding(14)
    .borderRadius(8)
    .backgroundColor($r('app.color.surface'))
    .onClick(() => {
      this.chooseFile();
    });
  }

  /**
   * 种子内的文件树。
   *
   * 勾选状态就是「要不要下载这个文件」，所以复选框上直接对应服务端的
   * `files_wanted` / `files_unwanted`，没有第三态。
   */
  @Builder
  filesSection(): void {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Text($r('app.string.add_files_title'))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'));
        Blank();
        Text($r('app.string.add_files_selected', `${this.wantedCount}`, `${this.fileRows.length}`, formatBytes(this.wantedSize)))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'));
      }
      .width('100%');

      List({ space: 1 }) {
        ForEach(
          this.fileNodes,
          (node: TorrentFileNode) => {
            ListItem() {
              this.fileNodeRow(node)
            }
          },
          // 键里带上勾选与折叠状态：`ForEach` 只在键变化时重画该项，否则勾选
          // 一个目录后，它的复选框会停在旧状态上。
          (node: TorrentFileNode) => `${node.path}-${node.wanted}-${this.isCollapsed(node.path)}`,
        )
      }
      .width('100%')
      .layoutWeight(1)
      .borderRadius(8)
      .clip(true)
      .backgroundColor($r('app.color.surface'))
      .scrollBar(BarState.Off);
    }
    .width('100%')
    .layoutWeight(1);
  }

  /** 目录树的一行：复选框、折叠箭头、类型图标、名称与大小。 */
  @Builder
  fileNodeRow(node: TorrentFileNode): void {
    Row({ space: TREE_GAP }) {
      Checkbox()
        .select(node.allWanted)
        .selectedColor($r('app.color.accent'))
        .onChange((checked: boolean) => {
          this.setSubtreeWanted(node, checked);
        });

      if (node.collapsible) {
        SymbolGlyph(this.isCollapsed(node.path) ? AppIcons.CHEVRON_RIGHT : AppIcons.CHEVRON_DOWN)
          .fontSize(14)
          .fontColor([$r('app.color.icon')])
          .width(TREE_GUTTER);
      }

      SymbolGlyph(node.isFolder ? AppIcons.FOLDER : AppIcons.forFileKind(node.kind))
        .fontSize(TREE_ICON)
        .fontColor([$r('app.color.icon')])
        // 文件没有折叠箭头，用它占位；间距里再加上箭头后面本应有的间隔，
        // 两种行的图标才会落在同一条竖线上。
        .margin({ left: node.collapsible ? 0 : TREE_GUTTER + TREE_GAP });

      Column({ space: 2 }) {
        Text(node.name)
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%');
        Text(formatBytes(node.length))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .width('100%');
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1);
    }
    .width('100%')
    .padding({ left: 8 + node.depth * TREE_INDENT, right: 10, top: 8, bottom: 8 })
    .onClick(() => {
      if (node.collapsible) {
        this.toggleFolder(node.path);
      }
    });
  }

  /**
   * 目标目录。
   *
   * 进入页面时会回显服务端的默认目录，所以留空只在查询失败时才是常态 ——
   * 用户看到的是实际生效的路径，而不是一个需要凭记忆填写的空框。
   */
  @Builder
  directoryField(): void {
    Column({ space: 6 }) {
      Text($r('app.string.add_download_dir'))
        .fontSize(13)
        .fontColor($r('app.color.text_tertiary'))
        .width('100%');
      TextInput({ text: this.downloadDir, placeholder: $r('app.string.add_download_dir_hint') })
        .backgroundColor($r('app.color.surface'))
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_tertiary'))
        .height(48)
        .width('100%')
        .onChange((value: string) => {
          this.downloadDir = value;
        });
    }
    .width('100%');
  }

  /** 「添加后暂停」开关。 */
  @Builder
  pausedSwitch(): void {
    Row() {
      Text($r('app.string.add_start_paused'))
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1);
      Toggle({ type: ToggleType.Switch, isOn: this.paused })
        .selectedColor($r('app.color.accent'))
        .onChange((isOn: boolean) => {
          this.paused = isOn;
        });
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 6, bottom: 6 })
    .borderRadius(8)
    .backgroundColor($r('app.color.surface'));
  }

  /** 提交按钮，请求进行中时禁用。 */
  @Builder
  submitButton(): void {
    Button($r('app.string.add_submit'))
      .width('100%')
      .height(46)
      .enabled(!this.busy && this.client() !== undefined)
      .backgroundColor($r('app.color.accent'))
      .fontColor($r('app.color.text_on_accent'))
      .onClick(() => {
        this.submit();
      });
  }

  // ------------------------------------------------------------- behaviour

  /**
   * 回显服务端的默认下载目录。
   *
   * 只在进入页面时取一次：之后输入框归用户所有，反复刷新会覆盖他正在敲的
   * 路径。取不到就留空，输入框的占位提示已经说明了留空的含义。
   */
  private loadServerDirectory(): void {
    const client = this.client();
    if (client === undefined) {
      return;
    }
    AddTorrentHelper.defaultDownloadDir(client)
      .then((dir: string | undefined) => {
        if (dir !== undefined && this.downloadDir.length === 0) {
          this.downloadDir = dir;
        }
      })
      .catch((error: Object) => {
        // `defaultDownloadDir` 内部已经吞掉了失败，这里只是兜底。
        console.warn('Transmission: could not read the default download directory');
      });
  }

  /** 拉起系统文件选择器，并在选中后立即解析。 */
  private chooseFile(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    AddTorrentHelper.pickTorrentFile(context)
      .then((picked: PickedTorrent | undefined) => {
        if (picked === undefined) {
          return;
        }
        this.pickedName = picked.name;
        this.pickedBytes = picked.bytes;
        this.readMetainfo(picked.bytes);
      })
      .catch((error: Object) => {
        this.toastResource(describeErrorResource(error));
      });
  }

  /**
   * 把选中的种子解析成可勾选的文件树。
   *
   * 解析失败不是异常路径：用户完全可能选到一个不是 `.torrent` 的文件。此时
   * 清空文件树并提示一句，他仍可以改用链接方式，或重新选择。
   */
  private readMetainfo(bytes: Uint8Array): void {
    const metainfo = Metainfo.parse(bytes);
    if (metainfo === undefined) {
      this.clearMetainfo();
      this.toastResource($r('app.string.add_files_invalid'));
      return;
    }
    const rows: TorrentFileRow[] = [];
    for (let index = 0; index < metainfo.files.length; index++) {
      const file = metainfo.files[index];
      const row = new TorrentFileRow();
      // `index` 就是文件在 `files` 里的位置，也正是请求里要用的下标。
      row.index = index;
      row.name = file.name;
      row.length = file.length;
      row.bytesCompleted = 0;
      row.wanted = true;
      rows.push(row);
    }
    this.collapsedFolders = [];
    this.setRows(rows);
  }

  /** 换掉勾选状态，重建目录树并重算摘要。 */
  private setRows(rows: TorrentFileRow[]): void {
    this.fileRows = rows;
    this.fileTree = FileTree.build(rows);
    this.fileNodes = FileTree.flatten(this.fileTree, this.collapsedFolders);
    let count = 0;
    let size = 0;
    for (const row of rows) {
      if (row.wanted) {
        count++;
        size += row.length;
      }
    }
    this.wantedCount = count;
    this.wantedSize = size;
  }

  /** 丢弃已解析的种子文件树。 */
  private clearMetainfo(): void {
    this.fileRows = [];
    this.fileTree = [];
    this.fileNodes = [];
    this.collapsedFolders = [];
    this.wantedCount = 0;
    this.wantedSize = 0;
  }

  /** 某个目录是否已折叠。 */
  private isCollapsed(path: string): boolean {
    return this.collapsedFolders.indexOf(path) >= 0;
  }

  /** 展开或折叠一个目录。 */
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
    this.fileNodes = FileTree.flatten(this.fileTree, this.collapsedFolders);
  }

  /**
   * 勾选或取消一个文件、或一个目录下的全部文件。
   *
   * 目录那一支是重点：勾一个文件夹要落到底下每一个文件，无论嵌套多深，而
   * 请求是按文件在 `files` 里的下标说话的 —— 这正是
   * {@link FileTree.leafIndices} 返回的东西。
   */
  private setSubtreeWanted(node: TorrentFileNode, wanted: boolean): void {
    const targets = new Set<number>();
    for (const index of FileTree.leafIndices(node)) {
      targets.add(index);
    }
    const next: TorrentFileRow[] = [];
    for (const row of this.fileRows) {
      const copy = row.copy();
      if (targets.has(row.index)) {
        copy.wanted = wanted;
      }
      next.push(copy);
    }
    this.setRows(next);
  }

  /** 未勾选的文件下标；全部勾选时为空。 */
  private unwantedIndices(): number[] {
    const out: number[] = [];
    for (const row of this.fileRows) {
      if (!row.wanted) {
        out.push(row.index);
      }
    }
    return out;
  }

  /** 发出添加请求，成功后关闭本页。 */
  private submit(): void {
    const client = this.client();
    if (client === undefined) {
      this.toastResource($r('app.string.status_not_connected'));
      return;
    }

    const isLink = this.method === AddMethod.LINK;
    const bytes = this.pickedBytes;
    if (isLink && this.link.length === 0) {
      this.toastResource($r('app.string.add_need_input'));
      return;
    }
    if (!isLink && bytes === undefined) {
      this.toastResource($r('app.string.add_need_input'));
      return;
    }
    // 一个文件都不勾等于什么都不下载，Transmission 会直接拒绝这种请求，不如
    // 在本地就说清楚。
    if (!isLink && this.fileRows.length > 0 && this.wantedCount === 0) {
      this.toastResource($r('app.string.add_files_none'));
      return;
    }

    this.busy = true;
    const request: Promise<TorrentAddResult> = isLink
      ? AddTorrentHelper.addFromLink(client, this.link, this.downloadDir, this.paused)
      : AddTorrentHelper.addFromBytes(
        client,
        bytes as Uint8Array,
        this.downloadDir,
        this.paused,
        this.unwantedIndices(),
      );

    request
      .then((result: TorrentAddResult) => {
        this.toastResource(
          result.wasDuplicate ? $r('app.string.add_result_duplicate') : $r('app.string.add_result_added'),
        );
        this.pathStack.pop();
      })
      .catch((error: Object) => {
        this.toastResource(describeErrorResource(error));
      })
      .finally(() => {
        this.busy = false;
      });
  }

  /** 当前生效的客户端，未连接时为 `undefined`。 */
  private client(): TransmissionClient | undefined {
    return AppContext.get().activeClient;
  }

  /** 用字符串资源弹一条短提示。 */
  private toastResource(message: Resource): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
  }
}
