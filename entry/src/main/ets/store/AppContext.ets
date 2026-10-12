// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Persistence for servers and settings, plus the single SDK client the whole
 * application shares.
 *
 * `AppContext` is a process-wide singleton because ArkUI recreates pages freely;
 * holding the `TransmissionClient` in a page would reconnect on every
 * navigation and lose the CSRF session id each time.
 *
 * Persisted blobs are JSON strings in a `preferences` store. Everything read
 * from disk is treated as untrusted: a truncated or hand-edited value yields
 * defaults rather than a crash at start-up.
 *
 * @since 1.0.0
 */

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import {
  HilogLogger,
  Json,
  JsonArray,
  JsonObject,
  LogLevel,
  TransmissionClient,
  TransmissionClientBuilder,
  TransmissionError,
  TransmissionErrorKind,
} from 'transmission_sdk';
import { AppSettings, ServerProfile } from '../model/AppModels';

/** Name of the preferences store on disk. */
const STORE_NAME: string = 'transmission_app';
/** Key holding the serialised server list. */
const KEY_SERVERS: string = 'servers';
/** Key holding the selected server id. */
const KEY_ACTIVE_SERVER: string = 'activeServerId';
/** Key holding the serialised settings. */
const KEY_SETTINGS: string = 'settings';
/** Key holding the cached CSRF session id of the active server. */
const KEY_SESSION_ID: string = 'sessionId';

/** What the UI can show about the current connection. */
export class ConnectionState {
  /** True once a call has succeeded. */
  connected: boolean = false;
  /** Human readable dialect, e.g. `JSON-RPC 2.0 (Transmission >= 4.1.0)`. */
  apiStyle: string = '';
  /** `rpc_version_semver` reported by the server. */
  serverVersion: string = '';
  /** `version` reported by the server. */
  serverVersionString: string = '';
  /** The endpoint in use. */
  url: string = '';
}

/**
 * Process-wide application state.
 *
 * Not observable: pages copy the fields they care about into `@State` after an
 * `await`, which keeps the reactivity rules simple and predictable.
 */
export class AppContext {
  /**
   * `AppStorage` key carrying the change counter.
   *
   * The store is deliberately not observable, and `NavPathStack.pushPath`
   * returns `void` (only `pushDestination` returns a promise), so there is no
   * return value to hang a completion callback off. A monotonically increasing
   * counter in `AppStorage` gives the screens a `@StorageLink` + `@Watch`
   * hand-off instead.
   */
  static readonly REVISION_KEY: string = 'dataRevision';

  private static shared: AppContext | undefined = undefined;
  private revision: number = 0;

  /** Persisted settings. */
  settings: AppSettings = new AppSettings();
  /** Persisted servers, in the order the user added them. */
  servers: ServerProfile[] = [];
  /** Id of the selected server, or an empty string. */
  activeServerId: string = '';

  private store: preferences.Preferences | undefined = undefined;
  private client: TransmissionClient | undefined = undefined;
  private sessionIds: Map<string, string> = new Map<string, string>();

  /**
   * Announces that persisted or server-side state changed.
   *
   * Called by the screens that mutate something another screen displays, so
   * that whoever is listening can re-read rather than show stale data.
   */
  notifyChanged(): void {
    this.revision++;
    AppStorage.setOrCreate(AppContext.REVISION_KEY, this.revision);
  }

  /** The singleton instance. */
  static get(): AppContext {
    if (AppContext.shared === undefined) {
      AppContext.shared = new AppContext();
    }
    return AppContext.shared;
  }

  // ------------------------------------------------------------- lifecycle

  /**
   * Loads persisted state. Safe to call more than once.
   *
   * @param context ability context used to locate the preferences store
   */
  async load(context: common.UIAbilityContext): Promise<void> {
    if (this.store !== undefined) {
      return;
    }
    this.store = await preferences.getPreferences(context, STORE_NAME);

    this.settings = AppSettings.fromJson(this.readJson(KEY_SETTINGS));
    this.servers = AppContext.parseServers(this.readJson(KEY_SERVERS));
    this.activeServerId = this.readString(KEY_ACTIVE_SERVER, '');
    this.sessionIds = AppContext.parseSessionIds(this.readJson(KEY_SESSION_ID));

    if (this.activeServerId.length === 0 && this.servers.length > 0) {
      this.activeServerId = this.servers[0].id;
    }
  }

  /** The selected server, or `undefined` when none is configured. */
  get activeServer(): ServerProfile | undefined {
    for (const server of this.servers) {
      if (server.id === this.activeServerId) {
        return server;
      }
    }
    return this.servers.length > 0 ? this.servers[0] : undefined;
  }

  // ---------------------------------------------------------------- server

  /** Creates a server id that is unique within this installation. */
  static newServerId(): string {
    return `srv-${Date.now()}-${Math.floor(Math.random() * 100000)}`;
  }

