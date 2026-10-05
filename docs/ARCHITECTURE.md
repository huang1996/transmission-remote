# Architecture

This document explains how the SDK is layered, what each layer is allowed to know about, and why the
pieces are shaped the way they are.

## Layers

```
┌──────────────────────────────────────────────────────────────────────┐
│  application                                                         │
└───────────────┬──────────────────────────────────────────────────────┘
                │  TransmissionClient  (client/)
                │    .torrents  .session  .system  .groups
┌───────────────▼──────────────────────────────────────────────────────┐
│  api/            TorrentApi · SessionApi · SystemApi · BandwidthGroupApi
│                  thin, typed, one method per RPC method              │
├──────────────────────────────────────────────────────────────────────┤
│  model/          Torrent · SessionSettings · …                       │
│                  request builders (TorrentGetRequest, …)             │
├──────────────────────────────────────────────────────────────────────┤
│  core/           RpcClient   — retries, CSRF, negotiation, batching  │
│                  RpcBatch    — several calls, one round trip         │
│                  TransmissionConfig                                  │
├──────────────────────────────────────────────────────────────────────┤
│  compat/         ModernCodec · LegacyCodec · KeyConverter ·           │
│                  StyleNegotiator · LegacyKeys (generated)            │
├──────────────────────────────────────────────────────────────────────┤
│  transport/      HttpTransport  (port)                               │
│  platform/       ArkHttpTransport · HilogLogger  (adapters)          │
└──────────────────────────────────────────────────────────────────────┘
        util/ (Json · Base64 · Semver · Logger) and error/ are shared by every layer
```

### Dependency rule

Dependencies point **downwards only**:

- `api/` may use `core/`, `model/`, `error/`, `util/`, `constants/`.
- `core/` may use `compat/`, `transport/`, `error/`, `util/`, `constants/`. It never imports `api/`,
  `client/` or `platform/`.
- `compat/` may use `error/`, `util/`, `constants/`. It never imports `core/`.
- `model/` may use `util/`, `error/`, `constants/`. It never performs I/O.
- `platform/` is the only place that imports a HarmonyOS kit (`@kit.NetworkKit`,
  `@kit.BasicAnalysisKit`). It implements ports declared in `transport/` and `util/`.

The payoff is concrete: because nothing above `platform/` touches the network, every layer can be
driven by a scripted fake transport. The 380+ unit tests run on a plain JavaScript engine, without a
Transmission daemon and without a device.

## The transport port

```ts
export interface HttpTransport {
  execute(request: HttpRequest): Promise<HttpResponse>;
  destroy(): void;
}
```

`HttpRequest` / `HttpResponse` are plain value objects; header names are normalised to lower case on
both sides, and `HttpResponse.header(name)` is case-insensitive.

- Production: `platform/ArkHttpTransport` wraps `@kit.NetworkKit`. A `http.HttpRequest` is created per
  call and destroyed in `finally`, because NetworkKit does not document its request object as safe
  for concurrent use.
- Tests: `src/test/helpers/FakeTransport` replays a scripted queue of responses and records every
  request, which is what allows asserting the exact wire bytes for each dialect.

Logging follows the same pattern: `util/Logger` is an interface with `NoopLogger` (the default),
`ConsoleLogger`, `InMemoryLogger`, and the platform-backed `HilogLogger`.

## Request lifecycle

`RpcClient.execute()` is the only place that knows how a call reaches the server:

