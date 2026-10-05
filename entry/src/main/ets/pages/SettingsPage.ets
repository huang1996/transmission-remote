// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * The Options screen: appearance, refresh, notifications and connection tuning.
 *
 * Every row is backed by a field of {@link AppSettings}; the local `@State`
 * copies exist only so ArkUI re-renders, and every change is written straight
 * back through `AppContext.saveSettings()` so leaving the screen without a
 * "save" tap cannot lose a preference.
 *
 * @since 1.0.0
 */

import { common } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { ApiStyleMode } from 'transmission_sdk';
import { ThemeMode } from '../model/AppModels';
import { AppContext } from '../store/AppContext';
import { ThemeManager } from '../theme/ThemeManager';

/** The refresh intervals the user can choose, in seconds; `0` means manual. */
const REFRESH_SECONDS: number[] = [0, 5, 10, 30, 60, 300];
/** Largest timeout accepted by the connection group. */
const MAX_TIMEOUT_SECONDS: number = 120;

/** Application preferences, grouped the way the reference client groups them. */
@Component
export struct SettingsPage {
  /** Stack this destination was pushed onto; refreshed by `onReady`. */
  pathStack: NavPathStack = new NavPathStack();

  @State themeMode: ThemeMode = ThemeMode.SYSTEM;
  @State refreshIndex: number = 0;
  @State showAddFab: boolean = true;
  @State notificationsEnabled: boolean = false;
  @State timeoutText: string = '15';
  @State apiStyleMode: ApiStyleMode = ApiStyleMode.AUTO;

  aboutToAppear(): void {
    const settings = AppContext.get().settings;
    this.themeMode = settings.themeMode;
    this.refreshIndex = this.indexOfRefresh(settings.refreshIntervalSeconds);
    this.showAddFab = settings.showAddFab;
    this.notificationsEnabled = settings.notificationsEnabled;
    this.timeoutText = `${settings.requestTimeoutSeconds}`;
    this.apiStyleMode = settings.apiStyleMode;

    // The persisted preference wins: re-apply it in case the application colour
    // mode was changed elsewhere since this page was last built.
    const context = this.hostContext();
    if (context !== undefined) {
      ThemeManager.apply(context, this.themeMode);
    }
  }

