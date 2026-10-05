#!/usr/bin/env node
/**
 * run-tests.mjs — run ArkTS (*.ets) unit tests on plain Node.js, with no
 * DevEco Studio and no ArkTS toolchain involved.
 *
 * How it works:
 *
 *   1. `.node-build/` is deleted and recreated.
 *   2. Every `*.ets` file below `transmission_sdk/src/main/ets`,
 *      `transmission_sdk/src/test`, `entry/src/test`, and the ArkUI-free part of
 *      `entry/src/main/ets` is copied to `.node-build/src/...` as `.ts`,
 *      preserving the layout of `transmission_sdk/src` so that relative imports
 *      between tests and sources keep working. Import/export specifiers are
 *      rewritten textually while copying (see rewriteSpecifier).
 *   3. The shim packages in `scripts/node-shims/**` are copied to
 *      `.node-build/node_modules/**`, so `@ohos/hypium`, `@ohos.hilog`,
 *      `@kit.NetworkKit`, `@kit.BasicServicesKit` and `@ohos.util` resolve for
 *      both the TypeScript compiler and the emitted `require(...)` calls.
 *   4. `.node-build/tsconfig.json` compiles `src/**\/*.ts` into `out/`.
 *   5. `.node-build/run.js` loads the compiled `out/test/**\/*.test.js` files
 *      and executes them through the hypium shim.
 *
 * Usage:
 *   node scripts/run-tests.mjs [--filter <substr>] [--no-emit]
 */

import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');
// Overridable so that several agents/CI jobs can compile the same sources in
// parallel without stepping on each other's build directory.
const BUILD_DIR_NAME = process.env.DSH_BUILD_DIR ?? '.node-build';
const BUILD_DIR = path.join(REPO_ROOT, BUILD_DIR_NAME);
const SRC_DIR = path.join(BUILD_DIR, 'src');
const OUT_DIR = path.join(BUILD_DIR, 'out');
const SHIM_DIR = path.join(__dirname, 'node-shims');
const MODULE_SRC_DIR = path.join(REPO_ROOT, 'transmission_sdk', 'src');

/**
 * The package name the application imports the SDK by. It has to match the
 * `name` in `transmission_sdk/oh-package.json5` *and* the module name in the
 * project-level `build-profile.json5`, otherwise hvigor reports that a local
 * module dependency has no module info.
 *
 * The alias directory and the stub `package.json` are both derived from this
 * constant on purpose: they once drifted apart (the directory was spelled as
 * two separate path segments), which left the alias pointing at a name nothing
 * imported and broke every test that touched the SDK.
 */
const SDK_PACKAGE_NAME = 'transmission_sdk';

/**
 * `prefix` is the path below `transmission_sdk/src` that the root's contents
 * keep inside `.node-build/src`. Keeping `main/ets` and `test` means a relative
 * import such as `../../main/ets/foo` written in a test still resolves to the
 * copied source, and it puts test files under `out/test/**` where run.js looks
 * for them.
 */
const SOURCE_ROOTS = [
  {
    dir: path.join(MODULE_SRC_DIR, 'main', 'ets'),
    prefix: path.join('main', 'ets'),
    label: 'transmission_sdk/src/main/ets',
  },
  {
    dir: path.join(MODULE_SRC_DIR, 'test'),
    prefix: 'test',
    label: 'transmission_sdk/src/test',
  },
  {
    // The sample application's ArkUI-free layers. `tsc` cannot parse a `struct`
    // or an ArkUI decorator, so only files that are plain TypeScript are copied
    // here; the UI itself is covered by `scripts/lint-arkts.mjs` and DevEco.
    dir: path.join(REPO_ROOT, 'entry', 'src', 'main', 'ets'),
    prefix: path.join('entry', 'main', 'ets'),
    label: 'entry/src/main/ets',
    include: (relative) =>
      [
        path.join('model', 'AppModels.ets'),
        path.join('model', 'NavParams.ets'),
        path.join('viewmodel', 'Formatters.ets'),
        path.join('viewmodel', 'TorrentListModel.ets'),
        path.join('viewmodel', 'FileTree.ets'),
      ].includes(relative),
  },
  {
    dir: path.join(REPO_ROOT, 'entry', 'src', 'test'),
    prefix: path.join('entry', 'test'),
    label: 'entry/src/test',
  },
];

