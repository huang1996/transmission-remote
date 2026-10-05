// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * The Files tab: one editable row per file, grouped into a folder tree.
 *
 * Why this lives apart from `TorrentDetailModel`
 * ----------------------------------------------
 * Everything here is pure: it reads a `Torrent` and returns plain objects, with
 * no `AppContext`, no RPC and no ArkUI. That is deliberate — it lets
 * `scripts/run-tests.mjs` type-check and unit-test this file on Node, which the
 * detail model cannot be, because the detail model imports the store (and with
 * it the preferences API) at the top.
 *
 * Rows versus nodes
 * -----------------
 * `TorrentFileRow` stays flat and in wire order, because `torrent_set` addresses
 * files by their index in `Torrent.files` and nothing here may perturb that.
 * `TorrentFileNode` is the tree built *over* those rows for display: the same
 * three fields plus the aggregates a folder needs. Only the row list is the
 * source of truth; the tree is rebuilt from it after every edit.
 *
 * ArkUI cannot recurse through a `@Builder`, so the tree is never rendered
 * directly — {@link FileTree.flatten} turns it into a depth-first list that a
 * single `ForEach` can walk, with `depth` carried on each node for indentation.
 *
 * @since 1.0.0
 */

import { FilePriority, Torrent, TorrentFile, TorrentFileStat } from 'transmission_sdk';

/**
 * The broad category of a file, derived from its extension.
 *
 * Only the Files tab consumes this, to pick the icon on the row. A folder is
 * deliberately *not* a member: {@link TorrentFileNode.isFolder} already says
 * whether a node is one, and the row template branches on that first, so a
 * `FOLDER` case here could never be reached.
 */
export enum FileKind {
  /** Video: `.mkv`, `.mp4`, … */
  VIDEO = 'video',
  /** Audio: `.flac`, `.mp3`, … */
  AUDIO = 'audio',
  /** An image or photo. */
  IMAGE = 'image',
  /** A document: text, office, e-book. */
  DOCUMENT = 'document',
  /** A compressed archive. */
  ARCHIVE = 'archive',
  /** A subtitle track. */
  SUBTITLE = 'subtitle',
  /** A disc image: `.iso`, `.mdf`, … */
  DISC = 'disc',
  /** Anything unrecognised, including a name with no extension at all. */
  OTHER = 'other',
}

/**
 * Maps a file name to a {@link FileKind} by its extension.
 *
 * The table is a closed list rather than a set of prefix guesses: an extension
 * nobody listed is `OTHER`, because a neutral icon is better than a confident
 * wrong one. A single pass builds the lookup once, so the per-file cost is one
 * `lastIndexOf` and one hash lookup even for a torrent with thousands of files.
 */
export class FileKinds {
  /**
   * Extensions, without their dot, in lower case.
   *
   * Grouped here rather than inline in the map so the list stays readable, and
   * in the order the enum declares its cases.
   */
  private static readonly VIDEO: string[] = [
    'mkv', 'mp4', 'm4v', 'avi', 'mov', 'wmv', 'flv', 'webm', 'mpg', 'mpeg',
    'm2ts', 'mts', 'ts', 'vob', 'rm', 'rmvb', '3gp', 'ogm', 'ogv', 'divx', 'xvid', 'asf', 'f4v',
  ];
  private static readonly AUDIO: string[] = [
    'mp3', 'flac', 'aac', 'm4a', 'm4b', 'ogg', 'oga', 'opus', 'wav', 'wma',
    'ape', 'alac', 'aiff', 'aif', 'mka', 'mid', 'midi', 'dsf', 'dff',
  ];
  private static readonly IMAGE: string[] = [
    'jpg', 'jpeg', 'jpe', 'png', 'gif', 'bmp', 'webp', 'tif', 'tiff', 'svg',
    'heic', 'heif', 'avif', 'raw', 'cr2', 'cr3', 'nef', 'arw', 'dng', 'ico', 'psd', 'xcf',
  ];
  private static readonly DOCUMENT: string[] = [
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'odt', 'ods', 'odp',
    'rtf', 'txt', 'text', 'md', 'csv', 'tsv', 'epub', 'mobi', 'azw', 'azw3',
    'fb2', 'djvu', 'chm', 'pages', 'numbers', 'key',
  ];
  private static readonly ARCHIVE: string[] = [
    'zip', 'rar', '7z', 'tar', 'gz', 'tgz', 'bz2', 'tbz2', 'xz', 'txz',
    'zst', 'lz', 'lzma', 'lz4', 'cab', 'arj', 'ace', 'z',
  ];
  private static readonly SUBTITLE: string[] = ['srt', 'ass', 'ssa', 'sub', 'vtt', 'idx', 'sup', 'smi'];
  private static readonly DISC: string[] = ['iso', 'mdf', 'nrg', 'cue', 'toast', 'dmg'];

