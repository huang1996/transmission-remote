// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for the Files tab's row shaping and folder tree.
 *
 * The tree is pure logic with three easy ways to be quietly wrong: the
 * aggregates (a folder must sum its whole subtree, not just its direct
 * children), the ordering (folders first, then by name), and the flattening
 * (a collapsed folder must hide its descendants, not merely its children). All
 * three are covered here rather than only on a device.
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { FilePriority, JsonArray, JsonObject, Torrent } from 'transmission_sdk';
import { FileKind, FileKinds, FileTree, TorrentFileNode } from '../../main/ets/viewmodel/FileTree';

/** One `files` entry. */
function file(name: string, length: number, completed: number): JsonObject {
  const json: JsonObject = {};
  json['name'] = name;
  json['length'] = length;
  json['bytes_completed'] = completed;
  return json;
}

/** One `file_stats` entry. */
function stat(wanted: boolean, priority: FilePriority, completed: number): JsonObject {
  const json: JsonObject = {};
  json['wanted'] = wanted;
  json['priority'] = priority;
  json['bytes_completed'] = completed;
  return json;
}

/**
 * Builds a torrent from `files` and `file_stats`.
 *
 * Goes through `Torrent.fromJson` rather than assigning the model directly, so
 * the tests exercise the same parsing path the app uses.
 */
function torrentOf(files: JsonArray, stats: JsonArray): Torrent {
  const json: JsonObject = {};
  json['id'] = 1;
  json['name'] = 'test';
  json['hash_string'] = 'hash';
  json['files'] = files;
  json['file_stats'] = stats;
  return Torrent.fromJson(json);
}

/**
 * `name` of every flattened node, for compact assertions.
 *
 * The result is compared with `assertDeepEquals`: the shim's `assertEqual` is a
 * `===` comparison, so it can never match two distinct arrays.
 */
function names(nodes: TorrentFileNode[]): string[] {
  const out: string[] = [];
  for (const node of nodes) {
    out.push(node.isFolder ? `${node.name}/` : node.name);
  }
  return out;
}

/**
 * 按名字取同级里的一个节点。
 *
 * 用例里不用下标取节点：`build` 会按「文件夹优先、然后按名字」重排，用下标就等于
 * 把某个用例的判断绑在排序结果上，排序一变失败原因看起来会像是聚合算错了。
 */
function nodeNamed(nodes: TorrentFileNode[], name: string): TorrentFileNode {
  for (const node of nodes) {
    if (node.name === name) {
      return node;
    }
  }
  throw new Error(`测试语料里没有名为 ${name} 的节点`);
}