const TS_CONFIG = {
  compilerOptions: {
    target: 'ES2021',
    module: 'CommonJS',
    moduleResolution: 'node',
    strict: true,
    noImplicitOverride: true,
    useDefineForClassFields: false,
    experimentalDecorators: true,
    skipLibCheck: true,
    esModuleInterop: true,
    forceConsistentCasingInFileNames: true,
    declaration: false,
    sourceMap: false,
    outDir: 'out',
    rootDir: 'src',
    lib: ['ES2021'],
    // Relative to .node-build/, where the generated tsconfig lives.
    // typeRoots is deliberately non-standard (it points at plain node_modules),
    // so the *implicit* type libraries are listed explicitly: TypeScript's
    // typeRoots scan only looks one level deep and would otherwise treat the
    // `@ohos` / `@dsh` scope directories themselves as packages. Module
    // specifiers such as `@kit.NetworkKit` are resolved by node module
    // resolution and need no entry here.
    baseUrl: '.',
    typeRoots: ['./node_modules', './node_modules/@types'],
    types: ['@ohos/hypium', '@dsh/host-globals'],
  },
  include: ['src/**/*.ts'],
  exclude: ['node_modules'],
};

const BUILD_PACKAGE_JSON = {
  name: 'dsh-node-build',
  private: true,
  // The repo root is an ESM package; the emitted CommonJS must not inherit that.
  type: 'commonjs',
};

/* ------------------------------------------------------------------ */
/* CLI                                                                 */
/* ------------------------------------------------------------------ */

function printUsage() {
  console.log(`Usage: node scripts/run-tests.mjs [--filter <substr>] [--no-emit]

  --filter <substr>  Only run tests whose full name contains <substr>.
  --no-emit          Type-check only; do not emit JS and do not run tests.
  -h, --help         Show this help.`);
}

function parseArgs(argv) {
  const options = { filter: '', noEmit: false };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--no-emit' || arg === '--noEmit') {
      options.noEmit = true;
    } else if (arg === '--filter') {
      options.filter = argv[i + 1] === undefined ? '' : argv[i + 1];
      i += 1;
    } else if (arg.startsWith('--filter=')) {
      options.filter = arg.slice('--filter='.length);
    } else if (arg === '-h' || arg === '--help') {
      printUsage();
      process.exit(0);
    } else {
      console.error(`[run-tests] unknown argument: ${arg}`);
      printUsage();
      process.exit(2);
    }
  }
  return options;
}

/* ------------------------------------------------------------------ */
/* Small filesystem helpers                                            */
/* ------------------------------------------------------------------ */

function listFilesRecursive(dir, predicate) {
  const found = [];
  const walk = (current) => {
    let entries;
    try {
      entries = fs.readdirSync(current, { withFileTypes: true });
    } catch (err) {
      return;
    }
    for (const entry of entries) {
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) {
        if (entry.name === 'node_modules' || entry.name.startsWith('.')) continue;
        walk(full);
      } else if (entry.isFile() && predicate(full)) {
        found.push(full);
      }
    }
  };
  walk(dir);
  return found;
}

function toRepoRelative(file) {
  const relative = path.relative(REPO_ROOT, file);
  return relative.startsWith('..') ? file : relative;
}

/* ------------------------------------------------------------------ */
/* .ets -> .ts copy + specifier transform                              */
/* ------------------------------------------------------------------ */

/**
 * Relative specifiers without an extension are left untouched: TypeScript
 * resolves `./Foo` to `Foo.ts` and the emitted CommonJS resolves to `Foo.js`.
 * A relative specifier that carries a source extension (`./Foo.ets`) is mapped
 * to `./Foo.js`, which TypeScript resolves back to `Foo.ts` and Node resolves
 * to the emitted `Foo.js`. Non-relative (package) specifiers are never touched.
 */
function rewriteSpecifier(specifier) {
  if (!specifier.startsWith('.')) return specifier;
  if (/\.(ets|ts|tsx|mts|cts)$/i.test(specifier)) {
    return specifier.replace(/\.(ets|ts|tsx|mts|cts)$/i, '.js');
  }
  return specifier;
}