  /**
   * Inserts or replaces a server and persists the list.
   *
   * @param profile the server to save; its id must be set
   */
  async saveServer(profile: ServerProfile): Promise<void> {
    let replaced = false;
    for (let i = 0; i < this.servers.length; i++) {
      if (this.servers[i].id === profile.id) {
        this.servers[i] = profile;
        replaced = true;
        break;
      }
    }
    if (!replaced) {
      this.servers.push(profile);
    }
    await this.persistServers();
    this.notifyChanged();
  }

  /** Removes a server and, when it was active, selects another one. */
  async removeServer(serverId: string): Promise<void> {
    const remaining: ServerProfile[] = [];
    for (const server of this.servers) {
      if (server.id !== serverId) {
        remaining.push(server);
      }
    }
    this.servers = remaining;
    this.sessionIds.delete(serverId);
    if (this.activeServerId === serverId) {
      this.activeServerId = this.servers.length > 0 ? this.servers[0].id : '';
    }
    this.disconnect();
    await this.persistServers();
    await this.persistSessionIds();
    this.notifyChanged();
  }

  /**
   * Selects a server and connects to it.
   *
   * @param serverId id to activate
   * @returns the negotiated connection state
   */
  async selectServer(serverId: string): Promise<ConnectionState> {
    if (this.activeServerId !== serverId) {
      this.activeServerId = serverId;
      this.disconnect();
      await this.write(KEY_ACTIVE_SERVER, serverId);
      this.notifyChanged();
    }
    return this.connect();
  }

  // ----------------------------------------------------------------- client

  /**
   * Connects to the active server, reusing the existing client when possible.
   *
   * @returns the negotiated connection state
   * @throws TransmissionError when the server is unreachable or misconfigured
   */
  async connect(): Promise<ConnectionState> {
    const server = this.activeServer;
    if (server === undefined) {
      throw TransmissionError.configuration('no server has been configured');
    }
    if (this.client === undefined) {
      this.client = this.buildClient(server);
    }
    await this.client.connect();
    return this.connectionState();
  }

  /** The active client, if a connection has been established. */
  get activeClient(): TransmissionClient | undefined {
    return this.client;
  }

  /**
   * The active client, or an error explaining why there is none.
   *
   * @throws TransmissionError with kind `configuration`
   */
  requireClient(): TransmissionClient {
    if (this.client === undefined) {
      throw TransmissionError.configuration('not connected to a server');
    }
    return this.client;
  }

  /** Drops the connection and its cached CSRF session id. */
  disconnect(): void {
    if (this.client !== undefined) {
      this.rememberSessionId();
      this.client.close();
      this.client = undefined;
    }
  }

  /** Describes the current connection. */
  connectionState(): ConnectionState {
    const state = new ConnectionState();
    const server = this.activeServer;
    if (server !== undefined) {
      state.url = server.url;
    }
    const client = this.client;
    if (client !== undefined) {
      state.connected = client.isConnected;
      state.apiStyle = client.apiStyleLabel;
      const version = client.serverVersion;
      state.serverVersion = version === undefined ? '' : version.toString();
    }
    return state;
  }

  /** True when a client exists and has completed a call. */
  get isConnected(): boolean {
    const client = this.client;
    return client !== undefined && client.isConnected;
  }

  // ------------------------------------------------------------- settings

  /** Persists the current settings. */
  async saveSettings(): Promise<void> {
    await this.write(KEY_SETTINGS, JSON.stringify(this.settings.toJson()));
  }

  /** Applies the configured API dialect to the next connection. */
  applyApiStyle(): void {
    // The dialect is chosen when the client is built, so an existing client has
    // to be dropped for a change to take effect.
    this.disconnect();
  }

  /** Timeout in milliseconds, derived from the settings. */
  get timeoutMs(): number {
    const seconds = this.settings.requestTimeoutSeconds;
    return seconds > 0 ? Math.round(seconds * 1000) : 15000;
  }

  // ------------------------------------------------------------- internals

  /** Builds a client for `server`, restoring the cached CSRF session id. */
  private buildClient(server: ServerProfile): TransmissionClient {
    const builder = new TransmissionClientBuilder()
      .url(server.url)
      .apiStyleMode(this.settings.apiStyleMode)
      .timeout(this.timeoutMs)
      // 路由 SDK 诊断到 hilog（tag 为 TransmissionSDK/*）。DEBUG 级会打印
      // 每次 HTTP 请求体与响应状态，是排查连接问题唯一的证据来源。
      .logger(new HilogLogger(LogLevel.DEBUG))
      .onApiStyleResolved((style) => {
        // The resolved dialect is intentionally not persisted: negotiation is
        // cheap and a stale guess would be worse than re-detecting it.
        console.info(`TransmissionClient: negotiated api style ${style}`);
      });

    if (server.username.length > 0) {
      builder.credentials(server.username, server.password);
    }
    const cached = this.sessionIds.get(server.id);
    if (cached !== undefined) {
      builder.sessionId(cached);
    }
    return builder.build();
  }

