# Protocol compatibility

This document records exactly how the SDK supports both Transmission RPC dialects, where the rules
come from, and what a caller can rely on.

## The two dialects

Transmission 4.1.0 (`rpc-version-semver` **6.0.0**) introduced JSON-RPC 2.0 and converted every RPC
string to `snake_case`. The original bespoke protocol and its mix of `kebab-case` and `camelCase`
strings are still accepted by 4.1.x, but are deprecated and slated for removal.

| | Modern (≥ 4.1.0) | Legacy (< 4.1.0) |
|:--|:--|:--|
| Envelope (request) | `{"jsonrpc":"2.0","method":"session_get","params":{…},"id":7}` | `{"method":"session-get","arguments":{…},"tag":7}` |
| Envelope (success) | `{"jsonrpc":"2.0","result":{…},"id":7}` | `{"arguments":{…},"result":"success","tag":7}` |
| Envelope (failure) | `{"jsonrpc":"2.0","error":{"code":8,"message":"…","data":{…}},"id":7}` | `{"arguments":{…},"result":"HTTP error from backend service","tag":7}` |
| Method names | `torrent_get` | `torrent-get` |
| Field names | `percent_done` | `percentDone` |
| Version reported | `rpc_version_semver` (`"6.0.0"`) | `rpc_version` (`17`) |
| 409 advertises its version | yes, `X-Transmission-Rpc-Version` | no such header |

Two details of the server implementation shape the client design:

1. **The response dialect mirrors the request dialect.** A 4.1.x server inspects the inbound request:
   if it carries `jsonrpc: "2.0"` the reply is JSON-RPC; otherwise the reply is converted to the
   legacy shape. So a client never has to guess how to parse a response.
2. **A pre-4.1.0 server has no notion of `jsonrpc` at all.** It simply fails to find the method and
   answers in its own legacy envelope. That failure is the signal the SDK uses to downgrade.

### Two downgrade signals, and why the shape wins

A modern request that comes back in a legacy envelope can only mean one thing: the server predates
JSON-RPC support. `RpcOutcome.legacyEnvelope` records that, and it is the primary signal.

The error *text* is only the fallback, because it is not stable across releases. Transmission 4.0.x
distinguishes two cases in `rpcimpl.cc`:

| Situation | `result` string |
|:--|:--|
| the request carried no `method` field | `no method name` |
| the method is unknown | `method name not recognized` |

Transmission 4.1.0's compatibility layer, however, only ever emits `no method name` when it
translates a JSON-RPC `METHOD_NOT_FOUND`. An SDK that matched on the 4.1.0 wording alone classified a
4.0.x reply as `UNKNOWN`, so `METHOD_NOT_FOUND` never matched, the retry never happened, and the raw
`{"arguments":{},"result":"method name not recognized"}` surfaced as an error. Both phrases are now
recognised, and the envelope shape makes the downgrade work even for a wording nobody has seen yet.

## Negotiation algorithm

`StyleNegotiator` implements this, and `RpcClient` drives it:

```
mode = AUTO (default) | MODERN | LEGACY

start in MODERN unless mode == LEGACY

on HTTP 409:
    if mode != AUTO: record the version, keep the dialect
    else if X-Transmission-Rpc-Version present:
        parse it; >= 6.0.0 -> MODERN, otherwise -> LEGACY
    else:
        LEGACY            // the header only exists from rpc-version-semver 6.0.0

on a dialect mismatch while mode == AUTO and dialect == MODERN:
    switch to LEGACY and retry the request once

on any successful session_get:
    prefer rpc_version_semver, fall back to the integer rpc_version,
    translate it through the table in util/Semver.ets,
    and align the dialect with it (AUTO only)
```

Retries are bounded: at most `MAX_ATTEMPTS = 4` HTTP attempts per logical call, at most two CSRF
refreshes, and at most one dialect downgrade. A server that keeps returning 409 ends in a `PROTOCOL`
error instead of a loop.

### Integer → semver table

`rpc_version` was a monotonically increasing counter; it maps to semver as follows (section 5 of the
RPC spec). `RpcVersions.fromInteger()` encodes the whole table.

| `rpc_version` | semver | Transmission |
|--:|:--|:--|
| 1 | 1.0.0 | 1.30 |
| 5 | 2.0.0 | 1.60 |
| 7 | 3.0.0 | 1.80 |
| 13 | 4.0.0 | 2.30 |
| 14 | 5.0.0 | 2.40 |
| 16 | 5.2.0 | 3.00 |
| 17 | 5.3.0 | 4.0.0 |
| 18 | 6.0.0 | 4.1.0 — JSON-RPC arrives |

`RpcVersions.supportsJsonRpc(version)` is the single predicate for "this server speaks snake_case".

## Key conversion rules

`compat/KeyConversion.ets` ports `convert_key()`, `convert_string()` and `convert_keys()` from
`libtransmission/api-compat.cc`. The table in `compat/LegacyKeys.ets` is generated from that same
file, so the mechanical cases cannot drift. Five rules are *not* mechanical and get explicit tests:

### 1. `download_dir` is context dependent

