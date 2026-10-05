#!/usr/bin/env node
/**
 * Launch hvigor with a self-resolving HarmonyOS toolchain environment.
 *
 * Why this exists
 * ---------------
 * Two things reliably break a command-line hvigor build on a machine that only
 * has DevEco Studio installed:
 *
 * 1. There is no `hvigorw` in the project. DevEco's own copy lives inside the
 *    IDE installation and is not on `PATH`, and the project ships no
 *    `hvigor/hvigor-wrapper.js` either — so there is simply nothing to run.
 * 2. `java` is not on `PATH`. `PackageHap` shells out to the JDK and dies with
 *    `spawn java ENOENT`, which hvigor reports as the entirely unhelpful
 *    `00308018 Unknown Error`. The JDK is right there inside the IDE (`jbr/`),
 *    it is just never exported.
 *
 * This script fixes both: it locates the toolchain, exports `DEVECO_SDK_HOME`,
 * `JAVA_HOME` and the matching `PATH` entries for the child process, then runs
 * hvigor with the arguments you passed. Anything already present in the
 * environment wins, so an explicit CI setup is never clobbered.
 *
 * Usage
 * -----
 *   node scripts/run-hvigor.mjs [--print-env] <hvigor task> [...hvigor args]
 *
 *   node scripts/run-hvigor.mjs --print-env
 *   node scripts/run-hvigor.mjs clean
 *   node scripts/run-hvigor.mjs assembleHap -p product=default -p buildMode=debug
 *   node scripts/run-hvigor.mjs assembleHar --mode module -p module=transmission_sdk@default
 *
 * You normally do not call this directly — the `hvigorw` / `hvigorw.bat`
 * wrappers in the repository root do. This file is the implementation they
 * share, so cmd.exe, Git Bash and CI all execute identical logic instead of
 * three drifting copies of the same batch/sh script.
 *
 * Toolchain layouts
 * -----------------
 * | Layout                  | Detected by                   | Node         | JDK        | SDK   |
 * | ----------------------- | ----------------------------- | ------------ | ---------- | ----- |
 * | DevEco Studio (the IDE) | `tools/hvigor/bin/hvigorw.js` | `tools/node` | `jbr`      | `sdk` |
 * | Huawei command-line-tools | `bin/hvigorw[.bat]`         | `tool/node`  | not bundled | `sdk` |
 *
 * The IDE layout is what you have locally. The command-line-tools layout is the
 * one Huawei documents for CI pipelines (it ships no JDK, so there you must
 * provide `JAVA_HOME` yourself — this script will say so).
 *
 * Environment variables
 * ---------------------
 * | Variable            | Effect                                                              |
 * | ------------------- | ------------------------------------------------------------------- |
 * | `DEVECO_HOME`       | Explicit toolchain root. Skips auto-detection. Use this when DevEco  |
 * |                     | is installed somewhere unusual, or in CI.                            |
 * | `DEVECO_SDK_HOME`   | HarmonyOS SDK root. Honoured if already set.                         |
 * | `JAVA_HOME`         | JDK root. Honoured if already set; otherwise the IDE's `jbr`.         |
 * | `HVIGOR_NODE`       | Node executable to run hvigor with. Honoured if already set.          |
 *
 * Exit codes: the child's exit code is propagated verbatim, so `hvigorw` is
 * safe to chain with `&&` in scripts.
 */

import { spawnSync } from 'node:child_process';
import { existsSync, statSync } from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const IS_WINDOWS = process.platform === 'win32';
const NODE_EXE = IS_WINDOWS ? 'node.exe' : 'node';

/** Repository root — this file lives in `<root>/scripts/`. */
const APP_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

/** Our own flags, stripped before the rest is forwarded to hvigor. */
const OWN_FLAGS = new Set(['--print-env']);

// ---------------------------------------------------------------------------
// small fs helpers
// ---------------------------------------------------------------------------

function isDir(p) {
  try {
    return statSync(p).isDirectory();
  } catch {
    return false;
  }
}

function isFile(p) {
  try {
    return statSync(p).isFile();
  } catch {
    return false;
  }
}

/** Remember why we picked what we picked, so `--print-env` and errors can explain. */
function note(notes, label, value, origin) {
  notes.push({ label, value, origin });
}

// ---------------------------------------------------------------------------
// toolchain discovery
// ---------------------------------------------------------------------------

/**
 * Places DevEco Studio is commonly installed, used only when `DEVECO_HOME` is
 * unset. Kept short on purpose: probing random directories is a good way to pick
 * up a stale installation.
 */
