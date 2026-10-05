// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * `.torrent` 文件里本应用需要的那部分信息。
 *
 * 只解出「有哪些文件、各多大、叫什么」—— 这是添加前让用户勾选要下载哪些
 * 文件所必需的。`pieces`（分块哈希）等字段刻意不解析：它们是几百 KB 的
 * 二进制，而服务端自己会从 `metainfo` 里读，客户端没有理由留一份。
 *
 * 与 `util/Bencode` 一样，解析失败返回 `undefined` 而不是抛错：用户完全
 * 可能选到一个不是 `.torrent` 的文件，那是正常路径而不是异常。
 *
 * @since 1.0.0
 */

import { Bencode, BencodeKind, BencodeValue } from '../util/Bencode';

/** 种子里的一个文件。 */
export class MetainfoFile {
  /**
   * 相对种子根目录的路径分段，例如 `['第一季', '01.mkv']`。
   *
   * 分段保存而不是拼成字符串，是因为目录树要按层聚合；拼接只在
   * {@link MetainfoFile.name} 里按需做一次。
   */
  path: string[] = [];
  /** 文件字节数。 */
  length: number = 0;

  /** 用 `/` 连接的完整路径，正是目录树分组所需的形态。 */
  get name(): string {
    return this.path.join('/');
  }
}

/** `.torrent` 的 `info` 字典中本应用使用的部分。 */
export class Metainfo {
  /** 种子名：多文件时是根目录名，单文件时就是文件名。 */
  name: string = '';
  /** 分块大小，仅用于在信息页展示，不参与任何计算。 */
  pieceLength: number = 0;
  /** 种子内的文件，顺序与 `files` 一致 —— `files-wanted` 按下标寻址。 */
  files: MetainfoFile[] = [];
  /** 全部文件字节数之和。 */
  totalSize: number = 0;
  /** 单文件种子：`info` 里没有 `files` 列表，`name` 即文件名。 */
  singleFile: boolean = false;

  /** 全部文件数。 */
  get fileCount(): number {
    return this.files.length;
  }

  /**
   * 解析一份 `.torrent`。
   *
   * @param bytes 文件原始字节
   * @returns 解析结果；不是合法种子、或种子里没有文件时返回 `undefined`
   */
  static parse(bytes: Uint8Array): Metainfo | undefined {
    const root = Bencode.decode(bytes);
    if (root === undefined || root.kind !== BencodeKind.DICTIONARY) {
      return undefined;
    }
    const info = root.get('info');
    if (info === undefined || info.kind !== BencodeKind.DICTIONARY) {
      return undefined;
    }

    const metainfo = new Metainfo();
    metainfo.name = info.textOf('name');
    metainfo.pieceLength = info.integerOf('piece length', 0);
    Metainfo.readFiles(info, metainfo);
    if (metainfo.files.length === 0) {
      return undefined;
    }
    for (const file of metainfo.files) {
      metainfo.totalSize += file.length;
    }
    return metainfo;
  }

  /**
   * 读出文件列表，兼容单文件与多文件两种种子。
   *
   * 单文件种子的 `info` 直接是 `length`，没有 `files`；多文件种子的每个条目
   * 是一只含 `length` 与 `path`（分段组成的列表）的字典。两者在这里被抹平成
   * 同一种 {@link MetainfoFile}，上面的 UI 就不必分两套。
   */
  private static readFiles(info: BencodeValue, metainfo: Metainfo): void {
    const entries = info.listOf('files');
    if (entries.length === 0) {
      // `info` 里既没有 `files` 也没有 `length`，那它根本不是一份种子；
      // 放行会得到一个 0 字节的假文件。
      const declared = info.get('length');
      if (declared === undefined || declared.kind !== BencodeKind.INTEGER) {
        return;
      }
      const single = new MetainfoFile();
      single.path = Metainfo.fallbackName(metainfo.name);
      single.length = declared.integer;
      metainfo.singleFile = true;
      metainfo.files.push(single);
      return;
    }
    for (const entry of entries) {
      if (entry.kind !== BencodeKind.DICTIONARY) {
        continue;
      }
      const file = new MetainfoFile();
      file.length = entry.integerOf('length', 0);
      for (const segment of entry.listOf('path')) {
        const text = segment.text();
        // 分段为空说明种子本身有问题；丢掉这一段比留下一级空目录好。
        if (text.length > 0) {
          file.path.push(text);
        }
      }
      if (file.path.length > 0) {
        metainfo.files.push(file);
      }
    }
  }

  /** 种子名为空时给单文件种子一个占位路径，避免目录树出现无名节点。 */
  private static fallbackName(name: string): string[] {
    return name.length > 0 ? [name] : ['torrent'];
  }
}
