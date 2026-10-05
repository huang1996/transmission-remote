// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * bencode 解码器的测试。
 *
 * 这是解析 `.torrent` 的基础，而它的输入来自用户选择的**任意文件** ——
 * 所以「合法输入解对」只是一半，更重要的另一半是「非法输入不许抛错、也不许
 * 返回半个结果」。两种情形都在这里覆盖。
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { Base64 } from '../../main/ets/util/Base64';
import { Bencode, BencodeKind, BencodeValue } from '../../main/ets/util/Bencode';

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

/** 把一段 UTF-8 文本编成 bencode 字节串：`<字节数>:<内容>`。 */
function bytes(value: string): Uint8Array {
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

/** bencode 字典；键按调用方给的顺序排列，调用方负责保证字典序。 */
function dictionary(entries: Uint8Array[]): Uint8Array {
  return join([text('d'), join(entries), text('e')]);
}

/** 解码一段 ASCII 编码的 bencode 文本。 */
function decode(value: string): BencodeValue | undefined {
  return Bencode.decode(text(value));
}

export default function bencodeTest(): void {
  describe('Bencode.decode', () => {
    it('解出整数', () => {
      const value = decode('i42e');
      expect(value === undefined).assertFalse();
      expect(value === undefined ? '' : value.kind).assertEqual(BencodeKind.INTEGER);
      expect(value === undefined ? 0 : value.integer).assertEqual(42);
    });

    it('解出负整数', () => {
      const value = decode('i-7e');
      expect(value === undefined ? 0 : value.integer).assertEqual(-7);
    });

    it('解出字节串', () => {
      const value = decode('4:spam');
      expect(value === undefined ? '' : value.text()).assertEqual('spam');
    });

    it('解出空字节串', () => {
      const value = decode('0:');
      expect(value === undefined ? 'x' : value.text()).assertEqual('');
    });

    it('解出列表', () => {
      const value = decode('l4:spami42ee');
      expect(value === undefined ? -1 : value.items.length).assertEqual(2);
      expect(value === undefined ? '' : value.items[0].text()).assertEqual('spam');
      expect(value === undefined ? 0 : value.items[1].integer).assertEqual(42);
    });

    it('解出嵌套字典，并能按键取值', () => {
      const value = decode('d3:bar4:spam3:fooi42ee');
      expect(value === undefined ? '' : value.kind).assertEqual(BencodeKind.DICTIONARY);
      expect(value === undefined ? '' : value.textOf('bar')).assertEqual('spam');
      expect(value === undefined ? 0 : value.integerOf('foo', 0)).assertEqual(42);
      // 不存在的键既不能抛错，也不能返回一个看似有效的值。
      expect(value === undefined ? 'x' : value.textOf('missing')).assertEqual('');
      expect(value === undefined ? -1 : value.integerOf('missing', -1)).assertEqual(-1);
    });

    it('字节串按 UTF-8 还原文本', () => {
      const value = Bencode.decode(bytes('崩坏：星穹铁道'));
      expect(value === undefined ? '' : value.text()).assertEqual('崩坏：星穹铁道');
    });

    it('长度按字节算，不按字符算', () => {
      // 中文一字三字节，长度写错就会解出乱码或越界。
      const payload = Base64.utf8Bytes('测试');
      expect(payload.length).assertEqual(6);
      const value = Bencode.decode(bytes('测试'));
      expect(value === undefined ? '' : value.text()).assertEqual('测试');
    });
  });

  describe('Bencode.decode 拒绝非法输入', () => {
    it('空输入', () => {
      expect(Bencode.decode(new Uint8Array(0)) === undefined).assertTrue();
    });

    it('无法识别的起始字节', () => {
      expect(decode('x') === undefined).assertTrue();
    });

    it('整数没有结束符', () => {
      expect(decode('i42') === undefined).assertTrue();
    });

    it('整数没有数字', () => {
      expect(decode('ie') === undefined).assertTrue();
    });

    it('字节串缺少冒号', () => {
      expect(decode('4spam') === undefined).assertTrue();
    });

    it('字节串长度超出剩余数据', () => {
      expect(decode('9:spam') === undefined).assertTrue();
    });

    it('字典的键不是字节串', () => {
      expect(decode('di1e4:spame') === undefined).assertTrue();
    });

    it('截断的列表', () => {
      expect(decode('l4:spam') === undefined).assertTrue();
    });

    it('尾部有多余字节', () => {
      // 通常说明选错了文件，而不是用户少粘了一段。
      expect(decode('i42ei43e') === undefined).assertTrue();
    });

    it('嵌套过深时失败而不是爆栈', () => {
      // 40 层已超过 32 层的上限。
      let deep = '';
      for (let i = 0; i < 40; i++) {
        deep += 'l';
      }
      for (let i = 0; i < 40; i++) {
        deep += 'e';
      }
      expect(decode(deep) === undefined).assertTrue();
    });

    it('上限之内的嵌套仍然可用', () => {
      let shallow = '';
      for (let i = 0; i < 16; i++) {
        shallow += 'l';
      }
      shallow += 'i1e';
      for (let i = 0; i < 16; i++) {
        shallow += 'e';
      }
      expect(decode(shallow) === undefined).assertFalse();
    });
  });

  describe('BencodeValue 的取值辅助', () => {
    it('类型不符时返回兜底值而不是抛错', () => {
      const value = decode('d1:ai1ee');
      expect(value === undefined ? 'x' : value.textOf('a')).assertEqual('');
      expect(value === undefined ? -1 : value.listOf('a').length).assertEqual(0);
    });

    it('非字节串调用 text() 得到空串', () => {
      const value = decode('i1e');
      expect(value === undefined ? 'x' : value.text()).assertEqual('');
    });

    it('字典的键与值一一对应，顺序保持', () => {
      const value = decode('d1:ai1e1:bi2ee');
      expect(value === undefined ? 0 : value.keys.length).assertEqual(2);
      expect(value === undefined ? '' : value.keys[0]).assertEqual('a');
      expect(value === undefined ? '' : value.keys[1]).assertEqual('b');
      expect(value === undefined ? 0 : value.integerOf('b', 0)).assertEqual(2);
    });

    it('可以手工构造值，不必每处都解码', () => {
      const made = BencodeValue.ofInteger(5);
      expect(made.kind).assertEqual(BencodeKind.INTEGER);
      expect(made.integer).assertEqual(5);
      expect(BencodeValue.ofBytes(text('ab')).text()).assertEqual('ab');
    });

    it('字典的构造顺序不影响按键查找', () => {
      const value = dictionary([bytes('b'), integer(2), bytes('a'), integer(1)]);
      const decoded = Bencode.decode(value);
      expect(decoded === undefined ? 0 : decoded.integerOf('a', 0)).assertEqual(1);
      expect(decoded === undefined ? 0 : decoded.integerOf('b', 0)).assertEqual(2);
    });
  });
}
