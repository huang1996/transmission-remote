# API reference

Everything below is exported from the package root:

```ts
import { /* … */ } from 'transmission_sdk';
```

## Contents

- [TransmissionClientBuilder](#transmissionclientbuilder)
- [TransmissionClient](#transmissionclient)
- [TorrentApi](#torrentapi)
- [SessionApi](#sessionapi)
- [SystemApi](#systemapi)
- [BandwidthGroupApi](#bandwidthgroupapi)
- [RpcBatch / BatchResults](#rpcbatch--batchresults)
- [RpcClient (advanced)](#rpcclient-advanced)
- [TransmissionConfig](#transmissionconfig)
- [Requests](#requests)
- [Models](#models)
- [Enums](#enums)
- [Errors](#errors)
- [Transport port](#transport-port)
- [Logging](#logging)
- [Utilities](#utilities)
- [Field and method constants](#field-and-method-constants)

---

## TransmissionClientBuilder

```ts
static create(): TransmissionClientBuilder

.config(config: TransmissionConfig): this
.url(url: string): this
.host(host: string, port?: number, path?: string): this     // defaults 9091, /transmission/rpc
.credentials(username: string, password: string): this
.apiStyleMode(mode: ApiStyleMode): this                     // default ApiStyleMode.AUTO
.timeout(timeoutMs: number): this                           // default 15_000
.header(name: string, value: string): this                  // added to every request
.sessionId(sessionId: string | undefined): this             // restore a previous CSRF id
.transport(transport: HttpTransport): this                  // default ArkHttpTransport
.logger(logger: Logger): this                               // default NoopLogger
.onApiStyleResolved(listener: ApiStyleListener): this
.build(): TransmissionClient                                 // throws on invalid configuration
```

`ApiStyleListener` is `(style: ApiStyle, version: RpcVersion | undefined) => void`.

---

## TransmissionClient

```ts
readonly torrents: TorrentApi
readonly session:  SessionApi
readonly system:   SystemApi
readonly groups:   BandwidthGroupApi

get url(): string
get apiStyle(): ApiStyle
get apiStyleLabel(): string                 // human readable dialect description
get isNegotiating(): boolean
get serverVersion(): RpcVersion | undefined
get isConnected(): boolean
get sessionId(): string | undefined
get isClosed(): boolean

connect(): Promise<SessionSettings>         // verifies connectivity, learns the version
ping(): Promise<boolean>                    // never throws
batch(): RpcBatch
raw(method: RpcMethod, params?: JsonObject): Promise<JsonObject>
setSessionId(sessionId: string | undefined): void
close(): void
```

`connect()` performs one `session_get`. On first contact with a server older than 4.1.0 it
transparently downgrades the dialect; see [COMPATIBILITY.md](COMPATIBILITY.md).

---

## TorrentApi

### Reading

```ts
get(request?: TorrentGetRequest): Promise<Torrent[]>
getTable(request?: TorrentGetRequest): Promise<TorrentTable>
getOne(id: number | string, fields?: string[]): Promise<Torrent | undefined>
getRecentlyActive(request?: TorrentGetRequest): Promise<RecentlyActiveTorrents>
getFiles(id: number | string): Promise<TorrentFile[]>
count(): Promise<number>
```

`TorrentGetRequest` defaults to `TorrentFields.BASIC`. `getTable()` sets `format: "table"`, which is
cheaper to transfer and parse for large sessions.

### Actions

```ts
start(ids?: TorrentIds): Promise<void>
startNow(ids?: TorrentIds): Promise<void>
stop(ids?: TorrentIds): Promise<void>
verify(ids?: TorrentIds): Promise<void>
reannounce(ids?: TorrentIds): Promise<void>
moveToTop(ids?: TorrentIds): Promise<void>
moveUp(ids?: TorrentIds): Promise<void>
moveDown(ids?: TorrentIds): Promise<void>
moveToBottom(ids?: TorrentIds): Promise<void>
```

Every `ids` parameter defaults to `TorrentIds.ALL`, which omits the `ids` key entirely.

### Mutating

```ts
add(request: TorrentAddRequest): Promise<TorrentAddResult>   // throws CONFIGURATION without filename/metainfo
addFromUri(uri: string): Promise<TorrentAddResult>
addMagnet(magnetLink: string): Promise<TorrentAddResult>
addFromBytes(bytes: Uint8Array): Promise<TorrentAddResult>
remove(ids: TorrentIds, deleteLocalData?: boolean): Promise<void>
set(request: TorrentSetRequest): Promise<void>
setLocation(ids: TorrentIds, location: string, move?: boolean): Promise<void>
renamePath(id: number | string, path: string, name: string): Promise<TorrentRenameResult>
```

---

## SessionApi

```ts
get(fields?: string[]): Promise<SessionSettings>
getRaw(fields?: string[]): Promise<JsonObject>
set(request: SessionSetRequest): Promise<void>
setValue(key: string, value: string | number | boolean): Promise<void>
stats(): Promise<SessionStats>
close(): Promise<void>
```

---

## SystemApi

```ts
freeSpace(path: string): Promise<FreeSpace>          // `path` is on the server
portTest(protocol?: IpProtocol): Promise<PortTestResult>
updateBlocklist(): Promise<number>                   // -1 when the server does not report a size
```

---

## BandwidthGroupApi

```ts
getAll(names?: string[]): Promise<BandwidthGroup[]>
get(name: string): Promise<BandwidthGroup | undefined>
set(request: BandwidthGroupSetRequest): Promise<void>
```

`BandwidthGroupSetRequest`:

```ts
new BandwidthGroupSetRequest(name: string)
  .honorsSessionLimits(enabled: boolean)
  .speedLimitDown(kilobytesPerSecond: number)
  .speedLimitDownEnabled(enabled: boolean)
  .speedLimitUp(kilobytesPerSecond: number)
  .speedLimitUpEnabled(enabled: boolean)
  .toJson(): JsonObject
```

---

## RpcBatch / BatchResults

```ts
client.batch()
  .add(method: RpcMethod, params?: JsonObject): RpcBatch
  .addCall(call: RpcCall): RpcBatch
  .size / .isEmpty / .methods
  .execute(): Promise<RpcOutcome[]>          // one HTTP round trip, per-element outcomes
  .executeOrThrow(): Promise<JsonObject[]>   // throws on the first failure

new BatchResults(outcomes: RpcOutcome[])
  .size / .isSuccess
  .at(index: number): JsonObject             // throws when the call failed or the index is out of range
  .outcomeAt(index: number): RpcOutcome | undefined
```

---

## RpcClient (advanced)

```ts
new RpcClient(config, transport, negotiator, logger?)

get currentStyle(): ApiStyle
get serverVersion(): RpcVersion | undefined
get currentSessionId(): string | undefined
get isNegotiating(): boolean
get isClosed(): boolean

call(method: RpcMethod, params?: JsonObject): Promise<JsonObject>
callBatch(calls: RpcCall[]): Promise<RpcOutcome[]>
callRaw(body: JsonObject): Promise<JsonObject>       // escape hatch; not passed through compat
setSessionId(sessionId: string | undefined): void
close(): void
```

Prefer `TransmissionClient`; this class is exported so that applications can implement methods the
SDK does not wrap yet without re-implementing the handshake.

---

## TransmissionConfig

```ts
static of(url?: string): TransmissionConfig                        // default http://127.0.0.1:9091/transmission/rpc
static forHost(host: string, port?: number, path?: string): TransmissionConfig

get url / username / password / apiStyleMode / timeoutMs / headers / sessionId

withUrl(url) / withCredentials(user, password) / withApiStyleMode(mode)
withTimeout(ms) / withHeader(name, value) / withSessionId(id)
validate(): void                                                   // throws TransmissionError(CONFIGURATION)
```

`DEFAULT_TIMEOUT_MS` is exported as `15_000`.

---

## Requests

### `TorrentIds`

```ts
static readonly ALL: TorrentIds              // omits `ids`
static readonly RECENTLY_ACTIVE: TorrentIds  // ids: "recently_active"
static of(ids: TorrentId[]): TorrentIds
static single(id: TorrentId): TorrentIds
static ofHashes(hashes: string[]): TorrentIds
static ofNumbers(ids: number[]): TorrentIds

get isAll / isRecentlyActive / size
toJson(): JsonValue | undefined
applyTo(builder: JsonObjectBuilder): JsonObjectBuilder
toString(): string
```

`TorrentId` is `number | string` (numeric id or info-hash).

### `TorrentGetRequest`

```ts
new TorrentGetRequest(fields?: string[])       // default TorrentFields.BASIC
  .ids(ids: TorrentIds)
  .fields(fields: string[])
  .addField(field: string)
  .addFields(fields: string[])
  .format(format: TorrentFormat)
  .toJson(): JsonObject
```

### `TorrentAddRequest`

```ts
static create(): TorrentAddRequest
static fromFilename(filename: string)
static fromMagnet(magnetLink: string)
static fromBytes(bytes: Uint8Array)            // base64-encodes for you
static fromMetainfo(base64Metainfo: string)

.filename(v) / .metainfo(v) / .metainfoBytes(bytes)
.downloadDir(path) / .cookies(v) / .labels(labels) / .paused(flag)
.peerLimit(n) / .bandwidthPriority(p)
.filesWanted(indices) / .filesUnwanted(indices)
.priorityHigh(indices) / .priorityLow(indices) / .priorityNormal(indices)
.sequentialDownload(flag) / .sequentialDownloadFromPiece(piece)
get isComplete(): boolean
toJson(): JsonObject
```

### `TorrentSetRequest`

```ts
new TorrentSetRequest(ids?: TorrentIds)        // default TorrentIds.ALL
  .ids(ids)
  .bandwidthPriority(p)
  .downloadLimit(kBps) / .downloadLimited(flag)
  .uploadLimit(kBps)   / .uploadLimited(flag)
  .honorsSessionLimits(flag)
  .filesWanted(i) / .filesUnwanted(i)
  .priorityHigh(i) / .priorityLow(i) / .priorityNormal(i)
  .labels(labels) / .group(name) / .location(path)
  .peerLimit(n) / .queuePosition(n)
  .seedIdleLimit(minutes) / .seedIdleMode(mode)
  .seedRatioLimit(ratio)  / .seedRatioMode(mode)
  .sequentialDownload(flag) / .sequentialDownloadFromPiece(piece)
  .trackerList(announceUrls)
  .trackerAdd(urls) / .trackerRemove(ids) / .trackerReplace(pairs)   // deprecated upstream
  get hasChanges(): boolean
  toJson(): JsonObject
```

Calling `filesWanted([])` / `priorityHigh([])` / `labels([])` sends an empty array, which
Transmission interprets as a reset. Setters that are never called are absent from the payload.

### `SessionSetRequest`

Generated from §4.1.1 of the RPC spec — 49 setters covering every mutable session setting, e.g.
`altSpeedDown`, `downloadDir`, `downloadQueueEnabled`, `encryption`, `peerLimitGlobal`, `peerPort`,
`preferredTransports`, `seedRatioLimit`, `speedLimitDownEnabled`, …

```ts
new SessionSetRequest()
  .downloadDir('/srv/media')
  .encryption(EncryptionMode.REQUIRED)
  .preferredTransports([TransportProtocol.UTP, TransportProtocol.TCP])
  .speedLimitDown(4096)
  .speedLimitDownEnabled(true)

.setRaw(key: string, value: JsonValue): SessionSetRequest   // escape hatch
get hasChanges(): boolean
get size(): number
toJson(): JsonObject
```

### `TorrentFields`

```ts
static readonly BASIC: string[]      // 18 fields for a list screen
static readonly PROGRESS: string[]   // 45 fields for a detail screen
static readonly DETAILED: string[]   // PROGRESS + files, peers, trackers, …
```

Requesting fewer fields is the cheapest available optimisation for `torrent_get`.

---

## Models

| Class | Returned by |
|:--|:--|
| `Torrent` | `torrent_get` |
| `TorrentFile`, `TorrentFileStat` | `Torrent.files`, `Torrent.fileStats` |
| `Peer`, `PeerSources` | `Torrent.peers`, `Torrent.peersFrom` |
| `Tracker`, `TrackerStat` | `Torrent.trackers`, `Torrent.trackerStats` |
| `Webseed` | `Torrent.webseedsEx` |
| `TorrentTable` | `torrent_get` with `format: "table"` |
| `TorrentAddResult` | `torrent_add` (`added`, `duplicate`) |
| `TorrentRenameResult` | `torrent_rename_path` |
| `RecentlyActiveTorrents` | `torrent_get` with `ids: "recently_active"` |
| `SessionSettings`, `SessionUnits`, `BlocklistInfo` | `session_get`, `blocklist_update` |
| `SessionStats`, `SessionStatsEntry` | `session_stats` |
| `BandwidthGroup` | `group_get` |
| `FreeSpace` | `free_space` |
| `PortTestResult` | `port_test` |

Every model exposes `static fromJson(json: JsonObject | undefined): T`, which never throws. Missing
keys keep their documented defaults, and unknown keys are ignored — which is why a single model class
can represent a response from any 4.x server.

Selected conveniences:

```ts
Torrent:      isActive, isComplete, totalRate
PeerSources:  total
TrackerStat:  seederCount / leecherCount / downloadCount default to -1 when unknown
SessionUnits: isDecimal(), bytesPerKb()
SessionSettings: rpcVersion, supportsJsonRpc
SessionStats: totalRate;  SessionStatsEntry: ratio, totalBytes
FreeSpace:    usedBytes, usedFraction
TorrentAddResult: wasAdded, wasDuplicate, torrent
TorrentTable: columns, rows, isTable
BandwidthGroup: listFromJson(json) reads the `group` array
RecentlyActiveTorrents: fromObjects / fromTable / fromJson (auto-detect)
```

---

## Enums

All numeric enums match `libtransmission/transmission.h` and are sent on the wire unchanged.

| Enum | Values |
|:--|:--|
| `TorrentStatus` | `STOPPED` 0 … `SEEDING` 6 |
| `TorrentPriority` | `LOW` -1, `NORMAL` 0, `HIGH` 1 |
| `FilePriority` | `LOW` -1, `NORMAL` 0, `HIGH` 1 |
| `IdleLimitMode` | `GLOBAL` 0, `SINGLE` 1, `UNLIMITED` 2 |
| `RatioLimitMode` | `GLOBAL` 0, `SINGLE` 1, `UNLIMITED` 2 |
| `TrackerAnnounceState` | `INACTIVE` 0, `WAITING` 1, `QUEUED` 2, `ACTIVE` 3 |
| `TrackerScrapeState` | `INACTIVE` 0, `QUEUED` 1, `ACTIVE` 2 |
| `EncryptionMode` | `REQUIRED`, `PREFERRED`, `ALLOWED` |
| `TransportProtocol` | `UTP`, `TCP` |
| `TorrentFormat` | `OBJECTS`, `TABLE` |
| `IpProtocol` | `IPV4`, `IPV6` |
| `ApiStyle` | `MODERN`, `LEGACY` |
| `ApiStyleMode` | `AUTO`, `MODERN`, `LEGACY` |

Helpers: `isTorrentActive(status)`, `isTorrentStopped(status)`, `parseEnum(value, allowed, fallback)`,
`apiStyleLabel(style)`.

---

## Errors

```ts
class TransmissionError extends Error {
  readonly kind: TransmissionErrorKind
  readonly rpcCode: RpcErrorCode | undefined
  readonly rawCode: number | undefined
  readonly httpStatus: number | undefined
  readonly data: JsonObject | undefined
  readonly detail: string | undefined
  readonly request: string | undefined
  readonly cause: Error | undefined
  get retryable(): boolean
  get fullMessage(): string
}
```

`TransmissionErrorKind`: `TRANSPORT`, `HTTP`, `PROTOCOL`, `RPC`, `TIMEOUT`, `AUTHENTICATION`,
`CONFIGURATION`, `UNSUPPORTED`, `CANCELLED`.

Factories: `transport`, `timeout`, `protocol`, `authentication`, `http`, `rpc`, `unsupported`,
`configuration`.

`RpcErrorCode` and the helpers `rpcErrorMessage(code)` / `rpcErrorCodeFromMessage(message)` are
documented in [COMPATIBILITY.md](COMPATIBILITY.md#error-code-normalisation).

---

## Transport port

```ts
interface HttpTransport {
  execute(request: HttpRequest): Promise<HttpResponse>;
  destroy(): void;
}

class HttpRequest {
  constructor(url: string, verb: HttpVerb, headers: Map<string, string>,
              body: string | undefined, timeoutMs: number)
  get description(): string
}

class HttpResponse {
  constructor(status: number, headers: Map<string, string>, body: string)
  header(name: string): string | undefined      // case-insensitive
}
```

`ArkHttpTransport` is the HarmonyOS implementation; `AbstractHttpTransport` is a convenience base
class that handles the disposed flag.

---

## Logging

```ts
interface Logger {
  log(level: LogLevel, tag: string, message: string): void
  debug(tag, message) / info(tag, message) / warn(tag, message) / error(tag, message)
  isEnabled(level: LogLevel): boolean
}
```

`LogLevel`: `DEBUG` 0, `INFO` 1, `WARN` 2, `ERROR` 3, `NONE` 4.

Implementations: `NoopLogger` (default), `ConsoleLogger`, `InMemoryLogger`, `HilogLogger` (platform).
`AbstractLogger` implements the level filtering; subclasses override `write`.

---

## Utilities

| Export | Purpose |
|:--|:--|
| `Json` | total JSON accessors: `get*`, `as*`, `to*Array`, `keys`, `isEmpty`, `parse`, `stringify`, `clone`, `deepEquals` |
| `JsonObjectBuilder` | `set` / `setAlways` / `setArray` / `setObject` / `has` / `build`; drops `undefined` |
| `JsonValue`, `JsonObject`, `JsonArray`, `JsonPrimitive` | dynamic JSON types |
| `Base64` | `encodeUtf8`, `decodeUtf8`, `encodeBytes`, `decodeToBytes`, `utf8Bytes`, `utf8ToString`, `basicAuthorization` |
| `RpcVersion` | `parse`, `compareTo`, `isAtLeast`, `isBelow`, `equals`, `toString` |
| `RpcVersions` | `fromInteger`, `supportsJsonRpc`, `V6_0_0`, `MAXIMUM_KNOWN_INTEGER` |

---

## Field and method constants

```ts
enum RpcMethod { TORRENT_GET = 'torrent_get', SESSION_SET = 'session_set', … }   // 24 methods
ALL_RPC_METHODS: RpcMethod[]
isKnownRpcMethod(method: string): boolean
```

Generated field-name enums, useful for building field lists without typos:

| Enum | Count |
|:--|--:|
| `TorrentField` | 80 |
| `SessionField` | 61 |
| `TrackerStatField` | 28 |
| `PeerField` | 20 |
| `PeerSourceField` | 8 |
| `BandwidthGroupField`, `TorrentFileField`, `SessionStatField`, `SessionStatsEntryField` | 5–7 |
| `WebseedField`, `TorrentFileStatField` | 3 |

`WireKeys` exposes the envelope key names (`jsonrpc`, `method`, `params`, `arguments`, `result`,
`error`, `id`, `tag`, …) plus `HttpStatus`, `HEADER_SESSION_ID`, `HEADER_RPC_VERSION`,
`DEFAULT_RPC_URL`, `DEFAULT_RPC_PORT`, `DEFAULT_RPC_PATH`.

Compatibility internals (`LegacyKeys`, `KeyConverter`, `KeyDirection`, `ConversionContext`,
`ModernCodec`, `LegacyCodec`, `StyleNegotiator`, `RpcCall`, `RpcOutcome`, `RpcErrorInfo`) are exported
for diagnostics and testing. Application code should not need them.