  /** Stores the live CSRF session id so the next launch skips the handshake. */
  private rememberSessionId(): void {
    const server = this.activeServer;
    const client = this.client;
    if (server === undefined || client === undefined) {
      return;
    }
    const sessionId = client.sessionId;
    if (sessionId !== undefined && sessionId.length > 0) {
      this.sessionIds.set(server.id, sessionId);
      this.persistSessionIds();
    }
  }

  /** Reads a string, falling back when the key is absent. */
  private readString(key: string, fallback: string): string {
    const store = this.store;
    if (store === undefined) {
      return fallback;
    }
    const value = store.getSync(key, fallback) as string;
    return typeof value === 'string' ? value : fallback;
  }

  /** Reads and parses a JSON blob, returning `undefined` when unusable. */
  private readJson(key: string): JsonObject | undefined {
    const raw = this.readString(key, '');
    if (raw.length === 0) {
      return undefined;
    }
    try {
      return Json.asObject(Json.parse(raw));
    } catch (error) {
      console.warn(`discarding unreadable preference "${key}": ${(error as Error).message}`);
      return undefined;
    }
  }

  /** Writes a value and flushes it to disk. */
  private async write(key: string, value: string): Promise<void> {
    const store = this.store;
    if (store === undefined) {
      return;
    }
    await store.put(key, value);
    await store.flush();
  }

  private async persistServers(): Promise<void> {
    const array: JsonArray = [];
    for (const server of this.servers) {
      array.push(server.toJson());
    }
    const root: JsonObject = {};
    root['items'] = array;
    await this.write(KEY_SERVERS, JSON.stringify(root));
    await this.write(KEY_ACTIVE_SERVER, this.activeServerId);
  }

  private async persistSessionIds(): Promise<void> {
    const root: JsonObject = {};
    this.sessionIds.forEach((value: string, key: string) => {
      root[key] = value;
    });
    await this.write(KEY_SESSION_ID, JSON.stringify(root));
  }

  /** Parses the persisted server list. */
  private static parseServers(json: JsonObject | undefined): ServerProfile[] {
    const result: ServerProfile[] = [];
    const array = Json.getArray(json, 'items');
    if (array === undefined) {
      return result;
    }
    for (const item of array) {
      const profile = ServerProfile.fromJson(Json.asObject(item));
      if (profile.host.length > 0) {
        result.push(profile);
      }
    }
    return result;
  }

  /** Parses the persisted session-id map. */
  private static parseSessionIds(json: JsonObject | undefined): Map<string, string> {
    const result = new Map<string, string>();
    if (json === undefined) {
      return result;
    }
    for (const key of Json.keys(json)) {
      const value = Json.asString(json[key]);
      if (value !== undefined) {
        result.set(key, value);
      }
    }
    return result;
  }
}

/** Maps a failure onto a string resource the UI can show. */
export function describeErrorResource(error: Object): Resource {
  if (error instanceof TransmissionError) {
    // 打出完整错误（kind / rpcCode / httpStatus / request / cause），否则 UI 只显示
    // 一句泛化的文案，真实原因会被吞掉，无法排查。
    console.error(
      `TransmissionError kind=${error.kind} rpcCode=${error.rpcCode ?? '-'} ` +
        `httpStatus=${error.httpStatus ?? '-'} request=${error.request ?? '-'} ` +
        `message=${error.fullMessage} cause=${error.cause === undefined ? '-' : error.cause.message}`,
    );
    switch (error.kind) {
      case TransmissionErrorKind.AUTHENTICATION:
        return $r('app.string.error_auth');
      case TransmissionErrorKind.TIMEOUT:
        return $r('app.string.error_timeout');
      case TransmissionErrorKind.TRANSPORT:
        return $r('app.string.error_network');
      case TransmissionErrorKind.CONFIGURATION:
        return $r('app.string.error_config');
      case TransmissionErrorKind.UNSUPPORTED:
        return $r('app.string.error_unsupported');
      case TransmissionErrorKind.PROTOCOL:
        return $r('app.string.error_protocol');
      default:
        return $r('app.string.error_protocol');
    }
  }
  // 非 TransmissionError：说明抛出的是普通异常（TypeError 等），这才是最需要被看到的。
  const plain = error as Error;
  console.error(
    `Non-TransmissionError thrown: name=${plain?.name ?? '?'} message=${plain?.message ?? '?'} stack=${plain?.stack ?? '?'}`,
  );
  return $r('app.string.error_protocol');
}
