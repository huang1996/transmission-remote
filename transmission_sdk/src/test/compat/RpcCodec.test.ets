// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for the two wire codecs.
 *
 * These pin down the exact bytes that go over the wire for each dialect, which
 * is the part of the SDK a formatting change could silently break.
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { LegacyCodec, ModernCodec, RpcCall, RpcErrorInfo, RpcOutcome } from '../../main/ets/compat/RpcCodec';
import { ApiStyle } from '../../main/ets/compat/ApiStyle';
import { Json, JsonArray, JsonObject, JsonValue } from '../../main/ets/util/Json';
import { RpcMethod } from '../../main/ets/constants/RpcMethods';
import { RpcErrorCode, TransmissionError, TransmissionErrorKind } from '../../main/ets/error/TransmissionError';
import { RpcFakes } from '../helpers/RpcFakes';

/** Builds request parameters with a nested torrent filter. */
function torrentGetParams(): JsonObject {
  const params: JsonObject = {};
  params['ids'] = [7, 'hash'] as JsonArray;
  params['fields'] = ['id', 'name', 'download_dir'] as JsonArray;
  params['format'] = 'objects';
  return params;
}

export default function rpcCodecTest(): void {
  describe('ModernCodec request encoding', () => {
    it('reports the modern dialect', () => {
      expect(ModernCodec.instance().style).assertEqual(ApiStyle.MODERN);
    });

    it('uses the canonical method name verbatim', () => {
      expect(ModernCodec.instance().encodeMethodName(RpcMethod.TORRENT_GET)).assertEqual('torrent_get');
      expect(ModernCodec.instance().encodeMethodName(RpcMethod.QUEUE_MOVE_BOTTOM)).assertEqual('queue_move_bottom');
    });

    it('wraps the call in a JSON-RPC 2.0 envelope', () => {
      const encoded = ModernCodec.instance().encodeRequest(new RpcCall(RpcMethod.TORRENT_GET, torrentGetParams()), 42);
      expect(Json.getString(encoded, 'jsonrpc')).assertEqual('2.0');
      expect(Json.getString(encoded, 'method')).assertEqual('torrent_get');
      expect(Json.getNumber(encoded, 'id')).assertEqual(42);
      expect(Json.has(encoded, 'params')).assertTrue();
      expect(Json.has(encoded, 'arguments')).assertFalse();
      expect(Json.has(encoded, 'tag')).assertFalse();
    });

    it('forwards canonical parameter keys untouched', () => {
      const encoded = ModernCodec.instance().encodeRequest(new RpcCall(RpcMethod.TORRENT_GET, torrentGetParams()), 1);
      const params = Json.getObject(encoded, 'params');
      // `download_dir` must survive verbatim: in this dialect it is already the
      // wire name, and rewriting it would break `torrent_get`.
      expect(Json.getStringArray(params, 'fields')).assertDeepEquals(['id', 'name', 'download_dir']);
    });

    it('omits params entirely when there are none', () => {
      const encoded = ModernCodec.instance().encodeRequest(new RpcCall(RpcMethod.SESSION_STATS), 7);
      expect(Json.has(encoded, 'params')).assertFalse();
      expect(Json.getNumber(encoded, 'id')).assertEqual(7);
    });

    it('always sends an id so the server replies rather than treating it as a notification', () => {
      const encoded = ModernCodec.instance().encodeRequest(new RpcCall(RpcMethod.SESSION_CLOSE), 3);
      expect(Json.getNumber(encoded, 'id')).assertEqual(3);
    });
  });

  describe('ModernCodec response decoding', () => {
    it('decodes a successful response', () => {
      const outcome = ModernCodec.instance().decodeResponse(RpcFakes.modernSuccess({ version: '4.1.0' }, 9));
      expect(outcome.isSuccess).assertTrue();
      expect(outcome.id).assertEqual(9);
      expect(Json.getString(outcome.resultOrEmpty, 'version')).assertEqual('4.1.0');
    });

    it('treats a missing result as an empty object', () => {
      const outcome = ModernCodec.instance().decodeResponse(RpcFakes.modernSuccess(Json.emptyObject(), 1));
      expect(outcome.isSuccess).assertTrue();
      expect(Json.isEmpty(outcome.resultOrEmpty)).assertTrue();
    });

    it('decodes an error object with its data payload', () => {
      const data: JsonObject = {};
      data['error_string'] = "Couldn't test port";
      const extra: JsonObject = {};
      extra['ip_protocol'] = 'ipv6';
      data['result'] = extra;

      const outcome = ModernCodec.instance().decodeResponse(
        RpcFakes.modernError(RpcErrorCode.HTTP_ERROR, 'HTTP error from backend service', 5, data),
      );
      expect(outcome.isSuccess).assertFalse();
      expect(outcome.id).assertEqual(5);
      const error = outcome.error;
      expect(error === undefined).assertFalse();
      if (error !== undefined) {
        expect(error.code).assertEqual(RpcErrorCode.HTTP_ERROR);
        expect(error.rawCode).assertEqual(8);
        expect(error.message).assertEqual('HTTP error from backend service');
        expect(error.detail).assertEqual("Couldn't test port");
        expect(Json.getString(error.result, 'ip_protocol')).assertEqual('ipv6');
      }
    });

    it('maps an unrecognised error code to UNKNOWN but keeps the raw value', () => {
      const outcome = ModernCodec.instance().decodeResponse(RpcFakes.modernError(-32000, 'custom'));
      const error = outcome.error;
      expect(error === undefined ? RpcErrorCode.SUCCESS : error.code).assertEqual(RpcErrorCode.UNKNOWN);
      expect(error === undefined ? 0 : error.rawCode).assertEqual(-32000);
    });

    it('falls back to the canonical text for the code when the server omits a message', () => {
      const body: JsonObject = {};
      body['jsonrpc'] = '2.0';
      body['error'] = RpcFakes.modernErrorObject(RpcErrorCode.INVALID_PARAMS);
      body['id'] = 1;
      const outcome = ModernCodec.instance().decodeResponse(body);
      expect(outcome.error === undefined ? '' : outcome.error.message).assertEqual('Invalid params');
      expect(outcome.error === undefined ? RpcErrorCode.UNKNOWN : outcome.error.code).assertEqual(
        RpcErrorCode.INVALID_PARAMS,
      );
    });

    it('flags the envelope shape so the client can switch dialect', () => {
      // The shape is the dependable dialect signal; the error text is not.
      const legacySuccess = ModernCodec.instance().decodeResponse(
        RpcFakes.legacySuccess({ version: '4.0.6' }),
      );
      expect(legacySuccess.legacyEnvelope).assertTrue();
      expect(legacySuccess.isSuccess).assertTrue();

      const legacyError = ModernCodec.instance().decodeResponse(
        RpcFakes.legacyError('method name not recognized'),
      );
      expect(legacyError.legacyEnvelope).assertTrue();

      const modern = ModernCodec.instance().decodeResponse(RpcFakes.modernSuccess({ version: '4.1.0' }, 1));
      expect(modern.legacyEnvelope).assertFalse();
    });

    it('also accepts a legacy-shaped reply from a pre-4.1.0 server', () => {
      const outcome = ModernCodec.instance().decodeResponse(
        RpcFakes.legacyError('no method name'),
      );
      expect(outcome.isSuccess).assertFalse();
      expect(outcome.error === undefined ? RpcErrorCode.SUCCESS : outcome.error.code).assertEqual(
        RpcErrorCode.METHOD_NOT_FOUND,
      );
    });

    it('rejects a body with neither result nor error', () => {
      const body: JsonObject = {};
      body['jsonrpc'] = '2.0';
      body['id'] = 1;
      expect(() => ModernCodec.instance().decodeResponse(body)).assertThrowError();
    });

    it('rejects a non-object body', () => {
      expect(() => ModernCodec.instance().decodeResponse('not an object')).assertThrowError();
      expect(() => ModernCodec.instance().decodeResponse([] as JsonArray)).assertThrowError();
    });
  });

  describe('LegacyCodec request encoding', () => {
    it('reports the legacy dialect', () => {
      expect(LegacyCodec.instance().style).assertEqual(ApiStyle.LEGACY);
    });

    it('kebab-cases every method name', () => {
      const codec = LegacyCodec.instance();
      expect(codec.encodeMethodName(RpcMethod.TORRENT_GET)).assertEqual('torrent-get');
      expect(codec.encodeMethodName(RpcMethod.SESSION_GET)).assertEqual('session-get');
      expect(codec.encodeMethodName(RpcMethod.QUEUE_MOVE_TOP)).assertEqual('queue-move-top');
      expect(codec.encodeMethodName(RpcMethod.TORRENT_SET_LOCATION)).assertEqual('torrent-set-location');
      expect(codec.encodeMethodName(RpcMethod.TORRENT_RENAME_PATH)).assertEqual('torrent-rename-path');
    });

    it('uses the arguments/tag envelope and the legacy key spellings', () => {
      const encoded = LegacyCodec.instance().encodeRequest(new RpcCall(RpcMethod.TORRENT_GET, torrentGetParams()), 11);
      expect(Json.getString(encoded, 'method')).assertEqual('torrent-get');
      expect(Json.getNumber(encoded, 'tag')).assertEqual(11);
      expect(Json.has(encoded, 'jsonrpc')).assertFalse();
      expect(Json.has(encoded, 'params')).assertFalse();
      expect(Json.has(encoded, 'id')).assertFalse();

      const args = Json.getObject(encoded, 'arguments');
      expect(Json.getStringArray(args, 'fields')).assertDeepEquals(['id', 'name', 'downloadDir']);
      expect(Json.getArray(args, 'ids')).assertDeepEquals([7, 'hash']);
    });

    it('always sends an arguments object, even when empty', () => {
      const encoded = LegacyCodec.instance().encodeRequest(new RpcCall(RpcMethod.SESSION_STATS), 2);
      expect(Json.has(encoded, 'arguments')).assertTrue();
      expect(Json.isEmpty(Json.getObject(encoded, 'arguments'))).assertTrue();
    });

    it('translates session parameter keys with the session spelling', () => {
      const params: JsonObject = {};
      params['download_dir'] = '/srv';
      params['peer_port'] = 51413;
      const encoded = LegacyCodec.instance().encodeRequest(new RpcCall(RpcMethod.SESSION_SET, params), 1);
      const args = Json.getObject(encoded, 'arguments');
      expect(Json.getString(args, 'download-dir')).assertEqual('/srv');
      expect(Json.getNumber(args, 'peer-port')).assertEqual(51413);
    });
  });

  describe('LegacyCodec response decoding', () => {
    it('canonicalises the arguments of a successful response', () => {
      const args: JsonObject = {};
      args['version'] = '4.0.6';
      args['download-dir'] = '/srv/downloads';
      args['peer-port'] = 51413;
      args['rpc-version-semver'] = '5.3.0';
      const outcome = LegacyCodec.instance().decodeResponse(RpcFakes.legacySuccess(args, 8));
      expect(outcome.isSuccess).assertTrue();
      expect(outcome.id).assertEqual(8);
      const result = outcome.resultOrEmpty;
      expect(Json.getString(result, 'version')).assertEqual('4.0.6');
      expect(Json.getString(result, 'download_dir')).assertEqual('/srv/downloads');
      expect(Json.getNumber(result, 'peer_port')).assertEqual(51413);
      expect(Json.getString(result, 'rpc_version_semver')).assertEqual('5.3.0');
    });

    it('converts the legacy wanted integers into booleans', () => {
      const torrent: JsonObject = {};
      torrent['wanted'] = [1, 0] as JsonArray;
      const args: JsonObject = {};
      args['torrents'] = [torrent] as JsonArray;
      const outcome = LegacyCodec.instance().decodeResponse(RpcFakes.legacySuccess(args));
      const torrents = Json.getArray(outcome.resultOrEmpty, 'torrents');
      const first = Json.asObject(torrents === undefined ? undefined : torrents[0]);
      expect(Json.getArray(first, 'wanted')).assertDeepEquals([true, false]);
    });

    it('converts the legacy encryption spelling', () => {
      const args: JsonObject = {};
      args['encryption'] = 'tolerated';
      const outcome = LegacyCodec.instance().decodeResponse(RpcFakes.legacySuccess(args));
      expect(Json.getString(outcome.resultOrEmpty, 'encryption')).assertEqual('allowed');
    });

    it('maps a legacy error string onto a normalised code', () => {
      const outcome = LegacyCodec.instance().decodeResponse(RpcFakes.legacyError('no method name'));
      expect(outcome.isSuccess).assertFalse();
      const error = outcome.error;
      expect(error === undefined ? RpcErrorCode.SUCCESS : error.code).assertEqual(RpcErrorCode.METHOD_NOT_FOUND);
      expect(error === undefined ? '' : error.message).assertEqual('Method not found');
      expect(error === undefined ? '' : error.detail).assertEqual('no method name');
    });

    it('keeps an unrecognised legacy error message verbatim', () => {
      const outcome = LegacyCodec.instance().decodeResponse(RpcFakes.legacyError('something brand new'));
      const error = outcome.error;
      expect(error === undefined ? RpcErrorCode.SUCCESS : error.code).assertEqual(RpcErrorCode.UNKNOWN);
      expect(error === undefined ? '' : error.message).assertEqual('something brand new');
    });

    it('accepts a JSON-RPC style error object too', () => {
      const body: JsonObject = {};
      body['arguments'] = Json.emptyObject();
      body['error'] = RpcFakes.modernErrorObject(RpcErrorCode.INVALID_PARAMS, 'Invalid params');
      body['tag'] = 4;
      const outcome = LegacyCodec.instance().decodeResponse(body);
      expect(outcome.isSuccess).assertFalse();
      expect(outcome.error === undefined ? RpcErrorCode.SUCCESS : outcome.error.code).assertEqual(
        RpcErrorCode.INVALID_PARAMS,
      );
    });

    it('rejects a response without a result field', () => {
      const body: JsonObject = {};
      body['arguments'] = Json.emptyObject();
      body['tag'] = 1;
      expect(() => LegacyCodec.instance().decodeResponse(body)).assertThrowError();
    });

    it('tolerates a missing arguments object on success', () => {
      const body: JsonObject = {};
      body['result'] = 'success';
      body['tag'] = 1;
      const outcome = LegacyCodec.instance().decodeResponse(body);
      expect(outcome.isSuccess).assertTrue();
      expect(Json.isEmpty(outcome.resultOrEmpty)).assertTrue();
    });
  });

  describe('Batch handling', () => {
    it('wraps encoded requests in a JSON array', () => {
      const codec = ModernCodec.instance();
      const first = codec.encodeRequest(new RpcCall(RpcMethod.SESSION_GET), 1);
      const second = codec.encodeRequest(new RpcCall(RpcMethod.SESSION_STATS), 2);
      const batch = Json.asArray(codec.encodeBatch([first, second]));
      expect(batch === undefined ? -1 : batch.length).assertEqual(2);
    });

    it('decodes every element of a batch response', () => {
      const responses: JsonValue[] = [
        RpcFakes.modernSuccess({ version: '4.1.0' }, 1),
        RpcFakes.modernError(RpcErrorCode.INVALID_PARAMS, 'Invalid params', 2),
        RpcFakes.modernSuccess({ torrents: [] as JsonArray }, 3),
      ];
      const outcomes = ModernCodec.instance().decodeBatch(responses);
      expect(outcomes.length).assertEqual(3);
      expect(outcomes[0].isSuccess).assertTrue();
      expect(outcomes[1].isSuccess).assertFalse();
      expect(outcomes[2].isSuccess).assertTrue();
    });

    it('decodes a legacy batch response too', () => {
      const responses: JsonValue[] = [
        RpcFakes.legacySuccess({ version: '4.0.6' }, 1),
        RpcFakes.legacyError('no method name', Json.emptyObject(), 2),
      ];
      const outcomes = LegacyCodec.instance().decodeBatch(responses);
      expect(outcomes.length).assertEqual(2);
      expect(outcomes[0].isSuccess).assertTrue();
      expect(outcomes[1].error === undefined ? RpcErrorCode.SUCCESS : outcomes[1].error.code).assertEqual(
        RpcErrorCode.METHOD_NOT_FOUND,
      );
    });

    it('treats a non-array batch body as a single response', () => {
      const outcomes = ModernCodec.instance().decodeBatch(RpcFakes.modernSuccess(Json.emptyObject(), 1));
      expect(outcomes.length).assertEqual(1);
    });
  });

  describe('RpcOutcome', () => {
    it('converts a failure into a TransmissionError', () => {
      const outcome = LegacyCodec.instance().decodeResponse(RpcFakes.legacyError('no location'));
      const error: TransmissionError = outcome.toError('torrent_set_location http://host/rpc');
      expect(error.rpcCode).assertEqual(RpcErrorCode.INVALID_PARAMS);
      expect(error.request).assertEqual('torrent_set_location http://host/rpc');
      expect(error.kind).assertEqual(TransmissionErrorKind.RPC);
    });

    it('exposes the result or an empty object', () => {
      const withoutResult = RpcOutcome.success(1, undefined);
      expect(withoutResult.isSuccess).assertTrue();
      expect(Json.isEmpty(withoutResult.resultOrEmpty)).assertTrue();

      const withResult: JsonObject = {};
      withResult['version'] = '4.1.0';
      const outcome = RpcOutcome.success(1, withResult);
      expect(Json.getString(outcome.resultOrEmpty, 'version')).assertEqual('4.1.0');
    });

    it('carries an error info object through RpcOutcome.failure', () => {
      const info = new RpcErrorInfo(RpcErrorCode.SYSTEM_ERROR, 5, 'system error');
      const outcome = RpcOutcome.failure(3, info);
      expect(outcome.isSuccess).assertFalse();
      expect(outcome.id).assertEqual(3);
      expect(outcome.error === undefined ? '' : outcome.error.message).assertEqual('system error');
    });
  });
}
