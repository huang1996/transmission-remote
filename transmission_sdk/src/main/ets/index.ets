// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Transmission SDK for HarmonyOS / ArkTS — public API.
 *
 * Import everything from the package root:
 *
 * ```ts
 * import {
 *   TransmissionClient,
 *   TransmissionClientBuilder,
 *   TorrentGetRequest,
 *   TorrentFields,
 *   TorrentIds,
 *   LogLevel,
 * } from 'transmission_sdk';
 *
 * const client = new TransmissionClientBuilder()
 *   .host('192.168.1.10')
 *   .credentials('admin', 'secret')
 *   .build();
 *
 * const settings = await client.connect();
 * const torrents = await client.torrents.get(new TorrentGetRequest(TorrentFields.BASIC));
 * ```
 *
 * The SDK speaks both RPC dialects Transmission has shipped:
 *
 * - **JSON-RPC 2.0 / snake_case** (Transmission >= 4.1.0,
 *   `rpc-version-semver` >= 6.0.0)
 * - **the legacy bespoke protocol / mixed kebab-case and camelCase**
 *   (Transmission < 4.1.0)
 *
 * The dialect is negotiated automatically. Application code always uses the
 * canonical snake_case names; the `compat/` layer translates them.
 *
 * @packageDocumentation
 * @since 1.0.0
 */

// ----------------------------------------------------------------- client ---

export { TransmissionClient } from './client/TransmissionClient';
export { TransmissionClientBuilder } from './client/TransmissionClientBuilder';

// ------------------------------------------------------------------- core ---

export { TransmissionConfig, DEFAULT_TIMEOUT_MS } from './core/TransmissionConfig';
export { RpcClient } from './core/RpcClient';
export { RpcBatch, BatchResults } from './core/RpcBatch';

// -------------------------------------------------------------- transport ---

export {
  HttpRequest,
  HttpResponse,
  HttpTransport,
  HttpVerb,
  AbstractHttpTransport,
} from './transport/HttpTransport';

// --------------------------------------------------------------- platform ---

export { ArkHttpTransport } from './platform/ArkHttpTransport';
export { HilogLogger } from './platform/HilogLogger';

// ------------------------------------------------------------------ compat ---

export { ApiStyle, ApiStyleMode, apiStyleLabel } from './compat/ApiStyle';
export { StyleNegotiator, ApiStyleListener } from './compat/StyleNegotiator';
export { RpcCall, RpcErrorInfo, RpcOutcome, RpcCodec, BaseRpcCodec, ModernCodec, LegacyCodec } from './compat/RpcCodec';
export { KeyConverter, KeyDirection, ConversionContext } from './compat/KeyConversion';
export { LegacyKeys } from './compat/LegacyKeys';

// ------------------------------------------------------------------ errors ---

export {
  TransmissionError,
  TransmissionErrorKind,
  TransmissionErrorOptions,
  RpcErrorCode,
  rpcErrorMessage,
  rpcErrorCodeFromMessage,
} from './error/TransmissionError';

// ---------------------------------------------------------------- services ---

export { TorrentApi } from './api/TorrentApi';
export { SessionApi } from './api/SessionApi';
export { SystemApi } from './api/SystemApi';
export { BandwidthGroupApi, BandwidthGroupSetRequest } from './api/BandwidthGroupApi';

// ------------------------------------------------------------------ models ---

export {
  Torrent,
  TorrentFile,
  TorrentFileStat,
  Peer,
  PeerSources,
  Tracker,
  TrackerStat,
  Webseed,
} from './model/Torrent';

export {
  TorrentIds,
  TorrentFields,
  TorrentId,
  TorrentGetRequest,
  TorrentAddRequest,
  TorrentSetRequest,
} from './model/TorrentRequests';

export {
  TorrentTable,
  TorrentRenameResult,
  TorrentAddResult,
  RecentlyActiveTorrents,
} from './model/TorrentResults';

export { SessionSettings, SessionUnits, BlocklistInfo } from './model/SessionSettings';
export { Metainfo, MetainfoFile } from './model/Metainfo';
export { SessionSetRequest } from './model/SessionSetRequest';
export { SessionStats, SessionStatsEntry } from './model/SessionStats';
export { BandwidthGroup } from './model/BandwidthGroup';
export { FreeSpace, PortTestResult } from './model/SystemInfo';

export {
  TorrentStatus,
  TorrentPriority,
  FilePriority,
  IdleLimitMode,
  RatioLimitMode,
  TrackerAnnounceState,
  TrackerScrapeState,
  EncryptionMode,
  TransportProtocol,
  TorrentFormat,
  IpProtocol,
  isTorrentActive,
  isTorrentStopped,
  parseEnum,
} from './model/Enums';

// ------------------------------------------------------------- constants ---

export { RpcMethod, ALL_RPC_METHODS, isKnownRpcMethod } from './constants/RpcMethods';
export {
  TorrentField,
  TorrentFileField,
  TorrentFileStatField,
  PeerField,
  PeerSourceField,
  TrackerField,
  TrackerStatField,
  WebseedField,
  SessionField,
  SessionStatField,
  SessionStatsEntryField,
  BandwidthGroupField,
} from './constants/RpcFields';
export {
  WireKeys,
  HttpStatus,
  HEADER_SESSION_ID,
  HEADER_RPC_VERSION,
  DEFAULT_RPC_URL,
  DEFAULT_RPC_PORT,
  DEFAULT_RPC_PATH,
} from './constants/WireProtocol';

// -------------------------------------------------------------- utilities ---

export { Json, JsonObject, JsonArray, JsonValue, JsonPrimitive, JsonObjectBuilder } from './util/Json';
export { Base64 } from './util/Base64';
export { Bencode, BencodeKind, BencodeValue } from './util/Bencode';
export { RpcVersion, RpcVersions } from './util/Semver';
export {
  Logger,
  LogLevel,
  logLevelName,
  AbstractLogger,
  NoopLogger,
  ConsoleLogger,
  InMemoryLogger,
} from './util/Logger';
