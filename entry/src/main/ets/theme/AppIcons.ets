// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Every icon the application draws, in one place.
 *
 * HarmonyOS ships a system symbol library that `SymbolGlyph` renders by name
 * (`$r('sys.symbol.…')`). Using it instead of text glyphs means the icons follow
 * the system font weight, scale with the accessibility font size and match the
 * platform's own look.
 *
 * ### Why the names live in one file
 *
 * A symbol that does not exist in the installed SDK is a *compile-time* resource
 * error, and the exact set varies between SDK releases. Keeping every reference
 * here means a name that has to change is a one-line edit rather than a hunt
 * through seven screens.
 *
 * The names below were checked against the community HarmonyOS Symbol index
 * (3844 names, `runoob-coder/hm_symbol_flutter` → `tool/HMSymbol.nam`), which
 * mirrors the system library. If DevEco reports `resource not found` for one of
 * them, replace that single constant — the semantic name on the left stays the
 * same, so no call site changes.
 *
 * Reference: https://developer.huawei.com/consumer/cn/design/harmonyos-symbol/
 *
 * @since 1.0.0
 */

import { FileKind } from '../viewmodel/FileTree';

/** System symbol resources used by the application. */
export class AppIcons {
  // ------------------------------------------------------------ navigation
  /** Opens the navigation drawer. */
  static readonly MENU: Resource = $r('sys.symbol.line_3_horizontal');
  /** Overflow menu of secondary actions. */
  static readonly MORE: Resource = $r('sys.symbol.dot_grid_2x2');
  /** Collapses the floating action button. */
  static readonly CLOSE: Resource = $r('sys.symbol.xmark');
  /** Expands the floating action button / adds something. */
  static readonly PLUS: Resource = $r('sys.symbol.plus');
  /** "More items in this direction". */
  static readonly CHEVRON_RIGHT: Resource = $r('sys.symbol.chevron_right');
  /** Drop-down affordance next to the server name. */
  static readonly CHEVRON_DOWN: Resource = $r('sys.symbol.chevron_down');
  /** Ascending sort direction. */
  static readonly CHEVRON_UP: Resource = $r('sys.symbol.chevron_up');

  // -------------------------------------------------------------- transfers
  /** Resume a torrent. */
  static readonly RESUME: Resource = $r('sys.symbol.play_fill');
  /** Pause a torrent. */
  static readonly PAUSE: Resource = $r('sys.symbol.pause_fill');
  /** Download rate. */
  static readonly DOWNLOAD: Resource = $r('sys.symbol.arrow_down_circle');
  /** Upload rate. */
  static readonly UPLOAD: Resource = $r('sys.symbol.arrow_up_circle');

  // ------------------------------------------------------- torrent actions
  /** Verify local data. */
  static readonly VERIFY: Resource = $r('sys.symbol.checkmark_circle');
  /** Re-announce to trackers. */
  static readonly REANNOUNCE: Resource = $r('sys.symbol.arrow_2_circlepath');
  /** Edit something. */
  static readonly EDIT: Resource = $r('sys.symbol.square_and_pencil');
  /** Remove a torrent or a server. */
  static readonly DELETE: Resource = $r('sys.symbol.trash');
  /** Refresh the list or the free-space figure. */
  static readonly REFRESH: Resource = $r('sys.symbol.arrow_clockwise');
  /** Search the list. */
  static readonly SEARCH: Resource = $r('sys.symbol.magnifyingglass');
  /** A confirmed selection. */
  static readonly CHECK: Resource = $r('sys.symbol.checkmark');
  /**
   * 把当前页面的改动写入服务器（方框内的向下箭头，即「保存到文件」）。
   *
   * 不用勾号：勾号表达的是「已确认 / 已完成」，是无状态的结果；而这一颗按钮
   * 表达的是「提交这次改动」，是一件要去做的事。两者在同一屏里靠得太近时，
   * 勾号会被读成「这一页已经存过了」。
   */
  static readonly SAVE: Resource = $r('sys.symbol.save');
  /** A finished torrent. */
  static readonly FINISHED: Resource = $r('sys.symbol.checkmark_circle_fill');
  /** Sort direction control. */
  static readonly SORT: Resource = $r('sys.symbol.sort');

