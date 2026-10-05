// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Posts a local notification when a torrent finishes downloading.
 *
 * Transmission has no server-side push, so "finished" is detected by comparing
 * consecutive list refreshes. Two details make that usable rather than annoying:
 *
 * - the very first observation only *records* state, so launching the app next
 *   to a completed download does not fire a burst of notifications for work
 *   that finished days ago;
 * - torrents are remembered by info-hash, because numeric torrent ids are not
 *   stable across daemon restarts.
 *
 * @since 1.0.0
 */

import { notificationManager } from '@kit.NotificationKit';
import { common } from '@kit.AbilityKit';
import { Torrent } from 'transmission_sdk';

/** Tracks torrent completion and publishes notifications for transitions. */
export class CompletionNotifier {
  /** Info-hashes already seen in the `finished` state. */
  private static readonly finished: Set<string> = new Set<string>();
  /** False until the first observation has seeded {@link finished}. */
  private static primed: boolean = false;
  /** Monotonic notification id; reusing ids replaces earlier notifications. */
  private static nextNotificationId: number = 1000;

  private constructor() {
    // Static-only utility class.
  }

  /**
   * Asks the user to allow notifications, or withdraws them.
   *
   * @param context ability context required by the permission dialog
   * @param enable true to request, false to clear any posted notifications
   * @returns true when notifications are available
   */
  static async setEnabled(context: common.UIAbilityContext, enable: boolean): Promise<boolean> {
    if (!enable) {
      CompletionNotifier.reset();
      try {
        await notificationManager.cancelAll();
      } catch (error) {
        console.info(`could not clear notifications: ${(error as Error).message}`);
      }
      return true;
    }
    try {
      await notificationManager.requestEnableNotification(context);
      return true;
    } catch (error) {
      console.info(`notification permission declined: ${(error as Error).message}`);
      return false;
    }
  }

  /** Forgets the observed state, so the next refresh re-primes silently. */
  static reset(): void {
    CompletionNotifier.finished.clear();
    CompletionNotifier.primed = false;
  }

  /**
   * Compares `torrents` with the previous observation and notifies for each
   * torrent that has just finished.
   *
   * @param torrents the freshly loaded list
   * @param enabled the user's notification preference
   * @param serverName shown in the notification body to disambiguate servers
   */
  static async observe(
    context: common.UIAbilityContext,
    torrents: Torrent[],
    enabled: boolean,
    serverName: string,
  ): Promise<void> {
    if (!enabled) {
      return;
    }

    const justFinished: Torrent[] = [];
    for (const torrent of torrents) {
      const hash = torrent.hashString;
      if (hash.length === 0) {
        continue;
      }
      if (!torrent.isFinished) {
        CompletionNotifier.finished.delete(hash);
        continue;
      }
      if (!CompletionNotifier.finished.has(hash)) {
        CompletionNotifier.finished.add(hash);
        // The seeding pass only records what was already done before start-up.
        if (CompletionNotifier.primed) {
          justFinished.push(torrent);
        }
      }
    }
    CompletionNotifier.primed = true;

    for (const torrent of justFinished) {
      await CompletionNotifier.publish(context, torrent, serverName);
    }
  }

  /** Publishes one completion notification. */
  private static async publish(
    context: common.UIAbilityContext,
    torrent: Torrent,
    serverName: string,
  ): Promise<void> {
    const name = torrent.name.length > 0 ? torrent.name : torrent.hashString;
    // `NotificationBasicContent` takes plain strings, so the localised title is
    // resolved from the resource table rather than passed as a `Resource`.
    const title = context.resourceManager.getStringSync($r('app.string.notification_done_title').id);
    const normal: notificationManager.NotificationBasicContent = {
      title: title,
      text: serverName.length > 0 ? `${name} · ${serverName}` : name,
    };
    const content: notificationManager.NotificationContent = {
      notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
      normal: normal,
    };
    const request: notificationManager.NotificationRequest = {
      id: CompletionNotifier.nextNotificationId,
      content: content,
    };
    CompletionNotifier.nextNotificationId++;

    try {
      await notificationManager.publish(request);
    } catch (error) {
      console.warn(`could not publish a completion notification: ${(error as Error).message}`);
    }
  }
}
