// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Batching support.
 *
 * Both RPC dialects accept a top-level JSON array of requests and answer with
 * an array of responses, so several independent calls can share one HTTP round
 * trip. That is the single biggest latency win available to a client that
 * regularly needs more than one piece of information at a time — for example a
 * dashboard that refreshes `session_get`, `session_stats` and `torrent_get`
 * together.
 *
 * @since 1.0.0
 */

import { JsonObject } from '../util/Json';
import { RpcCall, RpcOutcome } from '../compat/RpcCodec';
import { RpcMethod } from '../constants/RpcMethods';
import { TransmissionError } from '../error/TransmissionError';
import { RpcClient } from './RpcClient';

/**
 * Accumulates calls and executes them in one request.
 *
 * ```ts
 * const outcomes = await client
 *   .batch()
 *   .add(RpcMethod.SESSION_GET, sessionParams)
 *   .add(RpcMethod.SESSION_STATS)
 *   .add(RpcMethod.TORRENT_GET, torrentParams)
 *   .execute();
 * ```
 */
export class RpcBatch {
  private readonly rpc: RpcClient;
  private readonly calls: RpcCall[] = [];

  /**
   * @param rpc the shared RPC engine
   */
  constructor(rpc: RpcClient) {
    this.rpc = rpc;
  }

  /** Queues a call. */
  add(method: RpcMethod, params?: JsonObject): RpcBatch {
    this.calls.push(new RpcCall(method, params));
    return this;
  }

  /** Queues a call that was built elsewhere. */
  addCall(call: RpcCall): RpcBatch {
    this.calls.push(call);
    return this;
  }

  /** Number of queued calls. */
  get size(): number {
    return this.calls.length;
  }

  /** True when nothing has been queued. */
  get isEmpty(): boolean {
    return this.calls.length === 0;
  }

  /** Methods queued so far, in order. */
  get methods(): RpcMethod[] {
    const result: RpcMethod[] = [];
    for (const call of this.calls) {
      result.push(call.method);
    }
    return result;
  }

  /**
   * Executes every queued call in one round trip.
   *
   * @returns one outcome per call, in queue order. Individual failures are
   *          returned rather than thrown, so a partial success is visible.
   */
  async execute(): Promise<RpcOutcome[]> {
    if (this.calls.length === 0) {
      return [];
    }
    const outcomes = await this.rpc.callBatch(this.calls);
    this.calls.length = 0;
    return outcomes;
  }

  /**
   * Executes every queued call and fails if any of them failed.
   *
   * @returns one result object per call, in queue order
   * @throws TransmissionError describing the first failure
   */
  async executeOrThrow(): Promise<JsonObject[]> {
    const outcomes = await this.execute();
    const results: JsonObject[] = [];
    for (const outcome of outcomes) {
      if (!outcome.isSuccess) {
        throw outcome.toError();
      }
      results.push(outcome.resultOrEmpty);
    }
    return results;
  }
}

/**
 * Index-addressed view over {@link RpcBatch.execute}'s outcomes.
 *
 * Batching loses the natural "one call, one return value" shape of the API.
 * This helper restores readability at the call site:
 *
 * ```ts
 * const batch = client.batch()
 *   .add(RpcMethod.SESSION_GET)
 *   .add(RpcMethod.SESSION_STATS);
 * const results = new BatchResults(await batch.execute());
 * const settings = SessionSettings.fromJson(results.at(0));
 * const stats = SessionStats.fromJson(results.at(1));
 * ```
 */
export class BatchResults {
  private readonly outcomes: RpcOutcome[];

  /**
   * @param outcomes outcomes returned by {@link RpcBatch.execute}
   */
  constructor(outcomes: RpcOutcome[]) {
    this.outcomes = outcomes;
  }

  /** Number of results. */
  get size(): number {
    return this.outcomes.length;
  }

  /** True when every call succeeded. */
  get isSuccess(): boolean {
    return !this.outcomes.some((outcome: RpcOutcome) => !outcome.isSuccess);
  }

  /**
   * Result of the `index`-th queued call.
   *
   * @throws TransmissionError when the call failed or the index is out of range
   */
  at(index: number): JsonObject {
    if (index < 0 || index >= this.outcomes.length) {
      throw TransmissionError.protocol(`batch result ${index} is out of range (size ${this.outcomes.length})`);
    }
    const outcome = this.outcomes[index];
    if (!outcome.isSuccess) {
      throw outcome.toError();
    }
    return outcome.resultOrEmpty;
  }

  /** Outcome of the `index`-th queued call, without throwing. */
  outcomeAt(index: number): RpcOutcome | undefined {
    return index < 0 || index >= this.outcomes.length ? undefined : this.outcomes[index];
  }
}