  // ------------------------------------------------------------- structure
  /** A saved server / backup storage. */
  static readonly SERVER: Resource = $r('sys.symbol.externaldrive');
  /** Remaining space on the server. */
  static readonly STORAGE: Resource = $r('sys.symbol.externaldrive');
  /** The Options screen. */
  static readonly SETTINGS: Resource = $r('sys.symbol.gearshape');
  /** Advanced settings. */
  static readonly ADVANCED: Resource = $r('sys.symbol.slider_horizontal_2');
  /** Night mode. */
  static readonly NIGHT: Resource = $r('sys.symbol.moon_fill');
  /** Appearance / theme. */
  static readonly THEME: Resource = $r('sys.symbol.moon');
  /** Notifications. */
  static readonly NOTIFICATION: Resource = $r('sys.symbol.bell');
  /** Refresh interval. */
  static readonly INTERVAL: Resource = $r('sys.symbol.clock');

  // ------------------------------------------------------------ file types
  /**
   * Icons for the Files tab, one per {@link FileKind}.
   *
   * The system library has no `photo` or `image` symbol, so pictures borrow the
   * camera glyph — the closest name in the set. Every name here was checked
   * against the symbol table the SDK ships in
   * `previewer/common/resources/resources.index`, which is the same table the
   * resource compiler resolves `sys.symbol.*` from.
   */
  /** A video file. */
  static readonly FILE_VIDEO: Resource = $r('sys.symbol.film');
  /** A music or audio file. */
  static readonly FILE_AUDIO: Resource = $r('sys.symbol.music');
  /** An image or photo. */
  static readonly FILE_IMAGE: Resource = $r('sys.symbol.camera');
  /** A document: a text, office or e-book file. */
  static readonly FILE_DOCUMENT: Resource = $r('sys.symbol.doc_text');
  /** A compressed archive. */
  static readonly FILE_ARCHIVE: Resource = $r('sys.symbol.archivebox');
  /** A subtitle track. */
  static readonly FILE_SUBTITLE: Resource = $r('sys.symbol.text_bubble_left_2');
  /** A disc image. */
  static readonly FILE_DISC: Resource = $r('sys.symbol.opticaldisc');

  // ---------------------------------------------------------------- content
  /** A `.torrent` file, and any file whose type is not recognised. */
  static readonly FILE: Resource = $r('sys.symbol.doc');
  /** A magnet link or URL. */
  static readonly LINK: Resource = $r('sys.symbol.link');
  /** The download location. */
  static readonly FOLDER: Resource = $r('sys.symbol.folder');
  /** Add a server, or open a folder. */
  static readonly FOLDER_ADD: Resource = $r('sys.symbol.folder_badge_plus');
  /** Trackers, drawn as radio waves. */
  static readonly TRACKERS: Resource = $r('sys.symbol.dot_radiowaves_left_and_right');
  /** Connected peers. */
  static readonly PEERS: Resource = $r('sys.symbol.person_2');
  /** Informational row. */
  static readonly INFO: Resource = $r('sys.symbol.info_circle');
  /** An error or warning. */
  static readonly WARNING: Resource = $r('sys.symbol.exclamationmark_triangle');

  private constructor() {
    // Static-only holder.
  }

  /**
   * 文件类型对应的图标。
   *
   * 放在这里而不是各个页面里，是因为「详情页的文件标签」和「添加页的种子
   * 文件树」都要用同一套映射，两处各写一遍迟早会漂移。
   *
   * @param kind 由 {@link FileKinds.of} 从扩展名判定出的类型
   */
  static forFileKind(kind: FileKind): Resource {
    if (kind === FileKind.VIDEO) {
      return AppIcons.FILE_VIDEO;
    }
    if (kind === FileKind.AUDIO) {
      return AppIcons.FILE_AUDIO;
    }
    if (kind === FileKind.IMAGE) {
      return AppIcons.FILE_IMAGE;
    }
    if (kind === FileKind.DOCUMENT) {
      return AppIcons.FILE_DOCUMENT;
    }
    if (kind === FileKind.ARCHIVE) {
      return AppIcons.FILE_ARCHIVE;
    }
    if (kind === FileKind.SUBTITLE) {
      return AppIcons.FILE_SUBTITLE;
    }
    if (kind === FileKind.DISC) {
      return AppIcons.FILE_DISC;
    }
    return AppIcons.FILE;
  }
}