  /** Extension → kind, built once from the lists above. */
  private static readonly BY_EXTENSION: Map<string, FileKind> = FileKinds.build();

  /**
   * The kind of a file name.
   *
   * Only the last path segment is examined, so a dot inside a directory name
   * (`Season 1/Ep.01/`) cannot be mistaken for an extension. A leading dot marks
   * a hidden file rather than an extension, which is why the dot has to be past
   * position zero.
   *
   * @param name file name, optionally with a directory prefix
   */
  static of(name: string): FileKind {
    const slash: number = name.lastIndexOf('/');
    const base: string = slash < 0 ? name : name.substring(slash + 1);
    const dot: number = base.lastIndexOf('.');
    if (dot <= 0 || dot === base.length - 1) {
      return FileKind.OTHER;
    }
    const found: FileKind | undefined = FileKinds.BY_EXTENSION.get(base.substring(dot + 1).toLowerCase());
    return found === undefined ? FileKind.OTHER : found;
  }

  private static build(): Map<string, FileKind> {
    const map = new Map<string, FileKind>();
    FileKinds.addAll(map, FileKinds.VIDEO, FileKind.VIDEO);
    FileKinds.addAll(map, FileKinds.AUDIO, FileKind.AUDIO);
    FileKinds.addAll(map, FileKinds.IMAGE, FileKind.IMAGE);
    FileKinds.addAll(map, FileKinds.DOCUMENT, FileKind.DOCUMENT);
    FileKinds.addAll(map, FileKinds.ARCHIVE, FileKind.ARCHIVE);
    FileKinds.addAll(map, FileKinds.SUBTITLE, FileKind.SUBTITLE);
    FileKinds.addAll(map, FileKinds.DISC, FileKind.DISC);
    return map;
  }

  /** Inserts one list, leaving an extension that is already claimed alone. */
  private static addAll(map: Map<string, FileKind>, extensions: string[], kind: FileKind): void {
    for (const extension of extensions) {
      if (!map.has(extension)) {
        map.set(extension, kind);
      }
    }
  }

  private constructor() {
    // Static-only holder.
  }
}

/** One editable row of the Files tab, in wire order. */
export class TorrentFileRow {
  /** Index into `Torrent.files`; exactly the value `torrent_set` expects. */
  index: number = 0;
  /** File name, relative to the torrent's download directory. */
  name: string = '';
  /** File length in bytes. */
  length: number = 0;
  /** Bytes of this file that are already present. */
  bytesCompleted: number = 0;
  /** True when the file is scheduled for download. */
  wanted: boolean = true;
  /**
   * Effective priority. {@link FilePriority.LOW} is Transmission's encoding of
   * "do not download", so it always travels together with `wanted === false`.
   */
  priority: FilePriority = FilePriority.NORMAL;

  /**
   * Completion of this file as a `0..100` value for `Progress`.
   *
   * Guarded against a zero length because a zero-byte file in a torrent is
   * legal and would otherwise produce `NaN`.
   */
  get progressPercent(): number {
    if (this.length <= 0) {
      return 0;
    }
    return Math.min(100, (this.bytesCompleted / this.length) * 100);
  }

  /**
   * 这个文件的字节是否已经全部到手。
   *
   * 用 `>=` 而不是 `===`：服务端偶尔会在收尾时把 `bytesCompleted` 报成比
   * `length` 略大一点。零字节文件（长度和已完成都是 0）算已完成，这与
   * Transmission 自己的判断一致。
   *
   * 判定放在模型上而不是页面里：{@link FileTree.build} 的聚合和页面的级联
   * 勾选都要用它，两处各写一遍迟早会漂移。
   */
  get isComplete(): boolean {
    return this.bytesCompleted >= this.length;
  }

  /**
   * A detached copy.
   *
   * ArkUI only re-renders a `@State` array when the array itself is replaced,
   * and only redraws a `ForEach` item when its key changes, so a row edit
   * produces a copied array rather than an in-place mutation.
   */
  copy(): TorrentFileRow {
    const other = new TorrentFileRow();
    other.index = this.index;
    other.name = this.name;
    other.length = this.length;
    other.bytesCompleted = this.bytesCompleted;
    other.wanted = this.wanted;
    other.priority = this.priority;
    return other;
  }
}

/**
 * One node of the Files tab tree: a folder, or a leaf file.
 *
 * A folder carries the same size and completion fields as a file, summed over
 * its subtree, so one row template can render both.
 */
