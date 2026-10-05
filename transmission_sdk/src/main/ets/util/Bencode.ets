// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Bencode 解码器。
 *
 * bencode 是 `.torrent` 文件与 tracker 协议使用的编码：整数写作 `i42e`、
 * 字节串写作 `<长度>:<内容>`、列表写作 `l...e`、字典写作 `d...e`。
 * 本文件只做**解码**，够用即可 —— SDK 需要它的唯一原因，是
 * `torrent-add` 的 `metainfo` 参数就是一份 base64 过的 `.torrent`，
 * 而要在添加前把「这个种子里有哪些文件」显示给用户，就得自己解开它。
 *
 * ### 为什么不用 `@ohos.util` / 第三方库
 *
 * 与 `util/Base64`、`util/Json` 同样的理由：不依赖平台，才能让
 * `scripts/run-tests.mjs` 在普通 JS 引擎上跑单测。
 *
 * ### 为什么不抛异常
 *
 * 解码失败是**常态**（用户完全可能选到一个不是 `.torrent` 的文件），
 * 所以入口返回 `undefined` 而不是抛错。这与 `util/Json` 的「全函数、永不抛」
 * 取值风格一致，也让调用方不必包 try/catch —— 本工程用 JSDoc `@throws`
 * 模拟受检异常，抛错会顺着调用链一路传播到 UI 边界。
 *
 * @since 1.0.0
 */

import { Base64 } from './Base64';

/** bencode 值的种类。 */
export enum BencodeKind {
  /** 整数，如 `i42e`。 */
  INTEGER = 'integer',
  /** 字节串，如 `4:spam`。 */
  STRING = 'string',
  /** 列表，如 `l4:spami1ee`。 */
  LIST = 'list',
  /** 字典，如 `d4:spami1ee`。 */
  DICTIONARY = 'dictionary',
}

/**
 * 一个已解码的 bencode 值。
 *
 * 用「标签 + 各字段」的扁平结构而不是子类多态：ArkTS 禁止 `any`，也不便做
 * 运行时类型判断，而一个带 `kind` 的类能让调用方用一次 `if` 就取到负载，
 * 不必做类型断言。
 */
export class BencodeValue {
  /** 本值的种类，决定下面哪个字段有意义。 */
  kind: BencodeKind = BencodeKind.STRING;
  /** INTEGER 的数值；其他种类为 0。 */
  integer: number = 0;
  /** STRING 的原始字节；其他种类为空。 */
  bytes: Uint8Array = new Uint8Array(0);
  /** LIST 的元素，或 DICTIONARY 的值；与 `keys` 一一对应。 */
  items: BencodeValue[] = [];
  /** DICTIONARY 的键，顺序与 `items` 相同（bencode 要求键按字节序排列）。 */
  keys: string[] = [];

  /** 构造一个整数值。 */
  static ofInteger(value: number): BencodeValue {
    const result = new BencodeValue();
    result.kind = BencodeKind.INTEGER;
    result.integer = value;
    return result;
  }

  /** 构造一个字节串值。 */
  static ofBytes(value: Uint8Array): BencodeValue {
    const result = new BencodeValue();
    result.kind = BencodeKind.STRING;
    result.bytes = value;
    return result;
  }

  /** 字典中某个键的值，不存在时返回 `undefined`。 */
  get(key: string): BencodeValue | undefined {
    for (let i = 0; i < this.keys.length; i++) {
      if (this.keys[i] === key) {
        return this.items[i];
      }
    }
    return undefined;
  }

  /**
   * 字节串按 UTF-8 解码后的文本。
   *
   * 非字节串返回空串。种子里的 `name` / `path` 都是 UTF-8 文本，所以中文
   * 文件名能正确还原；`pieces` 之类的二进制字段调用方不会读。
   */
  text(): string {
    return this.kind === BencodeKind.STRING ? Base64.utf8ToString(this.bytes) : '';
  }

  /** 字典中某个键的整数值；缺失或类型不符时返回 `fallback`。 */
  integerOf(key: string, fallback: number): number {
    const child = this.get(key);
    return child !== undefined && child.kind === BencodeKind.INTEGER ? child.integer : fallback;
  }

  /** 字典中某个键的文本值；缺失时返回空串。 */
  textOf(key: string): string {
    const child = this.get(key);
    return child === undefined ? '' : child.text();
  }

  /** 字典中某个键的列表元素；缺失或类型不符时返回空数组。 */
  listOf(key: string): BencodeValue[] {
    const child = this.get(key);
    return child !== undefined && child.kind === BencodeKind.LIST ? child.items : [];
  }
}

/** 解码游标；只在本文件内使用。 */
class BencodeCursor {
  readonly bytes: Uint8Array;
  index: number = 0;

  constructor(bytes: Uint8Array) {
    this.bytes = bytes;
  }

  /** 是否已读到末尾。 */
  get atEnd(): boolean {
    return this.index >= this.bytes.length;
  }

  /** 当前字节，已到末尾时返回 `-1`。 */
  peek(): number {
    return this.atEnd ? -1 : this.bytes[this.index];
  }
}

const CHAR_ZERO: number = 0x30;
const CHAR_NINE: number = 0x39;
const CHAR_COLON: number = 0x3a;
const CHAR_MINUS: number = 0x2d;
const CHAR_D: number = 0x64;
const CHAR_E: number = 0x65;
const CHAR_I: number = 0x69;
const CHAR_L: number = 0x6c;

