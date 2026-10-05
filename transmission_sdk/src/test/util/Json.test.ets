// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for the defensive JSON accessors.
 *
 * Every accessor is used while parsing server payloads whose shape varies with
 * the Transmission version, so the contract that matters here is "never throws,
 * always returns a usable value".
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { Json, JsonArray, JsonObject, JsonObjectBuilder, JsonValue } from '../../main/ets/util/Json';

/** Builds an object with a deliberately mixed bag of value types. */
function sampleObject(): JsonObject {
  const object: JsonObject = {};
  object['text'] = 'value';
  object['count'] = 42;
  object['ratio'] = 1.5;
  object['flag'] = true;
  object['nothing'] = null;
  object['list'] = ['a', 'b'] as JsonArray;
  object['numbers'] = [1, 2, 3] as JsonArray;
  const nested: JsonObject = {};
  nested['inner'] = 'deep';
  object['nested'] = nested;
  return object;
}

export default function jsonTest(): void {
  describe('Json readers', () => {
    it('classifies objects, arrays and scalars without throwing', () => {
      const object = sampleObject();
      expect(Json.isObject(Json.get(object, 'nested'))).assertTrue();
      expect(Json.isObject(Json.get(object, 'list'))).assertFalse();
      expect(Json.isArray(Json.get(object, 'list'))).assertTrue();
      expect(Json.isObject(undefined)).assertFalse();
      expect(Json.isObject(null)).assertFalse();
      expect(Json.isArray(null)).assertFalse();
    });

    it('returns undefined rather than throwing for mismatched types', () => {
      const object = sampleObject();
      expect(Json.asObject(Json.get(object, 'text'))).assertUndefined();
      expect(Json.asString(Json.get(object, 'count'))).assertUndefined();
      expect(Json.asNumber(Json.get(object, 'text'))).assertUndefined();
      expect(Json.asBoolean(Json.get(object, 'text'))).assertUndefined();
      expect(Json.asArray(Json.get(object, 'nested'))).assertUndefined();
    });

    it('reads every scalar type', () => {
      const object = sampleObject();
      expect(Json.getString(object, 'text')).assertEqual('value');
      expect(Json.getNumber(object, 'count')).assertEqual(42);
      expect(Json.getNumber(object, 'ratio')).assertEqual(1.5);
      expect(Json.getBoolean(object, 'flag')).assertTrue();
    });

    it('tolerates the legacy 0/1 boolean encoding', () => {
      const object: JsonObject = {};
      object['one'] = 1;
      object['zero'] = 0;
      expect(Json.getBoolean(object, 'one')).assertTrue();
      expect(Json.getBoolean(object, 'zero')).assertFalse();
      expect(Json.asLooseBoolean(2)).assertUndefined();
    });

    it('applies fallbacks for absent keys', () => {
      const object = sampleObject();
      expect(Json.getNumber(object, 'missing', -1)).assertEqual(-1);
      expect(Json.getString(object, 'missing', 'fallback')).assertEqual('fallback');
      expect(Json.getBoolean(object, 'missing', true)).assertTrue();
      expect(Json.getString(object, 'missing')).assertEqual('');
      expect(Json.get(object, 'missing')).assertUndefined();
      expect(Json.get(undefined, 'anything')).assertUndefined();
    });

    it('reports key presence without relying on hasOwnProperty', () => {
      const object = sampleObject();
      expect(Json.has(object, 'text')).assertTrue();
      expect(Json.has(object, 'missing')).assertFalse();
      expect(Json.has(undefined, 'text')).assertFalse();
    });

    it('converts arrays while skipping malformed entries', () => {
      const nested: JsonObject = {};
      nested['id'] = 1;
      const object: JsonObject = {};
      object['strings'] = ['a', 7, 'b', null] as JsonArray;
      object['numbers'] = [1, 'x', 2] as JsonArray;
      object['objects'] = [nested, 5] as JsonArray;
      expect(Json.getStringArray(object, 'strings')).assertDeepEquals(['a', 'b']);
      expect(Json.toNumberArray(Json.getArray(object, 'numbers'))).assertDeepEquals([1, 2]);
      expect(Json.toObjectArray(Json.getArray(object, 'objects')).length).assertEqual(1);
      expect(Json.toStringArray(undefined).length).assertEqual(0);
    });

    it('enumerates keys and reports emptiness', () => {
      const object = sampleObject();
      expect(Json.keys(object).length).assertEqual(8);
      expect(Json.keys(undefined).length).assertEqual(0);
      expect(Json.isEmpty(object)).assertFalse();
      expect(Json.isEmpty(Json.emptyObject())).assertTrue();
      expect(Json.isEmpty(undefined)).assertTrue();
    });

    it('round-trips through parse and stringify', () => {
      const text = '{"a":[1,2,{"b":"c"}],"d":null}';
      const parsed = Json.asObject(Json.parse(text));
      expect(Json.stringify(Json.parse(text))).assertEqual(text);
      const array = Json.getArray(parsed, 'a');
      expect(array === undefined ? -1 : array.length).assertEqual(3);
      const nested = Json.asObject(array === undefined ? undefined : array[2]);
      expect(Json.getString(nested, 'b')).assertEqual('c');
      expect(Json.get(parsed, 'd')).assertNull();
    });

    it('throws a SyntaxError for malformed JSON', () => {
      expect(() => Json.parse('{not json')).assertThrowError();
    });

    it('compares JSON values structurally', () => {
      const left: JsonObject = {};
      left['a'] = 1;
      left['b'] = [1, 2] as JsonArray;
      const right: JsonObject = {};
      right['a'] = 1;
      right['b'] = [1, 2] as JsonArray;
      const different: JsonObject = {};
      different['a'] = 1;
      different['b'] = [2, 1] as JsonArray;
      expect(Json.deepEquals(left, right)).assertTrue();
      expect(Json.deepEquals(left, different)).assertFalse();
      expect(Json.deepEquals(left, undefined)).assertFalse();
      expect(Json.deepEquals(null, null)).assertTrue();
      expect(Json.deepEquals('a', 'a')).assertTrue();
    });

    it('clones deeply so the copy is detached', () => {
      const inner: JsonObject = {};
      inner['value'] = 1;
      const original: JsonObject = {};
      original['nested'] = inner;
      const copy = Json.asObject(Json.clone(original));
      expect(copy !== undefined).assertTrue();
      if (copy !== undefined) {
        const nested = Json.getObject(copy, 'nested');
        if (nested !== undefined) {
          nested['value'] = 99;
        }
        expect(Json.getNumber(Json.getObject(original, 'nested'), 'value')).assertEqual(1);
      }
    });
  });

  describe('JsonObjectBuilder', () => {
    it('omits undefined values so absent settings stay absent', () => {
      const built = new JsonObjectBuilder()
        .set('present', 'yes')
        .set('absent', undefined)
        .setNumber('count', 3)
        .setNumber('nothing', undefined)
        .build();
      expect(Json.get(built, 'present')).assertEqual('yes');
      expect(Json.has(built, 'absent')).assertFalse();
      expect(Json.getNumber(built, 'count')).assertEqual(3);
      expect(Json.has(built, 'nothing')).assertFalse();
    });

    it('distinguishes empty arrays per setter', () => {
      const built = new JsonObjectBuilder()
        .setArray('droppedWhenEmpty', [] as JsonArray)
        .setAlways('keptWhenEmpty', [] as JsonArray)
        .setNonEmpty('droppedWhenBlank', '')
        .build();
      expect(Json.has(built, 'droppedWhenEmpty')).assertFalse();
      expect(Json.has(built, 'keptWhenEmpty')).assertTrue();
      expect(Json.has(built, 'droppedWhenBlank')).assertFalse();
    });

    it('drops empty objects but keeps non-empty ones', () => {
      const nested: JsonObject = {};
      nested['key'] = 'value';
      const built = new JsonObjectBuilder().setObject('empty', Json.emptyObject()).setObject('nested', nested).build();
      expect(Json.has(built, 'empty')).assertFalse();
      expect(Json.has(built, 'nested')).assertTrue();
    });

    it('reports whether a key was set', () => {
      const builder = new JsonObjectBuilder();
      expect(builder.has('x')).assertFalse();
      builder.set('x', 1);
      expect(builder.has('x')).assertTrue();
    });

    it('create() returns an independent builder each time', () => {
      const first = JsonObjectBuilder.create().set('a', 1);
      const second = JsonObjectBuilder.create().set('b', 2);
      expect(Json.has(first.build(), 'b')).assertFalse();
      expect(Json.has(second.build(), 'a')).assertFalse();
    });
  });
}
