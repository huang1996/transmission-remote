# The application

`entry/` is the TransmissionRemote application — a complete Transmission remote
that doubles as the reference for how to consume the SDK. This document covers
its structure, the navigation model, theming, persistence and the trade-offs
taken along the way.

## Screens

| Screen | File | Reached from |
|:--|:--|:--|
| Torrent list (home) | `pages/Index.ets` | app start |
| Torrent detail (5 tabs) | `pages/TorrentDetailPage.ets` | tapping a row |
| Add torrent | `pages/AddTorrentPage.ets` | the floating button, or the overflow menu |
| Servers | `pages/ServersPage.ets` | the drawer, or the overflow menu |
| Options | `pages/SettingsPage.ets` | the drawer |

The home screen is the only `@Entry` page listed in
`resources/base/profile/main_pages.json`; everything else is a `NavDestination`
pushed onto the `NavPathStack` owned by the home screen.

```
Index (Navigation + SideBarContainer)
├── DrawerContent            servers · filters · sort · night mode · options · free space
├── topBar                   ☰ · server ▾ · ▶ · ‖ · ⋮ (or the search field)
├── listArea                 Refresh > List > TorrentRowView, swipeAction per row
│   └── floatingButton       ＋ expands into 文件 / 地址
└── bottomBar                ↓ total · ↑ total · ⌕
```

## Navigation

`Index` owns a `NavPathStack` and registers a destination builder:

```ts
Navigation(this.pathStack) { … }
  .hideTitleBar(true)
  .mode(NavigationMode.Stack)
  .navDestination(this.pageMap)

@Builder
pageMap(name: string, param: object) {
  if (name === RouteName.DETAIL) {
    TorrentDetailPage({ torrentId: (param as DetailParam).torrentId })
  } else if (name === RouteName.ADD) {
    AddTorrentPage({ pathStack: this.pathStack, initialMethod: (param as AddParam).method })
  } …
}
```

Route names and the typed parameter classes live in `model/NavParams.ets`. The
stack arrives as an untyped `object`, so each branch casts it to the class the
caller pushed — the cast target is a class rather than a primitive because ArkTS
casts to primitives from `object` are not safe.

`@ohos.router` is deliberately **not** used: it is deprecated from API 12 in
favour of `Navigation`, and the deprecated form emits build warnings.

## Theming

Two things make light/dark support boring, which is the goal:

1. **Resource-qualified colours.** Every colour is a token
   (`app_background`, `surface`, `text_primary`, `accent`, …) defined twice:
   `resources/base/element/color.json` for light and
   `resources/dark/element/color.json` for dark. Components only ever write
   `$r('app.color.surface')`, so the platform swaps the palette — no runtime
   branching, no theme object threaded through the tree.
2. **One stored preference.** `ThemeMode.SYSTEM | LIGHT | DARK` is persisted and
   applied with `applicationContext.setColorMode(...)`:
   `COLOR_MODE_NOT_SET` for `SYSTEM`, `COLOR_MODE_LIGHT` / `COLOR_MODE_DARK`
   otherwise. `ThemeManager.applyPersisted` runs in `EntryAbility.onCreate`, so
   a cold start never flashes the wrong palette.

The drawer's night-mode switch is a plain on/off control, so it writes an
explicit `LIGHT` or `DARK` rather than `SYSTEM`: switching it off must produce
light even on a device that is currently dark. To go back to following the
system, use *Options → Appearance*.

Localisation works the same way. `resources/base` holds English and
`resources/zh_CN` holds Chinese; every label in the UI is a `$r('app.string.*')`
reference.

Both palettes and both locales are **generated from one table** by
`scripts/generate-app-resources.mjs`, because a token missing from the dark
palette silently falls back to the light value — which looks like a styling bug
rather than a missing resource. The linter asserts parity in both directions.

## Persistence

`store/AppContext.ets` is a process-wide singleton holding:

- `servers: ServerProfile[]` and the selected `activeServerId`;
- `settings: AppSettings` (appearance, refresh interval, FAB, notifications,
  timeout, dialect, filter, sort);
- the live `TransmissionClient`, plus a per-server cache of the CSRF session id.

It is a singleton rather than page state on purpose: ArkUI recreates pages
freely, and a client owned by a page would reconnect on every navigation and
lose its CSRF session id each time.

Everything is stored as JSON in a `preferences` store. Values read from disk are
treated as untrusted — a truncated or hand-edited blob yields defaults instead of
a crash at start-up.

## Servers

`ServerProfile` models `scheme://host:port/path` with optional HTTP Basic
credentials, so both plain HTTP and HTTPS work; the URL is built by
`ServerProfile.url` and handed straight to `TransmissionClientBuilder`. A server
is validated before saving (host required, port in 1…65535), and the editor can
test a connection without touching the saved configuration.

## Swipe actions and the detail tabs

Row actions use ArkUI's built-in `swipeAction`:

```ts
ListItem() { TorrentRowView({ … }) }
  .swipeAction({ end: this.rowActions(row), edgeEffect: SwipeEdgeEffect.Spring })
```

