#!/usr/bin/env node
/**
 * ArkTS conformance linter + module manifest schema check.
 *
 * `tsc` validates TypeScript semantics but knows nothing about the ArkTS
 * restrictions the DevEco toolchain enforces on `.ets` files, and it cannot see
 * `module.json5` at all. Both gaps have already produced build failures that
 * only surfaced inside DevEco Studio, so this script encodes the rules that
 * actually bit us:
 *
 * - `arkts-no-untyped-obj-literals` — an object literal needs a contextual type.
 *   `const x: T = {}` is fine; a bare `{}` in a ternary branch, a `return` or a
 *   call argument is not.
 * - `module.json5` schema — HAR and HAP modules accept different key sets
 *   (`deliveryWithInstall` and `pages` are HAP-only), and `virtualMachine` only
 *   accepts `ark` or `default`.
 * - Resource references — `$r('app.color.foo')` naming a token that the
 *   generated resource files do not define is a build failure inside DevEco and
 *   invisible to every other tool here.
 * - Module resolution — a relative import whose target file does not exist, or
 *   an `import { X } from 'transmission_sdk'` naming a symbol the barrel does
 *   not export. `tsc` cannot check the app module because ArkUI structs are not
 *   TypeScript, so this is the only place those mistakes get caught.
 * - Component member names — a `struct` field whose name matches a universal
 *   attribute (`tabIndex`, `width`, `onClick`, …) shadows an inherited
 *   `CustomComponent` method and is a hard compile error.
 * - SDK version ordering in `build-profile.json5` — the toolchain requires
 *   `compatibleSdkVersion <= targetSdkVersion <= compileSdkVersion` and fails
 *   the build otherwise, which is a slow way to learn about a typo.
 * - A parameterised `@Builder` called with an argument that reads state. ArkUI
 *   passes `@Builder` arguments by value, so the UI built from them never
 *   refreshes; the fix is a component with an `@Prop`.
 * - `NavPathStack.pushPath(...).then(...)` — `pushPath` returns `void`, so any
 *   completion callback attached to it is a compile error. Only
 *   `pushDestination` returns a promise.
 * - Duplicate imports, leftover text glyphs where a system symbol belongs, and
 *   `sys.symbol.*` references outside `theme/AppIcons.ets`. The first two came
 *   from an automated edit that the linter happily passed: a renamed identifier
 *   was still referenced and an import had been inserted twice.
 *
 * It is deliberately *stricter* than the compiler for the object-literal rule:
 * any `{}` without an immediately visible type annotation is flagged, because a
 * false positive costs one `Json.emptyObject()` call while a false negative
 * costs a failed build inside DevEco Studio. For every other rule only the
 * unambiguous forms are detected. Comments and string literals are stripped
 * first, and each finding names its rule so a human can judge it.
 *
 * Usage:
 *   node scripts/lint-arkts.mjs [--quiet]
 *
 * Exits non-zero when any error-level finding is reported.
 */
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const REPO_ROOT = path.resolve(import.meta.dirname, '..');
const QUIET = process.argv.includes('--quiet');

/**
 * The package name the application imports the SDK by.
 *
 * The import pattern below is *built* from it rather than written out as a
 * literal, because a scoped package name contains a `/` that must be escaped
 * inside a regex literal. Spelling it out by hand is how this check once went
 * silently dead: the package was renamed, the escaped literal no longer
 * matched anything, and `unknown-sdk-export` stopped reporting without saying
 * so. Escaping at build time means the pattern cannot rot the same way.
 */
const SDK_PACKAGE_NAME = 'transmission_sdk';
const SDK_IMPORT_PATTERN = new RegExp(
  `import\\s*\\{([^}]*)\\}\\s*from\\s*'${SDK_PACKAGE_NAME.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}'`,
  'g',
);

/** Source roots that the DevEco ArkTS compiler processes. */
const SOURCE_ROOTS = [
  path.join(REPO_ROOT, 'transmission_sdk', 'src', 'main', 'ets'),
  path.join(REPO_ROOT, 'transmission_sdk', 'src', 'test'),
  path.join(REPO_ROOT, 'entry', 'src', 'main', 'ets'),
];

/** Resource directory of the sample application. */
const REQ_RES = path.join(REPO_ROOT, 'entry', 'src', 'main', 'resources');

/** Module manifests to validate, with the schema variant that applies. */
const MANIFESTS = [
  { file: path.join(REPO_ROOT, 'transmission_sdk', 'src', 'main', 'module.json5'), kind: 'har' },
  { file: path.join(REPO_ROOT, 'entry', 'src', 'main', 'module.json5'), kind: 'entry' },
];

/* ------------------------------------------------------------------ */
/* Helpers                                                             */
/* ------------------------------------------------------------------ */

function listEtsFiles(dir, out = []) {
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return out;
  }
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) listEtsFiles(full, out);
    else if (entry.isFile() && entry.name.endsWith('.ets')) out.push(full);
  }
  return out;
}

/**
 * Blanks out comments and string/template literals while preserving every
 * character position, so reported line/column numbers still refer to the
 * original file. Without this, prose in a doc comment ("`any` is not allowed")
 * would be reported as a violation.
 */