  build(): void {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          this.buildGeneralSection();
          this.buildConnectionSection();
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 24 });
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Auto)
    }
    .title($r('app.string.page_title_settings'))
    .backgroundColor($r('app.color.app_background'))
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }

  // -------------------------------------------------------------- sections

  @Builder
  buildGeneralSection(): void {
    Column({ space: 8 }) {
      Text($r('app.string.settings_section_general'))
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .width('100%');

      Column() {
        this.buildThemeRow();
        Divider().color($r('app.color.divider')).strokeWidth(1);
        this.buildRefreshRow();
        Divider().color($r('app.color.divider')).strokeWidth(1);
        this.buildShowFabRow();
        Divider().color($r('app.color.divider')).strokeWidth(1);
        this.buildNotificationsRow();
      }
      .width('100%')
      .borderRadius(12)
      .backgroundColor($r('app.color.surface'));
    }
    .width('100%')
  }

  @Builder
  buildConnectionSection(): void {
    Column({ space: 8 }) {
      Text($r('app.string.settings_section_connection'))
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .width('100%');

      Column() {
        this.buildTimeoutRow();
        Divider().color($r('app.color.divider')).strokeWidth(1);
        this.buildApiStyleRow();
      }
      .width('100%')
      .borderRadius(12)
      .backgroundColor($r('app.color.surface'));
    }
    .width('100%')
  }

  // ------------------------------------------------------------------ rows

  @Builder
  buildThemeRow(): void {
    Row({ space: 12 }) {
      Text($r('app.string.settings_theme'))
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1);

      Select(this.themeOptions())
        .selected(this.themeIndex())
        .value(this.themeLabel())
        .onSelect((index: number) => {
          this.applyThemeIndex(index);
        });
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
  }

  @Builder
  buildRefreshRow(): void {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text($r('app.string.settings_refresh'))
          .fontSize(15)
          .fontColor($r('app.color.text_primary'));
        Text($r('app.string.settings_refresh_desc'))
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'));
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1);

      Select(this.refreshOptions())
        .selected(this.refreshIndex)
        .value(this.refreshLabel(this.refreshIndex))
        .onSelect((index: number) => {
          this.applyRefreshIndex(index);
        });
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
  }

  @Builder
  buildShowFabRow(): void {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text($r('app.string.settings_show_fab'))
          .fontSize(15)
          .fontColor($r('app.color.text_primary'));
        Text($r('app.string.settings_show_fab_desc'))
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'));
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1);

      Toggle({ type: ToggleType.Switch, isOn: this.showAddFab })
        .selectedColor($r('app.color.accent'))
        .onChange((isOn: boolean) => {
          this.applyShowFab(isOn);
        });
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
  }

  @Builder
  buildNotificationsRow(): void {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text($r('app.string.settings_notifications'))
          .fontSize(15)
          .fontColor($r('app.color.text_primary'));
        Text($r('app.string.settings_notifications_desc'))
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'));
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1);

      Toggle({ type: ToggleType.Switch, isOn: this.notificationsEnabled })
        .selectedColor($r('app.color.accent'))
        .onChange((isOn: boolean) => {
          this.applyNotifications(isOn);
        });
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
  }

  @Builder
  buildTimeoutRow(): void {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text($r('app.string.settings_timeout'))
          .fontSize(15)
          .fontColor($r('app.color.text_primary'));
        Text($r('app.string.settings_timeout_desc'))
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'));
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1);

      TextInput({ text: this.timeoutText })
        .type(InputType.Number)
        .width(76)
        .height(40)
        .textAlign(TextAlign.Center)
        .onChange((value: string) => {
          this.timeoutText = value;
        })
        .onBlur(() => {
          this.commitTimeout();
        });
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
  }

  @Builder
  buildApiStyleRow(): void {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text($r('app.string.settings_api_style'))
          .fontSize(15)
          .fontColor($r('app.color.text_primary'));
        Text($r('app.string.settings_api_style_desc'))
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'));
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1);

      Select(this.apiStyleOptions())
        .selected(this.apiStyleIndex())
        .value(this.apiStyleLabel())
        .onSelect((index: number) => {
          this.applyApiStyleIndex(index);
        });
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
  }

  // ----------------------------------------------------------- appearance

  /** The three appearance choices, in `ThemeMode` display order. */
  private themeOptions(): SelectOption[] {
    const options: SelectOption[] = [
      { value: $r('app.string.settings_theme_system') },
      { value: $r('app.string.settings_theme_light') },
      { value: $r('app.string.settings_theme_dark') },
    ];
    return options;
  }

  private themeIndex(): number {
    if (this.themeMode === ThemeMode.LIGHT) {
      return 1;
    }
    if (this.themeMode === ThemeMode.DARK) {
      return 2;
    }
    return 0;
  }

  private themeLabel(): ResourceStr {
    if (this.themeMode === ThemeMode.LIGHT) {
      return $r('app.string.settings_theme_light');
    }
    if (this.themeMode === ThemeMode.DARK) {
      return $r('app.string.settings_theme_dark');
    }
    return $r('app.string.settings_theme_system');
  }

  /** Applies a new appearance immediately and persists the preference. */
  private async applyThemeIndex(index: number): Promise<void> {
    let mode: ThemeMode = ThemeMode.SYSTEM;
    if (index === 1) {
      mode = ThemeMode.LIGHT;
    } else if (index === 2) {
      mode = ThemeMode.DARK;
    }
    this.themeMode = mode;
    AppContext.get().settings.themeMode = mode;

    const context = this.hostContext();
    if (context !== undefined) {
      ThemeManager.apply(context, mode);
    }
    await this.flushSettings();
  }

  // -------------------------------------------------------------- refresh

  private indexOfRefresh(seconds: number): number {
    for (let i = 0; i < REFRESH_SECONDS.length; i++) {
      if (REFRESH_SECONDS[i] === seconds) {
        return i;
      }
    }
    return 0;
  }

  /** The label of one interval; `0` is the only one with a resource. */
  private refreshLabel(index: number): ResourceStr {
    if (index < 0 || index >= REFRESH_SECONDS.length) {
      return $r('app.string.settings_refresh_off');
    }
    const seconds = REFRESH_SECONDS[index];
    if (seconds === 0) {
      return $r('app.string.settings_refresh_off');
    }
    return `${seconds}`;
  }

  private refreshOptions(): SelectOption[] {
    const options: SelectOption[] = [];
    for (let i = 0; i < REFRESH_SECONDS.length; i++) {
      const option: SelectOption = { value: this.refreshLabel(i) };
      options.push(option);
    }
    return options;
  }

  private async applyRefreshIndex(index: number): Promise<void> {
    if (index < 0 || index >= REFRESH_SECONDS.length) {
      return;
    }
    this.refreshIndex = index;
    AppContext.get().settings.refreshIntervalSeconds = REFRESH_SECONDS[index];
    await this.flushSettings();
  }

  // ---------------------------------------------------------- general flags

  private async applyShowFab(isOn: boolean): Promise<void> {
    this.showAddFab = isOn;
    AppContext.get().settings.showAddFab = isOn;
    await this.flushSettings();
  }

  /**
   * Turns notifications on or off.
   *
   * Asking for the permission and recording the answer are one operation: a
   * declined prompt must leave the switch off, so the catch reverts both the
   * local state and the persisted setting before anything is written.
   */
  private async applyNotifications(isOn: boolean): Promise<void> {
    this.notificationsEnabled = isOn;
    const app = AppContext.get();
    app.settings.notificationsEnabled = isOn;

    if (isOn) {
      const context = this.hostContext();
      if (context === undefined) {
        this.notificationsEnabled = false;
        app.settings.notificationsEnabled = false;
        await this.flushSettings();
        return;
      }
      try {
        await notificationManager.requestEnableNotification(context);
      } catch (error) {
        this.notificationsEnabled = false;
        app.settings.notificationsEnabled = false;
      }
    }
    await this.flushSettings();
  }

  // ------------------------------------------------------------- connection

  /** Stores the timeout field, restoring the persisted value when invalid. */
  private async commitTimeout(): Promise<void> {
    const parsed = Number.parseInt(this.timeoutText.trim(), 10);
    const app = AppContext.get();
    if (Number.isNaN(parsed) || parsed < 1 || parsed > MAX_TIMEOUT_SECONDS) {
      this.timeoutText = `${app.settings.requestTimeoutSeconds}`;
      return;
    }
    app.settings.requestTimeoutSeconds = parsed;
    this.timeoutText = `${parsed}`;
    await this.flushSettings();
  }

  private apiStyleOptions(): SelectOption[] {
    const options: SelectOption[] = [
      { value: $r('app.string.settings_api_style_auto') },
      { value: $r('app.string.settings_api_style_modern') },
      { value: $r('app.string.settings_api_style_legacy') },
    ];
    return options;
  }

  private apiStyleIndex(): number {
    if (this.apiStyleMode === ApiStyleMode.MODERN) {
      return 1;
    }
    if (this.apiStyleMode === ApiStyleMode.LEGACY) {
      return 2;
    }
    return 0;
  }

  private apiStyleLabel(): ResourceStr {
    if (this.apiStyleMode === ApiStyleMode.MODERN) {
      return $r('app.string.settings_api_style_modern');
    }
    if (this.apiStyleMode === ApiStyleMode.LEGACY) {
      return $r('app.string.settings_api_style_legacy');
    }
    return $r('app.string.settings_api_style_auto');
  }

  /** Drops the current client so the new dialect is negotiated on reconnect. */
  private async applyApiStyleIndex(index: number): Promise<void> {
    let mode: ApiStyleMode = ApiStyleMode.AUTO;
    if (index === 1) {
      mode = ApiStyleMode.MODERN;
    } else if (index === 2) {
      mode = ApiStyleMode.LEGACY;
    }
    this.apiStyleMode = mode;
    const app = AppContext.get();
    app.settings.apiStyleMode = mode;
    app.applyApiStyle();
    await this.flushSettings();
  }

  // ---------------------------------------------------------------- shared

  /** The hosting ability context, or `undefined` before the page is attached. */
  private hostContext(): common.UIAbilityContext | undefined {
    const host = this.getUIContext().getHostContext();
    if (host === undefined) {
      return undefined;
    }
    return host as common.UIAbilityContext;
  }

  /** Writes the current settings back to disk, tolerating a failed write. */
  private async flushSettings(): Promise<void> {
    try {
      const app = AppContext.get();
      await app.saveSettings();
      // The home screen has to re-apply the refresh interval, the FAB flag and
      // the appearance, so tell it something changed.
      app.notifyChanged();
    } catch (error) {
      console.warn(`cannot persist settings: ${(error as Error).message}`);
    }
  }
}
