// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Adding torrents from a link or from a local `.torrent` file.
 *
 * The file path needs three HarmonyOS APIs in sequence — the document picker,
 * `fileIo` to read the bytes, and the SDK's Base64 encoder to reach the wire —
 * so the sequence lives here rather than being duplicated by the list FAB and
 * the add screen.
 *
 * @since 1.0.0
 */

import { fileIo } from '@kit.CoreFileKit';
import { picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { TorrentAddRequest, TorrentAddResult, TransmissionClient } from 'transmission_sdk';

/** A `.torrent` file chosen by the user. */
export class PickedTorrent {
  /** Display name, used in the confirmation toast. */
  name: string = '';
  /** Raw file contents. */
  bytes: Uint8Array = new Uint8Array(0);
}

/** Helpers for the two supported ways of adding a torrent. */
export class AddTorrentHelper {
  private constructor() {
    // Static-only utility class.
  }

  /**
   * Opens the system document picker and reads the chosen `.torrent` file.
   *
   * @param context ability context that owns the picker
   * @returns the file, or `undefined` when the user cancelled
   */
  static async pickTorrentFile(context: common.UIAbilityContext): Promise<PickedTorrent | undefined> {
    const options = new picker.DocumentSelectOptions();
    options.maxSelectNumber = 1;
    options.fileSuffixFilters = ['.torrent'];

    const documentPicker = new picker.DocumentViewPicker(context);
    const uris = await documentPicker.select(options);
    if (uris === undefined || uris.length === 0) {
      return undefined;
    }

    const uri = uris[0];
    const picked = new PickedTorrent();
    picked.name = AddTorrentHelper.fileNameOf(uri);
    picked.bytes = AddTorrentHelper.readAllBytes(uri);
    return picked;
  }

  /**
   * Reads a file completely.
   *
   * `fileIo.readSync` fills at most one buffer, so the file size is queried
   * first and a single precisely sized buffer is allocated.
   *
   * @param uri file uri returned by the picker
   */
  static readAllBytes(uri: string): Uint8Array {
    const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    try {
      const stat = fileIo.statSync(file.fd);
      const buffer = new ArrayBuffer(stat.size);
      const read = fileIo.readSync(file.fd, buffer);
      return new Uint8Array(buffer.slice(0, read));
    } finally {
      fileIo.closeSync(file);
    }
  }

  /**
   * Adds a torrent described by a magnet link or a URL.
   *
   * @param client connected client
   * @param link magnet link or `.torrent` URL
   * @param downloadDir target directory, or an empty string for the server default
   * @param paused when true the torrent is added stopped
   */
  static async addFromLink(
    client: TransmissionClient,
    link: string,
    downloadDir: string,
    paused: boolean,
  ): Promise<TorrentAddResult> {
    const request = TorrentAddRequest.fromFilename(link).paused(paused);
    if (downloadDir.length > 0) {
      request.downloadDir(downloadDir);
    }
    return client.torrents.add(request);
  }

  /**
   * 添加一份 `.torrent` 字节。
   *
   * @param client 已连接的客户端
   * @param bytes 文件内容
   * @param downloadDir 目标目录；传空串表示用服务端默认目录
   * @param paused 为真时添加后保持暂停
   * @param unwanted 不要下载的文件下标
   */
  static async addFromBytes(
    client: TransmissionClient,
    bytes: Uint8Array,
    downloadDir: string,
    paused: boolean,
    unwanted: number[],
  ): Promise<TorrentAddResult> {
    const request = TorrentAddRequest.fromBytes(bytes).paused(paused);
    if (downloadDir.length > 0) {
      request.downloadDir(downloadDir);
    }
    // 只说明「不要哪些」：Transmission 的默认行为就是全部要，所以勾选状态里
    // 只有未勾选的那部分需要出现在请求里，报文也更短。
    if (unwanted.length > 0) {
      request.filesUnwanted(unwanted);
    }
    return client.torrents.add(request);
  }

  /**
   * 读取服务端会话的默认下载目录。
   *
   * 用来给「下载到」输入框做回显：留空时服务端会用它自己的默认值，但用户
   * 看不到那是什么，也就无法判断要不要改。查询失败不是致命错误 —— 拿不到就
   * 留空，由占位提示说明留空的含义。
   *
   * @param client 已连接的客户端
   * @returns 目录路径；为空或查询失败时返回 `undefined`
   */
  static async defaultDownloadDir(client: TransmissionClient): Promise<string | undefined> {
    try {
      const settings = await client.session.get(['download_dir']);
      return settings.downloadDir.length > 0 ? settings.downloadDir : undefined;
    } catch (error) {
      return undefined;
    }
  }

  /** Last path segment of a file uri, decoded for display. */
  private static fileNameOf(uri: string): string {
    const separator = uri.lastIndexOf('/');
    const raw = separator >= 0 ? uri.substring(separator + 1) : uri;
    try {
      return decodeURIComponent(raw);
    } catch (error) {
      return raw;
    }
  }
}