function stripNoise(source) {
  let out = '';
  let state = 'code';
  const n = source.length;
  for (let i = 0; i < n; i++) {
    const c = source[i];
    const d = source[i + 1];

    if (state === 'code') {
      if (c === '/' && d === '/') {
        state = 'line';
        out += '  ';
        i++;
        continue;
      }
      if (c === '/' && d === '*') {
        state = 'block';
        out += '  ';
        i++;
        continue;
      }
      if (c === "'") {
        state = 'squote';
        out += ' ';
        continue;
      }
      if (c === '"') {
        state = 'dquote';
        out += ' ';
        continue;
      }
      if (c === '`') {
        state = 'template';
        out += ' ';
        continue;
      }
      out += c;
      continue;
    }

    if (c === '\n') {
      out += '\n';
      if (state === 'line') state = 'code';
      continue;
    }
    if (state === 'block' && c === '*' && d === '/') {
      out += '  ';
      i++;
      state = 'code';
      continue;
    }
    if (c === '\\') {
      out += '  ';
      i++;
      continue;
    }
    if (state === 'squote' && c === "'") {
      out += ' ';
      state = 'code';
      continue;
    }
    if (state === 'dquote' && c === '"') {
      out += ' ';
      state = 'code';
      continue;
    }
    if (state === 'template' && c === '`') {
      out += ' ';
      state = 'code';
      continue;
    }
    out += ' ';
  }
  return out;
}

/**
 * Blanks out comments only, leaving string literals intact.
 *
 * Resource references such as `$r('app.color.accent')` keep their argument in a
 * string, so the full {@link stripNoise} would erase exactly what this check
 * needs to see.
 */
function stripCommentsOnly(source) {
  let out = '';
  let state = 'code';
  const n = source.length;
  for (let i = 0; i < n; i++) {
    const c = source[i];
    const d = source[i + 1];

    if (state === 'code') {
      if (c === '/' && d === '/') {
        state = 'line';
        out += '  ';
        i++;
        continue;
      }
      if (c === '/' && d === '*') {
        state = 'block';
        out += '  ';
        i++;
        continue;
      }
      // Entering a literal: its contents are kept, but a "//" inside it is not
      // a comment. A URL in a string literal is the reason this matters.
      if (c === "'" || c === '"' || c === '`') {
        state = c === "'" ? 'squote' : c === '"' ? 'dquote' : 'template';
        out += c;
        continue;
      }
      out += c;
      continue;
    }

    if (c === '\n') {
      out += '\n';
      if (state === 'line') state = 'code';
      continue;
    }
    if (state === 'line') {
      out += ' ';
      continue;
    }
    if (state === 'block' && c === '*' && d === '/') {
      out += '  ';
      i++;
      state = 'code';
      continue;
    }
    if (state === 'block') {
      // Comment body: blank it out, but keep the position so line numbers hold.
      out += ' ';
      continue;
    }
    // Inside a literal: preserve the text, honour escapes, stop at the closer.
    if (c === '\\') {
      out += c;
      if (d !== undefined) {
        out += d;
        i++;
      }
      continue;
    }
    const closes =
      (state === 'squote' && c === "'") || (state === 'dquote' && c === '"') || (state === 'template' && c === '`');
    if (closes) {
      out += c;
      state = 'code';
      continue;
    }
    out += c;
  }
  return out;
}

/** Reads `module.json5` as JSON (the repository writes plain, comment-free JSON5). */
function readJson5(file) {
  const raw = fs.readFileSync(file, 'utf8');
  // Comments are blanked first, then the trailing commas a JSON5 author is
  // allowed to leave behind. String contents are preserved throughout.
  const withoutComments = stripCommentsOnly(raw);
  return JSON.parse(withoutComments.replace(/,(\s*[}\]])/g, '$1'));
}

/* ------------------------------------------------------------------ */
/* Rule definitions                                                    */
/* ------------------------------------------------------------------ */

/**
 * Simple, line-oriented rules. `skip` guards against the few shapes that look
 * like a violation but are not.
 */
