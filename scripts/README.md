# Running ArkTS unit tests on plain Node.js

`scripts/run-tests.mjs` type-checks and runs the ArkTS (`*.ets`) unit tests of
this repository on plain Node.js — no DevEco Studio, no HarmonyOS SDK, no
hvigor, no emulator and no network access required. It uses the repository's own
`typescript` package as a compiler and a set of tiny shim packages that stand in
for the `@ohos.*` / `@kit.*` imports.

```bash
# type-check + compile + run every test
npm test                       # == node scripts/run-tests.mjs

# type-check only (no JS emitted, tests are not run)
npm run typecheck              # == node scripts/run-tests.mjs --no-emit

# run only tests whose full name contains a substring
node scripts/run-tests.mjs --filter "LegacyCodec converts download_dir"

# talk to the console / see hilog output and failure stacks
DSH_TEST_VERBOSE=1 node scripts/run-tests.mjs
```

Exit codes: `0` all tests passed and the program type-checked; `1` at least one
test failed **or** the program had type errors; `2` the tool itself was
misconfigured (bad argument, missing `typescript`, two sources mapping to the
same build path). If neither source root exists (or no `.ets` file is found) the
tool prints `no sources yet` and exits `0`.

## What it does, step by step

1. Deletes and recreates `.node-build/` (git-ignored).
2. Recursively collects every `*.ets` file below:
   - `transmission_sdk/src/main/ets`
   - `transmission_sdk/src/test`

   Missing directories are ignored.
3. Copies each file into `.node-build/src/` as `.ts`, preserving the layout
   *below* `transmission_sdk/src` (see the mapping table below), and rewriting
   import/export specifiers on the way (see below). Types are **not** stripped
   and nothing else is rewritten — the TypeScript compiler does the real work.
4. Copies `scripts/node-shims/**` into `.node-build/node_modules/**` as real
   Node packages, so the same names resolve for `tsc` *and* for the emitted
   `require(...)` calls.
5. Writes `.node-build/tsconfig.json` (see below) and compiles
   `.node-build/src/**/*.ts` to `.node-build/out/**/*.js`.
6. Writes and runs `.node-build/run.js`, which loads every emitted
   `out/test/**/*.test.js`, executes the suites through the hypium shim and
   prints the summary.

### Source → build path mapping

`.node-build/src` mirrors `transmission_sdk/src`, so a relative import such as
`../../main/ets/foo` inside a test keeps working after the copy:

| Source | Build |
| --- | --- |
| `transmission_sdk/src/main/ets/Transport.ets` | `.node-build/src/main/ets/Transport.ts` |
| `transmission_sdk/src/test/Transport.test.ets` | `.node-build/src/test/Transport.test.ts` |

Tests therefore land in `out/test/**/*.test.js`, which is where the runner looks
for them.

### Import specifier rewriting

While copying, `from '<spec>'`, `export ... from '<spec>'` and `import('<spec>')`
are inspected:

- **relative and extensionless** (`./Foo`, `../../main/ets/Foo`) — left exactly
  as written. `tsc` resolves `./Foo` to `Foo.ts`, and the emitted CommonJS
  resolves `./Foo` to the emitted `Foo.js`.
- **relative with a source extension** (`./Foo.ets`, `./Foo.ts`) — the extension
  is mapped to `.js`. TypeScript resolves a `./Foo.js` import back to `Foo.ts`,
  and Node resolves it to the emitted `Foo.js`.
- **everything else** (package specifiers such as `@ohos/hypium`) — untouched.

Set `DSH_TEST_VERBOSE=1` to see each rewritten specifier.

### Generated `tsconfig.json`

```jsonc
{
  "compilerOptions": {
    "target": "ES2021", "module": "CommonJS", "moduleResolution": "node",
    "strict": true, "noImplicitOverride": true, "useDefineForClassFields": false,
    "experimentalDecorators": true, "skipLibCheck": true, "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true, "declaration": false, "sourceMap": false,
    "outDir": "out", "rootDir": "src", "lib": ["ES2021"],
    "baseUrl": ".", "typeRoots": ["./node_modules", "./node_modules/@types"],
    "types": ["@ohos/hypium", "@dsh/host-globals"]
  },
  "include": ["src/**/*.ts"],
  "exclude": ["node_modules"]
}
```

