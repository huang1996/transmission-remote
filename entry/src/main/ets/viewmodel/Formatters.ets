// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Display formatting helpers.
 *
 * Transmission reports raw bytes, seconds and `0..1` fractions; every screen
 * needs the same conversions, so they live here rather than being re-derived per
 * component.
 *
 * @since 1.0.0
 */

/** Formats a byte count using binary units, e.g. `26.3 GB`. */
export function formatBytes(bytes: number): string {
  if (!Number.isFinite(bytes) || bytes < 0) {
    return '—';
  }
  if (bytes === 0) {
    return '0 B';
  }
  const units: string[] = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  let value = bytes;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value = value / 1024;
    unit++;
  }
  const decimals = unit === 0 ? 0 : value >= 100 ? 0 : 1;
  return `${value.toFixed(decimals)} ${units[unit]}`;
}

/** Formats a transfer rate, e.g. `1.2 MB/s`. Zero renders as `0.0 KB/s`, as in the reference UI. */
export function formatSpeed(bytesPerSecond: number): string {
  if (!Number.isFinite(bytesPerSecond) || bytesPerSecond <= 0) {
    return '0.0 KB/s';
  }
  if (bytesPerSecond < 1024) {
    return `${bytesPerSecond.toFixed(1)} B/s`;
  }
  return `${formatBytes(bytesPerSecond)}/s`;
}

/** Formats a duration in seconds, e.g. `1h 04m`. */
export function formatEta(seconds: number): string {
  if (!Number.isFinite(seconds) || seconds < 0) {
    return '—';
  }
  if (seconds < 60) {
    return `${Math.floor(seconds)}s`;
  }
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) {
    return `${minutes}m`;
  }
  const hours = Math.floor(minutes / 60);
  if (hours < 24) {
    return `${hours}h ${(minutes % 60).toString().padStart(2, '0')}m`;
  }
  const days = Math.floor(hours / 24);
  return `${days}d ${hours % 24}h`;
}

/**
 * Formats an elapsed time in seconds, e.g. `18h 56m`, `4m 49s`, `0s`.
 *
 * Distinct from {@link formatEta}, which answers "how much longer" and is
 * allowed to give up with `—`. An elapsed counter always has a value, and
 * always showing two units keeps the width stable as it ticks.
 */
export function formatDuration(seconds: number): string {
  if (!Number.isFinite(seconds) || seconds <= 0) {
    return '0s';
  }
  const total = Math.floor(seconds);
  const days = Math.floor(total / 86400);
  if (days > 0) {
    return `${days}d ${Math.floor((total % 86400) / 3600)}h`;
  }
  const hours = Math.floor(total / 3600);
  if (hours > 0) {
    return `${hours}h ${Math.floor((total % 3600) / 60)}m`;
  }
  const minutes = Math.floor(total / 60);
  if (minutes > 0) {
    return `${minutes}m ${total % 60}s`;
  }
  return `${total}s`;
}

/** Formats a `0..1` fraction as a whole percentage, e.g. `42%`. */
export function formatPercent(fraction: number): string {
  if (!Number.isFinite(fraction) || fraction <= 0) {
    return '0%';
  }
  return `${Math.round(fraction * 100)}%`;
}

/** Formats a `0..1` fraction with one decimal, e.g. `42.7%`. */
export function formatPercentPrecise(fraction: number): string {
  if (!Number.isFinite(fraction) || fraction <= 0) {
    return '0.0%';
  }
  return `${(fraction * 100).toFixed(1)}%`;
}

/**
 * Formats a `0..1` fraction with two decimals, e.g. `75.06%`.
 *
 * Used for recheck progress, where Transmission reports a precise fraction and
 * the user is watching it creep upwards.
 */
export function formatPercentExact(fraction: number): string {
  if (!Number.isFinite(fraction) || fraction <= 0) {
    return '0.00%';
  }
  return `${(fraction * 100).toFixed(2)}%`;
}

/** Formats a share ratio with two decimals, as the reference UI does. */
export function formatRatio(ratio: number): string {
  if (!Number.isFinite(ratio) || ratio < 0) {
    return '0.00';
  }
  return ratio.toFixed(2);
}

/** Formats a Unix timestamp as `YYYY-MM-DD HH:mm`, or `—` for `0`. */
export function formatTimestamp(epochSeconds: number): string {
  if (!Number.isFinite(epochSeconds) || epochSeconds <= 0) {
    return '—';
  }
  const date = new Date(epochSeconds * 1000);
  const day = date.getDate().toString().padStart(2, '0');
  const month = (date.getMonth() + 1).toString().padStart(2, '0');
  const hours = date.getHours().toString().padStart(2, '0');
  const minutes = date.getMinutes().toString().padStart(2, '0');
  return `${date.getFullYear()}-${month}-${day} ${hours}:${minutes}`;
}

/** Formats a number that may legitimately be unknown (`-1`), e.g. tracker counts. */
export function formatCountOrDash(value: number): string {
  return Number.isFinite(value) && value >= 0 ? `${value}` : '—';
}

/** Formats a byte count that may be unknown, e.g. desired availability. */
export function formatBytesOrDash(value: number): string {
  return Number.isFinite(value) && value >= 0 ? formatBytes(value) : '—';
}