const SPECIFIER_PATTERN = /(\bfrom\s*|\bimport\s*\(\s*)(['"])([^'"\n]+)\2/g;

function transformSpecifiers(source, file) {
  return source.replace(SPECIFIER_PATTERN, (match, prefix, quote, specifier) => {
    const rewritten = rewriteSpecifier(specifier);
    if (rewritten !== specifier && process.env.DSH_TEST_VERBOSE) {
      console.log(`[run-tests] ${toRepoRelative(file)}: ${specifier} -> ${rewritten}`);
    }
    return `${prefix}${quote}${rewritten}${quote}`;
  });
}

function copySources() {
  const copied = [];
  const destinations = new Map();

  for (const root of SOURCE_ROOTS) {
    if (!fs.existsSync(root.dir)) continue;
    for (const file of listFilesRecursive(root.dir, (candidate) => candidate.endsWith('.ets'))) {
      const relative = path.relative(root.dir, file);
      if (root.include !== undefined && !root.include(relative)) continue;
      const destination = path.join(SRC_DIR, root.prefix, relative.replace(/\.ets$/i, '.ts'));

      if (destinations.has(destination)) {
        console.error(
          `[run-tests] two sources map to the same build path: ${toRepoRelative(destinations.get(destination))} and ${toRepoRelative(file)}`
        );
        process.exit(2);
      }
      destinations.set(destination, file);

      fs.mkdirSync(path.dirname(destination), { recursive: true });
      const source = fs.readFileSync(file, 'utf8');
      fs.writeFileSync(destination, transformSpecifiers(source, file), 'utf8');
      copied.push({ from: file, to: destination });
    }
  }

  return copied;
}

/* ------------------------------------------------------------------ */
/* Build scaffolding                                                   */
/* ------------------------------------------------------------------ */

function installShims() {
  if (!fs.existsSync(SHIM_DIR)) {
    console.error(`[run-tests] shim directory is missing: ${toRepoRelative(SHIM_DIR)}`);
    process.exit(2);
  }
  const modules = path.join(BUILD_DIR, 'node_modules');
  fs.cpSync(SHIM_DIR, modules, { recursive: true });
  installSdkAlias(modules);
}

/**
 * Aliases the package name `transmission_sdk` onto the SDK sources already
 * copied into the build directory.
 *
 * The sample application imports the SDK by package name, which would otherwise
 * be unresolvable here: the real package is linked by `ohpm` inside DevEco and
 * does not exist in a plain checkout. Types resolve to the copied `.ts` barrel
 * and the runtime resolves to the emitted `.js` barrel.
 */
function installSdkAlias(modules) {
  const aliasDir = path.join(modules, SDK_PACKAGE_NAME);
  fs.mkdirSync(aliasDir, { recursive: true });
  fs.writeFileSync(
    path.join(aliasDir, 'package.json'),
    `${JSON.stringify({ name: SDK_PACKAGE_NAME, version: '1.0.0', main: 'index.js', types: 'index.d.ts' }, null, 2)}\n`
  );
  // Walk back from the alias directory to the build directory instead of
  // hardcoding a depth: the alias sits one level deeper for every `/` in the
  // package name, so `../../` was only correct while the name was unscoped.
  const toBuildDir = path.relative(aliasDir, BUILD_DIR).split(path.sep).join('/');
  fs.writeFileSync(path.join(aliasDir, 'index.d.ts'), `export * from '${toBuildDir}/src/main/ets/index';\n`);
  fs.writeFileSync(path.join(aliasDir, 'index.js'), `module.exports = require('${toBuildDir}/out/main/ets/index');\n`);
}

function writeScaffolding() {
  fs.writeFileSync(path.join(BUILD_DIR, 'package.json'), `${JSON.stringify(BUILD_PACKAGE_JSON, null, 2)}\n`, 'utf8');
  fs.writeFileSync(path.join(BUILD_DIR, 'tsconfig.json'), `${JSON.stringify(TS_CONFIG, null, 2)}\n`, 'utf8');
}

/* ------------------------------------------------------------------ */
/* TypeScript                                                          */
/* ------------------------------------------------------------------ */

function loadTypeScript() {
  try {
    return require('typescript');
  } catch (err) {
    console.error('[run-tests] the "typescript" package could not be resolved from scripts/run-tests.mjs.');
    console.error('[run-tests] expected it at node_modules/typescript (it is installed with --no-save).');
    console.error(`[run-tests] ${err && err.message ? err.message : err}`);
    process.exit(2);
  }
}

function formatDiagnostic(ts, diagnostic) {
  const message = ts.flattenDiagnosticMessageText(diagnostic.messageText, '\n    ');
  const kind =
    diagnostic.category === ts.DiagnosticCategory.Error
      ? 'error'
      : diagnostic.category === ts.DiagnosticCategory.Warning
        ? 'warning'
        : 'message';

  if (diagnostic.file && typeof diagnostic.start === 'number') {
    const position = diagnostic.file.getLineAndCharacterOfPosition(diagnostic.start);
    return `${toRepoRelative(diagnostic.file.fileName)}:${position.line + 1}:${position.character + 1} - ${kind} TS${diagnostic.code}: ${message}`;
  }
  return `${kind} TS${diagnostic.code}: ${message}`;
}

function compile(ts, { noEmit }) {
  const configPath = path.join(BUILD_DIR, 'tsconfig.json');
  const configFile = ts.readConfigFile(configPath, ts.sys.readFile);
  if (configFile.error) {
    console.error('[run-tests] the generated tsconfig.json could not be read:');
    console.error(`  ${formatDiagnostic(ts, configFile.error)}`);
    process.exit(2);
  }

  const parsed = ts.parseJsonConfigFileContent(configFile.config, ts.sys, BUILD_DIR);
  if (noEmit) parsed.options.noEmit = true;

  const program = ts.createProgram(parsed.fileNames, parsed.options);

  let emitResult = null;
  if (!noEmit) {
    emitResult = program.emit();
  }

  const collected = [...parsed.errors, ...ts.getPreEmitDiagnostics(program)];
  if (emitResult) collected.push(...emitResult.diagnostics);

  const seen = new Set();
  const diagnostics = [];
  for (const diagnostic of collected) {
    const message = ts.flattenDiagnosticMessageText(diagnostic.messageText, '\n');
    const key = `${diagnostic.file ? diagnostic.file.fileName : ''}:${diagnostic.start}:${diagnostic.code}:${message}`;
    if (seen.has(key)) continue;
    seen.add(key);
    diagnostics.push(diagnostic);
  }

  diagnostics.sort((a, b) => {
    const fileA = a.file ? a.file.fileName : '';
    const fileB = b.file ? b.file.fileName : '';
    if (fileA !== fileB) return fileA < fileB ? -1 : 1;
    return (a.start || 0) - (b.start || 0);
  });

  const errors = diagnostics.filter((diagnostic) => diagnostic.category === ts.DiagnosticCategory.Error);

  if (diagnostics.length > 0) {
    console.log('');
    console.log(`[run-tests] TypeScript diagnostics (${errors.length} error${errors.length === 1 ? '' : 's'}):`);
    for (const diagnostic of diagnostics) {
      console.log(`  ${formatDiagnostic(ts, diagnostic)}`);
    }
  } else {
    console.log(`[run-tests] type-check clean (${parsed.fileNames.length} TypeScript file${parsed.fileNames.length === 1 ? '' : 's'})`);
  }

  return { errors, emitResult, fileCount: parsed.fileNames.length };
}

/* ------------------------------------------------------------------ */
/* Test runner generation                                              */
/* ------------------------------------------------------------------ */

const RUNNER_SOURCE = `'use strict';
// Generated by scripts/run-tests.mjs — do not edit by hand.
const fs = require('fs');
const path = require('path');

function collect(dir, out) {
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch (err) {
    return out;
  }
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) collect(full, out);
    else if (entry.isFile() && full.endsWith('.test.js') && entry.name !== 'List.test.js') {
      // List.test.ets is DevEco Studio's suite aggregator: it calls every other
      // suite. Loading it here as well would register each test twice.
      out.push(path.resolve(full));
    }
  }
  return out;
}

const testRoots = [
  path.join(__dirname, 'out', 'test'),
  path.join(__dirname, 'out', 'entry', 'test'),
];
const manifest = testRoots.flatMap((root) => collect(root, [])).sort();
globalThis.__DSH_TEST_MANIFEST__ = manifest;

// Installs the ArkTS resource global before any app module is evaluated.
require('@dsh/host-globals');
const hypium = require('@ohos/hypium');
const loadFailures = [];

for (const file of manifest) {
  try {
    const loaded = require(file);
    // DevEco Studio's generated test template exports the suite as
    // "export default function suite() { describe(...) }"; real hypium loads
    // that function, so do the same here. Plain top-level describe() calls
    // have already registered themselves by this point.
    if (typeof loaded === 'function') loaded();
    else if (loaded && typeof loaded.default === 'function') loaded.default();
  } catch (err) {
    loadFailures.push({ file, err });
  }
}

(async () => {
  let stats = null;
  try {
    stats = await hypium.__runAll();
  } catch (err) {
    console.error('[run] fatal error while running tests:');
    console.error((err && err.stack) || err);
    process.exitCode = 1;
    return;
  }

  for (const failure of loadFailures) {
    console.error('[run] failed to load ' + path.relative(__dirname, failure.file) + ': ' + ((failure.err && failure.err.message) || failure.err));
    if (failure.err && failure.err.stack) console.error(failure.err.stack);
  }

  if (manifest.length === 0) {
    console.log('[run] no emitted test files found under ' + path.relative(__dirname, testRoot));
  }

  const failed = (stats && stats.failed > 0) || loadFailures.length > 0;
  process.exitCode = failed ? 1 : 0;
})();
`;

function writeRunner() {
  const runnerPath = path.join(BUILD_DIR, 'run.js');
  fs.writeFileSync(runnerPath, RUNNER_SOURCE, 'utf8');
  return runnerPath;
}

function runRunner(runnerPath, filter) {
  const result = spawnSync(process.execPath, [runnerPath], {
    cwd: BUILD_DIR,
    stdio: 'inherit',
    env: { ...process.env, DSH_TEST_FILTER: filter || '' },
  });

  if (result.error) {
    console.error(`[run-tests] failed to start the test runner: ${result.error.message}`);
    return 1;
  }
  if (result.signal) {
    console.error(`[run-tests] the test runner was terminated by ${result.signal}`);
    return 1;
  }
  return result.status === null ? 1 : result.status;
}

/* ------------------------------------------------------------------ */
/* Main                                                                */
/* ------------------------------------------------------------------ */

function main() {
  const options = parseArgs(process.argv.slice(2));

  console.log(`[run-tests] recreating ${BUILD_DIR_NAME}/`);
  fs.rmSync(BUILD_DIR, { recursive: true, force: true });
  fs.mkdirSync(SRC_DIR, { recursive: true });

  const copied = copySources();
  if (copied.length === 0) {
    console.log('[run-tests] no sources yet: neither transmission_sdk/src/main/ets nor transmission_sdk/src/test contains a .ets file.');
    fs.rmSync(BUILD_DIR, { recursive: true, force: true });
    process.exit(0);
  }

  console.log(`[run-tests] copied ${copied.length} .ets file${copied.length === 1 ? '' : 's'} to ${BUILD_DIR_NAME}/src/`);
  installShims();
  writeScaffolding();

  const ts = loadTypeScript();
  const { errors, emitResult } = compile(ts, { noEmit: options.noEmit });

  if (options.noEmit) {
    console.log('[run-tests] --no-emit: type-check only, no JS emitted and no tests run.');
    process.exit(errors.length > 0 ? 1 : 0);
  }

  if (emitResult && emitResult.emitSkipped && errors.length > 0) {
    console.error('[run-tests] emit failed; skipping the test run.');
    process.exit(1);
  }

  const runnerPath = writeRunner();
  console.log('[run-tests] running tests with node');
  const testExitCode = runRunner(runnerPath, options.filter);

  if (testExitCode !== 0) process.exit(testExitCode);
  if (errors.length > 0) process.exit(1);
  process.exit(0);
}

main();
