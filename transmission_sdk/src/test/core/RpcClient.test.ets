// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for the RPC engine.
 *
 * `RpcClient` owns the protocol plumbing: the CSRF handshake, dialect
 * negotiation, HTTP/RPC error mapping and batch dispatch. Driving it directly
 * with a scripted {@link FakeTransport} lets every branch of that state machine
 * be observed without a server.
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { RpcClient } from '../../main/ets/core/RpcClient';
import { TransmissionConfig } from '../../main/ets/core/TransmissionConfig';
import { RpcCall } from '../../main/ets/compat/RpcCodec';
import { ApiStyle, ApiStyleMode } from '../../main/ets/compat/ApiStyle';
import { StyleNegotiator } from '../../main/ets/compat/StyleNegotiator';
import { RpcMethod } from '../../main/ets/constants/RpcMethods';
import { HttpStatus } from '../../main/ets/constants/WireProtocol';
import { Json, JsonObject, JsonValue } from '../../main/ets/util/Json';
import { Base64 } from '../../main/ets/util/Base64';
import { RpcErrorCode, TransmissionError, TransmissionErrorKind } from '../../main/ets/error/TransmissionError';
import { FakeTransport, ScriptedResponse } from '../helpers/FakeTransport';
import { RpcFakes } from '../helpers/RpcFakes';

/** Endpoint used by every client in this suite. */
const TEST_URL: string = 'http://127.0.0.1:9091/transmission/rpc';

/** Builds a client with an injected transport and negotiation mode. */
function clientWith(transport: FakeTransport, mode: ApiStyleMode, sessionId?: string): RpcClient {
  const config = TransmissionConfig.of(TEST_URL)
    .withApiStyleMode(mode)
    .withSessionId(sessionId);
  return new RpcClient(config, transport, new StyleNegotiator(mode));
}

/** Parsed body of the `index`-th request seen by the transport. */
function bodyAt(transport: FakeTransport, index: number): JsonObject {
  return transport.requests[index].json;
}

/** A `session_get` result whose fields resolve negotiation to JSON-RPC 2.0. */
function sessionResult(): JsonObject {
  const result: JsonObject = {};
  result['version'] = '4.1.0';
  result['rpc_version_semver'] = '6.0.0';
  result['download_dir'] = '/downloads';
  result['peer_port'] = 51413;
  result['encryption'] = 'allowed';
  return result;
}

/** A result carrying only a server version string. */
function versionResult(version: string): JsonObject {
  const result: JsonObject = {};
  result['version'] = version;
  return result;
}

/** Runs a `session_get` and returns the dialect the client settled on. */
async function negotiatedStyle(result: JsonObject): Promise<ApiStyle> {
  const transport = FakeTransport.create();
  transport.enqueueJson(RpcFakes.modernSuccess(result, 1));
  const client = clientWith(transport, ApiStyleMode.AUTO, 'cached-session');
  await client.call(RpcMethod.SESSION_GET);
  return client.currentStyle;
}