const LINE_RULES = [
  {
    rule: 'arkts-no-untyped-obj-literals',
    level: 'error',
    pattern: /(\?|\?\?|\|\||\(|\[|,)\s*\{\s*\}/,
    message: 'bare object literal with no contextual type; use Json.emptyObject() or declare a local with a type annotation',
    skip: (line) => /=>\s*\{\s*\}\s*[),;]?\s*$/.test(line),
  },
  {
    rule: 'arkts-no-untyped-obj-literals',
    level: 'error',
    pattern: /return\s*\{\s*\}\s*;/,
    message: 'returning a bare object literal; give it an explicit type',
  },
  {
    rule: 'arkts-no-untyped-obj-literals',
    level: 'error',
    pattern: /=\s*\{\s*\}\s*;/,
    message: 'assigning a bare object literal without a type annotation',
    skip: (line) => /:\s*[A-Za-z_$][\w$<>[\]|.,\s]*=\s*\{\s*\}\s*;/.test(line),
  },
  {
    rule: 'arkts-no-indexed-signatures',
    level: 'error',
    pattern: /^\s*\[[^\]]*:\s*[A-Za-z_$][\w$<>[\]|.,\s]*\]\s*:/,
    message: 'index signatures are not supported in ArkTS; use Record<K, V>',
  },
  {
    rule: 'arkts-no-destruct-decls',
    level: 'error',
    pattern: /\b(const|let)\s+[[{]/,
    message: 'destructuring declarations are not supported; use explicit temporaries',
  },
  {
    rule: 'arkts-no-destruct-decls',
    level: 'error',
    pattern: /for\s*\(\s*(const|let)\s+[[{]/,
    message: 'destructuring in for-of is not supported; iterate values and index members',
  },
  {
    rule: 'arkts-no-for-in',
    level: 'error',
    pattern: /for\s*\(\s*(const|let|var)\s+[\w$]+\s+in\s/,
    message: 'for..in is not supported; use for..of or Object.keys()',
  },
  {
    rule: 'arkts-no-delete',
    level: 'error',
    pattern: /\bdelete\s+[\w$[(]/,
    message: 'delete is not supported because object layout is fixed at compile time',
  },
  {
    rule: 'arkts-no-any-unknown',
    level: 'error',
    pattern: /:\s*(any|unknown)\b|\bas\s+(any|unknown)\b|<\s*any\s*>/,
    message: 'any and unknown are not supported; declare a concrete type',
  },
  {
    rule: 'arkts-no-regexp-literals',
    level: 'error',
    pattern: /(=\s*|return\s+|\(\s*)\/(?![/=*])[^\n/]+\/[gimsuy]*\s*[;,)]/,
    message: 'regular expression literals are not supported; use new RegExp(...)',
  },
  {
    rule: 'arkts-limited-stdlib',
    level: 'error',
    pattern: /\bhasOwnProperty\b/,
    message: 'Object.prototype.hasOwnProperty is not supported; use Object.keys().includes()',
  },
  {
    rule: 'arkts-limited-stdlib',
    level: 'error',
    pattern:
      /\bObject\.(assign|create|defineProperty|defineProperties|freeze|fromEntries|getOwnPropertyDescriptor|getOwnPropertyDescriptors|getOwnPropertySymbols|getPrototypeOf|is|isExtensible|isFrozen|isPrototypeOf|isSealed|preventExtensions|propertyIsEnumerable|seal|setPrototypeOf)\b/,
    message: 'this Object API is not supported in ArkTS',
  },
  {
    rule: 'arkts-limited-stdlib',
    level: 'error',
    pattern: /\b(globalThis|eval\s*\()/,
    message: 'globalThis/eval are not supported in ArkTS',
  },
  {
    rule: 'arkts-no-symbol',
    level: 'error',
    pattern: /\bSymbol\s*\(/,
    message: 'Symbol() is not supported (only Symbol.iterator)',
  },
  {
    rule: 'arkts-no-require',
    level: 'error',
    pattern: /\brequire\s*\(/,
    message: 'require() is not supported; use import',
  },
  {
    rule: 'arkts-no-var',
    level: 'error',
    pattern: /\bvar\s+[\w$]/,
    message: 'use let instead of var',
  },
  {
    rule: 'arkts-no-as-const',
    level: 'error',
    pattern: /\bas\s+const\b/,
    message: 'as const assertions are not supported',
  },
  {
    rule: 'arkts-no-definite-assignment',
    level: 'warning',
    pattern: /\b[\w$]+\s*!:\s*[A-Za-z_$]/,
    message: 'definite assignment assertions are discouraged; initialise the field instead',
  },
  {
    rule: 'arkts-no-utility-types',
    level: 'error',
    pattern:
      /\b(Pick|Omit|Exclude|Extract|NonNullable|Parameters|ConstructorParameters|ReturnType|InstanceType|ThisType|Uppercase|Lowercase|Capitalize|Uncapitalize|Awaited)</,
    message: 'only Partial, Required, Readonly and Record are supported utility types',
  },
  {
    rule: 'arkts-no-obj-literals-as-types',
    level: 'error',
    pattern: /^\s*(export\s+)?type\s+[\w$]+(\s*<[^>]*>)?\s*=\s*\{/,
    message: 'object literal types are not supported; declare a class or interface',
  },
  {
    rule: 'arkts-no-func-expressions',
    level: 'error',
    pattern: /=\s*function\b/,
    message: 'function expressions are not supported; use an arrow function',
  },
  {
    rule: 'arkts-no-ctor-prop-decls',
    level: 'error',
    pattern: /constructor\s*\([^)]*\b(private|public|protected|readonly)\b/,
    message: 'constructor parameter properties are not supported; declare the field in the class body',
  },
  {
    rule: 'arkts-no-spread',
    level: 'error',
    pattern: /\{\s*\.\.\.\s*[\w$]/,
    message: 'object spread is not supported (array spread into an array literal is)',
  },
];

/* ------------------------------------------------------------------ */
/* Source checks                                                       */
/* ------------------------------------------------------------------ */

const findings = [];

function report(file, line, column, rule, level, message, text) {
  findings.push({
    file: path.relative(REPO_ROOT, file).replace(/\\/g, '/'),
    line,
    column,
    rule,
    level,
    message,
    text: text.trim().slice(0, 110),
  });
}

function lintSource(file) {
  const original = fs.readFileSync(file, 'utf8');
  const stripped = stripNoise(original);
  const lines = stripped.split('\n');
  const originalLines = original.split('\n');

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.trim().length === 0) continue;
    for (const rule of LINE_RULES) {
      const match = rule.pattern.exec(line);
      if (!match) continue;
      if (rule.skip !== undefined && rule.skip(line, match)) continue;
      report(file, i + 1, match.index + 1, rule.rule, rule.level, rule.message, originalLines[i] ?? '');
    }
  }

  // `this` inside a static method (arkts-no-standalone-this).
  let inStatic = false;
  let depthAtEntry = 0;
  let depth = 0;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (/\bstatic\s+(readonly\s+)?[A-Za-z_$][\w$]*\s*\(/.test(line) && line.includes('{')) {
      inStatic = true;
      depthAtEntry = depth;
    }
    if (inStatic && /\bthis\s*\./.test(line)) {
      report(
        file,
        i + 1,
        line.indexOf('this') + 1,
        'arkts-no-standalone-this',
        'error',
        '`this` cannot be used inside a static method',
        originalLines[i] ?? '',
      );
    }
    depth += (line.match(/\{/g) ?? []).length - (line.match(/\}/g) ?? []).length;
    if (inStatic && depth <= depthAtEntry) inStatic = false;
  }
}

/* ------------------------------------------------------------------ */
/* Manifest checks                                                     */
/* ------------------------------------------------------------------ */

/** Keys accepted by `module` in a HAR manifest (from hvigor's schema error). */
const HAR_MODULE_KEYS = new Set([
  'name',
  'type',
  'srcEntrance',
  'srcEntry',
  'description',
  'process',
  'mainElement',
  'deviceTypes',
  'installationFree',
  'virtualMachine',
  'uiSyntax',
  'metadata',
  'abilities',
  'extensionAbilities',
  'requestPermissions',
  'definePermissions',
  'testRunner',
  'dependencies',
  'libIsolation',
  'routerMap',
  'appStartup',
  'crossAppSharedConfig',
]);

/** Keys that are valid for an entry HAP but not for a HAR. */
const HAP_ONLY_KEYS = new Set(['deliveryWithInstall', 'pages', 'installationFree', 'shortcuts', 'widgets']);

const VIRTUAL_MACHINES = new Set(['ark', 'default']);

function lintManifest({ file, kind }) {
  let parsed;
  try {
    parsed = readJson5(file);
  } catch (error) {
    report(file, 1, 1, 'module.json5', 'error', `cannot parse: ${error.message}`, '');
    return;
  }
  const module = parsed.module;
  if (module === undefined) {
    report(file, 1, 1, 'module.json5', 'error', 'missing the top-level "module" object', '');
    return;
  }
  if (module.type !== kind) {
    report(file, 1, 1, 'module.json5', 'error', `expected "type": "${kind}", found ${JSON.stringify(module.type)}`, '');
  }

  if (kind === 'har') {
    for (const key of Object.keys(module)) {
      if (HAR_MODULE_KEYS.has(key)) continue;
      const hint = HAP_ONLY_KEYS.has(key) ? ' (a HAP-only key; HARs cannot be installed independently)' : '';
      report(file, 1, 1, 'module.json5', 'error', `"${key}" is not allowed in a HAR manifest${hint}`, '');
    }
  }

  if (module.virtualMachine !== undefined && !VIRTUAL_MACHINES.has(module.virtualMachine)) {
    report(
      file,
      1,
      1,
      'module.json5',
      'error',
      `"virtualMachine" must be one of ${[...VIRTUAL_MACHINES].join(', ')}`,
      '',
    );
  }
}

/* ------------------------------------------------------------------ */
/* SDK versions                                                        */
/* ------------------------------------------------------------------ */

/**
 * Reads the API level out of an SDK version field.
 *
 * Two spellings are in use: `"7.0.0(26)"` (HarmonyOS version with the API level
 * in parentheses, which this project uses) and the plain `"26.0.0"`. The API
 * level is what the ordering rule compares.
 *
 * @param value the raw field value
 * @returns the API level, or `undefined` when it cannot be determined
 */
function apiLevelOf(value) {
  if (typeof value === 'number') return value;
  if (typeof value !== 'string') return undefined;
  const parenthesised = /\((\d+)\)/.exec(value);
  if (parenthesised !== null) return Number.parseInt(parenthesised[1], 10);
  const leading = /^(\d+)/.exec(value.trim());
  return leading === null ? undefined : Number.parseInt(leading[1], 10);
}

/**
 * Verifies the SDK version fields of every product.
 *
 * `compatible` is the install floor, `target` the version the app is adapted to,
 * and `compile` the SDK used to build. The toolchain rejects
 * `compatible > target` or `target > compile`, and warns when `target` is
 * missing altogether.
 */
function lintBuildProfileVersions() {
  const file = path.join(REPO_ROOT, 'build-profile.json5');
  if (!fs.existsSync(file)) return;

  let profile;
  try {
    profile = readJson5(file);
  } catch (error) {
    report(file, 1, 1, 'build-profile', 'error', `cannot parse: ${error.message}`, '');
    return;
  }

  const products = (profile.app && profile.app.products) || [];
  for (const product of products) {
    const name = product.name || 'unnamed';
    const compatible = apiLevelOf(product.compatibleSdkVersion);
    const target = apiLevelOf(product.targetSdkVersion);
    const compile = apiLevelOf(product.compileSdkVersion);

    if (product.targetSdkVersion === undefined) {
      report(
        file,
        1,
        1,
        'build-profile',
        'warning',
        `product "${name}" does not set targetSdkVersion; hvigor recommends configuring it`,
        '',
      );
    }
    if (compatible !== undefined && target !== undefined && compatible > target) {
      report(
        file,
        1,
        1,
        'build-profile',
        'error',
        `product "${name}": compatibleSdkVersion (API ${compatible}) must not exceed targetSdkVersion (API ${target})`,
        '',
      );
    }
    if (target !== undefined && compile !== undefined && target > compile) {
      report(
        file,
        1,
        1,
        'build-profile',
        'error',
        `product "${name}": targetSdkVersion (API ${target}) must not exceed compileSdkVersion (API ${compile})`,
        '',
      );
    }
  }
}

/* ------------------------------------------------------------------ */
/* Builder arguments                                                   */
/* ------------------------------------------------------------------ */

/**
 * Reads the argument text of a call, starting at its opening parenthesis.
 *
 * Quote-aware, so a parenthesis inside a string literal does not end the call.
 *
 * @param source the source to scan
 * @param open index of the `(`
 * @returns the text between the parentheses
 */
function readCallArguments(source, open) {
  let depth = 0;
  let quote = null;
  for (let i = open; i < source.length; i++) {
    const c = source[i];
    if (quote !== null) {
      if (c === '\\') {
        i++;
      } else if (c === quote) {
        quote = null;
      }
      continue;
    }
    if (c === "'" || c === '"' || c === '`') {
      quote = c;
      continue;
    }
    if (c === '(') {
      depth++;
      continue;
    }
    if (c === ')') {
      depth--;
      if (depth === 0) {
        return source.slice(open + 1, i);
      }
    }
  }
  return '';
}

/**
 * Flags a parameterised `@Builder` invoked with an argument that reads state.
 *
 * ArkUI passes `@Builder` arguments **by value**; when the argument derives from
 * a state variable, a later change does not refresh the UI built from it. The
 * symptom is a screen that renders correctly once and then freezes — which is
 * what the torrent detail screen did, because its definition rows were built by
 * `this.fieldRow(label, formatBytes(this.currentTorrent().downloadedEver))` while
 * the torrent was still loading.
 *
 * Arguments that are constants, `ForEach` items or callbacks (`=>`) are fine, and
 * so are parameterless builders, which re-read state on every rebuild.
 */
function lintBuilderArguments() {
  const declaration = /@Builder\s+([A-Za-z_]\w*)\s*\(([^)]*)\)/g;
  for (const file of files) {
    const original = fs.readFileSync(file, 'utf8');
    const code = stripCommentsOnly(original);

    const builders = new Set();
    declaration.lastIndex = 0;
    let declared = declaration.exec(code);
    while (declared !== null) {
      if (declared[2].trim().length > 0) {
        builders.add(declared[1]);
      }
      declared = declaration.exec(code);
    }
    if (builders.size === 0) {
      continue;
    }

    for (const name of builders) {
      const call = new RegExp('this\\.' + name + '\\s*\\(', 'g');
      let found = call.exec(code);
      while (found !== null) {
        const args = readCallArguments(code, found.index + found[0].length - 1);
        if (args.includes('this.') && !args.includes('=>')) {
          const line = code.slice(0, found.index).split('\n').length;
          report(
            file,
            line,
            1,
            'builder-value-param',
            'error',
            `"${name}" takes an argument that reads state; @Builder arguments are passed by value and will not refresh — use a component with @Prop`,
            original.split('\n')[line - 1] ?? '',
          );
        }
        found = call.exec(code);
      }
    }
  }
}

/* ------------------------------------------------------------------ */
/* Navigation API usage                                                */
/* ------------------------------------------------------------------ */

/**
 * Flags a completion callback attached to `pushPath`.
 *
 * `NavPathStack.pushPath` and `pushPathByName` return `void`; only
 * `pushDestination` and `pushDestinationByName` return a promise. The mistake is
 * easy to make because every other navigation call in ArkUI is asynchronous.
 */
function lintNavigationCalls() {
  const pattern = /\bpushPath(?:ByName)?\s*\([^;]{0,400}?\)\s*\.\s*then\s*\(/g;
  for (const file of files) {
    const original = fs.readFileSync(file, 'utf8');
    const stripped = stripCommentsOnly(original);
    pattern.lastIndex = 0;
    let match = pattern.exec(stripped);
    while (match !== null) {
      const line = stripped.slice(0, match.index).split('\n').length;
      report(
        file,
        line,
        1,
        'push-path-returns-void',
        'error',
        'pushPath() returns void; use pushDestination() for a promise, or a @StorageLink + @Watch hand-off',
        original.split('\n')[line - 1] ?? '',
      );
      match = pattern.exec(stripped);
    }
  }
}

/* ------------------------------------------------------------------ */
/* Imports, icons and symbol concentration                             */
/* ------------------------------------------------------------------ */

/**
 * Characters that used to stand in for icons before the application moved to
 * the HarmonyOS symbol library.
 *
 * A text glyph does not scale with the accessibility font size, does not match
 * the system font weight, and renders differently across device fonts, so a new
 * one is a regression rather than a style choice.
 */
const TEXT_ICON_CHARACTERS = /[\u2190-\u21FF\u2300-\u23FF\u25A0-\u25FF\u2600-\u27BF\u2B00-\u2BFF\uFF0B\uFE0F]/;

/** File that is allowed to mention `sys.symbol.*`. */
const ICON_REGISTRY = path.join('entry', 'src', 'main', 'ets', 'theme', 'AppIcons.ets');

/** Flags the same name imported twice from anywhere in one file. */
function lintDuplicateImports() {
  for (const file of files) {
    const source = stripCommentsOnly(fs.readFileSync(file, 'utf8'));
    const lines = fs.readFileSync(file, 'utf8').split('\n');
    const seen = new Map();
    const pattern = /import\s*\{([^}]*)\}\s*from\s*['"]([^'"]+)['"]/g;
    pattern.lastIndex = 0;
    let match = pattern.exec(source);
    while (match !== null) {
      const from = match[2];
      for (const raw of match[1].split(',')) {
        const name = raw.trim().split(/\s+as\s+/).pop().trim();
        if (name.length === 0) continue;
        const key = `${name}`;
        if (seen.has(key)) {
          const line = source.slice(0, match.index).split('\n').length;
          report(
            file,
            line,
            1,
            'duplicate-import',
            'error',
            `"${name}" is imported twice (also from "${seen.get(key)}")`,
            lines[line - 1] ?? '',
          );
        } else {
          seen.set(key, from);
        }
      }
      match = pattern.exec(source);
    }
  }
}

/**
 * Flags text characters used as icons.
 *
 * Only string literals are examined, and only from the shipped app sources:
 * the SDK communicates with a server and has no UI.
 */
function lintTextIcons() {
  const pattern = /'([^'\n]{1,3})'/g;
  for (const file of files) {
    if (!file.includes(`${path.sep}entry${path.sep}`)) continue;
    if (file.endsWith(ICON_REGISTRY.split(path.sep).pop())) continue;
    const original = fs.readFileSync(file, 'utf8');
    const stripped = stripCommentsOnly(original).split('\n');
    const lines = original.split('\n');
    for (let i = 0; i < lines.length; i++) {
      const code = stripped[i];
      pattern.lastIndex = 0;
      let match = pattern.exec(code);
      while (match !== null) {
        if (TEXT_ICON_CHARACTERS.test(match[1])) {
          report(
            file,
            i + 1,
            match.index + 1,
            'text-icon',
            'error',
            `"${match[1]}" is a text glyph used as an icon; use AppIcons (a sys.symbol resource)`,
            lines[i],
          );
        }
        match = pattern.exec(code);
      }
    }
  }
}

/**
 * Keeps every `sys.symbol.*` reference inside the icon registry.
 *
 * A symbol name that the installed SDK does not ship is a compile-time resource
 * error, and the exact set changes between SDK releases. One file means one
 * place to fix.
 */
function lintSymbolConcentration() {
  for (const file of files) {
    const relative = path.relative(REPO_ROOT, file);
    if (relative === ICON_REGISTRY) continue;
    const original = fs.readFileSync(file, 'utf8');
    const stripped = stripCommentsOnly(original).split('\n');
    const lines = original.split('\n');
    for (let i = 0; i < lines.length; i++) {
      const code = stripped[i];
      const index = code.indexOf('sys.symbol.');
      if (index >= 0) {
        report(
          file,
          i + 1,
          index + 1,
          'symbol-concentration',
          'error',
          'reference sys.symbol.* only through AppIcons, so a name that has to change is a one-line edit',
          lines[i],
        );
      }
    }
  }
}

/* ------------------------------------------------------------------ */
/* Component member names                                              */
/* ------------------------------------------------------------------ */

/**
 * Universal attributes declared on ArkUI's `CustomComponent`.
 *
 * Every `@Component struct` inherits these as methods, so a field with the same
 * name shadows the base member and the compiler rejects it:
 *
 *   Property 'tabIndex' in type 'X' is not assignable to the same property in
 *   base type 'CustomComponent'.
 *
 * The list is the subset a UI author would plausibly use as a state field name;
 * layout-only attributes such as `gridRow` are omitted because nothing sensible
 * would be named after them.
 */
const UNIVERSAL_ATTRIBUTES = new Set([
  'id', 'key', 'width', 'height', 'size', 'constraintSize', 'padding', 'margin',
  'border', 'borderStyle', 'borderWidth', 'borderColor', 'borderRadius', 'borderImage',
  'background', 'backgroundColor', 'backgroundImage', 'backgroundImageSize',
  'backgroundImagePosition', 'backgroundBlurStyle', 'backgroundEffect',
  'foregroundColor', 'foregroundBlurStyle', 'opacity', 'visibility', 'enabled',
  'zIndex', 'direction', 'align', 'position', 'markAnchor', 'offset', 'clip', 'mask',
  'overlay', 'shadow', 'blur', 'backdropBlur', 'scale', 'rotate', 'translate',
  'transform', 'transition', 'animation', 'gesture', 'priorityGesture',
  'parallelGesture', 'focusable', 'defaultFocus', 'groupDefaultFocus',
  'focusOnTouch', 'tabIndex', 'sharedTransition', 'obscured', 'reuseId', 'renderFit',
  'linearGradient', 'sweepGradient', 'radialGradient', 'clipShape', 'maskShape',
  'accessibilityText', 'accessibilityDescription', 'accessibilityLevel',
  'accessibilityGroup', 'accessibilityVirtualNode', 'stateStyles', 'restoreId',
  'brightness', 'contrast', 'grayscale', 'invert', 'sepia', 'saturate', 'colorBlend',
  'hueRotate', 'blendMode', 'motionPath', 'motionBlur', 'attributeModifier',
  'gestureModifier', 'draggable', 'dragPreview', 'allowDrop', 'responseRegion',
  'touchable', 'hitTestBehavior', 'monopolizeEvents', 'expandSafeArea',
  'keyboardShortcut', 'bindMenu', 'bindContextMenu', 'bindPopup', 'bindSheet',
  'bindContentCover', 'bindCustomDialog', 'onClick', 'onTouch', 'onAppear',
  'onDisAppear', 'onKeyEvent', 'onFocus', 'onBlur', 'onHover', 'onMouse',
  'onAreaChange', 'onVisibleAreaChange', 'onSizeChange', 'onDragStart', 'onDrop',
  'onDragEnter', 'onDragMove', 'onDragLeave', 'onDragEnd', 'onPreDrag',
]);

/**
 * Yields `{ name, body, startLine }` for every `struct` declaration.
 *
 * Brace matching is used rather than a regular expression so that nested
 * `build()` blocks do not truncate the body.
 */
function structDeclarations(source) {
  const results = [];
  const pattern = /\bstruct\s+([A-Za-z_$][\w$]*)\s*\{/g;
  pattern.lastIndex = 0;
  let match = pattern.exec(source);
  while (match !== null) {
    const open = match.index + match[0].length - 1;
    let depth = 0;
    for (let i = open; i < source.length; i++) {
      const c = source[i];
      if (c === '{') depth++;
      else if (c === '}') {
        depth--;
        if (depth === 0) {
          results.push({
            name: match[1],
            body: source.slice(open + 1, i),
            startLine: source.slice(0, open + 1).split('\n').length,
          });
          break;
        }
      }
    }
    match = pattern.exec(source);
  }
  return results;
}

/**
 * Flags `struct` fields whose name matches a universal attribute.
 *
 * Method declarations are skipped: `aboutToAppear(): void {` has a `(` after the
 * name, and those are overrides the framework expects rather than collisions.
 */
function lintComponentMemberNames() {
  for (const file of files) {
    const source = fs.readFileSync(file, 'utf8');
    const stripped = stripCommentsOnly(source);
    const originalLines = source.split('\n');
    for (const declaration of structDeclarations(stripped)) {
      const lines = declaration.body.split('\n');
      for (let i = 0; i < lines.length; i++) {
        const code = lines[i];
        const attribute = /^\s*(?:@[A-Za-z_$][\w$]*(?:\([^)]*\))?\s+)*(?:private\s+|public\s+|protected\s+|readonly\s+|static\s+)*([A-Za-z_$][\w$]*)\s*[?:=]/.exec(code);
        if (attribute === null) continue;
        const member = attribute[1];
        if (!UNIVERSAL_ATTRIBUTES.has(member)) continue;
        const lineNumber = declaration.startLine + i;
        report(
          file,
          lineNumber,
          code.indexOf(member) + 1,
          'attribute-name-collision',
          'error',
          `"${member}" in struct ${declaration.name} shadows a universal attribute of CustomComponent; rename it`,
          originalLines[lineNumber - 1] ?? '',
        );
      }
    }
  }
}

/* ------------------------------------------------------------------ */
/* Module resolution                                                   */
/* ------------------------------------------------------------------ */

/** Extensions ArkTS resolves for a relative import, in priority order. */
const IMPORT_EXTENSIONS = ['.ets', '.ts', '.js', '.d.ets', '.d.ts'];

/**
 * Resolves a relative import specifier to a file on disk.
 *
 * @param fromFile file containing the import
 * @param specifier the raw specifier, e.g. `../viewmodel/Formatters`
 * @returns the resolved path, or `undefined` when nothing matches
 */
function resolveRelative(fromFile, specifier) {
  const base = path.resolve(path.dirname(fromFile), specifier);
  for (const extension of IMPORT_EXTENSIONS) {
    if (fs.existsSync(base + extension)) return base + extension;
  }
  for (const extension of IMPORT_EXTENSIONS) {
    const candidate = path.join(base, 'index' + extension);
    if (fs.existsSync(candidate)) return candidate;
  }
  if (fs.existsSync(base) && fs.statSync(base).isFile()) return base;
  return undefined;
}

/** Verifies that every relative import in the app resolves to a real file. */
function lintRelativeImports() {
  const pattern = /(?:^|\n)\s*(?:import|export)[^;]*?from\s+['"](\.[^'"]+)['"]/g;
  for (const file of files) {
    const source = stripCommentsOnly(fs.readFileSync(file, 'utf8'));
    pattern.lastIndex = 0;
    let match = pattern.exec(source);
    while (match !== null) {
      const specifier = match[1];
      if (resolveRelative(file, specifier) === undefined) {
        const line = source.slice(0, match.index).split('\n').length;
        report(
          file,
          line,
          1,
          'unresolved-import',
          'error',
          `cannot resolve "${specifier}"`,
          specifier,
        );
      }
      match = pattern.exec(source);
    }
  }
}

/**
 * Collects the names exported by the SDK barrel.
 *
 * The barrel is written entirely with `export { A, B } from './x'`, so a single
 * pass over those blocks is enough.
 */
function collectSdkExports() {
  const barrel = path.join(REPO_ROOT, 'transmission_sdk', 'src', 'main', 'ets', 'index.ets');
  const names = new Set();
  if (!fs.existsSync(barrel)) return names;
  const source = stripCommentsOnly(fs.readFileSync(barrel, 'utf8'));
  const pattern = /export\s*\{([^}]*)\}\s*from/g;
  pattern.lastIndex = 0;
  let match = pattern.exec(source);
  while (match !== null) {
    for (const raw of match[1].split(',')) {
      const name = raw.trim();
      if (name.length > 0) names.add(name);
    }
    match = pattern.exec(source);
  }
  // Names declared directly in the barrel, if any are ever added.
  const declared = /export\s+(?:declare\s+)?(?:abstract\s+)?(?:class|function|enum|interface|type|const|let)\s+([A-Za-z_$][\w$]*)/g;
  declared.lastIndex = 0;
  let decl = declared.exec(source);
  while (decl !== null) {
    names.add(decl[1]);
    decl = declared.exec(source);
  }
  return names;
}

/**
 * Verifies that every named import from `transmission_sdk` exists.
 *
 * A typo here compiles fine under `tsc` for the SDK but breaks the app module,
 * which only DevEco can see.
 */
function lintSdkImports() {
  const exported = collectSdkExports();
  if (exported.size === 0) return;
  const pattern = new RegExp(SDK_IMPORT_PATTERN.source, 'g');
  for (const file of files) {
    const source = stripCommentsOnly(fs.readFileSync(file, 'utf8'));
    pattern.lastIndex = 0;
    let match = pattern.exec(source);
    while (match !== null) {
      for (const raw of match[1].split(',')) {
        const name = raw.trim().split(/\s+as\s+/)[0].trim();
        if (name.length > 0 && !exported.has(name)) {
          const line = source.slice(0, match.index).split('\n').length;
          report(
            file,
            line,
            1,
            'unknown-sdk-export',
            'error',
            `"${name}" is not exported by transmission_sdk/index.ets`,
            name,
          );
        }
      }
      match = pattern.exec(source);
    }
  }
}

/* ------------------------------------------------------------------ */
/* Resource references                                                 */
/* ------------------------------------------------------------------ */

/** Resource kinds that resolve against files in `entry/src/main/resources`. */
const RESOURCE_TARGETS = [
  { kind: 'color', file: path.join(REQ_RES, 'base', 'element', 'color.json'), key: 'color' },
  { kind: 'string', file: path.join(REQ_RES, 'base', 'element', 'string.json'), key: 'string' },
  { kind: 'string', file: path.join(REQ_RES, 'zh_CN', 'element', 'string.json'), key: 'string' },
];

/**
 * Collects the names declared by a HarmonyOS element resource file.
 *
 * @param file `element/*.json` file
 * @param key top-level array name, e.g. `color`
 */
function readResourceNames(file, key) {
  const parsed = readJson5(file);
  const list = parsed[key];
  const names = new Set();
  if (Array.isArray(list)) {
    for (const entry of list) {
      if (entry && typeof entry.name === 'string') names.add(entry.name);
    }
  }
  return names;
}

/** Verifies that base and a qualified variant declare the same names. */
function checkResourceParity(kind, key, files) {
  const sets = files.map((file) => ({ file, names: readResourceNames(file, key) }));
  const reference = sets[0];
  for (const other of sets.slice(1)) {
    for (const name of reference.names) {
      if (!other.names.has(name)) {
        report(
          other.file,
          1,
          1,
          'resource-parity',
          'error',
          `"${name}" is missing here but declared in ${path.basename(path.dirname(path.dirname(reference.file)))}`,
          '',
        );
      }
    }
    for (const name of other.names) {
      if (!reference.names.has(name)) {
        report(
          reference.file,
          1,
          1,
          'resource-parity',
          'error',
          `"${name}" is missing here but declared in ${path.basename(path.dirname(path.dirname(other.file)))}`,
          '',
        );
      }
    }
  }
}

/**
 * Checks every `$r('app.<kind>.<name>')` in the app sources against the
 * generated resource files, and every `$r('app.media.<name>')` against the
 * media directory.
 */
function lintResourceReferences() {
  const available = new Map();
  for (const target of RESOURCE_TARGETS) {
    const names = available.get(target.kind) ?? new Set();
    for (const name of readResourceNames(target.file, target.key)) names.add(name);
    available.set(target.kind, names);
  }
  // `media` is a directory of files rather than an element list.
  const mediaDir = path.join(REQ_RES, 'base', 'media');
  const media = new Set();
  try {
    for (const entry of fs.readdirSync(mediaDir)) media.add(entry.replace(/\.[^.]+$/, ''));
  } catch {
    // No media directory: nothing to check.
  }
  available.set('media', media);

  const pattern = /\$r\(\s*'app\.([a-zA-Z]+)\.([A-Za-z0-9_]+)'/g;
  for (const file of files) {
    const original = fs.readFileSync(file, 'utf8');
    // Strip over the whole file: a per-line pass cannot see that a line sits
    // inside a multi-line comment, and would report the prose as a violation.
    const stripped = stripCommentsOnly(original).split('\n');
    const lines = original.split('\n');
    for (let i = 0; i < lines.length; i++) {
      const code = stripped[i];
      pattern.lastIndex = 0;
      let match = pattern.exec(code);
      while (match !== null) {
        const kind = match[1];
        const name = match[2];
        const known = available.get(kind);
        if (known !== undefined && !known.has(name)) {
          report(
            file,
            i + 1,
            match.index + 1,
            'unknown-resource',
            'error',
            `$r('app.${kind}.${name}') is not declared in entry/src/main/resources`,
            lines[i],
          );
        }
        match = pattern.exec(code);
      }
    }
  }
}

/* ------------------------------------------------------------------ */
/* Main                                                                */
/* ------------------------------------------------------------------ */

const extraFiles = [path.join(REPO_ROOT, 'transmission_sdk', 'index.ets')].filter((file) => fs.existsSync(file));
const files = [...SOURCE_ROOTS.flatMap((root) => listEtsFiles(root)), ...extraFiles].sort();
for (const file of files) lintSource(file);
for (const manifest of MANIFESTS) lintManifest(manifest);

checkResourceParity('color', 'color', [
  path.join(REQ_RES, 'base', 'element', 'color.json'),
  path.join(REQ_RES, 'dark', 'element', 'color.json'),
]);
checkResourceParity('string', 'string', [
  path.join(REQ_RES, 'base', 'element', 'string.json'),
  path.join(REQ_RES, 'zh_CN', 'element', 'string.json'),
]);
lintResourceReferences();
lintRelativeImports();
lintSdkImports();
lintComponentMemberNames();
lintNavigationCalls();
lintBuilderArguments();
lintBuildProfileVersions();
lintDuplicateImports();
lintTextIcons();
lintSymbolConcentration();

const errors = findings.filter((finding) => finding.level === 'error');
const warnings = findings.filter((finding) => finding.level === 'warning');

if (!QUIET) {
  for (const finding of [...errors, ...warnings]) {
    const label = finding.level === 'error' ? 'ERROR' : 'WARN ';
    console.log(`${label} ${finding.file}:${finding.line}:${finding.column} - [${finding.rule}] ${finding.message}`);
    if (finding.text.length > 0) console.log(`      ${finding.text}`);
  }
}

console.log(
  `[lint-arkts] ${files.length} .ets files, ${MANIFESTS.length} manifests: ` +
    `${errors.length} error(s), ${warnings.length} warning(s)`,
);

process.exit(errors.length === 0 ? 0 : 1);
