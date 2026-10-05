// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for batching.
 *
 * A batch turns several calls into one HTTP round trip and answers with a
 * positionally ordered array. `RpcBatch` accumulates the calls; `BatchResults`
 * restores random access to the outcomes.
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { BatchResults, RpcBatch } from '../../main/ets/core/RpcBatch';
import { RpcClient } from '../../main/ets/core/RpcClient';
import { TransmissionConfig } from '../../main/ets/core/TransmissionConfig';
import { RpcErrorInfo, RpcCall, RpcOutcome } from '../../main/ets/compat/RpcCodec';
import { ApiStyleMode } from '../../main/ets/compat/ApiStyle';
import { StyleNegotiator } from '../../main/ets/compat/StyleNegotiator';
import { RpcMethod } from '../../main/ets/constants/RpcMethods';
import { Json, JsonObject, JsonValue } from '../../main/ets/util/Json';
import { RpcErrorCode, TransmissionError, TransmissionErrorKind } from '../../main/ets/error/TransmissionError';
import { FakeTransport } from '../helpers/FakeTransport';
import { RpcFakes } from '../helpers/RpcFakes';

/** Endpoint used by every client in this suite. */
const TEST_URL: string = 'http://127.0.0.1:9091/transmission/rpc';

/** Builds a batch whose calls go through a scripted, already-handshaken client. */
function batchOn(transport: FakeTransport): RpcBatch {
  const config = TransmissionConfig.of(TEST_URL)
    .withApiStyleMode(ApiStyleMode.MODERN)
    .withSessionId('cached-session');
  const rpc = new RpcClient(config, transport, new StyleNegotiator(ApiStyleMode.MODERN));
  return new RpcBatch(rpc);
}

export default function rpcBatchTest(): void {
  describe('RpcBatch queue accounting', () => {
    it('reports its size, emptiness and queued methods in order', () => {
      const batch = batchOn(FakeTransport.create());

      expect(batch.isEmpty).assertTrue();
      expect(batch.size).assertEqual(0);

      batch.add(RpcMethod.SESSION_GET);
      batch.add(RpcMethod.SESSION_STATS);
      batch.add(RpcMethod.TORRENT_GET);

      expect(batch.isEmpty).assertFalse();
      expect(batch.size).assertEqual(3);
      expect(batch.methods).assertDeepEquals([
        RpcMethod.SESSION_GET,
        RpcMethod.SESSION_STATS,
        RpcMethod.TORRENT_GET,
      ]);
    });
  });

  describe('RpcBatch.execute', () => {
    it('resolves an empty batch to an empty list without touching the transport', async () => {
      const transport = FakeTransport.create();
      const batch = batchOn(transport);

      const outcomes = await batch.execute();

      expect(outcomes.length).assertEqual(0);
      expect(transport.callCount).assertEqual(0);
    });

    it('clears the queue so a second execute sends nothing', async () => {
      const transport = FakeTransport.create();
      const first: JsonObject = {};
      first['marker'] = 1;
      const second: JsonObject = {};
      second['marker'] = 2;
      const responses: JsonValue[] = [
        RpcFakes.modernSuccess(first, 1),
        RpcFakes.modernSuccess(second, 1),
      ];
      transport.enqueueJson(responses);
      const batch = batchOn(transport);
      batch.add(RpcMethod.SESSION_GET).add(RpcMethod.SESSION_STATS);

      const outcomes = await batch.execute();
      expect(outcomes.length).assertEqual(2);
      expect(batch.size).assertEqual(0);
      expect(batch.isEmpty).assertTrue();

      const again = await batch.execute();
      expect(again.length).assertEqual(0);
      expect(transport.callCount).assertEqual(1);
    });

    it('throws the first failure from executeOrThrow', async () => {
      const transport = FakeTransport.create();
      const ok: JsonObject = {};
      ok['marker'] = 1;
      const responses: JsonValue[] = [
        RpcFakes.modernSuccess(ok, 1),
        RpcFakes.modernError(RpcErrorCode.SYSTEM_ERROR, 'system error', 1),
      ];
      transport.enqueueJson(responses);
      const batch = batchOn(transport);
      batch.add(RpcMethod.SESSION_GET).add(RpcMethod.SESSION_STATS);

      try {
        await batch.executeOrThrow();
        expect(true).assertFalse();
      } catch (error) {
        const failure = error as TransmissionError;
        expect(failure.kind).assertEqual(TransmissionErrorKind.RPC);
        expect(failure.rpcCode).assertEqual(RpcErrorCode.SYSTEM_ERROR);
      }
    });
  });

  describe('BatchResults', () => {
    it('returns the result at an index and reports overall success', () => {
      const first: JsonObject = {};
      first['marker'] = 7;
      const outcomes: RpcOutcome[] = [RpcOutcome.success(1, first)];
      const results = new BatchResults(outcomes);

      expect(results.size).assertEqual(1);
      expect(results.isSuccess).assertTrue();
      expect(Json.getNumber(results.at(0), 'marker')).assertEqual(7);
      expect(results.outcomeAt(0) === undefined).assertFalse();
    });

    it('reports failure when any outcome failed', () => {
      const first: JsonObject = {};
      first['marker'] = 7;
      const outcomes: RpcOutcome[] = [
        RpcOutcome.success(1, first),
        RpcOutcome.failure(1, new RpcErrorInfo(RpcErrorCode.SYSTEM_ERROR, 5, 'system error')),
      ];
      const results = new BatchResults(outcomes);

      expect(results.size).assertEqual(2);
      expect(results.isSuccess).assertFalse();
    });

    it('throws a protocol error when the index is out of range', () => {
      const results = new BatchResults([RpcOutcome.success(1, Json.emptyObject())]);
      try {
        results.at(4);
        expect(true).assertFalse();
      } catch (error) {
        expect((error as TransmissionError).kind).assertEqual(TransmissionErrorKind.PROTOCOL);
      }
    });

    it('throws the underlying failure when the indexed call failed', () => {
      const results = new BatchResults([
        RpcOutcome.failure(1, new RpcErrorInfo(RpcErrorCode.SYSTEM_ERROR, 5, 'system error')),
      ]);
      try {
        results.at(0);
        expect(true).assertFalse();
      } catch (error) {
        const failure = error as TransmissionError;
        expect(failure.kind).assertEqual(TransmissionErrorKind.RPC);
        expect(failure.rpcCode).assertEqual(RpcErrorCode.SYSTEM_ERROR);
      }
    });

    it('returns undefined from outcomeAt for an out-of-range index', () => {
      const results = new BatchResults([RpcOutcome.success(1, Json.emptyObject())]);
      expect(results.outcomeAt(-1)).assertUndefined();
      expect(results.outcomeAt(9)).assertUndefined();
    });
  });
}
