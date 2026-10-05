// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Typed navigation parameters.
 *
 * `NavPathStack.pushPath` carries an untyped `param`; wrapping it in a class
 * gives the destination builder something concrete to cast to, and keeps the
 * route names in one place instead of scattering string literals.
 *
 * @since 1.0.0
 */

/** Route names registered with the `Navigation` destination builder. */
export class RouteName {
  /** Torrent detail screen. */
  static readonly DETAIL: string = 'torrentDetail';
  /** Add-torrent screen. */
  static readonly ADD: string = 'addTorrent';
  /** Server list and editor. */
  static readonly SERVERS: string = 'servers';
  /** Options screen. */
  static readonly SETTINGS: string = 'settings';
  /** About screen: what the app is, and which build this is. */
  static readonly ABOUT: string = 'about';

  private constructor() {
    // Static-only utility class.
  }
}

/** Parameter for {@link RouteName.DETAIL}. */
export class DetailParam {
  /** Torrent to display. */
  torrentId: number = 0;

  /**
   * @param torrentId torrent id
   */
  constructor(torrentId: number) {
    this.torrentId = torrentId;
  }
}

/** Parameter for {@link RouteName.SERVERS}. */
export class ServerParam {
  /** True opens the editor immediately instead of the saved-server list. */
  startInEdit: boolean = false;

  /**
   * @param startInEdit true when the caller has no server to show yet
   */
  constructor(startInEdit: boolean) {
    this.startInEdit = startInEdit;
  }
}

/** Which input the add-torrent screen starts on. */
export enum AddMethod {
  /** Magnet link or URL. */
  LINK = 'link',
  /** Local `.torrent` file. */
  FILE = 'file',
}

/** Parameter for {@link RouteName.ADD}. */
export class AddParam {
  /** Input the screen should start on. */
  method: AddMethod = AddMethod.LINK;

  /**
   * @param method initial input method
   */
  constructor(method: AddMethod) {
    this.method = method;
  }
}