All paths are relative to `.node-build/`. `lib` is ES2021 **without** DOM, on
purpose: ArkTS has no DOM, so `document`/`window` must not type-check.
`baseUrl`/`typeRoots` point at `.node-build/node_modules`, so `@ohos/*` and
`@kit.*` resolve to the copied shims. `types` lists the two type-only packages
explicitly because TypeScript's *implicit* type-library scan only looks one
level into `node_modules` and would otherwise mistake the `@ohos` and `@dsh`
scope directories for packages; ordinary imports such as `@kit.NetworkKit` are
resolved by normal node module resolution and need no entry.

A generated `.node-build/package.json` with `"type": "commonjs"` makes the
emitted CommonJS files and `run.js` load correctly even though the repository
root is an ESM package.

## The shims

Each directory under `scripts/node-shims/` is a complete, dependency-free
package with `package.json` (`main` + `types`), `index.js` and `index.d.ts`. They
are copied verbatim into `.node-build/node_modules/`, so nothing here can leak
into the SDK output.

| Package | Purpose |
| --- | --- |
| `@ohos/hypium` | The test framework: `describe`/`it` (+ `it(name, filter, fn)`), `beforeAll`/`beforeEach`/`afterEach`/`afterAll`, `expect` and `__runAll`. |
| `@ohos.hilog` | `hilog.debug/info/warn/error/fatal(domain, tag, format, ...args)`. Silent unless `DSH_TEST_VERBOSE` is set, then forwards through `util.format` to the console. |
| `@kit.PerformanceAnalysisKit` | The modern kit wrapper for the same `hilog` surface; re-exports the `@ohos.hilog` shim. |
| `@kit.NetworkKit` | `http.RequestMethod`, `http.HttpDataType`, `HttpRequestOptions`, `HttpResponse`, `HttpRequest`, `http.createHttp()`. `request()` rejects with `Error('not available in node')`; `destroy()`/`on()`/`off()` are no-ops. |
| `@kit.BasicServicesKit` | `BusinessError extends Error { code; name; data? }`. |
| `@ohos.util` | `Base64Helper` (`encodeToString`/`decodeSync`) backed by Node's `Buffer`, exposed both as a top-level class and as `util.Base64Helper` so `import { util } from '@ohos.util'` also works. |
| `@dsh/host-globals` | **Type-only.** Adds `console` and `setTimeout`/`clearTimeout`/`setInterval`/`clearInterval`/`queueMicrotask` to the DOM-free ES2021 lib, because the ArkTS runtime provides them and tests commonly `await new Promise(setTimeout)`. No runtime behaviour. |

### hypium runner semantics

- Nested `describe` blocks compose full names with a single space, e.g.
  `LegacyCodec converts download_dir`.
- `beforeAll`/`afterAll` run once per block (outermost first / innermost first).
- `beforeEach`/`afterEach` wrap every test (outermost first / innermost first),
  and still run when the test body throws.
- Async test bodies and async hooks are awaited.
- A failing assertion records its message and stack and the run continues with
  the remaining tests.
- `not` inverts any assertion. `assertContain` handles strings (substring),
  arrays (element deep-equality), `Map`/`Set` and plain objects (own key).
  `assertThrowError` accepts a function (either as the value under test or as its
  argument), optionally matching a stringified error message.
- A test file may register tests at module top level *or* use DevEco Studio's
  `export default function suite() { describe(...) }` template; the runner calls
  such a default export automatically.

## `lint-arkts.mjs`

`node scripts/lint-arkts.mjs` (or `npm run lint`) is a second, independent
safety net. It exists because two build failures shipped from this repository
that `tsc` could not see:

- an object literal used as a bare expression (`cond ? {} : value`) is rejected
  by ArkTS, even though it is perfectly valid TypeScript;
- `module.json5` for a HAR rejects `deliveryWithInstall` and `virtualMachine:
  "arkTS"`, both of which are easy to copy over from a HAP example.

What it checks:

