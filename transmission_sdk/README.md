# TransmissionRemote

An **ArkTS / HarmonyOS SDK for the Transmission BitTorrent client's RPC API**, compatible with
**both** protocol generations:

| Transmission | RPC version | Wire dialect | SDK support |
|:--|:--|:--|:--|
| **4.1.0 and newer** | `rpc-version-semver` ≥ `6.0.0` | JSON-RPC 2.0, snake_case keys | ✅ preferred dialect |
| **4.0.x and older** (1.30 → 4.0.x) | `rpc-version` ≤ `17` | bespoke RPC, mixed kebab-case/camelCase | ✅ automatic downgrade |

Application code is written **once**, in the modern snake_case vocabulary. The compatibility layer
translates method names, field names and value encodings for older servers, so the same call drives
every 4.x daemon.

```ts
import { TransmissionClientBuilder, TorrentGetRequest, TorrentFields } from 'transmission_sdk';

const client = new TransmissionClientBuilder()
  .host('192.168.1.10')          // http://192.168.1.10:9091/transmission/rpc
  .credentials('admin', 'secret')
  .build();

await client.connect();                                   // negotiates the dialect automatically
const torrents = await client.torrents.get(new TorrentGetRequest(TorrentFields.BASIC));

for (const torrent of torrents) {
  console.info(`${torrent.name} — ${torrent.percentDone * 100}%`);
}

await client.torrents.addMagnet('magnet:?xt=urn:btih:…');
client.close();
```

---

## Highlights

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

## Repository layout

```
TransmissionRemote/
├── AppScope/                      # application-level manifest and resources
├── entry/                         # sample HAP: a complete Transmission remote
│   └── src/main/ets/
│       ├── entryability/          # UIAbility entry point
│       ├── pages/                 # list · detail (5 tabs) · add · servers · options
│       ├── components/            # drawer and torrent row
│       ├── model/                 # servers, settings, sort/filter/theme enums
│       ├── store/                 # persisted state + the shared SDK client
│       ├── theme/                 # light/dark application
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
│       └── test/                  # hypium unit tests (run on-device or on Node)
├── hvigorw · hvigorw.bat          # build wrappers: resolve the toolchain, then run hvigor
├── scripts/                       # host test harness, build wrapper, table generators
└── docs/                          # ARCHITECTURE · COMPATIBILITY · API
```

Documentation:

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — layering, request lifecycle, design decisions
- [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md) — the two dialects, negotiation, conversion rules
- [docs/API.md](docs/API.md) — reference for every exported symbol
- [docs/APP.md](docs/APP.md) — the sample application: screens, theming, persistence

## Adding the SDK to an application

The SDK is a standard HarmonyOS **HAR** module.

1. Copy `transmission_sdk/` into your project (or publish it to your ohpm registry).
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

## Quick start

### Connect and read

```ts
import {
  TransmissionClientBuilder,
  TorrentGetRequest,
  TorrentFields,
  TorrentIds,
  ApiStyleMode,
  LogLevel,
} from 'transmission_sdk';

const client = new TransmissionClientBuilder()
  .host('127.0.0.1')
  .credentials('admin', 'secret')
  .apiStyleMode(ApiStyleMode.AUTO)   // default
  .timeout(10_000)
  .build();

const settings = await client.connect();
console.info(`server ${settings.version}, rpc ${client.serverVersion?.toString()}`);

const torrents = await client.torrents.get(
  new TorrentGetRequest(TorrentFields.BASIC).ids(TorrentIds.RECENTLY_ACTIVE),
);
```

### Mutate

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

### Session settings

`SessionSetRequest` exposes every mutable setting documented in the RPC spec (49 setters):

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

### Batch a dashboard refresh into one request

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

### Handle errors

```ts
import { TransmissionError, TransmissionErrorKind } from 'transmission_sdk';

try {
  await client.torrents.addFromUri('magnet:?xt=urn:btih:…');
} catch (error) {
  if (error instanceof TransmissionError) {
    if (error.kind === TransmissionErrorKind.AUTHENTICATION) {
      // wrong credentials
    }
    console.error(`${error.fullMessage} (rpc ${error.rpcCode ?? 'n/a'})`);
  }
}
```

### Persist the negotiated dialect (optional)

```ts
let detectedStyle: ApiStyle | undefined;

const client = new TransmissionClientBuilder()
  .host('192.168.1.10')
  .apiStyleMode(ApiStyleMode.AUTO)
  .onApiStyleResolved((style) => {
    detectedStyle = style;                 // e.g. store in preferences
  })
  .sessionId(await preferences.get('sessionId', ''))
  .build();
```