```
canonical            download_dir
torrent_get/set      downloadDir      (camelCase!)
session_get/set      download-dir     (kebab-case)
everything else      download-dir
```

The same applies inside a `fields` array: asking a legacy `torrent-get` for `download_dir` means
sending `["downloadDir"]`.

### 2. `free_space.total_size` keeps its underscore

The legacy `free-space` response reports `total_size`, not `totalSize`, even though `torrent-get`
uses `totalSize` for the same concept. A legacy free-space response is recognised by having both
`path` and `size-bytes`.

### 3. Strings inside key-valued arrays are keys

`{"fields": ["percent_done"]}` and `{"ids": […]}`, `{"method": …}`, `{"torrents": …}` carry strings
that are themselves RPC keys, so they are translated with the same context as object keys. Hash
strings in `ids` never match a known key, so the translation is a no-op for them.

### 4. `wanted` changes type

`torrent_get`'s `wanted` array is `true`/`false` in the modern dialect and `1`/`0` in the legacy
dialect. The converter normalises both directions, and `Torrent.wanted` is always `boolean[]`.

### 5. `encryption` changes spelling

`EncryptionMode.ALLOWED` (`"allowed"`) is `"tolerated"` in the legacy dialect. Unknown values pass
through untouched so a future server can introduce a new mode without breaking this SDK.

## Error-code normalisation

The modern dialect reports a numeric code. The SDK maps it onto `RpcErrorCode`, which contains both
the JSON-RPC reserved range and Transmission's own codes:

| Code | Meaning |
|--:|:--|
| `-32700` | Parse error |
| `-32600` | Invalid Request |
| `-32601` | Method not found |
| `-32602` | Invalid params |
| `-32603` | Internal error |
| `0` | success |
| `1` | error setting announce list |
| `2` | invalid tracker list |
| `3` | path is not absolute |
| `4` | unrecognized info |
| `5` | system error |
| `6` | file index out of range |
| `7` | piece index out of range |
| `8` | HTTP error from backend service |
| `9` | invalid or corrupt torrent file |
| `10` | couldn't parse any valid blocklist rules |
| `1000` | `UNKNOWN` — a code this SDK does not recognise; the raw value is kept |

The legacy dialect reports no code at all, only a message. `rpcErrorCodeFromMessage()` reproduces
Transmission's own `guess_error_code()` substring table, for example:

- `"no method name"` (4.1.0's compatibility layer) → `METHOD_NOT_FOUND`
- `"method name not recognized"` (4.0.x) → `METHOD_NOT_FOUND`
- `"Couldn't test port: No Response (0)"` → `HTTP_ERROR`
- `"invalid or corrupt torrent file"` → `CORRUPT_TORRENT`
- `"path is not absolute"` → `PATH_NOT_ABSOLUTE`

An unrecognised message becomes `UNKNOWN` with the original text preserved in `TransmissionError.detail`
and `message`.

## Version-dependent behaviour

Some fields and methods only exist from a given RPC version. The SDK does not hide that, because
guessing would be worse than failing; instead:

- `SessionSettings.rpcVersion` / `.supportsJsonRpc` expose the negotiated version.
- `TransmissionError.unsupported(feature, requiredVersion, actualVersion)` builds a consistent error
  for callers that want to gate a feature.
- Fields added after 4.1.0 are simply absent from older responses, and the corresponding model
  properties keep their documented defaults.

Notable version boundaries worth knowing when targeting old daemons:

| Feature | Introduced |
|:--|:--|
| `torrent_remove` | RPC 1.2.0 (1.41) |
| `session_stats` cumulative/current stats | 1.3.0 (1.50) |
| Labels | Transmission 3.00 |
| `sequential_download` | Transmission 3.00 |
| `group_get` / `group_set` (bandwidth groups) | Transmission 3.00 |
| `tracker_list` on `torrent_set` | Transmission 4.0.0 |
| `ip_protocol` on `port_test` | 6.0.0 (4.1.0) |
| `preferred_transports` replacing `utp_enabled` / `tcp_enabled` | 6.0.0 (4.1.0) |
| `webseeds_ex` replacing `webseeds` | 6.0.0 (4.1.0) |
| `sequential_download_from_piece` | 6.0.0+ |

## What is intentionally not supported

- **`format: "table"` for a legacy `free_space` / non-torrent payload.** Table mode is a `torrent_get`
  feature; `TorrentTable.parse` reports `isTable === false` for anything else.
- **Transport-level (UDP) RPC.** Only the documented HTTP endpoint is implemented.
- **Notifications.** The SDK always sends an `id`, so the server always replies. Fire-and-forget
  notifications would give up error reporting for no practical gain here.
- **The legacy HTTP `?` query form.** Only `POST` with a JSON body is used.

## Keeping the tables honest

The three generated files are produced by scripts that read the Transmission sources directly:

```bash
node scripts/generate-legacy-keys.mjs
node scripts/generate-rpc-fields.mjs
node scripts/generate-session-set-request.mjs
```

They default to `../transmission-ref`; pass another checkout path as the first argument. Tests assert
the generated sizes (`212` key pairs, `231` field names, ≥ 40 session setters) and the irregular
entries, so a bad regeneration fails the suite rather than shipping.
