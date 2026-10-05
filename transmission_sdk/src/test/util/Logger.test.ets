// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for the logging abstraction.
 *
 * The SDK must be silent by default — a torrent client that logs on every poll
 * would drown an application's own logs — so the level filtering is part of the
 * public contract, not an implementation detail.
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import {
  AbstractLogger,
  InMemoryLogger,
  Logger,
  LogLevel,
  logLevelName,
  NoopLogger,
} from '../../main/ets/util/Logger';

/** A logger that records the raw calls it receives, to prove filtering. */
class SpyLogger extends AbstractLogger {
  readonly seen: string[] = [];

  constructor(minLevel: LogLevel = LogLevel.DEBUG) {
    super(minLevel);
  }

  protected write(level: LogLevel, tag: string, message: string): void {
    this.seen.push(`${logLevelName(level)}|${tag}|${message}`);
  }

  /** Exposes the protected sink for assertions. */
  count(): number {
    return this.seen.length;
  }
}

export default function loggerTest(): void {
  describe('LogLevel', () => {
    it('names every level', () => {
      expect(logLevelName(LogLevel.DEBUG)).assertEqual('DEBUG');
      expect(logLevelName(LogLevel.INFO)).assertEqual('INFO');
      expect(logLevelName(LogLevel.WARN)).assertEqual('WARN');
      expect(logLevelName(LogLevel.ERROR)).assertEqual('ERROR');
      expect(logLevelName(LogLevel.NONE)).assertEqual('NONE');
    });

    it('orders levels from verbose to silent', () => {
      expect(LogLevel.DEBUG < LogLevel.INFO).assertTrue();
      expect(LogLevel.INFO < LogLevel.WARN).assertTrue();
      expect(LogLevel.WARN < LogLevel.ERROR).assertTrue();
      expect(LogLevel.ERROR < LogLevel.NONE).assertTrue();
    });
  });

  describe('AbstractLogger level filtering', () => {
    it('emits everything at DEBUG', () => {
      const logger = new SpyLogger(LogLevel.DEBUG);
      logger.debug('t', 'd');
      logger.info('t', 'i');
      logger.warn('t', 'w');
      logger.error('t', 'e');
      expect(logger.count()).assertEqual(4);
    });

    it('suppresses messages below the threshold', () => {
      const logger = new SpyLogger(LogLevel.WARN);
      logger.debug('t', 'd');
      logger.info('t', 'i');
      logger.warn('t', 'w');
      logger.error('t', 'e');
      expect(logger.count()).assertEqual(2);
      expect(logger.seen[0]).assertEqual('WARN|t|w');
    });

    it('treats NONE as fully silent even for errors', () => {
      const logger = new SpyLogger(LogLevel.NONE);
      logger.error('t', 'e');
      expect(logger.count()).assertEqual(0);
      expect(logger.isEnabled(LogLevel.ERROR)).assertFalse();
    });

    it('reports enablement so callers can skip expensive formatting', () => {
      const logger = new SpyLogger(LogLevel.INFO);
      expect(logger.isEnabled(LogLevel.DEBUG)).assertFalse();
      expect(logger.isEnabled(LogLevel.INFO)).assertTrue();
      expect(logger.isEnabled(LogLevel.ERROR)).assertTrue();
    });
  });

  describe('InMemoryLogger', () => {
    it('captures readable, level-tagged lines', () => {
      const logger = new InMemoryLogger(LogLevel.DEBUG);
      logger.info('RpcClient', 'connected');
      logger.error('RpcClient', 'boom');
      expect(logger.messages.length).assertEqual(2);
      expect(logger.messages[0]).assertEqual('[INFO] RpcClient: connected');
      expect(logger.messages[1]).assertEqual('[ERROR] RpcClient: boom');
    });

    it('clears its buffer', () => {
      const logger = new InMemoryLogger(LogLevel.DEBUG);
      logger.warn('t', 'w');
      logger.clear();
      expect(logger.messages.length).assertEqual(0);
    });

    it('hands out a copy, not the live buffer', () => {
      const logger = new InMemoryLogger(LogLevel.DEBUG);
      logger.info('t', 'first');
      const snapshot = logger.messages;
      logger.info('t', 'second');
      expect(snapshot.length).assertEqual(1);
    });
  });

  describe('NoopLogger', () => {
    it('swallows everything and reports itself disabled', () => {
      const logger: Logger = new NoopLogger();
      logger.debug('t', 'd');
      logger.info('t', 'i');
      logger.warn('t', 'w');
      logger.error('t', 'e');
      logger.log(LogLevel.ERROR, 't', 'e');
      expect(logger.isEnabled(LogLevel.ERROR)).assertFalse();
      expect(logger.isEnabled(LogLevel.DEBUG)).assertFalse();
    });
  });
}