export default function fileTreeTest(): void {
  describe('FileTree.buildRows', () => {
    it('zips files with file_stats', () => {
      const files: JsonArray = [file('a.txt', 100, 40), file('b.txt', 200, 200)];
      const stats: JsonArray = [stat(true, FilePriority.HIGH, 40), stat(false, FilePriority.LOW, 200)];

      const rows = FileTree.buildRows(torrentOf(files, stats));

      expect(rows.length).assertEqual(2);
      expect(rows[0].index).assertEqual(0);
      expect(rows[0].name).assertEqual('a.txt');
      expect(rows[0].length).assertEqual(100);
      expect(rows[0].wanted).assertTrue();
      expect(rows[0].priority).assertEqual(FilePriority.HIGH);
      // The wire index must stay positional even though the second file sorts
      // and renders differently.
      expect(rows[1].index).assertEqual(1);
      expect(rows[1].wanted).assertFalse();
      expect(rows[1].priority).assertEqual(FilePriority.LOW);
    });

    it('defaults a file whose file_stats entry is missing', () => {
      const files: JsonArray = [file('a.txt', 100, 40), file('b.txt', 200, 0)];
      const stats: JsonArray = [stat(false, FilePriority.LOW, 40)];

      const rows = FileTree.buildRows(torrentOf(files, stats));

      expect(rows.length).assertEqual(2);
      expect(rows[1].wanted).assertTrue();
      expect(rows[1].priority).assertEqual(FilePriority.NORMAL);
    });

    it('guards the completion of a zero-length file', () => {
      const files: JsonArray = [file('empty.txt', 0, 0)];
      const stats: JsonArray = [stat(true, FilePriority.NORMAL, 0)];

      const rows = FileTree.buildRows(torrentOf(files, stats));

      expect(rows[0].progressPercent).assertEqual(0);
    });
  });

  describe('FileTree.build', () => {
    it('groups a nested path into folders', () => {
      const files: JsonArray = [file('Season 1/Episode 1.mkv', 100, 50)];
      const stats: JsonArray = [stat(true, FilePriority.NORMAL, 50)];

      const roots = FileTree.build(FileTree.buildRows(torrentOf(files, stats)));

      expect(roots.length).assertEqual(1);
      expect(roots[0].isFolder).assertTrue();
      expect(roots[0].name).assertEqual('Season 1');
      expect(roots[0].path).assertEqual('Season 1');
      expect(roots[0].children.length).assertEqual(1);
      expect(roots[0].children[0].isFolder).assertFalse();
      expect(roots[0].children[0].name).assertEqual('Episode 1.mkv');
      expect(roots[0].children[0].path).assertEqual('Season 1/Episode 1.mkv');
      expect(roots[0].children[0].index).assertEqual(0);
    });

    it('keeps a file with no directory as a single root leaf', () => {
      const files: JsonArray = [file('solo.mkv', 10, 0)];
      const stats: JsonArray = [stat(true, FilePriority.NORMAL, 0)];

      const roots = FileTree.build(FileTree.buildRows(torrentOf(files, stats)));

      expect(roots.length).assertEqual(1);
      expect(roots[0].isFolder).assertFalse();
      expect(roots[0].name).assertEqual('solo.mkv');
      expect(roots[0].depth).assertEqual(0);
    });

    it('sums a folder over its whole subtree, not just its children', () => {
      const files: JsonArray = [
        file('root/a/x.bin', 100, 100),
        file('root/a/y.bin', 50, 0),
        file('root/b/z.bin', 25, 25),
      ];
      const stats: JsonArray = [
        stat(true, FilePriority.NORMAL, 100),
        stat(false, FilePriority.LOW, 0),
        stat(true, FilePriority.NORMAL, 25),
      ];

      const roots = FileTree.build(FileTree.buildRows(torrentOf(files, stats)));
      const root: TorrentFileNode = roots[0];

      expect(root.name).assertEqual('root');
      expect(root.length).assertEqual(175);
      expect(root.bytesCompleted).assertEqual(125);
      expect(root.fileCount).assertEqual(3);
      expect(root.wantedCount).assertEqual(2);
      // A file directly under an intermediate folder still rolls up into it.
      expect(root.children[0].name).assertEqual('a');
      expect(root.children[0].length).assertEqual(150);
      expect(root.children[0].fileCount).assertEqual(2);
    });

    it('orders folders before files, then by name', () => {
      const files: JsonArray = [file('z.txt', 1, 0), file('m/a.txt', 1, 0), file('a.txt', 1, 0)];
      const stats: JsonArray = [
        stat(true, FilePriority.NORMAL, 0),
        stat(true, FilePriority.NORMAL, 0),
        stat(true, FilePriority.NORMAL, 0),
      ];

      const roots = FileTree.build(FileTree.buildRows(torrentOf(files, stats)));

      expect(names(roots)).assertDeepEquals(['m/', 'a.txt', 'z.txt']);
    });

    it('reports how many of a folder\'s files are wanted', () => {
      const files: JsonArray = [file('d/a', 1, 0), file('d/b', 1, 0)];
      const stats: JsonArray = [stat(true, FilePriority.NORMAL, 0), stat(false, FilePriority.LOW, 0)];

      const roots = FileTree.build(FileTree.buildRows(torrentOf(files, stats)));

      expect(roots[0].wantedCount).assertEqual(1);
      expect(roots[0].allWanted).assertFalse();
      expect(roots[0].noneWanted).assertFalse();
    });
  });

  describe('FileTree.flatten', () => {
    it('walks the tree depth-first and records each depth', () => {
      const files: JsonArray = [file('root/a/x.bin', 1, 0)];
      const stats: JsonArray = [stat(true, FilePriority.NORMAL, 0)];
      const roots = FileTree.build(FileTree.buildRows(torrentOf(files, stats)));

      const flat = FileTree.flatten(roots, []);

      expect(names(flat)).assertDeepEquals(['root/', 'a/', 'x.bin']);
      expect(flat[0].depth).assertEqual(0);
      expect(flat[1].depth).assertEqual(1);
      expect(flat[2].depth).assertEqual(2);
    });

    it('hides the descendants of a collapsed folder, not just its children', () => {
      const files: JsonArray = [file('root/a/x.bin', 1, 0), file('root/b.bin', 1, 0)];
      const stats: JsonArray = [stat(true, FilePriority.NORMAL, 0), stat(true, FilePriority.NORMAL, 0)];
      const roots = FileTree.build(FileTree.buildRows(torrentOf(files, stats)));

      const flat = FileTree.flatten(roots, ['root']);

      // `root` itself stays visible so it can be tapped open again; everything
      // below it — including `a`, which is not itself collapsed — goes away.
      expect(names(flat)).assertDeepEquals(['root/']);
    });

    it('collapses an inner folder without touching its parent', () => {
      const files: JsonArray = [file('root/a/x.bin', 1, 0), file('root/b.bin', 1, 0)];
      const stats: JsonArray = [stat(true, FilePriority.NORMAL, 0), stat(true, FilePriority.NORMAL, 0)];
      const roots = FileTree.build(FileTree.buildRows(torrentOf(files, stats)));

      const flat = FileTree.flatten(roots, ['root/a']);

      expect(names(flat)).assertDeepEquals(['root/', 'a/', 'b.bin']);
    });

    it('leaves a folder\'s aggregates intact when it is collapsed', () => {
      const files: JsonArray = [file('root/a/x.bin', 1, 0), file('root/b.bin', 1, 0)];
      const stats: JsonArray = [stat(true, FilePriority.NORMAL, 0), stat(true, FilePriority.NORMAL, 0)];
      const roots = FileTree.build(FileTree.buildRows(torrentOf(files, stats)));

      const expanded = FileTree.flatten(roots, []);
      const collapsed = FileTree.flatten(roots, ['root']);

      expect(expanded.length).assertEqual(4);
      expect(collapsed.length).assertEqual(1);
      // Hiding the children must not change what the folder reports about them:
      // `flatten` only assigns `depth` and picks nodes, never touches the sums.
      expect(collapsed[0].fileCount).assertEqual(2);
      expect(collapsed[0].wantedCount).assertEqual(2);
      expect(collapsed[0].length).assertEqual(2);
    });
  });

  describe('FileTree.leafIndices', () => {
    it('returns its own index for a file', () => {
      const files: JsonArray = [file('a.bin', 1, 0), file('b.bin', 1, 0)];
      const stats: JsonArray = [stat(true, FilePriority.NORMAL, 0), stat(true, FilePriority.NORMAL, 0)];
      const roots = FileTree.build(FileTree.buildRows(torrentOf(files, stats)));

      expect(FileTree.leafIndices(roots[1])).assertDeepEquals([1]);
    });

    it('collects a whole subtree, however deep', () => {
      // Indices are the wire positions, so they are neither contiguous nor in
      // tree order — this is exactly the mapping a folder's checkbox needs.
      const files: JsonArray = [
        file('root/a/deep/x.bin', 1, 0),
        file('root/b.bin', 1, 0),
        file('root/a/y.bin', 1, 0),
      ];
      const stats: JsonArray = [
        stat(true, FilePriority.NORMAL, 0),
        stat(true, FilePriority.NORMAL, 0),
        stat(true, FilePriority.NORMAL, 0),
      ];
      const roots = FileTree.build(FileTree.buildRows(torrentOf(files, stats)));
      const flat = FileTree.flatten(roots, []);

      // root/ a/ deep/ x.bin b.bin y.bin — located by path rather than by
      // position so the test does not depend on the sort order.
      let position: number = -1;
      for (let i = 0; i < flat.length; i++) {
        if (flat[i].path === 'root/a') {
          position = i;
        }
      }
      expect(position >= 0).assertTrue();
      expect(FileTree.leafIndices(flat[position])).assertDeepEquals([0, 2]);
    });

    it('returns nothing for a folder with no files below it', () => {
      const empty: TorrentFileNode = new TorrentFileNode();
      empty.isFolder = true;
      expect(FileTree.leafIndices(empty).length).assertEqual(0);
    });
  });

  describe('FileKinds.of', () => {
    it('classifies the recognised extensions', () => {
      expect(FileKinds.of('Season 1/Episode 1.mkv')).assertEqual(FileKind.VIDEO);
      expect(FileKinds.of('track.flac')).assertEqual(FileKind.AUDIO);
      expect(FileKinds.of('cover.PNG')).assertEqual(FileKind.IMAGE);
      expect(FileKinds.of('notes.pdf')).assertEqual(FileKind.DOCUMENT);
      expect(FileKinds.of('archive.tar.gz')).assertEqual(FileKind.ARCHIVE);
      expect(FileKinds.of('subs.srt')).assertEqual(FileKind.SUBTITLE);
      expect(FileKinds.of('disc.iso')).assertEqual(FileKind.DISC);
    });

    it('ignores the case of the extension', () => {
      expect(FileKinds.of('A.MKV')).assertEqual(FileKinds.of('a.mkv'));
      expect(FileKinds.of('A.Mkv')).assertEqual(FileKind.VIDEO);
    });

    it('reads only the last path segment', () => {
      // The dot lives in a directory name, so the file itself has no
      // extension at all and must not borrow the folder's.
      expect(FileKinds.of('Movies.2024/README')).assertEqual(FileKind.OTHER);
      // And the final segment is the one that counts.
      expect(FileKinds.of('a.txt/b.mp4')).assertEqual(FileKind.VIDEO);
    });

    it('falls back to OTHER rather than guessing', () => {
      expect(FileKinds.of('no-extension')).assertEqual(FileKind.OTHER);
      expect(FileKinds.of('unknown.qqq')).assertEqual(FileKind.OTHER);
      // A leading dot marks a hidden file, not an extension.
      expect(FileKinds.of('.gitignore')).assertEqual(FileKind.OTHER);
      // A trailing dot is not an extension either.
      expect(FileKinds.of('odd.')).assertEqual(FileKind.OTHER);
      expect(FileKinds.of('')).assertEqual(FileKind.OTHER);
    });

    it('only classifies leaves, leaving folders at OTHER', () => {
      const files: JsonArray = [file('root/a/x.bin', 1, 0), file('root/clip.mkv', 2, 0)];
      const stats: JsonArray = [stat(true, FilePriority.NORMAL, 0), stat(true, FilePriority.NORMAL, 0)];

      const flat = FileTree.flatten(FileTree.build(FileTree.buildRows(torrentOf(files, stats))), []);

      expect(flat[0].isFolder).assertTrue();
      expect(flat[0].kind).assertEqual(FileKind.OTHER);
      expect(flat[2].isFolder).assertFalse();
      expect(flat[2].kind).assertEqual(FileKind.OTHER);
      expect(flat[3].kind).assertEqual(FileKind.VIDEO);
    });
  });

  describe('完成状态', () => {
    it('字节全部到手即算完成，多报几个字节也算', () => {
      const exact: JsonArray = [file('a.mkv', 100, 100)];
      const exactStats: JsonArray = [stat(true, FilePriority.NORMAL, 100)];
      const rows = FileTree.buildRows(torrentOf(exact, exactStats));

      // 顺带确认 `files[].bytes_completed` 真的走到了行模型上 ——
      // 下面所有完成状态的断言都建立在这条链路上。
      expect(rows[0].bytesCompleted).assertEqual(100);
      expect(rows[0].isComplete).assertTrue();

      // 服务端收尾时偶尔会把已完成字节报得比长度略大。
      const over: JsonArray = [file('b.mkv', 100, 101)];
      const overStats: JsonArray = [stat(true, FilePriority.NORMAL, 101)];
      expect(FileTree.buildRows(torrentOf(over, overStats))[0].isComplete).assertTrue();
    });

    it('未完成的文件可勾选，已完成的锁住', () => {
      const files: JsonArray = [file('done.mkv', 100, 100), file('pending.mkv', 100, 40)];
      const stats: JsonArray = [
        stat(true, FilePriority.NORMAL, 100),
        stat(true, FilePriority.NORMAL, 40),
      ];
      const roots = FileTree.build(FileTree.buildRows(torrentOf(files, stats)));

      const done = nodeNamed(roots, 'done.mkv');
      expect(done.isComplete).assertTrue();
      expect(done.checkable).assertFalse();
      expect(done.allPendingWanted).assertFalse();

      const pending = nodeNamed(roots, 'pending.mkv');
      expect(pending.isComplete).assertFalse();
      expect(pending.checkable).assertTrue();
      expect(pending.allPendingWanted).assertTrue();
    });

    it('文件夹的复选框只看未完成的那部分', () => {
      // 两个已完成、一个待下载，且待下载的那个是勾上的。
      const files: JsonArray = [
        file('root/a.mkv', 100, 100),
        file('root/b.mkv', 100, 100),
        file('root/c.mkv', 100, 30),
      ];
      const stats: JsonArray = [
        stat(true, FilePriority.NORMAL, 100),
        stat(true, FilePriority.NORMAL, 100),
        stat(true, FilePriority.NORMAL, 30),
      ];
      const root = nodeNamed(FileTree.build(FileTree.buildRows(torrentOf(files, stats))), 'root');

      expect(root.fileCount).assertEqual(3);
      expect(root.pendingCount).assertEqual(1);
      expect(root.pendingWantedCount).assertEqual(1);
      expect(root.isComplete).assertFalse();
      expect(root.checkable).assertTrue();
      expect(root.allPendingWanted).assertTrue();
    });

    it('待下载的文件被取消勾选后，未完成的那部分不再显示为选中', () => {
      const files: JsonArray = [file('root/a.mkv', 100, 100), file('root/b.mkv', 100, 0)];
      const stats: JsonArray = [
        stat(true, FilePriority.NORMAL, 100),
        stat(false, FilePriority.LOW, 0),
      ];
      const root = nodeNamed(FileTree.build(FileTree.buildRows(torrentOf(files, stats))), 'root');

      expect(root.pendingCount).assertEqual(1);
      expect(root.pendingWantedCount).assertEqual(0);
      expect(root.allPendingWanted).assertFalse();
      expect(root.checkable).assertTrue();
      // 还有一个文件没下完，所以整个文件夹不算完成。
      expect(root.isComplete).assertFalse();
    });

    it('已完成但服务端标成不下载的文件，仍然显示为选中', () => {
      const files: JsonArray = [file('root/a.mkv', 100, 100), file('root/b.mkv', 100, 100)];
      const stats: JsonArray = [
        stat(false, FilePriority.LOW, 100),
        stat(true, FilePriority.NORMAL, 100),
      ];
      const root = nodeNamed(FileTree.build(FileTree.buildRows(torrentOf(files, stats))), 'root');

      // 两个文件都已经在磁盘上，所以整棵子树算完成、复选框锁住并显示为选中 ——
      // 哪怕其中一个在服务端被标成了「不下载」。
      expect(root.isComplete).assertTrue();
      expect(root.checkable).assertFalse();

      // 而 `allWanted` 在这里是假的，因为它数的是「要的」而不是「有没有下完」。
      // 这正是复选框不能拿 `allWanted` 当依据的原因：拿它当依据的话，这个
      // 文件夹会显示成未勾选，看起来像还有东西没下。
      expect(root.allWanted).assertFalse();
    });
  });
}

    it('整棵子树都下载完成时文件夹锁定并显示为选中', () => {
      const files: JsonArray = [file('root/a.mkv', 100, 100), file('root/sub/b.mkv', 50, 50)];
      const stats: JsonArray = [
        stat(true, FilePriority.NORMAL, 100),
        stat(true, FilePriority.NORMAL, 50),
      ];
      const root = nodeNamed(FileTree.build(FileTree.buildRows(torrentOf(files, stats))), 'root');

      expect(root.pendingCount).assertEqual(0);
      expect(root.isComplete).assertTrue();
      expect(root.checkable).assertFalse();

      // 空子树不算「已完成」，否则一个没挂上任何文件的文件夹会自称下完了。
      expect(new TorrentFileNode().isComplete).assertFalse();
    });
  });
}