```
call(method, params)
  │
  ├─ id = nextRequestId++
  ├─ codec = negotiator.codec()          // modern or legacy
  ├─ body  = codec.encodeRequest(call, id)
  ├─ POST body to config.url, with
  │     content-type, accept,
  │     x-transmission-session-id (once known),
  │     authorization (when credentials are configured),
  │     any extra headers from the configuration
  │
  ├─ HTTP 409 ─┬─ capture x-transmission-session-id
  │            ├─ negotiator.observeVersionHeader(x-transmission-rpc-version)
  │            └─ retry (at most twice)
  ├─ HTTP 401 ─── TransmissionError(AUTHENTICATION)
  ├─ HTTP 403 ─── TransmissionError(HTTP)   // usually rpc_host_whitelist
  ├─ HTTP 200 ─┬─ parse JSON
  │            ├─ codec.decodeResponse(...)
  │            ├─ METHOD_NOT_FOUND in AUTO mode → downgrade → retry (at most once)
  │            └─ RpcOutcome (success or RPC error)
  └─ anything else → TransmissionError(HTTP)
```

The loop is bounded by `MAX_ATTEMPTS = 4`, so a misbehaving server cannot cause an infinite retry
storm; three consecutive 409s surface as a `PROTOCOL` error.

`callBatch()` runs the same state machine with a JSON array body, and reports per-element outcomes so
one failing call does not discard the others.

## Dialect negotiation

Transmission 4.1.0 accepts *both* dialects and mirrors the request's dialect in its response. That
property is what makes negotiation cheap:

1. The client starts in the **modern** dialect.
2. The first request always triggers the CSRF 409 on a server that has not been talked to before.
   - If `X-Transmission-Rpc-Version` is present, the server is ≥ 4.1.0 → stay modern.
   - If it is absent, the server predates 4.1.0 (the header only exists from `rpc-version-semver`
     6.0.0) → switch to legacy *before* the retry, so no request is wasted.
3. If the session id was already cached (a restored client), no 409 happens. A legacy server then
   answers the modern request with `METHOD_NOT_FOUND`, which triggers the same downgrade and one
   retry.
4. Any successful `session_get` also feeds `rpc_version_semver` / `rpc_version` into the negotiator,
   so the version is known even in the restored-session case.

Net cost for a modern server: **zero** extra requests. For a legacy server: **one** extra request, on
first contact only.

`StyleNegotiator` owns the decision. It is a plain object with no I/O, which makes every branch
table-testable. Its listener lets an application persist the resolved style and pin it on the next
launch via `ApiStyleMode.MODERN` / `ApiStyleMode.LEGACY`.

## Codecs and key conversion

`compat/RpcCodec.ets` defines three things:

- `RpcCall` — a logical call in canonical form (snake_case method and parameters).
- `RpcOutcome` — a decoded result: `RpcErrorInfo` or a canonical `result` object.
- `RpcCodec` — `encodeMethodName`, `encodeRequest`, `encodeBatch`, `decodeResponse`, `decodeBatch`.

`ModernCodec` forwards canonical keys verbatim (`download_dir` stays `download_dir`, including inside
a `fields` array) and wraps the call in `{jsonrpc, method, params, id}`.

`LegacyCodec` kebab-cases the method name, wraps the call in `{method, arguments, tag}` and pushes
every parameter through `KeyConverter.toLegacy`.

`KeyConverter` is a faithful port of `convert_key()` / `convert_string()` / `convert_keys()` from
`libtransmission/api-compat.cc`, quirks included:

| Quirk | Rule |
|:--|:--|
| `download_dir` | `downloadDir` inside `torrent_get`/`torrent_set`, `download-dir` everywhere else |
| `total_size` in a `free_space` response | stays `total_size`, even in the legacy dialect |
| `fields` array elements | translated as keys, because they *are* keys |
| `wanted` | booleans ⇄ `0`/`1` integers |
| `encryption` | `allowed` ⇄ `tolerated` |

Every conversion method is pure: it returns new JSON and never mutates the caller's request template.

Both codecs also tolerate the *other* dialect's envelope on decode. That leniency is not laziness — it
is what lets the modern decoder recognise the "method not found" reply a 4.0.x server sends to a
modern request.

## Models

Parsing lives in `static fromJson(json: JsonObject | undefined)` factories on the model classes.
They are deliberately:

