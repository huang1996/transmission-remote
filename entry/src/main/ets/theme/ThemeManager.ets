// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Application-wide appearance handling.
 *
 * Two sources of truth exist for what the user sees: the persisted preference
 * (`AppSettings.themeMode`) and the application-level colour mode that ArkUI
 * actually renders with. Keeping them in step is the whole job of this class:
 * the Options screen writes the preference and calls {@link apply}, and the
 * ability entry point calls {@link applyPersisted} before the first frame so a
 * dark-theme user never sees a white flash.
 *
 * @since 1.0.0
 */

import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { Json } from 'transmission_sdk';
import { ThemeMode, readThemeMode } from '../model/AppModels';

/** Name of the preferences store, shared with `AppContext`. */
export const THEME_STORE_NAME: string = 'transmission_app';
/** Key holding the serialised settings blob inside that store. */
export const THEME_SETTINGS_KEY: string = 'settings';

/** Resolves a preference to the colour mode the application should render with. */
function colorModeFor(mode: ThemeMode): ConfigurationConstant.ColorMode {
  if (mode === ThemeMode.LIGHT) {
    return ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
  }
  if (mode === ThemeMode.DARK) {
    return ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }
  return ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
}

/** The effective darkness of a raw colour-mode value. */
function isDarkColorMode(colorMode: number): boolean {
  // Compared numerically rather than against a named enum member: the
  // configuration reported by the resource manager and the constant used by
  // `setColorMode` are declared by different modules and may be distinct enum
  // types, which makes a typed `===` a compile error on some SDK revisions.
  return colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
}

/** Applies and reads the application colour mode. */
export class ThemeManager {
  /**
   * Applies a persisted preference to the whole application.
   *
   * @param context ability context whose application colour mode is changed
   * @param mode the appearance preference to apply
   */
  static apply(context: common.UIAbilityContext, mode: ThemeMode): void {
    try {
      context.getApplicationContext().setColorMode(colorModeFor(mode));
    } catch (error) {
      console.error(`ThemeManager: ${error}`)
    }
  }

  /** True when the device itself is currently dark. */
  static isSystemDark(context: common.UIAbilityContext): boolean {
    const configuration = context.resourceManager.getConfigurationSync();
    const colorMode: number = configuration.colorMode;
    return isDarkColorMode(colorMode);
  }

  /** The effective darkness for a preference (resolves SYSTEM against the device). */
  static isDark(context: common.UIAbilityContext, mode: ThemeMode): boolean {
    if (mode === ThemeMode.DARK) {
      return true;
    }
    if (mode === ThemeMode.LIGHT) {
      return false;
    }
    return ThemeManager.isSystemDark(context);
  }

  /**
   * The appearance the application is currently rendering with.
   *
   * Returns {@link ThemeMode.SYSTEM} when no explicit mode has been applied,
   * which is the state `apply(ThemeMode.SYSTEM)` leaves behind.
   */
  static currentMode(context: common.UIAbilityContext): ThemeMode {
    const configuration = context.resourceManager.getConfigurationSync();
    const colorMode: number = configuration.colorMode;
    if (isDarkColorMode(colorMode)) {
      return ThemeMode.DARK;
    }
    if (colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
      return ThemeMode.LIGHT;
    }
    return ThemeMode.SYSTEM;
  }

  /**
   * Reads the persisted preference and applies it; call from EntryAbility.
   *
   * Any failure — a missing store, a corrupt blob, a lost preference file — is
   * deliberately swallowed and treated as "follow the system", because a broken
   * appearance preference must never stop the application from starting.
   *
   * @param context ability context used to locate the preferences store
   */
  static applyPersisted(context: common.UIAbilityContext): void {
    let mode: ThemeMode = ThemeMode.SYSTEM;
    try {
      const store = preferences.getPreferencesSync(context, { name: THEME_STORE_NAME });
      const raw = store.getSync(THEME_SETTINGS_KEY, '');
      if (typeof raw === 'string' && raw.length > 0) {
        mode = readThemeMode(Json.asObject(Json.parse(raw)), ThemeMode.SYSTEM);
      }
    } catch (error) {
      console.warn('theme preference unreadable, following the system setting');
      mode = ThemeMode.SYSTEM;
    }
    ThemeManager.apply(context, mode);
  }
}