| Area | Rules |
| --- | --- |
| Object literals | `arkts-no-untyped-obj-literals` (deliberately stricter than the compiler: any `{}` without a visible type annotation) |
| Types | `arkts-no-indexed-signatures`, `arkts-no-obj-literals-as-types`, `arkts-no-utility-types`, `arkts-no-any-unknown`, `arkts-no-as-const` |
| Syntax | `arkts-no-destruct-decls`, `arkts-no-for-in`, `arkts-no-delete`, `arkts-no-var`, `arkts-no-func-expressions`, `arkts-no-ctor-prop-decls`, `arkts-no-spread`, `arkts-no-symbol`, `arkts-no-require`, `arkts-no-definite-assignment` |
| Standard library | `arkts-no-regexp-literals`, `arkts-limited-stdlib` (`hasOwnProperty`, reflective `Object.*`, `globalThis`, `eval`) |
| Semantics | `arkts-no-standalone-this` (brace-tracked, so only real static bodies are flagged) |
| Manifests | HAR/HAP key sets, `module.type`, and the `virtualMachine` enum |

It strips comments and string literals before matching, so `@see arkts-no-any-unknown`
in a doc comment is not reported. Exit code is non-zero when any error-level
finding is reported.

## Environment variables

| Variable | Effect |
| --- | --- |
| `DSH_TEST_FILTER` | Set by `--filter`; only tests whose full name contains the value run. Also settable directly. |
| `DSH_TEST_VERBOSE` | Per-test `ok`/`FAIL` lines, failure stacks, hilog output and specifier rewrites. |
| `DSH_BUILD_DIR` | Build directory name, relative to the repository root. Defaults to `.node-build`. Set it to run several type-check/test jobs in parallel without them deleting each other's output, e.g. `DSH_BUILD_DIR=.node-build-ci npm test`. |

## Files that are loaded as tests

Every emitted `out/test/**/*.test.js` is loaded, **except** `List.test.js`.
`src/test/List.test.ets` is DevEco Studio's suite aggregator: it *calls* all the
other suites, so loading it here as well would register (and run) every test
twice. DevEco needs it; this runner does not.

## Assumptions and limitations

- `typescript` is expected at `node_modules/typescript` (it is installed with
  `--no-save` in this checkout, and also declared in the root `package.json`).
  Nothing is installed at run time; the tool never touches the network.
- The SDK sources have no platform dependency below `platform/`, so the harness
  needs no HarmonyOS runtime. Files under `platform/` are still type-checked
  against the `@kit.NetworkKit` / `@kit.PerformanceAnalysisKit` shims.
- The build mirrors `transmission_sdk/src`, not the individual source roots.
  This is what keeps `../../main/ets/...` imports inside tests valid. If a test
  were instead written against a root-relative path such as `../../Transport`
  (resolving under `transmission_sdk/src/`) it would not resolve — normal
  ArkTS/DevEco layouts use the `main/ets` form.
- Type errors do not stop the tests from running: the JS is still emitted, the
  tests execute, and the process exits non-zero afterwards. With `--no-emit`
  nothing is emitted and no tests run.
- `@kit.NetworkKit`'s shim has no real transport; anything that actually
  performs I/O must be replaced by a fake in the test.
- `RequestMethod` is declared as a string enum (`RequestMethod.POST === 'POST'`)
  to match the real HarmonyOS API; `HttpDataType` is numeric (`STRING = 0`).

## Building with hvigor: `run-hvigor.mjs` and the `hvigorw` wrappers

Building a HAP needs the real DevEco toolchain (unlike the test harness above,
which deliberately needs none of it). Two things reliably break that from a
plain terminal on a machine where DevEco Studio is installed:

1. **There is no `hvigorw` to run.** DevEco keeps its copy inside the IDE
   install (`tools/hvigor/bin/`), and it is not on `PATH`.
2. **`java` is not on `PATH`.** The `PackageHap` task spawns plain `java` and
   dies with `spawn java ENOENT`, which hvigor reports as the spectacularly
   unhelpful `00308018 Unknown Error`. The JDK is right there in the IDE
   (`jbr/`), it is just never exported.