so the list keeps the platform's own gesture physics instead of a hand-rolled
pan recogniser.

The detail screen uses `Tabs`, which supports tapping a tab and swiping the
content out of the box; all it takes is not disabling `scrollable`.

## Staying in sync after a screen closes

`AppContext` is intentionally not observable (see above), so nothing pushes a
change from `ServersPage` back to the list. The obvious hand-off — awaiting
`pushPath` — does not exist: **`NavPathStack.pushPath` returns `void`** (only
`pushDestination` returns a promise), so there is no completion callback.

Instead the store broadcasts a monotonically increasing counter through
`AppStorage`:

```ts
// AppContext
notifyChanged(): void {
  this.revision++;
  AppStorage.setOrCreate(AppContext.REVISION_KEY, this.revision);
}

// Index
@StorageLink('dataRevision') @Watch('onDataChanged') dataRevision: number = 0;
```

`onDataChanged()` re-applies the preferences and calls `syncFromStore()`, which
re-reads the server list and decides whether a reconnect is needed: a different
`activeServerId` means the list on screen belongs to the previous server.

Who broadcasts: `saveServer`, `removeServer` and `selectServer`; the settings
screen after persisting; and the detail screen after a mutation, since the list
behind it shows the same torrent.

Two related behaviours fall out of this:

- **No server yet** — start-up opens the editor directly instead of showing a
  list the user cannot act on. Returning without saving shows a "no servers"
  state with an *Add server* button rather than re-opening the editor, so the
  user is never trapped in it.
- **Tap outside the drawer** — while the drawer is open the list sits under a
  transparent, hit-test-blocking layer, so tapping the region to its left closes
  it without triggering whatever is underneath.

## Refresh cadence

Two periods exist. The one the user configured in *Options* governs an idle
list, and `0` there means "manual only". While at least one torrent is
downloading, verifying or queued, a 2-second period takes over regardless —
otherwise a recheck's percentage would never move.

`isTorrentBusy()` in `model/AppModels.ets` decides which applies, and both the
list and the detail screen re-plan their timer after every load, so the cadence
follows the session's state without the user having to think about it.

Three details are worth knowing:

- **The detail screen refreshes too.** It used to load once in `aboutToAppear`
  and never again, so status, downloaded totals and rates stayed at whatever they
  were when the screen opened.
- **The periodic refresh does not rewrite the Options form.** `reload(false)`
  updates the rendered torrent and the Files/Trackers rows but leaves the input
  fields alone; rewriting a half-typed speed limit every two seconds would make
  the tab unusable. The fields are re-seeded when the screen opens, when the user
  retries, and after a change has been applied.
- **The list stops polling while a screen is pushed.** `Index` checks
  `pathStack.size()` before each tick, so the detail screen's refresh is not
  duplicated by the list underneath it.

A popped detail screen also guards against scheduling a timer from a reload that
was already in flight when the user navigated away.

## A trap worth knowing: `@Builder` arguments are passed by value

ArkUI passes a `@Builder`'s arguments **by value**, and a state change does not
refresh UI built from such an argument. A screen that renders its fields through
a parameterised builder therefore draws them once — at whatever values they held
at that moment — and then freezes.

That is exactly what happened to the torrent detail screen. It loaded
asynchronously, so the first build ran while the torrent was still `undefined`
and every field held its default; the reload that followed changed the data but
not the rendered rows:

```ts
// Rendered once, then never updated.
@Builder
fieldRow(label: Resource, value: string): void { … }

this.fieldRow($r('app.string.detail_field_downloaded'), formatBytes(this.currentTorrent().downloadedEver))
```

The list screen never had the problem because it hands its row to a **component**
(`TorrentRowView({ row })`), and `@Prop` is a live one-way sync.

| Builder called with | Refreshes? |
|:--|:--|
| no arguments, reading state directly | yes |
| constants | yes |
| a `ForEach` item | yes — the item is rebuilt when its key changes |
| a callback (`() => …`) | yes |
| **an argument derived from state** | **no** |

So the definition rows are `DetailFieldRow`, a component whose `label`, `value`
and `danger` are `@Prop`s; `statusCaption()` and `errorBanner()` take no arguments
and read state directly. The `builder-value-param` lint rule enforces this, and
deliberately stays quiet about constants, `ForEach` items and callbacks.

## Adding torrents

Both input methods land on the same screen, which is pre-selected by the caller:

- **Link** — magnet URI or a `.torrent` URL, sent as `filename`.
- **File** — `DocumentViewPicker` restricted to `.torrent`, read with `fileIo`,
  then base64-encoded by `TorrentAddRequest.fromBytes`. Binary file contents
  must not be treated as text, which is why the picker result is read into an
  `ArrayBuffer` and wrapped in a `Uint8Array`.

`viewmodel/AddTorrentHelper.ets` owns that three-API sequence so the floating
button and the add screen cannot drift apart.

## Filtering and sorting