- **total** — `undefined`, missing keys, wrong types and malformed array entries all produce a usable
  object rather than an exception;
- **explicit** — one assignment per field, so a reader can diff them against the RPC specification;
- **defaulted** — an absent field means "not requested", and the documented default is used.

`Torrent` also exposes `wanted: boolean[]` rather than raw `0`/`1`, because the codec already
normalises it.

Request builders are the mirror image: they only serialise the fields the caller set, which matters
because Transmission treats an absent key as "leave unchanged".

## Error model

`TransmissionError` is the only error type the SDK throws. It carries:

- `kind: TransmissionErrorKind` — `TRANSPORT`, `HTTP`, `PROTOCOL`, `RPC`, `TIMEOUT`,
  `AUTHENTICATION`, `CONFIGURATION`, `UNSUPPORTED`, `CANCELLED`;
- `rpcCode: RpcErrorCode` — the normalised protocol code, including Transmission's own `1`…`10`;
- `rawCode`, `httpStatus`, `data`, `detail`, `request`, `cause`;
- `retryable` and `fullMessage` conveniences.

The legacy dialect has no error codes, so `rpcErrorCodeFromMessage()` reproduces Transmission's own
`guess_error_code()` phrase table. Unrecognised phrases are preserved verbatim in `detail`, and the
canonical text is used as the message.

## Generated code

Three files are generated from the Transmission repository and committed, so the SDK cannot silently
drift from the protocol:

| Generated file | Source of truth | Generator |
|:--|:--|:--|
| `compat/LegacyKeys.ets` (212 key pairs) | `libtransmission/api-compat.cc` + `libtransmission/quark.*` | `scripts/generate-legacy-keys.mjs` |
| `constants/RpcFields.ets` (231 field names in 12 enums) | `docs/rpc-spec.md` | `scripts/generate-rpc-fields.mjs` |
| `model/SessionSetRequest.ets` (49 setters) | `docs/rpc-spec.md` §4.1.1 | `scripts/generate-session-set-request.mjs` |

Tests assert the generated tables' size and their irregular entries, so a regeneration that loses
rows fails the build.

## Threading and lifetime

The SDK is single-threaded in the ArkTS sense: every public method returns a `Promise`, nothing runs
in the background, and there are no timers or callbacks that outlive a call. `RpcClient` keeps only
the session id and a monotonically increasing request id, so several calls may be in flight
concurrently; the transport is responsible for whatever connection pooling it wants to do.

`TransmissionClient.close()` destroys the transport and marks the client closed; further calls reject
with `TRANSPORT`. The app calls it from `aboutToDisappear()`.

## Testing strategy

| Layer | How it is tested |
|:--|:--|
| `util/` | Direct unit tests, including RFC 4648 vectors and 256-byte round trips |
| `error/` | Phrase-table and factory tests |
| `compat/` | Wire-shape assertions for both codecs, plus the api-compat "crazy cases" |
| `core/` | `RpcClient` driven by `FakeTransport`: handshake, downgrade, retry caps, error mapping |
| `model/` | `fromJson` totality, nested collections, legacy encodings, table format |
| `api/` | Exact request assertions per method, both dialects |
| `client/` | The same operation against a fake modern server and a fake legacy server producing identical typed results |
| `platform/` | Not unit-tested on the host; it is a thin, reviewable adapter |

The application is covered the same way where it makes sense:

| Layer | How it is tested |
|:--|:--|
| `entry/model/` | Server-URL building, settings round-trips, unknown-enum fallbacks |
| `entry/viewmodel/` (logic) | Filter predicates, per-filter counts, every sort key, tie-breaking, row formatting |
| `entry/pages/`, `entry/components/` | ArkUI markup: `npm run lint` plus a DevEco build — `tsc` cannot parse `struct` or a decorator |

The host harness (`scripts/run-tests.mjs`) makes those tests runnable without DevEco Studio. See
[../scripts/README.md](../scripts/README.md).