function defaultToolchainRoots() {
  const env = process.env;

  if (IS_WINDOWS) {
    const roots = [
      path.join(env.ProgramFiles || 'C:\\Program Files', 'Huawei', 'DevEco Studio'),
      path.join(env['ProgramFiles(x86)'] || 'C:\\Program Files (x86)', 'Huawei', 'DevEco Studio'),
    ];
    if (env.LOCALAPPDATA) {
      roots.push(path.join(env.LOCALAPPDATA, 'Huawei', 'DevEco Studio'));
    }
    // DevEco's installer happily puts the IDE on a non-system drive.
    for (const drive of ['C', 'D', 'E', 'F']) {
      roots.push(`${drive}:\\Huawei\\DevEco Studio`);
      roots.push(`${drive}:\\DevEco Studio`);
    }
    return roots;
  }

  if (process.platform === 'darwin') {
    return [
      '/Applications/DevEco-Studio.app/Contents',
      '/Applications/DevEco Studio.app/Contents',
    ];
  }

  return ['/opt/deveco-studio', '/opt/DevEco-Studio', '/usr/local/deveco-studio'];
}

/**
 * Describe a candidate toolchain root, or return `null` if it is not one.
 *
 * @param {string} root
 * @returns {null | {
 *   root: string,
 *   kind: 'deveco' | 'commandline-tools',
 *   bootstrap: string,
 *   bootstrapIsScript: boolean,
 *   node: string | null,
 *   javaHome: string | null,
 *   sdk: string | null,
 * }}
 */
function inspectToolchain(root) {
  if (!root || !isDir(root)) return null;

  // --- DevEco Studio IDE ---------------------------------------------------
  const ideBootstrap = path.join(root, 'tools', 'hvigor', 'bin', 'hvigorw.js');
  if (isFile(ideBootstrap)) {
    const nodeDir = path.join(root, 'tools', 'node');
    const jbr = path.join(root, 'jbr');
    const sdk = path.join(root, 'sdk');
    return {
      root,
      kind: 'deveco',
      bootstrap: ideBootstrap,
      bootstrapIsScript: false,
      node: isFile(path.join(nodeDir, NODE_EXE)) ? path.join(nodeDir, NODE_EXE) : null,
      javaHome: isDir(path.join(jbr, 'bin')) ? jbr : null,
      sdk: isDir(sdk) ? sdk : null,
    };
  }

  // --- Huawei command-line-tools (the CI layout) ---------------------------
  const cltBootstrap = path.join(root, 'bin', IS_WINDOWS ? 'hvigorw.bat' : 'hvigorw');
  if (isFile(cltBootstrap)) {
    const nodeDir = path.join(root, 'tool', 'node');
    const sdk = path.join(root, 'sdk');
    return {
      root,
      kind: 'commandline-tools',
      bootstrap: cltBootstrap,
      bootstrapIsScript: true,
      node: isFile(path.join(nodeDir, NODE_EXE)) ? path.join(nodeDir, NODE_EXE) : null,
      javaHome: null, // command-line-tools deliberately ships no JDK
      sdk: isDir(sdk) ? sdk : null,
    };
  }

  return null;
}

function findToolchain(notes) {
  const forced = process.env.DEVECO_HOME;
  if (forced) {
    const found = inspectToolchain(forced);
    if (!found) {
      fail(
        `DEVECO_HOME is set to "${forced}", but that directory is neither a DevEco Studio\n` +
          'installation nor a Huawei command-line-tools installation.\n' +
          'Expected to find either "tools/hvigor/bin/hvigorw.js" or "bin/hvigorw".'
      );
    }
    note(notes, 'DEVECO_HOME', found.root, 'from environment');
    return found;
  }

  for (const root of defaultToolchainRoots()) {
    const found = inspectToolchain(root);
    if (found) {
      note(notes, 'DEVECO_HOME', found.root, 'auto-detected');
      return found;
    }
  }

  fail(
    'Could not find a HarmonyOS toolchain, so hvigor cannot be started.\n\n' +
      'Fix it with either:\n' +
      '  - DevEco Studio installed (auto-detection covers the default locations), or\n' +
      '  - DEVECO_HOME pointing at a DevEco Studio install or at Huawei command-line-tools, e.g.\n' +
      (IS_WINDOWS
        ? '      set DEVECO_HOME=D:\\Huawei\\DevEco Studio\n'
        : '      export DEVECO_HOME=/opt/deveco-studio\n') +
      '\nRun with --print-env to see what was probed.'
  );
}

// ---------------------------------------------------------------------------
// environment assembly
// ---------------------------------------------------------------------------

/**
 * Build the child environment. Precedence, outermost first:
 *   1. whatever the caller already exported (never overridden)
 *   2. the values discovered from the toolchain
 *
 * @param {ReturnType<typeof inspectToolchain>} toolchain
 */
