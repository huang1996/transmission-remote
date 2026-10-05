// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * `.torrent` metainfo 解析的测试。
 *
 * 解析结果直接决定「添加种子」页上那棵文件树：哪个文件在第几位、叫什么、
 * 多大。下标错了，用户勾掉的字幕就会变成被下载的正片 —— 所以下标与顺序
 * 在这里是重点。
 *
 * 语料由本文件按 bencode 规则拼出来，而不是塞一段 base64 黑盒：这样每个
 * 断言要检查的那一项都写在测试里，读的人不必先去解一份二进制。
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { Base64 } from '../../main/ets/util/Base64';
import { Metainfo } from '../../main/ets/model/Metainfo';

/** ASCII 文本的字节。 */
function text(value: string): Uint8Array {
  const out = new Uint8Array(value.length);
  for (let i = 0; i < value.length; i++) {
    out[i] = value.charCodeAt(i);
  }
  return out;
}

/** 按顺序拼接多段字节。 */
function join(parts: Uint8Array[]): Uint8Array {
  let total = 0;
  for (const part of parts) {
    total += part.length;
  }
  const out = new Uint8Array(total);
  let at = 0;
  for (const part of parts) {
    out.set(part, at);
    at += part.length;
  }
  return out;
}

/** UTF-8 文本编成 bencode 字节串。 */
function str(value: string): Uint8Array {
  const payload = Base64.utf8Bytes(value);
  return join([text(`${payload.length}:`), payload]);
}

/** bencode 整数。 */
function integer(value: number): Uint8Array {
  return text(`i${value}e`);
}

/** bencode 列表。 */
function list(items: Uint8Array[]): Uint8Array {
  return join([text('l'), join(items), text('e')]);
}

/** bencode 字典；调用方保证键是字典序。 */
function dictionary(entries: Uint8Array[]): Uint8Array {
  return join([text('d'), join(entries), text('e')]);
}

/** 用外层的 `info` 字典包成一个完整的 `.torrent`。 */
function torrent(entries: Uint8Array[]): Uint8Array {
  return dictionary([str('info'), dictionary(entries)]);
}

/** 多文件种子的一个文件条目。 */
function fileEntry(length: number, path: string[]): Uint8Array {
  const segments: Uint8Array[] = [];
  for (const segment of path) {
    segments.push(str(segment));
  }
  return dictionary([str('length'), integer(length), str('path'), list(segments)]);
}

/** 两个文件、同一目录的多文件种子。 */
function multiFileTorrent(): Uint8Array {
  return torrent([
    str('files'),
    list([fileEntry(100, ['第一季', '01.mkv']), fileEntry(200, ['第一季', '02.mkv'])]),
    str('name'),
    str('崩坏：星穹铁道'),
    str('piece length'),
    integer(262144),
  ]);
}

export default function metainfoTest(): void {
  describe('Metainfo.parse 多文件种子', () => {
    it('读出种子名与分块大小', () => {
      const metainfo = Metainfo.parse(multiFileTorrent());
      expect(metainfo === undefined).assertFalse();
      expect(metainfo === undefined ? '' : metainfo.name).assertEqual('崩坏：星穹铁道');
      expect(metainfo === undefined ? 0 : metainfo.pieceLength).assertEqual(262144);
    });

    it('文件顺序与下标保持一致', () => {
      const metainfo = Metainfo.parse(multiFileTorrent());
      expect(metainfo === undefined ? 0 : metainfo.fileCount).assertEqual(2);
      // 下标就是 `files_wanted` / `files_unwanted` 要用的位置，不能被打乱。
      expect(metainfo === undefined ? '' : metainfo.files[0].name).assertEqual('第一季/01.mkv');
      expect(metainfo === undefined ? '' : metainfo.files[1].name).assertEqual('第一季/02.mkv');
      expect(metainfo === undefined ? 0 : metainfo.files[0].length).assertEqual(100);
      expect(metainfo === undefined ? 0 : metainfo.files[1].length).assertEqual(200);
    });

    it('累计总大小', () => {
      const metainfo = Metainfo.parse(multiFileTorrent());
      expect(metainfo === undefined ? 0 : metainfo.totalSize).assertEqual(300);
    });

    it('多文件种子不算单文件', () => {
      const metainfo = Metainfo.parse(multiFileTorrent());
      expect(metainfo === undefined ? true : metainfo.singleFile).assertFalse();
    });

    it('路径分段也按 UTF-8 还原', () => {
      const metainfo = Metainfo.parse(multiFileTorrent());
      expect(metainfo === undefined ? 0 : metainfo.files[0].path.length).assertEqual(2);
      expect(metainfo === undefined ? '' : metainfo.files[0].path[0]).assertEqual('第一季');
    });
  });

  describe('Metainfo.parse 单文件种子', () => {
    it('没有 files 列表时，name 就是文件名', () => {
      const metainfo = Metainfo.parse(torrent([str('length'), integer(500), str('name'), str('movie.mkv')]));
      expect(metainfo === undefined ? 0 : metainfo.fileCount).assertEqual(1);
      expect(metainfo === undefined ? '' : metainfo.files[0].name).assertEqual('movie.mkv');
      expect(metainfo === undefined ? 0 : metainfo.files[0].length).assertEqual(500);
      expect(metainfo === undefined ? 0 : metainfo.totalSize).assertEqual(500);
      expect(metainfo === undefined ? false : metainfo.singleFile).assertTrue();
    });

    it('种子名为空时给一个占位路径，避免出现无名节点', () => {
      const metainfo = Metainfo.parse(torrent([str('length'), integer(1)]));
      expect(metainfo === undefined ? '' : metainfo.files[0].name).assertEqual('torrent');
    });
  });

  describe('Metainfo.parse 拒绝非种子输入', () => {
    it('不是 bencode', () => {
      expect(Metainfo.parse(text('this is not a torrent')) === undefined).assertTrue();
    });

    it('是 bencode 但没有 info', () => {
      expect(Metainfo.parse(dictionary([str('announce'), str('http://x/announce')])) === undefined).assertTrue();
    });

    it('info 不是字典', () => {
      expect(Metainfo.parse(dictionary([str('info'), integer(1)])) === undefined).assertTrue();
    });

    it('info 里既没有 files 也没有 length', () => {
      // 否则会解出一个 0 字节的假文件。
      expect(Metainfo.parse(torrent([str('name'), str('x')])) === undefined).assertTrue();
    });

    it('files 是空列表', () => {
      expect(Metainfo.parse(torrent([str('files'), list([]), str('name'), str('x')])) === undefined).assertTrue();
    });

    it('空输入', () => {
      expect(Metainfo.parse(new Uint8Array(0)) === undefined).assertTrue();
    });

    it('文件条目缺少 path 时跳过该条', () => {
      const metainfo = Metainfo.parse(torrent([
        str('files'),
        list([dictionary([str('length'), integer(9)]), fileEntry(3, ['ok.bin'])]),
        str('name'),
        str('x'),
      ]));
      expect(metainfo === undefined ? 0 : metainfo.fileCount).assertEqual(1);
      expect(metainfo === undefined ? '' : metainfo.files[0].name).assertEqual('ok.bin');
    });

    it('路径里的空分段被丢掉', () => {
      const metainfo = Metainfo.parse(torrent([
        str('files'),
        list([fileEntry(3, ['', 'a.bin'])]),
        str('name'),
        str('x'),
      ]));
      expect(metainfo === undefined ? '' : metainfo.files[0].name).assertEqual('a.bin');
    });
  });
}