`scripts/run-hvigor.mjs` fixes both. It locates the toolchain, exports
`DEVECO_SDK_HOME`, `JAVA_HOME` and the matching `PATH` entries **for the child
process only**, then runs hvigor with the arguments you passed.

`hvigorw` and `hvigorw.bat` in the repository root are thin shims onto that
script. That is deliberate: cmd.exe, Git Bash and CI all execute the same
logic, instead of three copies of a batch/sh script that drift apart.

```bash
./hvigorw --print-env                  # show what was resolved, run nothing
./hvigorw clean
./hvigorw assembleHap -p product=default -p buildMode=debug
./hvigorw assembleHar --mode module -p module=transmission_sdk@default

npm run env        # == node scripts/run-hvigor.mjs --print-env
npm run build      # == assembleHap -p product=default -p buildMode=debug
npm run build:har  # == assembleHar --mode module -p module=transmission_sdk@default
npm run build:app  # == assembleApp --mode project -p product=default -p buildMode=release
npm run clean
```

Products land where hvigor always puts them:

| Task | Output |
| --- | --- |
| `assembleHap` | `entry/build/default/outputs/default/entry-default-{signed,unsigned}.hap` |
| `assembleHar` | `transmission_sdk/build/default/outputs/default/transmission_sdk.har` |

### Toolchain layouts

| Layout | Detected by | Node | JDK | SDK |
| --- | --- | --- | --- | --- |
| DevEco Studio (the IDE) | `tools/hvigor/bin/hvigorw.js` | `tools/node` | `jbr` | `sdk` |
| Huawei command-line-tools | `bin/hvigorw[.bat]` | `tool/node` | not bundled | `sdk` |

The first is what you have locally. The second is what Huawei documents for CI
pipelines — command-line-tools deliberately ships **no JDK**, so there you must
provide `JAVA_HOME` yourself; the script says so explicitly when it cannot find
one.

### Environment precedence

Anything you have already exported wins. The script only fills in gaps, so an
explicit CI setup is never clobbered.

| Variable | Effect |
| --- | --- |
| `DEVECO_HOME` | Toolchain root. Skips auto-detection. Set this if DevEco lives somewhere unusual, or in CI. |
| `DEVECO_SDK_HOME` | HarmonyOS SDK root. Honoured if already set. |
| `JAVA_HOME` | JDK root. Honoured if already set, otherwise the IDE's `jbr`. Its `bin/` is put on `PATH` either way, because a `JAVA_HOME` that is set but not on `PATH` does not help `PackageHap`. |
| `HVIGOR_NODE` | Node executable to run hvigor with. Honoured if already set, otherwise the toolchain's own node, otherwise the interpreter running the script. |
| `HVIGOR_VERBOSE` | `1` prints the resolved environment before building. |

Auto-detection probes `%ProgramFiles%\Huawei\DevEco Studio`,
`%ProgramFiles(x86)%\Huawei\DevEco Studio`, `%LOCALAPPDATA%\Huawei\DevEco Studio`,
`<C..F>:\Huawei\DevEco Studio` and `<C..F>:\DevEco Studio`
(`/Applications/DevEco-Studio.app/Contents` on macOS, `/opt/deveco-studio`
on Linux). Run `./hvigorw --print-env` to see exactly what was picked.

Exit codes: hvigor's own exit code is propagated verbatim, so `hvigorw` chains
correctly with `&&`. Exit code `2` means the *wrapper* failed (no toolchain
found, or a bad `DEVECO_HOME`) rather than the build.

### A broken local-module link is a separate failure

If the build instead reports

```
"transmission_sdk" is imported by "...", but could not be resolved
```

that is not an environment problem. `entry` depends on the sibling HAR through
`"transmission_sdk": "file:../transmission_sdk"`, which ohpm satisfies by
creating a junction at `entry/oh_modules/transmission_sdk`. If that junction is
missing or dangling (a copied/archived checkout is the usual cause), the import
target simply does not exist. Rebuild it with:

```bash
ohpm install --all      # regenerates the junction
```

A dangling junction is easy to spot: `entry/oh_modules/transmission_sdk` exists
and passes `-e`, but contains **zero** files. After a correct install it
contains nine entries (the SDK root, including `index.ets` and `src/`).