function buildEnvironment(toolchain) {
  const env = { ...process.env };
  const notes = [];

  // PATH entries we must inject, highest priority last so it ends up first.
  const prepend = [];

  // --- JDK: the fix for `spawn java ENOENT` --------------------------------
  if (toolchain.javaHome) {
    if (!env.JAVA_HOME) {
      env.JAVA_HOME = toolchain.javaHome;
      note(notes, 'JAVA_HOME', toolchain.javaHome, 'from DevEco JBR');
    } else {
      note(notes, 'JAVA_HOME', env.JAVA_HOME, 'kept from environment');
    }
  } else if (env.JAVA_HOME) {
    note(notes, 'JAVA_HOME', env.JAVA_HOME, 'kept from environment');
  } else {
    note(notes, 'JAVA_HOME', '(unset!)', 'command-line-tools ships no JDK — set JAVA_HOME');
  }

  // `java` must be resolvable by name: hvigor's PackageHap task spawns plain
  // `java`, and a JAVA_HOME that is set but not on PATH does not help.
  if (env.JAVA_HOME && isDir(path.join(env.JAVA_HOME, 'bin'))) {
    prepend.push(path.join(env.JAVA_HOME, 'bin'));
  }

  // --- SDK ------------------------------------------------------------------
  if (toolchain.sdk) {
    if (!env.DEVECO_SDK_HOME) {
      env.DEVECO_SDK_HOME = toolchain.sdk;
      note(notes, 'DEVECO_SDK_HOME', toolchain.sdk, 'from DevEco SDK');
    } else {
      note(notes, 'DEVECO_SDK_HOME', env.DEVECO_SDK_HOME, 'kept from environment');
    }
  } else if (env.DEVECO_SDK_HOME) {
    note(notes, 'DEVECO_SDK_HOME', env.DEVECO_SDK_HOME, 'kept from environment');
  } else {
    note(notes, 'DEVECO_SDK_HOME', '(unset!)', 'no sdk/ directory found in the toolchain');
  }

  // --- Node ----------------------------------------------------------------
  // Prefer the toolchain's own node (it is the version the toolchain was built
  // against); fall back to the interpreter running this script.
  const hvigorNode = env.HVIGOR_NODE || toolchain.node || process.execPath;
  note(
    notes,
    'node',
    hvigorNode,
    env.HVIGOR_NODE ? 'from HVIGOR_NODE' : toolchain.node ? 'from toolchain' : 'this process'
  );
  if (toolchain.node && path.dirname(toolchain.node) !== path.dirname(process.execPath)) {
    prepend.push(path.dirname(toolchain.node));
  }

  // --- PATH ----------------------------------------------------------------
  if (prepend.length > 0) {
    const existing = env.PATH ? env.PATH.split(path.delimiter) : [];
    // Drop duplicates while keeping our order, then append the rest untouched.
    const seen = new Set(prepend.map((p) => p.toLowerCase()));
    env.PATH = [
      ...prepend,
      ...existing.filter((p) => !seen.has(p.toLowerCase())),
    ].join(path.delimiter);
  }

  return { env, notes, hvigorNode };
}

// ---------------------------------------------------------------------------
// reporting
// ---------------------------------------------------------------------------

function printTable(title, rows) {
  const width = Math.max(...rows.map((r) => r[0].length));
  process.stdout.write(`${title}\n`);
  for (const [label, value] of rows) {
    process.stdout.write(`  ${label.padEnd(width)} : ${value}\n`);
  }
}

function fail(message) {
  process.stderr.write(`\nrun-hvigor: ${message}\n\n`);
  process.exit(2);
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

const argv = process.argv.slice(2);
const ownFlags = argv.filter((a) => OWN_FLAGS.has(a));
const hvigorArgs = argv.filter((a) => !OWN_FLAGS.has(a));

const toolchain = findToolchain([]);
const { env, notes, hvigorNode } = buildEnvironment(toolchain);

const summary = [
  ['toolchain layout', toolchain.kind],
  ['hvigor bootstrap', toolchain.bootstrap],
  ...notes.map((n) => [n.label, `${n.value}  [${n.origin}]`]),
];

if (ownFlags.includes('--print-env')) {
  printTable('run-hvigor: resolved environment', summary);
  process.stdout.write(`\n  project root${' '.repeat(0)} : ${APP_ROOT}\n`);
  process.stdout.write('  (nothing was executed)\n');
  process.exit(0);
}

if (hvigorArgs.length === 0) {
  printTable('run-hvigor: resolved environment', summary);
  fail('No hvigor task given. Try: hvigorw clean, or hvigorw assembleHap -p product=default');
}

// Surface the resolution once, on stderr, so it never pollutes captured
// stdout — but is still visible when a build misbehaves.
if (process.env.HVIGOR_VERBOSE === '1') {
  printTable('run-hvigor: resolved environment', summary);
}

const command = toolchain.bootstrapIsScript
  ? // command-line-tools ships hvigorw as a launcher script, not a .js module.
    // Windows needs cmd.exe to run a .bat; POSIX executes the shell script.
    IS_WINDOWS
    ? { bin: 'cmd.exe', args: ['/d', '/s', '/c', `"${toolchain.bootstrap}"`, ...hvigorArgs] }
    : { bin: toolchain.bootstrap, args: hvigorArgs }
  : { bin: hvigorNode, args: [toolchain.bootstrap, ...hvigorArgs] };

const result = spawnSync(command.bin, command.args, {
  cwd: APP_ROOT,
  env,
  stdio: 'inherit',
});

if (result.error) {
  fail(`Failed to start hvigor: ${result.error.message}`);
}

process.exit(result.status === null ? 1 : result.status);