export default function rpcClientTest(): void {
  describe('RpcClient negotiation', () => {
    it('performs the modern CSRF handshake and keeps the modern dialect', async () => {
      const transport = FakeTransport.create();
      transport.enqueueCsrf('sess-modern', '6.0.0');
      transport.enqueueJson(RpcFakes.modernSuccess(sessionResult(), 1));
      const client = clientWith(transport, ApiStyleMode.AUTO);

      const result = await client.call(RpcMethod.SESSION_GET);

      expect(transport.callCount).assertEqual(2);
      const first = bodyAt(transport, 0);
      expect(Json.getString(first, 'jsonrpc')).assertEqual('2.0');
      expect(Json.getString(first, 'method')).assertEqual('session_get');
      expect(Json.getNumber(first, 'id') > 0).assertTrue();
      expect(transport.requests[0].header('x-transmission-session-id')).assertUndefined();
      expect(transport.requests[1].header('x-transmission-session-id')).assertEqual('sess-modern');
      expect(client.currentStyle).assertEqual(ApiStyle.MODERN);
      expect(Json.getString(result, 'version')).assertEqual('4.1.0');
    });

    it('downgrades to the legacy dialect when the 409 carries no version header', async () => {
      const transport = FakeTransport.create();
      transport.enqueueCsrf('sess-legacy');
      transport.enqueueJson(RpcFakes.legacySuccess(versionResult('4.0.6'), 1));
      const client = clientWith(transport, ApiStyleMode.AUTO);

      await client.call(RpcMethod.SESSION_GET);

      expect(transport.callCount).assertEqual(2);
      const retry = bodyAt(transport, 1);
      expect(Json.getString(retry, 'method')).assertEqual('session-get');
      expect(Json.get(retry, 'arguments') === undefined).assertFalse();
      expect(Json.getNumber(retry, 'tag') > 0).assertTrue();
      expect(Json.has(retry, 'jsonrpc')).assertFalse();
      expect(client.currentStyle).assertEqual(ApiStyle.LEGACY);
    });

    it('downgrades on a legacy-shaped reply whose wording it does not recognise', async () => {
      // Regression: Transmission 4.0.x answers a JSON-RPC request with
      // {"arguments":{},"result":"method name not recognized"}. Classifying that
      // as UNKNOWN instead of METHOD_NOT_FOUND made the downgrade never happen,
      // and the raw reply surfaced as an error instead.
      const transport = FakeTransport.create();
      transport.enqueueJson(RpcFakes.legacyError('method name not recognized'));
      transport.enqueueJson(RpcFakes.legacySuccess(versionResult('4.0.6'), 1));
      const client = clientWith(transport, ApiStyleMode.AUTO, 'cached-session');

      const result = await client.call(RpcMethod.SESSION_GET);

      expect(transport.callCount).assertEqual(2);
      expect(Json.getString(bodyAt(transport, 0), 'method')).assertEqual('session_get');
      expect(Json.getString(bodyAt(transport, 1), 'method')).assertEqual('session-get');
      expect(client.currentStyle).assertEqual(ApiStyle.LEGACY);
      expect(Json.getString(result, 'version')).assertEqual('4.0.6');
    });

    it('downgrades to the legacy dialect when a cached session id gets METHOD_NOT_FOUND', async () => {
      const transport = FakeTransport.create();
      transport.enqueueJson(RpcFakes.modernError(RpcErrorCode.METHOD_NOT_FOUND, 'Method not found', 1));
      transport.enqueueJson(RpcFakes.legacySuccess(versionResult('4.0.6'), 1));
      const client = clientWith(transport, ApiStyleMode.AUTO, 'abc');

      await client.call(RpcMethod.SESSION_GET);

      expect(transport.callCount).assertEqual(2);
      expect(Json.getString(bodyAt(transport, 0), 'method')).assertEqual('session_get');
      expect(Json.getString(bodyAt(transport, 1), 'method')).assertEqual('session-get');
      expect(client.currentStyle).assertEqual(ApiStyle.LEGACY);
    });

    it('does not downgrade when the modern dialect is forced', async () => {
      const transport = FakeTransport.create();
      transport.enqueueJson(RpcFakes.legacySuccess(versionResult('4.0.6'), 1));
      const client = clientWith(transport, ApiStyleMode.MODERN, 'cached-session');

      await client.call(RpcMethod.SESSION_GET);

      expect(transport.callCount).assertEqual(1);
      expect(Json.getString(bodyAt(transport, 0), 'method')).assertEqual('session_get');
      expect(client.currentStyle).assertEqual(ApiStyle.MODERN);
    });

    it('sends the legacy envelope on the very first request when the legacy dialect is forced', async () => {
      const transport = FakeTransport.create();
      transport.enqueueJson(RpcFakes.legacySuccess(versionResult('4.0.6'), 1));
      const client = clientWith(transport, ApiStyleMode.LEGACY, 'cached-session');

      await client.call(RpcMethod.SESSION_GET);

      const body = bodyAt(transport, 0);
      expect(Json.getString(body, 'method')).assertEqual('session-get');
      expect(Json.has(body, 'arguments')).assertTrue();
      expect(Json.getNumber(body, 'tag') > 0).assertTrue();
      expect(Json.has(body, 'jsonrpc')).assertFalse();
      expect(client.currentStyle).assertEqual(ApiStyle.LEGACY);
    });
  });

  describe('RpcClient error mapping', () => {
    it('maps HTTP 401 onto an authentication failure', async () => {
      const transport = FakeTransport.create();
      transport.enqueue(ScriptedResponse.unauthorized());
      const client = clientWith(transport, ApiStyleMode.MODERN, 'cached-session');

      try {
        await client.call(RpcMethod.SESSION_GET);
        expect(true).assertFalse();
      } catch (error) {
        const failure = error as TransmissionError;
        expect(failure.kind).assertEqual(TransmissionErrorKind.AUTHENTICATION);
        expect(failure.httpStatus).assertEqual(HttpStatus.UNAUTHORIZED);
        expect(failure.retryable).assertFalse();
      }
    });

    it('maps HTTP 403 onto an HTTP failure', async () => {
      const transport = FakeTransport.create();
      transport.enqueue(new ScriptedResponse(HttpStatus.FORBIDDEN, 'forbidden', new Map<string, string>()));
      const client = clientWith(transport, ApiStyleMode.MODERN, 'cached-session');

      try {
        await client.call(RpcMethod.SESSION_GET);
        expect(true).assertFalse();
      } catch (error) {
        const failure = error as TransmissionError;
        expect(failure.kind).assertEqual(TransmissionErrorKind.HTTP);
        expect(failure.httpStatus).assertEqual(HttpStatus.FORBIDDEN);
      }
    });

    it('maps HTTP 500 onto a non-retryable HTTP failure', async () => {
      const transport = FakeTransport.create();
      transport.enqueue(ScriptedResponse.serverError());
      const client = clientWith(transport, ApiStyleMode.MODERN, 'cached-session');

      try {
        await client.call(RpcMethod.SESSION_GET);
        expect(true).assertFalse();
      } catch (error) {
        const failure = error as TransmissionError;
        expect(failure.kind).assertEqual(TransmissionErrorKind.HTTP);
        expect(failure.httpStatus).assertEqual(500);
        expect(failure.retryable).assertFalse();
      }
    });

    it('marks HTTP 503 as a retryable HTTP failure', async () => {
      const transport = FakeTransport.create();
      transport.enqueue(new ScriptedResponse(503, 'unavailable', new Map<string, string>()));
      const client = clientWith(transport, ApiStyleMode.MODERN, 'cached-session');

      try {
        await client.call(RpcMethod.SESSION_GET);
        expect(true).assertFalse();
      } catch (error) {
        const failure = error as TransmissionError;
        expect(failure.kind).assertEqual(TransmissionErrorKind.HTTP);
        expect(failure.httpStatus).assertEqual(503);
        expect(failure.retryable).assertTrue();
      }
    });

    it('maps a malformed JSON body onto a protocol failure', async () => {
      const transport = FakeTransport.create();
      transport.enqueue(ScriptedResponse.ok('{not json'));
      const client = clientWith(transport, ApiStyleMode.MODERN, 'cached-session');

      try {
        await client.call(RpcMethod.SESSION_GET);
        expect(true).assertFalse();
      } catch (error) {
        expect((error as TransmissionError).kind).assertEqual(TransmissionErrorKind.PROTOCOL);
      }
    });

    it('maps a modern RPC error object and keeps the server detail', async () => {
      const data: JsonObject = {};
      data['error_string'] = "Couldn't test port";
      const transport = FakeTransport.create();
      transport.enqueueJson(RpcFakes.modernError(RpcErrorCode.HTTP_ERROR, 'HTTP error from backend service', 1, data));
      const client = clientWith(transport, ApiStyleMode.MODERN, 'cached-session');

      try {
        await client.call(RpcMethod.PORT_TEST);
        expect(true).assertFalse();
      } catch (error) {
        const failure = error as TransmissionError;
        expect(failure.kind).assertEqual(TransmissionErrorKind.RPC);
        expect(failure.rpcCode).assertEqual(RpcErrorCode.HTTP_ERROR);
        expect(failure.rawCode).assertEqual(RpcErrorCode.HTTP_ERROR);
        expect(failure.detail).assertEqual("Couldn't test port");
        expect(Json.getString(failure.data, 'error_string')).assertEqual("Couldn't test port");
      }
    });

    it('maps a legacy error phrase onto its canonical code', async () => {
      const transport = FakeTransport.create();
      transport.enqueueJson(RpcFakes.legacyError('no method name'));
      const client = clientWith(transport, ApiStyleMode.LEGACY, 'cached-session');

      try {
        await client.call(RpcMethod.TORRENT_GET);
        expect(true).assertFalse();
      } catch (error) {
        const failure = error as TransmissionError;
        expect(failure.kind).assertEqual(TransmissionErrorKind.RPC);
        expect(failure.rpcCode).assertEqual(RpcErrorCode.METHOD_NOT_FOUND);
      }
    });

    it('classifies a transport rejection as a retryable transport failure', async () => {
      const transport = FakeTransport.create();
      transport.failWith(new Error('socket closed'));
      const client = clientWith(transport, ApiStyleMode.MODERN, 'cached-session');

      try {
        await client.call(RpcMethod.SESSION_GET);
        expect(true).assertFalse();
      } catch (error) {
        const failure = error as TransmissionError;
        expect(failure.kind).assertEqual(TransmissionErrorKind.TRANSPORT);
        expect(failure.retryable).assertTrue();
      }
    });

    it('passes an existing TransmissionError through unchanged', async () => {
      const original = TransmissionError.timeout('the request timed out');
      const transport = FakeTransport.create();
      transport.failWith(original);
      const client = clientWith(transport, ApiStyleMode.MODERN, 'cached-session');

      try {
        await client.call(RpcMethod.SESSION_GET);
        expect(true).assertFalse();
      } catch (error) {
        expect(error).assertEqual(original);
        expect((error as TransmissionError).kind).assertEqual(TransmissionErrorKind.TIMEOUT);
      }
    });
  });

  describe('RpcClient request construction', () => {
    it('sends HTTP Basic credentials on every request', async () => {
      const transport = FakeTransport.create();
      transport.enqueueCsrf('sess-auth', '6.0.0');
      transport.enqueueJson(RpcFakes.modernSuccess(sessionResult(), 1));
      const config = TransmissionConfig.of(TEST_URL).withCredentials('admin', 'secret');
      const client = new RpcClient(config, transport, new StyleNegotiator(ApiStyleMode.AUTO));

      await client.call(RpcMethod.SESSION_GET);

      const expected = `Basic ${Base64.encodeUtf8('admin:secret')}`;
      expect(transport.callCount).assertEqual(2);
      expect(transport.requests[0].header('authorization')).assertEqual(expected);
      expect(transport.requests[1].header('authorization')).assertEqual(expected);
    });

    it('applies the configured timeout to the HTTP request', async () => {
      const transport = FakeTransport.create();
      transport.enqueueJson(RpcFakes.modernSuccess(sessionResult(), 1));
      const config = TransmissionConfig.of(TEST_URL)
        .withApiStyleMode(ApiStyleMode.MODERN)
        .withSessionId('cached-session')
        .withTimeout(4321);
      const client = new RpcClient(config, transport, new StyleNegotiator(ApiStyleMode.MODERN));

      await client.call(RpcMethod.SESSION_GET);

      expect(transport.requests[0].request.timeoutMs).assertEqual(4321);
    });
  });

  describe('RpcClient session observation', () => {
    it('downgrades to legacy when session_get reports rpc_version_semver 5.3.0', async () => {
      const result: JsonObject = {};
      result['rpc_version_semver'] = '5.3.0';
      expect(await negotiatedStyle(result)).assertEqual(ApiStyle.LEGACY);
    });

    it('keeps the modern dialect when session_get reports rpc_version_semver 6.0.0', async () => {
      const result: JsonObject = {};
      result['rpc_version_semver'] = '6.0.0';
      expect(await negotiatedStyle(result)).assertEqual(ApiStyle.MODERN);
    });

    it('downgrades to legacy when the deprecated integer version is 17', async () => {
      const result: JsonObject = {};
      result['rpc_version'] = 17;
      expect(await negotiatedStyle(result)).assertEqual(ApiStyle.LEGACY);
    });

    it('selects the modern dialect when the deprecated integer version is 18', async () => {
      const result: JsonObject = {};
      result['rpc_version'] = 18;
      expect(await negotiatedStyle(result)).assertEqual(ApiStyle.MODERN);
    });
  });

  describe('RpcClient.callBatch', () => {
    it('sends three calls as one array request and decodes the reply positionally', async () => {
      const transport = FakeTransport.create();
      const firstResult: JsonObject = {};
      firstResult['marker'] = 11;
      const secondResult: JsonObject = {};
      secondResult['marker'] = 22;
      const thirdResult: JsonObject = {};
      thirdResult['marker'] = 33;
      const responses: JsonValue[] = [
        RpcFakes.modernSuccess(firstResult, 1),
        RpcFakes.modernSuccess(secondResult, 1),
        RpcFakes.modernSuccess(thirdResult, 1),
      ];
      transport.enqueueJson(responses);
      const client = clientWith(transport, ApiStyleMode.MODERN, 'cached-session');

      const torrentParams: JsonObject = {};
      torrentParams['ids'] = 'recently_active';
      const calls: RpcCall[] = [
        new RpcCall(RpcMethod.SESSION_GET),
        new RpcCall(RpcMethod.SESSION_STATS),
        new RpcCall(RpcMethod.TORRENT_GET, torrentParams),
      ];
      const outcomes = await client.callBatch(calls);

      expect(transport.callCount).assertEqual(1);
      expect(outcomes.length).assertEqual(3);
      const envelopes = Json.asArray(Json.parse(transport.requests[0].body));
      expect(envelopes === undefined ? -1 : envelopes.length).assertEqual(3);
      if (envelopes !== undefined) {
        const first = Json.asObject(envelopes[0]);
        expect(Json.getString(first, 'jsonrpc')).assertEqual('2.0');
        expect(Json.getString(first, 'method')).assertEqual('session_get');
        const last = Json.asObject(envelopes[2]);
        expect(Json.getString(Json.getObject(last, 'params'), 'ids')).assertEqual('recently_active');
      }
      expect(Json.getNumber(outcomes[0].resultOrEmpty, 'marker')).assertEqual(11);
      expect(Json.getNumber(outcomes[1].resultOrEmpty, 'marker')).assertEqual(22);
      expect(Json.getNumber(outcomes[2].resultOrEmpty, 'marker')).assertEqual(33);
    });

    it('downgrades and replays the whole batch once when one element is METHOD_NOT_FOUND', async () => {
      const transport = FakeTransport.create();
      const a: JsonObject = {};
      a['marker'] = 1;
      const b: JsonObject = {};
      b['marker'] = 2;
      const c: JsonObject = {};
      c['marker'] = 3;
      const modernResponses: JsonValue[] = [
        RpcFakes.modernSuccess(a, 1),
        RpcFakes.modernError(RpcErrorCode.METHOD_NOT_FOUND, 'Method not found', 1),
        RpcFakes.modernSuccess(c, 1),
      ];
      const legacyResponses: JsonValue[] = [
        RpcFakes.legacySuccess(a, 1),
        RpcFakes.legacySuccess(b, 1),
        RpcFakes.legacySuccess(c, 1),
      ];
      transport.enqueueJson(modernResponses).enqueueJson(legacyResponses);
      const client = clientWith(transport, ApiStyleMode.AUTO, 'cached-session');

      const outcomes = await client.callBatch([
        new RpcCall(RpcMethod.SESSION_GET),
        new RpcCall(RpcMethod.SESSION_STATS),
        new RpcCall(RpcMethod.TORRENT_GET),
      ]);

      expect(transport.callCount).assertEqual(2);
      expect(client.currentStyle).assertEqual(ApiStyle.LEGACY);
      expect(outcomes.length).assertEqual(3);
      const retryEnvelopes = Json.asArray(Json.parse(transport.requests[1].body));
      expect(retryEnvelopes === undefined ? -1 : retryEnvelopes.length).assertEqual(3);
      if (retryEnvelopes !== undefined) {
        for (const item of retryEnvelopes) {
          const envelope = Json.asObject(item);
          expect(Json.has(envelope, 'jsonrpc')).assertFalse();
          expect(Json.has(envelope, 'arguments')).assertTrue();
        }
      }
    });
  });

  describe('RpcClient lifecycle guards', () => {
    it('gives up after three consecutive 409 responses instead of looping forever', async () => {
      const transport = FakeTransport.create();
      transport.enqueueCsrf('sess-1', '6.0.0');
      transport.enqueueCsrf('sess-2', '6.0.0');
      transport.enqueueCsrf('sess-3', '6.0.0');
      const client = clientWith(transport, ApiStyleMode.AUTO);

      try {
        await client.call(RpcMethod.SESSION_GET);
        expect(true).assertFalse();
      } catch (error) {
        expect((error as TransmissionError).kind).assertEqual(TransmissionErrorKind.PROTOCOL);
      }
      expect(transport.callCount).assertEqual(3);
    });

    it('destroys the transport and refuses further calls after close()', async () => {
      const transport = FakeTransport.create();
      const client = clientWith(transport, ApiStyleMode.MODERN, 'cached-session');

      client.close();

      expect(transport.isDestroyed).assertTrue();
      expect(client.isClosed).assertTrue();
      try {
        await client.call(RpcMethod.SESSION_GET);
        expect(true).assertFalse();
      } catch (error) {
        expect((error as TransmissionError).kind).assertEqual(TransmissionErrorKind.TRANSPORT);
      }
      expect(transport.callCount).assertEqual(0);
    });
  });
}