export class TorrentFileNode {
  /** True for an intermediate folder, false for a leaf file. */
  isFolder: boolean = false;
  /** Display name — the last path segment. */
  name: string = '';
  /**
   * Full path from the torrent root, e.g. `Season 1/Episode 1.mkv`.
   *
   * Doubles as the node's identity: it is the `ForEach` key and the entry in the
   * collapsed-folder set.
   */
  path: string = '';
  /** Index into `Torrent.files`; `-1` for a folder. */
  index: number = -1;
  /** Nesting level. Assigned by {@link FileTree.flatten}, not by `build`. */
  depth: number = 0;
  /** Size of this file, or the total over a folder's subtree. */
  length: number = 0;
  /** Bytes already present, over the same scope as `length`. */
  bytesCompleted: number = 0;
  /** Files in this subtree: `1` for a file. */
  fileCount: number = 0;
  /** Files in this subtree that are wanted. */
  wantedCount: number = 0;
  /** 这个子树里**尚未**下载完成的文件数。 */
  pendingCount: number = 0;
  /** 其中被勾选（需要下载）的文件数。 */
  pendingWantedCount: number = 0;
  /** True when this file is scheduled for download. Always true for a folder. */
  wanted: boolean = true;
  /** Priority of this file. A folder carries the lowest of its children. */
  priority: FilePriority = FilePriority.NORMAL;
  /**
   * Category of this file, from its extension.
   *
   * Stored rather than recomputed by the row template: the row is rebuilt on
   * every selection change, and classifying once per file per rebuild is
   * cheaper than doing it on every render. Left at `OTHER` on a folder, which
   * never reads it.
   */
  kind: FileKind = FileKind.OTHER;
  /** Children in display order. Empty for a file. */
  children: TorrentFileNode[] = [];

  /** Completion of this node as a `0..100` value for `Progress`. */
  get progressPercent(): number {
    if (this.length <= 0) {
      return 0;
    }
    return Math.min(100, (this.bytesCompleted / this.length) * 100);
  }

  /**
   * True when every file below is wanted.
   *
   * False for a folder whose subtree is empty, so an empty root never claims to
   * be complete.
   */
  get allWanted(): boolean {
    return this.fileCount > 0 && this.wantedCount === this.fileCount;
  }

  /** True when no file below is wanted. */
  get noneWanted(): boolean {
    return this.wantedCount === 0;
  }

  /**
   * 这个子树的内容是否已经全部下载完成。
   *
   * 用「待下载数为 0」而不是「bytesCompleted >= length」来判断：文件夹的
   * 聚合长度是所有子文件长度之和，只要有一个文件没下完两者就不相等，两种写法
   * 等价；但待下载数在叶子节点上与 {@link TorrentFileRow.isComplete} 同一个
   * 口径，子树和自己不会出现两套判断。
   */
  get isComplete(): boolean {
    return this.fileCount > 0 && this.pendingCount === 0;
  }

  /**
   * 复选框是否可动。
   *
   * 下载完成的节点锁住：它的字节已经在磁盘上，再勾一次或取消一次都不会改变
   * 任何东西，一个点了没反应的控件比一个明确不可点的控件更让人困惑。
   */
  get checkable(): boolean {
    return this.pendingCount > 0;
  }

  /**
   * 复选框是否打勾。
   *
   * 看的是**未下载完成**的那部分文件，而不是整个子树 —— 一个「两个已完成、
   * 一个待下载」的文件夹，勾选状态该由那一个待下载的文件决定，否则「取消勾选
   * 这个文件夹」会立刻让复选框变成未选中，看起来像把已完成的文件也取消了。
   */
  get allPendingWanted(): boolean {
    return this.pendingCount > 0 && this.pendingWantedCount === this.pendingCount;
  }

  /**
   * True when this node renders a fixed-width chevron gutter.
   *
   * Files get one too, so their names line up with their siblings'.
   */
  get collapsible(): boolean {
    return this.isFolder && this.children.length > 0;
  }
}

/** Builds, sorts and flattens the Files tab tree. */
export class FileTree {
  /**
   * Turns a torrent's `files` and `file_stats` arrays into flat rows.
   *
   * `file_stats` is normally the same length as `files`, but a server that does
   * not implement it (or a partially applied response) must not shift the rows:
   * a missing entry means "wanted, normal priority", which is the default the
   * row already carries.
   *
   * @param torrent the loaded torrent
   */
  static buildRows(torrent: Torrent): TorrentFileRow[] {
    const rows: TorrentFileRow[] = [];
    for (let index = 0; index < torrent.files.length; index++) {
      const file: TorrentFile = torrent.files[index];
      const row = new TorrentFileRow();
      row.index = index;
      row.name = file.name;
      row.length = file.length;
      row.bytesCompleted = file.bytesCompleted;
      if (index < torrent.fileStats.length) {
        const stat: TorrentFileStat = torrent.fileStats[index];
        row.wanted = stat.wanted;
        row.priority = stat.priority;
      } else {
        row.wanted = true;
        row.priority = FilePriority.NORMAL;
      }
      rows.push(row);
    }
    return rows;
  }