`viewmodel/TorrentListModel.ets` holds the raw `Torrent[]` **and** the rendered
rows, so changing a filter or a sort key never costs another round trip. Two
details worth knowing:

- Two "done" filters exist, matching the reference UI: *Downloaded* means every
  wanted byte is present (`isFinished`), *Completed* additionally requires that
  the torrent is no longer downloading.
- The sort section of the drawer folds: its heading row toggles twelve sort keys
  out of the way, and the direction control is a separate row inside it. The
  chevron shows which state the section is in rather than doubling as the
  direction toggle, which was ambiguous.
- A row's progress bar is coloured by what the torrent is doing, with a caption
  only while something is moving:

  | State | Bar | Caption |
  |:--|:--|:--|
  | Downloading | blue (`progress_fill`) | `下载数据 (42.10%)` |
  | Verifying | amber (`progress_fill_verify`) | `检查已存在的数据 (75.06%)` |
  | Finished | green (`progress_fill_done`) | none |
  | Error | red (`progress_fill_error`) | none |

  While verifying the bar follows `recheck_progress` rather than
  `percent_done` — completion does not move during a recheck, so showing it
  would leave the bar frozen.
- The row's third line is the **uploaded** total plus the share ratio, not the
  downloaded total: size and the progress bar already convey how much came down.
- `ForEach`'s key embeds everything the row renders (status, bar value, rates).
  A key of just the torrent id lets ArkUI reuse the component without
  re-rendering it, which freezes the progress bar and the caption at whatever
  they were first built with.
- Every sort breaks ties on `queue_position`, so a list full of paused torrents
  (all with identical progress) does not shuffle between two polls.

## Icons

Every icon is a HarmonyOS **system symbol**, drawn with `SymbolGlyph`:

```ts
SymbolGlyph($r('sys.symbol.play_fill'))
  .fontSize(18)
  .fontColor([$r('app.color.icon')])
```

That gives three things a text glyph cannot: the icon follows the system font
weight, it scales with the accessibility font size, and it renders identically
across device fonts.

### Why the names live in one file

All of them are declared in `theme/AppIcons.ets` and referenced by semantic name
(`AppIcons.PAUSE`, `AppIcons.DELETE`, …). A symbol that the installed SDK does
not ship is a **compile-time** resource error, and the exact symbol set changes
between SDK releases, so one file means one line to fix rather than a hunt
through seven screens.

The names were checked against the community HarmonyOS Symbol index (3844
names), which mirrors the system library. If DevEco reports `resource not found`
for one of them, replace that single constant — the semantic name on the left,
and every call site, stay unchanged.

`scripts/lint-arkts.mjs` enforces the concentration: a `sys.symbol.*` reference
anywhere outside `AppIcons.ets` is an error, as is a text glyph used as an icon.

Reference: <https://developer.huawei.com/consumer/cn/design/harmonyos-symbol/>

## Verifying UI changes

The app module cannot be compiled by the host harness — ArkUI `struct`s and
decorators are not TypeScript — so `scripts/lint-arkts.mjs` is the safety net.
For the app it checks, in addition to the ArkTS restrictions:

| Check | Catches |
|:--|:--|
| `resource-parity` | a colour or string added to one palette/locale but not the other |
| `unknown-resource` | `$r('app.color.typo')`, `$r('app.string.typo')`, `$r('app.media.typo')` |
| `unresolved-import` | `import … from './Missing'` |
| `unknown-sdk-export` | `import { Typo } from 'transmission_sdk'` |
| `attribute-name-collision` | a struct field named after a universal attribute |
| `duplicate-import` | the same binding imported twice |
| `text-icon` | a text glyph used as an icon instead of a system symbol |
| `symbol-concentration` | `sys.symbol.*` referenced outside `AppIcons.ets` |
| `push-path-returns-void` | a `.then()` attached to `pushPath` |
| `builder-value-param` | a `@Builder` called with a state-derived argument |
| `build-profile` | `compatibleSdkVersion > targetSdkVersion` (or `target > compile`) |

The `attribute-name-collision` rule deserves a note. Every `@Component struct`
inherits ArkUI's
universal attributes as methods, so a field called `tabIndex`, `padding`,
`width`, `onClick` or `opacity` shadows a base member and the compiler rejects
the file with a message that points at the *field*, not at the shadowing:

```
Property 'tabIndex' in type 'TorrentDetailPage' is not assignable to the same
property in base type 'CustomComponent'.
```

The state field on the detail screen is therefore named `currentTab`.

```bash
npm run lint        # all of the above, plus the ArkTS rules
npm test            # the above, plus type-checking and both unit-test suites
```

`npm test` also compiles and runs the ArkUI-free layers — `model/` and the list
filtering/sorting in `viewmodel/` — because `scripts/run-tests.mjs` copies them
into its build, aliases `transmission_sdk` onto the SDK sources and provides a
`$r` stub. That is where the filter predicates, every sort key, the tie-breaking
rule and the settings round-trips are covered.

Always build once in DevEco Studio after UI changes; none of the above can see
whether an ArkUI attribute name is correct.
