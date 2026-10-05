// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Logging abstraction.
 *
 * The SDK never calls a platform logging API directly: callers inject a
 * {@link Logger} through `TransmissionClientBuilder`. This keeps the core
 * testable on the host JVM/Node and lets applications route SDK diagnostics
 * into their own logging pipeline.
 *
 * @since 1.0.0
 */

/** Severity levels understood by {@link Logger}. */
export enum LogLevel {
  /** Verbose diagnostics, including wire payloads. */
  DEBUG = 0,
  /** High-level lifecycle events. */
  INFO = 1,
  /** Recoverable problems, such as a rejected request that will be retried. */
  WARN = 2,
  /** Failures that are surfaced to the caller. */
  ERROR = 3,
  /** Disables logging entirely. */
  NONE = 4,
}

/** Human readable name of a {@link LogLevel}, for diagnostics. */
export function logLevelName(level: LogLevel): string {
  switch (level) {
    case LogLevel.DEBUG:
      return 'DEBUG';
    case LogLevel.INFO:
      return 'INFO';
    case LogLevel.WARN:
      return 'WARN';
    case LogLevel.ERROR:
      return 'ERROR';
    default:
      return 'NONE';
  }
}

/** Sink for SDK diagnostics. */
export interface Logger {
  /** Writes a message at `level`. */
  log(level: LogLevel, tag: string, message: string): void;

  /** Convenience wrapper for {@link LogLevel.DEBUG}. */
  debug(tag: string, message: string): void;

  /** Convenience wrapper for {@link LogLevel.INFO}. */
  info(tag: string, message: string): void;

  /** Convenience wrapper for {@link LogLevel.WARN}. */
  warn(tag: string, message: string): void;

  /** Convenience wrapper for {@link LogLevel.ERROR}. */
  error(tag: string, message: string): void;

  /** True when messages at `level` would be emitted. */
  isEnabled(level: LogLevel): boolean;
}

/**
 * Base class that implements the level-filtering logic once.
 *
 * Subclasses only need to override {@link Logger.log}.
 */
export abstract class AbstractLogger implements Logger {
  private readonly minLevel: LogLevel;

  protected constructor(minLevel: LogLevel = LogLevel.WARN) {
    this.minLevel = minLevel;
  }

  /** Emits `message` when `level` passes the configured threshold. */
  log(level: LogLevel, tag: string, message: string): void {
    if (this.isEnabled(level)) {
      this.write(level, tag, message);
    }
  }

  debug(tag: string, message: string): void {
    this.log(LogLevel.DEBUG, tag, message);
  }

  info(tag: string, message: string): void {
    this.log(LogLevel.INFO, tag, message);
  }

  warn(tag: string, message: string): void {
    this.log(LogLevel.WARN, tag, message);
  }

  error(tag: string, message: string): void {
    this.log(LogLevel.ERROR, tag, message);
  }

  isEnabled(level: LogLevel): boolean {
    return level >= this.minLevel && this.minLevel !== LogLevel.NONE;
  }

  /** Performs the actual output. */
  protected abstract write(level: LogLevel, tag: string, message: string): void;
}

/** Discards every message. Used as the default to keep the SDK silent. */
export class NoopLogger implements Logger {
  log(_level: LogLevel, _tag: string, _message: string): void {
    // Intentionally empty.
  }

  debug(_tag: string, _message: string): void {
    // Intentionally empty.
  }

  info(_tag: string, _message: string): void {
    // Intentionally empty.
  }

  warn(_tag: string, _message: string): void {
    // Intentionally empty.
  }

  error(_tag: string, _message: string): void {
    // Intentionally empty.
  }

  isEnabled(_level: LogLevel): boolean {
    return false;
  }
}

/**
 * Writes to the platform console.
 *
 * Useful in unit tests and in the sample application; production HarmonyOS apps
 * normally prefer `platform/HilogLogger`.
 */
export class ConsoleLogger extends AbstractLogger {
  constructor(minLevel: LogLevel = LogLevel.WARN) {
    super(minLevel);
  }

  protected write(level: LogLevel, tag: string, message: string): void {
    const line = `[${logLevelName(level)}] ${tag}: ${message}`;
    if (level === LogLevel.ERROR) {
      console.error(line);
    } else if (level === LogLevel.WARN) {
      console.warn(line);
    } else {
      console.info(line);
    }
  }
}

/**
 * Records messages in memory so tests and diagnostics screens can inspect them.
 */
export class InMemoryLogger extends AbstractLogger {
  private readonly entries: string[] = [];

  constructor(minLevel: LogLevel = LogLevel.DEBUG) {
    super(minLevel);
  }

  protected write(level: LogLevel, tag: string, message: string): void {
    this.entries.push(`[${logLevelName(level)}] ${tag}: ${message}`);
  }

  /** Snapshot of everything logged so far. */
  get messages(): string[] {
    return this.entries.slice();
  }

  /** Drops every recorded message. */
  clear(): void {
    this.entries.length = 0;
  }
}