  /**
   * Groups flat rows into a folder tree by splitting each name on `/`.
   *
   * Aggregates are accumulated on every node the path passes through, so a
   * folder's size, completion and wanted count always describe its whole
   * subtree. Siblings are ordered folders-first, then by name.
   *
   * @param rows rows in wire order
   */
  static build(rows: TorrentFileRow[]): TorrentFileNode[] {
    const roots: TorrentFileNode[] = [];
    for (const row of rows) {
      const segments: string[] = row.name.split('/');
      let level: TorrentFileNode[] = roots;
      let prefix: string = '';
      for (let i = 0; i < segments.length; i++) {
        const segment: string = segments[i];
        if (segment.length === 0) {
          continue;
        }
        prefix = prefix.length === 0 ? segment : `${prefix}/${segment}`;
        const isLeaf: boolean = i === segments.length - 1;

        let node: TorrentFileNode | undefined = FileTree.find(level, segment);
        if (node === undefined) {
          node = new TorrentFileNode();
          node.name = segment;
          node.path = prefix;
          node.isFolder = !isLeaf;
          level.push(node);
        }

        node.length += row.length;
        node.bytesCompleted += row.bytesCompleted;
        node.fileCount += 1;
        if (row.wanted) {
          node.wantedCount += 1;
        }
        // 待下载数按整条路径累加，所以一个文件夹的计数天然覆盖整棵子树。
        if (!row.isComplete) {
          node.pendingCount += 1;
          if (row.wanted) {
            node.pendingWantedCount += 1;
          }
        }
        if (node.isFolder && row.priority > node.priority) {
          // Transmission puts normal above low, so the highest child priority is
          // what a folder should report when it shows one at all.
          node.priority = row.priority;
        }

        if (isLeaf) {
          node.index = row.index;
          node.wanted = row.wanted;
          node.priority = row.priority;
          node.kind = FileKinds.of(segment);
        } else {
          level = node.children;
        }
      }
    }
    FileTree.sortLevel(roots);
    return roots;
  }

  /**
   * Depth-first display list, skipping the children of collapsed folders.
   *
   * @param roots tree roots from {@link FileTree.build}
   * @param collapsed paths of the folders whose children are hidden
   */
  static flatten(roots: TorrentFileNode[], collapsed: string[]): TorrentFileNode[] {
    const out: TorrentFileNode[] = [];
    FileTree.append(roots, collapsed, 0, out);
    return out;
  }

  /**
   * Wire indices of every file at or below a node, in ascending order.
   *
   * This is what a folder's checkbox needs: checking it has to mark the whole
   * subtree, and the request that reaches the server addresses files by their
   * position in `Torrent.files`, not by path. A leaf returns its own index, so
   * the same call works for a file row.
   *
   * A folder with no files below it returns an empty list; the row template
   * never shows a checkbox for one, but returning an empty array rather than
   * throwing keeps the call site free of a special case.
   *
   * @param node node from {@link FileTree.build}
   */
  static leafIndices(node: TorrentFileNode): number[] {
    const out: number[] = [];
    FileTree.collectLeaves(node, out);
    return out;
  }

  /** One sibling with this name, or `undefined`. */
  private static find(level: TorrentFileNode[], name: string): TorrentFileNode | undefined {
    for (const node of level) {
      if (node.name === name) {
        return node;
      }
    }
    return undefined;
  }

  /** Orders one level folders-first, then by name, and recurses. */
  private static sortLevel(nodes: TorrentFileNode[]): void {
    nodes.sort((a: TorrentFileNode, b: TorrentFileNode): number => {
      if (a.isFolder !== b.isFolder) {
        return a.isFolder ? -1 : 1;
      }
      if (a.name === b.name) {
        return 0;
      }
      return a.name < b.name ? -1 : 1;
    });
    for (const node of nodes) {
      if (node.children.length > 0) {
        FileTree.sortLevel(node.children);
      }
    }
  }

  private static append(nodes: TorrentFileNode[], collapsed: string[], depth: number, out: TorrentFileNode[]): void {
    for (const node of nodes) {
      node.depth = depth;
      out.push(node);
      const hidden: boolean = node.isFolder && collapsed.indexOf(node.path) >= 0;
      if (node.children.length > 0 && !hidden) {
        FileTree.append(node.children, collapsed, depth + 1, out);
      }
    }
  }

  private static collectLeaves(node: TorrentFileNode, out: number[]): void {
    if (!node.isFolder) {
      out.push(node.index);
      return;
    }
    for (const child of node.children) {
      FileTree.collectLeaves(child, out);
    }
  }
}