Passing the known style back through `.apiStyleMode(...)` and restoring the session id lets later
launches skip negotiation and the CSRF handshake entirely.

## Building

Open the project in DevEco Studio, or build from a terminal:

```bash
npm run build          # debug HAP → entry/build/default/outputs/default/entry-default-signed.hap
npm run build:har      # the SDK  → transmission_sdk/build/default/outputs/default/transmission_sdk.har
npm run build:app      # release APP
npm run clean
./hvigorw --print-env  # show which toolchain will be used, and run nothing
```

`hvigorw` (and `npm run build`) needs neither `DEVECO_HOME` nor `JAVA_HOME` exported:
`scripts/run-hvigor.mjs` locates the DevEco Studio installation and then supplies
`DEVECO_SDK_HOME`, the bundled JDK (`jbr/`) and the matching `PATH` entries to hvigor. Without
that last step `PackageHap` fails with `spawn java ENOENT`, which hvigor surfaces only as
`00308018 Unknown Error`. Anything you have already exported wins, so the same command works
unchanged in CI. See [scripts/README.md](scripts/README.md).

## Tests

The SDK ships hypium unit tests that live next to the sources in `transmission_sdk/src/test/` and run
in DevEco Studio as local unit tests.

For CI (and for anyone without DevEco Studio) the repository also contains a host-side harness that
copies each `.ets` to `.ts`, compiles it with the repository's TypeScript, and runs the same test
files on Node.js against stand-ins for `@ohos/hypium`, `@kit.NetworkKit`, `@ohos.hilog` and
`@kit.BasicServicesKit`:

```bash
npm install                    # once: fetches TypeScript for the host harness
npm test                       # ArkTS lint + type-check + run every unit test
npm run typecheck              # lint + type-check only
npm run lint                   # ArkTS conformance + module.json5 schema only
node scripts/run-tests.mjs --filter "LegacyCodec"
DSH_BUILD_DIR=.node-build-x node scripts/run-tests.mjs   # isolated build directory
```

`npm run lint` is worth knowing about: `tsc` validates TypeScript semantics but
knows nothing about the ArkTS restrictions DevEco enforces, nor about
`module.json5` at all. `scripts/lint-arkts.mjs` encodes the rules that actually
break a DevEco build — context-free object literals
(`arkts-no-untyped-obj-literals`), index signatures, destructuring, regex
literals, `any`/`unknown`, static `this`, HAP-only keys in a HAR manifest, and
so on. See [scripts/README.md](scripts/README.md).

The transport port means no server is required: tests script the 409 handshake, both dialects'
envelopes, error payloads and malformed responses, and assert the resulting typed models.

The sample application's ArkUI-free layers (`model/`, and the list filtering/sorting in
`viewmodel/`) are compiled and tested by the same harness. ArkUI `struct`s and decorators are not
TypeScript, so the screens themselves are covered by `npm run lint` plus a DevEco build.

See [scripts/README.md](scripts/README.md) for the harness internals.

## Regenerating the protocol tables

Three source files are generated from the Transmission repository and committed:

```bash
node scripts/generate-legacy-keys.mjs          # compat/LegacyKeys.ets       (from libtransmission/api-compat.cc)
node scripts/generate-rpc-fields.mjs           # constants/RpcFields.ets     (from docs/rpc-spec.md)
node scripts/generate-session-set-request.mjs  # model/SessionSetRequest.ets (from docs/rpc-spec.md)
node scripts/generate-app-resources.mjs        # entry light/dark colours + en/zh strings
```

Each script defaults to a sibling `../transmission-ref` checkout; pass a path to override.

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

## Requirements

- HarmonyOS SDK / DevEco Studio with API 12 or newer. The build profile targets
  API 26 (HarmonyOS 7.0.0) and keeps `compatibleSdkVersion` at API 12, so the app
  still installs on HarmonyOS 5.0 devices.
- The three SDK fields must satisfy `compatibleSdkVersion <= targetSdkVersion
  <= compileSdkVersion`; `npm run lint` checks that ordering.
- Device types: `phone`, `tablet`, `default`.
- Runtime permission: `ohos.permission.INTERNET`.

## License

**GPL-2.0-only OR GPL-3.0-only** — the same dual license as Transmission itself, because three
generated files are transcribed from the Transmission source tree. See [LICENSE](LICENSE) for the
full reasoning and for the options if your application cannot be GPL-licensed.
