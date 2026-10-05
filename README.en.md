# TransmissionRemote

**English** · [简体中文](README.md)

A **HarmonyOS client for the [Transmission](https://transmissionbt.com/) BitTorrent daemon** — drive
your download box from a phone or tablet: follow progress, add magnets and `.torrent` files, tune
per-torrent and session settings, and keep several servers at hand.

The repository ships two things:

| Directory | What it is |
|:--|:--|
| **`entry/`** | the application — a complete Transmission remote built with ArkUI |
| **`transmission_sdk/`** | `transmission_sdk`, the ArkTS RPC client the app is built on, packaged as a HAR |

The SDK is a first-class deliverable rather than an implementation detail. It speaks **both** RPC
dialects Transmission has ever shipped, so the same app drives a current 4.1.x daemon *and* an
old NAS running something a decade old:

| Transmission | RPC version | Wire dialect | Support |
|:--|:--|:--|:--|
| **4.1.0 and newer** | `rpc-version-semver` ≥ `6.0.0` | JSON-RPC 2.0, snake_case keys | ✅ preferred dialect |
| **4.0.x and older** (1.30 → 4.0.x) | `rpc-version` ≤ `17` | bespoke RPC, mixed kebab-case/camelCase | ✅ automatic downgrade |

Application code is written **once**, in the modern snake_case vocabulary. The compatibility layer
translates method names, field names and value encodings for older servers, so one call drives every
daemon.

---

## Features

**Torrents**

- Torrent list with swipe actions: resume, pause, verify, re-announce, remove, remove-and-delete, edit.
- Detail screen with five tabs — Info, Files, Trackers, Peers, Options.
- Per-torrent editing: bandwidth limits and their enabled flags, queue position, peer limit, seed
  idling, ratio limits, bandwidth group, labels, sequential download, file priorities.
- Add a torrent from a magnet URI, an HTTP(S) `.torrent` URL, or a local `.torrent` file.
- Filters — All, Active, Downloading, Seeding, Paused, Downloaded, Completed — and twelve sort keys
  with a direction toggle. Filtering and sorting are local, so neither costs a round trip.

**Servers and session**

- Several saved servers, each `scheme://host:port/path` with optional HTTP Basic credentials, so both
  plain HTTP and HTTPS work.
- Test a connection from the editor without saving it.
- Session options: download directory, speed limits, encryption mode, preferred transports, and
  everything else the RPC spec exposes as mutable.

**Interface**

- Light and dark palettes, following the system by default and overridable per app.
- English and Chinese localisation.
- Every icon is a HarmonyOS **system symbol**, so it scales with the accessibility font size and
  follows the system font weight.
- The list polls faster while something is actually moving, and falls back to the configured interval
  when the session is idle.

## Screens

| Screen | File | Reached from |
|:--|:--|:--|
| Torrent list (home) | `entry/src/main/ets/pages/Index.ets` | app start |
| Torrent detail (5 tabs) | `pages/TorrentDetailPage.ets` | tapping a row |
| Add torrent | `pages/AddTorrentPage.ets` | the floating button, or the overflow menu |
| Servers | `pages/ServersPage.ets` | the drawer, or the overflow menu |
| Options | `pages/SettingsPage.ets` | the drawer |

The home screen is the only `@Entry` page; everything else is a `NavDestination` pushed onto its
`NavPathStack`.

```
Index (Navigation + SideBarContainer)
├── DrawerContent      servers · filters · sort · night mode · options · free space
├── topBar             ☰ · server ▾ · ▶ · ‖ · ⋮ (or the search field)
├── listArea           Refresh > List > TorrentRowView, swipeAction per row
│   └── floatingButton ＋ expands into 文件 / 地址
└── bottomBar          ↓ total · ↑ total · ⌕
```

## Requirements

To **run** the app:

- A HarmonyOS device (phone, tablet or 2-in-1) running HarmonyOS 5.0.0 (API 12) or newer.
  `compatibleSdkVersion` is held at API 12 so the app installs on 5.0 devices, while
  `targetSdkVersion` is API 26 (HarmonyOS 7.0.0).
- A reachable Transmission daemon with RPC enabled — *Preferences → Remote* in the Transmission GUI,
  or `rpc-enabled` in `settings.json`.
- The `ohos.permission.INTERNET` runtime permission, which the app requests in `module.json5`.

To **build** it:

- DevEco Studio with the HarmonyOS SDK, **or** the [Huawei command-line
  tools](https://developer.huawei.com/consumer/cn/download/) (see [Building](#building)).
- Node.js 18+ — only for the host test harness and the build wrapper.

## Project layout

```
TransmissionRemote/
├── AppScope/                      # application-level manifest and resources
├── entry/                         # the application module (HAP)
│   └── src/main/ets/
│       ├── entryability/          # UIAbility entry point
│       ├── pages/                 # list · detail (5 tabs) · add · servers · options
│       ├── components/            # drawer, torrent row, detail field row
│       ├── model/                 # servers, settings, sort/filter/theme enums
│       ├── store/                 # persisted state + the shared SDK client
│       ├── theme/                 # palette, theme manager, system-symbol names
│       └── viewmodel/             # list model, detail model, formatters, file picker
├── transmission_sdk/              # the SDK, packaged as a HAR
│   ├── index.ets                  # module entry (re-exports src/main/ets/index.ets)
│   ├── oh-package.json5           # HAR manifest; "main": "index.ets"
│   ├── obfuscation-rules.txt      # keeps the wire keys alive under obfuscation
│   └── src/
│       ├── main/ets/
│       │   ├── index.ets          # public API barrel
│       │   ├── api/               # TorrentApi · SessionApi · SystemApi · BandwidthGroupApi
│       │   ├── client/            # TransmissionClient · TransmissionClientBuilder
│       │   ├── core/              # RpcClient · RpcBatch · TransmissionConfig
│       │   ├── compat/            # dialect codecs, key conversion, negotiation
│       │   ├── constants/         # method names, field names, wire protocol constants
│       │   ├── error/             # TransmissionError, RpcErrorCode
│       │   ├── model/             # typed models and request builders
│       │   ├── platform/          # ArkTS implementations of the ports
│       │   ├── transport/         # HttpTransport port + request/response values
│       │   └── util/              # Json, Base64, Semver, Logger
│       └── test/                  # hypium unit tests (on-device or on Node)
├── hvigorw · hvigorw.bat          # build wrappers: resolve the toolchain, then run hvigor
├── scripts/                       # host test harness, build wrapper, table generators
└── docs/                          # ARCHITECTURE · COMPATIBILITY · API · APP
```

## The SDK

`transmission_sdk` is the only part of the app that talks to the network. It is a plain HAR module
with no dependency on the app.

- **One API, two dialects.** Newest-first negotiation costs at most one extra HTTP round trip on the
  very first request, and usually zero.
- **Fully typed models.** `Torrent`, `SessionSettings`, `Peer`, `TrackerStat`, … with parsed enums
  and documented defaults, instead of raw JSON.
- **Fluent requests.** `TorrentGetRequest`, `TorrentSetRequest`, `TorrentAddRequest`,
  `SessionSetRequest`, `BandwidthGroupSetRequest` only put the fields you actually set on the wire.
- **Typed errors.** A single `TransmissionError` with a coarse `kind` and the normalised
  `RpcErrorCode`, including a port of Transmission's own legacy-message→code heuristics.
- **Batching.** `client.batch()` folds several calls into one HTTP round trip.
- **Pluggable transport and logging.** The SDK only ever touches the network through the
  `HttpTransport` interface, which is what makes the whole client unit-testable off-device.
- **No platform dependencies in the core.** Only `platform/ArkHttpTransport` and
  `platform/HilogLogger` import a HarmonyOS kit.
- **Generated tables.** Field names and the legacy key map are generated from the Transmission
  sources, so they cannot drift.

### Adding it to your own application

1. Copy `transmission_sdk/` into your project, or publish it to your ohpm registry.
2. Declare the dependency:

   ```json5
   // entry/oh-package.json5
   {
     "dependencies": {
       "transmission_sdk": "file:../transmission_sdk"
     }
   }
   ```

3. Request network access in `module.json5`:

   ```json5
   {
     "module": {
       "requestPermissions": [
         { "name": "ohos.permission.INTERNET" },
         { "name": "ohos.permission.GET_NETWORK_INFO" }
       ]
     }
   }
   ```

4. Import from `transmission_sdk`.

### Quick start

```ts
import {
  TransmissionClientBuilder,
  TorrentGetRequest,
  TorrentFields,
  TorrentIds,
  ApiStyleMode,
} from 'transmission_sdk';

const client = new TransmissionClientBuilder()
  .host('192.168.1.10')              // http://192.168.1.10:9091/transmission/rpc
  .credentials('admin', 'secret')
  .apiStyleMode(ApiStyleMode.AUTO)   // default
  .timeout(10_000)
  .build();

const settings = await client.connect();   // negotiates the dialect automatically
console.info(`server ${settings.version}, rpc ${client.serverVersion?.toString()}`);

const torrents = await client.torrents.get(
  new TorrentGetRequest(TorrentFields.BASIC).ids(TorrentIds.RECENTLY_ACTIVE),
);

await client.torrents.addMagnet('magnet:?xt=urn:btih:…');
client.close();
```

**Mutating a torrent** — only the setters you call reach the wire:

```ts
import { TorrentIds, TorrentSetRequest, IdleLimitMode } from 'transmission_sdk';

await client.torrents.stop(TorrentIds.ofHashes(['a1b2c3…']));
await client.torrents.verify(TorrentIds.single(42));

await client.torrents.set(
  new TorrentSetRequest(TorrentIds.single(42))
    .downloadLimit(2048)
    .downloadLimited(true)
    .seedIdleMode(IdleLimitMode.UNLIMITED)
    .labels(['linux', 'iso']),
);
```

**Session settings** — `SessionSetRequest` exposes every mutable setting in the RPC spec (49 setters):

```ts
import { SessionSetRequest, EncryptionMode, TransportProtocol } from 'transmission_sdk';

await client.session.set(
  new SessionSetRequest()
    .downloadDir('/srv/media')
    .speedLimitDown(4096)
    .speedLimitDownEnabled(true)
    .encryption(EncryptionMode.REQUIRED)
    .preferredTransports([TransportProtocol.UTP, TransportProtocol.TCP]),
);
```

**Batching** — a dashboard refresh in one round trip:

```ts
import { RpcMethod, BatchResults, SessionSettings, SessionStats, TorrentGetRequest } from 'transmission_sdk';

const batch = client
  .batch()
  .add(RpcMethod.SESSION_GET)
  .add(RpcMethod.SESSION_STATS)
  .add(RpcMethod.TORRENT_GET, new TorrentGetRequest(TorrentFields.BASIC).toJson());

const results = new BatchResults(await batch.execute());
const settings = SessionSettings.fromJson(results.at(0));
const stats = SessionStats.fromJson(results.at(1));
```

**Errors** — one type, one coarse kind, one normalised code:

```ts
import { TransmissionError, TransmissionErrorKind } from 'transmission_sdk';

try {
  await client.torrents.addFromUri('magnet:?xt=urn:btih:…');
} catch (error) {
  if (error instanceof TransmissionError && error.kind === TransmissionErrorKind.AUTHENTICATION) {
    // wrong credentials
  }
}
```

**Skipping negotiation on later launches** — remember the resolved style and the CSRF session id:

```ts
const client = new TransmissionClientBuilder()
  .host('192.168.1.10')
  .apiStyleMode(ApiStyleMode.AUTO)
  .onApiStyleResolved((style) => { /* persist it */ })
  .sessionId(await preferences.get('sessionId', ''))
  .build();
```

Passing the known style back through `.apiStyleMode(...)` and restoring the session id lets later
launches skip both negotiation and the CSRF handshake.

## Building

Open the project in DevEco Studio and press *Run*, or build from a terminal:

```bash
npm run build          # debug HAP → entry/build/default/outputs/default/entry-default-signed.hap
npm run build:har      # the SDK  → transmission_sdk/build/default/outputs/default/transmission_sdk.har
npm run build:app      # release APP
npm run clean
./hvigorw --print-env  # show which toolchain will be used, and run nothing
```

`hvigorw` (and `npm run build`) needs neither `DEVECO_HOME` nor `JAVA_HOME` exported:
`scripts/run-hvigor.mjs` locates the DevEco Studio installation and then supplies `DEVECO_SDK_HOME`,
the bundled JDK (`jbr/`) and the matching `PATH` entries to hvigor. Without that last step
`PackageHap` fails with `spawn java ENOENT`, which hvigor surfaces only as `00308018 Unknown Error`.
Anything you have already exported wins, so the same command works unchanged in CI — point
`DEVECO_HOME` at Huawei's command-line tools and provide a JDK for that layout. See
[scripts/README.md](scripts/README.md).

> **Signing is tied to the bundle name.** The signing profile in `build-profile.json5` is issued for
> one `bundleName`; changing `bundleName` in `AppScope/app.json5` invalidates it and `SignHap` fails
> with `00303074`. Re-generate the signature in DevEco Studio via
> *File → Project Structure → Signing Configs → Automatically generate signature*. Without a valid
> signature the build still produces `entry-default-unsigned.hap`, but an unsigned package has to be
> re-signed with the signing tool before it can be installed.

## Tests

The SDK ships hypium unit tests next to its sources in `transmission_sdk/src/test/`, which run in
DevEco Studio as local unit tests.

For CI — and for anyone without DevEco Studio — the repository also contains a host-side harness that
copies each `.ets` to `.ts`, compiles it with the repository's TypeScript, and runs the same test
files on Node.js against stand-ins for `@ohos/hypium`, `@kit.NetworkKit`, `@ohos.hilog` and
`@kit.BasicServicesKit`:

```bash
npm install                    # once: fetches TypeScript for the host harness
npm test                       # ArkTS lint + type-check + run every unit test
npm run typecheck              # lint + type-check only
npm run lint                   # ArkTS conformance + manifest schema only
node scripts/run-tests.mjs --filter "LegacyCodec"
DSH_BUILD_DIR=.node-build-x node scripts/run-tests.mjs   # isolated build directory
```

The transport port means no server is required: the tests script the 409 handshake, both dialects'
envelopes, error payloads and malformed responses, and assert the resulting typed models. The app's
ArkUI-free layers (`model/`, and the list filtering/sorting in `viewmodel/`) are compiled and tested
by the same harness.

`npm run lint` covers what neither `tsc` nor the host harness can see — the ArkTS restrictions DevEco
enforces, `module.json5` / HAR manifest schema, resource parity between the light and dark palettes
and between the English and Chinese strings, unresolved imports and unknown SDK exports, and the
ArkUI traps documented in [docs/APP.md](docs/APP.md). See
[scripts/README.md](scripts/README.md) for the full rule list.

ArkUI `struct`s and decorators are not TypeScript, so the screens themselves are covered by
`npm run lint` plus a DevEco build.

## Compatibility at a glance

| Feature | Transmission ≥ 4.1.0 | Transmission < 4.1.0 |
|:--|:--|:--|
| Envelope | `{jsonrpc, method, params, id}` | `{method, arguments, tag}` |
| Method names | `torrent_get` | `torrent-get` |
| Field names | `percent_done` | `percentDone` |
| `download_dir` | `download_dir` | `downloadDir` in torrent calls, `download-dir` elsewhere |
| Booleans in `wanted` | `true`/`false` | `1`/`0` |
| `encryption: allowed` | `allowed` | `tolerated` |
| `free_space.total_size` | `total_size` | `total_size` (yes, underscored) |
| Error reporting | `error.code` + `error.message` + `error.data` | a string in `result` |
| Version discovery | `X-Transmission-Rpc-Version` header on the 409, plus `rpc_version_semver` | `rpc_version` (integer) |

Details, including the negotiation algorithm, are in [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md).

## Regenerating generated files

Four committed files are generated, so they can never drift from their source:

```bash
node scripts/generate-legacy-keys.mjs          # compat/LegacyKeys.ets       (from libtransmission/api-compat.cc)
node scripts/generate-rpc-fields.mjs           # constants/RpcFields.ets     (from docs/rpc-spec.md)
node scripts/generate-session-set-request.mjs  # model/SessionSetRequest.ets (from docs/rpc-spec.md)
node scripts/generate-app-resources.mjs        # entry light/dark colours + en/zh strings
```

Each script defaults to a sibling `../transmission-ref` checkout; pass a path to override.

## Documentation

- [docs/APP.md](docs/APP.md) — the application: screens, theming, persistence, refresh cadence
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — SDK layering, request lifecycle, design decisions
- [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md) — the two dialects, negotiation, conversion rules
- [docs/API.md](docs/API.md) — reference for every exported symbol
- [scripts/README.md](scripts/README.md) — the host test harness and the build wrapper

## License

**GPL-2.0-only OR GPL-3.0-only** — the same dual license as Transmission itself, because three
generated files are transcribed from the Transmission source tree. See [LICENSE](LICENSE) for the
full reasoning and for the options if your application cannot be GPL-licensed.