/** bencode 解码。 */
export class Bencode {
  /**
   * 嵌套深度上限。
   *
   * bencode 允许任意嵌套，而递归下降解析器遇到 `lllll…` 会爆栈。真实的
   * `.torrent` 只有三四层（root → info → files → file → path），32 层对
   * 合法输入绰绰有余，对恶意输入则直接判失败。
   */
  private static readonly MAX_DEPTH: number = 32;

  private constructor() {
    // 纯静态工具类。
  }

  /**
   * 解码一段 bencode 数据。
   *
   * @param bytes 数据
   * @returns 根值；数据不合法、或末尾有多余字节时返回 `undefined`
   */
  static decode(bytes: Uint8Array): BencodeValue | undefined {
    const cursor = new BencodeCursor(bytes);
    const root = Bencode.readValue(cursor, 0);
    // 末尾有多余字节同样视为非法：.torrent 里不该有尾随内容，而这通常
    // 说明选错了文件（比如把别的东西改了个 .torrent 后缀）。
    if (root === undefined || !cursor.atEnd) {
      return undefined;
    }
    return root;
  }

  /** 按当前字节分派到具体解析函数。 */
  private static readValue(cursor: BencodeCursor, depth: number): BencodeValue | undefined {
    if (depth > Bencode.MAX_DEPTH) {
      return undefined;
    }
    const marker = cursor.peek();
    if (marker === CHAR_I) {
      return Bencode.readInteger(cursor);
    }
    if (marker === CHAR_L) {
      return Bencode.readList(cursor, depth);
    }
    if (marker === CHAR_D) {
      return Bencode.readDictionary(cursor, depth);
    }
    return Bencode.readByteString(cursor);
  }

  /** 读取 `i<十进制>e`。 */
  private static readInteger(cursor: BencodeCursor): BencodeValue | undefined {
    cursor.index++;
    let negative = false;
    if (cursor.peek() === CHAR_MINUS) {
      negative = true;
      cursor.index++;
    }
    const start = cursor.index;
    while (cursor.peek() >= CHAR_ZERO && cursor.peek() <= CHAR_NINE) {
      cursor.index++;
    }
    if (cursor.index === start || cursor.peek() !== CHAR_E) {
      return undefined;
    }
    const magnitude = Number(Bencode.digitsOf(cursor.bytes, start, cursor.index));
    cursor.index++;
    if (Number.isNaN(magnitude)) {
      return undefined;
    }
    return BencodeValue.ofInteger(negative ? -magnitude : magnitude);
  }

  /** 读取 `<长度>:<内容>`。 */
  private static readByteString(cursor: BencodeCursor): BencodeValue | undefined {
    const start = cursor.index;
    while (cursor.peek() >= CHAR_ZERO && cursor.peek() <= CHAR_NINE) {
      cursor.index++;
    }
    if (cursor.index === start || cursor.peek() !== CHAR_COLON) {
      return undefined;
    }
    const length = Number(Bencode.digitsOf(cursor.bytes, start, cursor.index));
    if (Number.isNaN(length) || length < 0) {
      return undefined;
    }
    cursor.index++;
    const end = cursor.index + length;
    if (end > cursor.bytes.length) {
      return undefined;
    }
    // 复制而不是共享视图：`subarray` 会拖住整份原始缓冲区，而调用方通常
    // 只保留几个字段（文件名、长度），没必要为此一直持有几百 KB 的种子。
    const value = cursor.bytes.slice(cursor.index, end);
    cursor.index = end;
    return BencodeValue.ofBytes(value);
  }

  /** 读取 `l…e`。 */
  private static readList(cursor: BencodeCursor, depth: number): BencodeValue | undefined {
    cursor.index++;
    const result = new BencodeValue();
    result.kind = BencodeKind.LIST;
    while (true) {
      if (cursor.atEnd) {
        return undefined;
      }
      if (cursor.peek() === CHAR_E) {
        cursor.index++;
        return result;
      }
      const element = Bencode.readValue(cursor, depth + 1);
      if (element === undefined) {
        return undefined;
      }
      result.items.push(element);
    }
  }

  /** 读取 `d…e`；键必须是字节串。 */
  private static readDictionary(cursor: BencodeCursor, depth: number): BencodeValue | undefined {
    cursor.index++;
    const result = new BencodeValue();
    result.kind = BencodeKind.DICTIONARY;
    while (true) {
      if (cursor.atEnd) {
        return undefined;
      }
      if (cursor.peek() === CHAR_E) {
        cursor.index++;
        return result;
      }
      const key = Bencode.readByteString(cursor);
      if (key === undefined) {
        return undefined;
      }
      const value = Bencode.readValue(cursor, depth + 1);
      if (value === undefined) {
        return undefined;
      }
      result.keys.push(key.text());
      result.items.push(value);
    }
  }

  /** 把 `[from, to)` 区间的 ASCII 数字转成字符串（不用正则，ArkTS 不支持正则字面量）。 */
  private static digitsOf(bytes: Uint8Array, from: number, to: number): string {
    let out = '';
    for (let i = from; i < to; i++) {
      out += String.fromCharCode(bytes[i]);
    }
    return out;
  }
}
