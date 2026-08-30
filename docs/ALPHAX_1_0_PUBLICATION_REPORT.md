# AlphaX 1.0.0 Publication Report

Status: package publication and hosted-consumer verification complete.

## 1. Publication date and source

- Publication date: 2026-08-30 (UTC).
- Publication source commit: `77be267435c25ab5acf963426e7787b552a1d343`.
- The publication source is the accepted Task 57 stable-preparation source plus
  the Task 58 publication record. Package `lib/`, `test/`, and manifests were
  unchanged from the prepared stable source.
- Current repository HEAD after the separate current-example update is
  `efccb5b1a56f4f275589e41ad872614f9e83d5dc` and equals `origin/main`.

## 2. Published package set

All eight approved packages were accepted by pub.dev at `1.0.0`, in the
required sequential order:

1. `alphax`
2. `alphax_test`
3. `alphax_native`
4. `alphax_web`
5. `alphax_dio`
6. `alphax_transform`
7. `alphax_http`
8. `alphax_generator`

## 3. Hosted metadata, archives, and checksums

The hosted API reported version `1.0.0` for every package. Each downloaded
archive SHA-256 matched pub.dev's `archive_sha256` metadata. The byte sizes
below are the downloaded immutable archive sizes; the corresponding final
`dart pub publish --dry-run` display sizes were 67, 12, 104, 17, 15, 14, 12,
and 17 KB respectively.

| Package | Published UTC | Archive bytes | SHA-256 |
| --- | --- | ---: | --- |
| `alphax` | 17:44:47.781049 | 68,490 | `7a9b32f45a9cff0498146128a577a36209a924d4c4229f3abb7445c45e3f1d02` |
| `alphax_test` | 17:48:08.655497 | 13,007 | `be14a7da8bc78b1d3f2ab8d062374d9b9a8d354aa6e997a9c082348920e972ce` |
| `alphax_native` | 17:50:45.584219 | 106,272 | `39ef5743eb5f0af1fd045b7a78b674e691cc6f969549bca56dac8bd0d2cfa7c7` |
| `alphax_web` | 17:52:05.027365 | 18,067 | `2e8c4dd67d23311592b8f613f00eee08a3dc7f037044346bf2b2b95901fcdab3` |
| `alphax_dio` | 17:54:32.031853 | 16,313 | `fbd3585332cc96463794ac596e27ff82eaffc23884ccd70a725127d6d0db1cda` |
| `alphax_transform` | 17:56:58.625355 | 14,627 | `840481ef51fe35f8582e4113ac8e8b05cd8eb94f0c896de0d3808e042a178c2c` |
| `alphax_http` | 17:59:22.588803 | 12,599 | `df92cde75fd08e00159627a8da6206902c1d7ef25f73d7c8ef7ce69cf39a5958` |
| `alphax_generator` | 18:01:26.152006 | 17,785 | `fbac8e6974f3901f7099bcab4debfb090380cb27844d83e28c2521ac90e7e9fb` |

Archive inspection passed. No archive contained `.dart_tool`, build output,
benchmark data, disposable fixture output, local logs, `pubspec_overrides`,
local absolute paths, secrets, certificates, private keys, or signing
material.

## 4. Dependency resolution

The final manifest graph was published in the required order. Fresh-cache
hosted consumers resolved AlphaX stable packages from pub.dev without path
dependencies, dependency overrides, workspace resolution, or local mirrors.

The direct runtime graph remains bounded:

```text
alphax_test      -> alphax
alphax_native    -> alphax, Flutter, web_socket
alphax_web       -> alphax, http, web_socket
alphax_dio       -> alphax, dio
alphax_transform -> alphax
alphax_http      -> alphax, http
alphax_generator -> alphax plus analyzer/build/source-generation tooling
```

`alphax` remains pure Dart. Generator tooling dependencies are confined to
`alphax_generator`; generated application runtime validation used AlphaX
without Dio, `package:http`, or generator tooling.

## 5. Hosted consumers

All required stable hosted consumers passed.

| Consumer | Result | Evidence |
| --- | --- | --- |
| Native minimal | PASS | Hosted `alphax_native ^1.0.0`; one-import façade, `createAlphaXClient()`, request/close compile path; Flutter analysis, tests, and macOS debug build passed. |
| Web minimal | PASS | Hosted `alphax_web ^1.0.0`; Fetch façade and browser compile/test path passed. |
| Pure Dart/custom | PASS | Hosted `alphax ^1.0.0`; custom transport, direct request, annotations, SSE, and WebSocket imports passed. |
| Dio | PASS | Hosted `alphax`/`alphax_dio`; representative `Dio -> AlphaXDioAdapter -> AlphaX` fixture passed. |
| Retrofit | PASS | Hosted stable AlphaX/Dio with maintained Retrofit generation; GET/path/query/header, typed JSON POST, and HTTP error fixture passed. |
| `package:http` | PASS | Hosted `AlphaXHttpClient` generic injected-client fixture and local production fixture passed. |
| Chopper | PASS | Hosted Chopper generated service injected `AlphaXHttpClient`; representative requests and conversion passed. |
| GraphQL HTTP | PASS | Hosted GraphQL HTTP link used `AlphaXHttpClient`; query, variables, response, and GraphQL error-layer behavior passed. |
| SSE | PASS | Hosted native Dart IO stream and browser Fetch/parser consumers passed incremental/public-surface checks; no reconnect was added. |
| WebSocket native | PASS | Hosted native connector local fixture passed text, binary, ordering, subprotocol, close, cancellation, and failure coverage. |
| WebSocket browser | PASS | Hosted Chrome connector passed text, binary, negotiated subprotocol, and peer-close coverage. Browser boundaries remain authoritative. |
| Typed generator | PASS | Hosted pure Dart, native, and Web consumers resolved `alphax_generator`, ran build_runner, analyzed, tested, and verified direct AlphaX generation. |
| OpenAPI proof | PASS | Retained official template proof generated the checked-in AlphaX declaration against hosted stable packages; classification remains `PROOF_ONLY`. |
| Protobuf recipe | PASS | Hosted generated-message bytes round-tripped through AlphaX byte bodies; classification remains caller-layer serialization, not gRPC. |
| `alphax_transform` | PASS | Hosted stable one-shot transform consumer resolved and decoded JSON. |
| `alphax_test` | PASS | Hosted stable test helpers resolved in generator, Chopper, Retrofit, and dedicated consumer fixtures. |

## 6. Current example updates

After hosted validation, current example constraints were updated from rc.5 to
`^1.0.0`:

- `examples/basic/pubspec.yaml`
- `examples/waypoint/pubspec.yaml`
- `examples/waypoint/macos/Podfile.lock`

The separate example update commit is
`efccb5b1a56f4f275589e41ad872614f9e83d5dc` (`docs/examples: move AlphaX
consumers to 1.0.0`). `examples/basic` passed Flutter dependency resolution,
analysis, and tests. `examples/waypoint` passed dependency resolution,
analysis, tests, and a macOS debug build.

Historical rc.5 reports and fixtures were not rewritten.

## 7. Incidents and retries

- No package publication failed and no accepted immutable stable version was
  blindly republished.
- Several fresh hosted resolver checks needed bounded polling while pub.dev
  metadata/CDN propagation completed. All later checks resolved the published
  stable versions.
- A disposable native build initially used unsupported `--no-codesign`; the
  supported macOS debug build command passed. No package source changed.
- A disposable OpenAPI/Dio analysis initially scanned an in-project temporary
  cache; the cache was moved outside the fixture and the scoped analysis/test
  rerun passed.
- A disposable browser WebSocket abrupt-close variant was not used because its
  temporary fixture lacked the required handshake path. The required hosted
  browser text/binary/subprotocol/peer-close surface passed, and the accepted
  rc.5 provider evidence covers the broader abnormal-close behavior.

These were validation-environment issues, not package publication defects.

## 8. Stable limitations

- Protocol capabilities vary by provider; Dart IO remains an H1 scope.
- Browser TLS, CORS, proxy, origin, and protocol behavior remain browser-owned.
- Windows remains `WINDOWS_SUPPORTED_UNVERIFIED_IN_CURRENT_GATE`.
- Direct OpenAPI integration is a bounded `PROOF_ONLY`, not exhaustive OpenAPI
  SDK generation.
- GraphQL WebSocket/subscription integration remains a `PROOF_ONLY`
  caller-bridge result, not a GraphQL adapter.
- Protobuf is serialization interoperability; it does not imply gRPC.
- SSE and WebSocket do not automatically reconnect, replay, or back off.
- Provider-specific buffering, headers, ping/pong, frame, and message limits
  remain provider-dependent.

## 9. Final release state

All eight AlphaX `1.0.0` packages are published and hosted-consumer
verification is complete. The project is stable-release ready. The approved
stable tag and GitHub release are the remaining provenance operations for this
publication task.

Proposed tag: `v1.0.0`  
Proposed release: `AlphaX 1.0.0`

## 10. Tag and GitHub release state

At this report stage, no stable tag or GitHub release has been created. The tag
will point to the package publication source commit
`77be267435c25ab5acf963426e7787b552a1d343`; later report/example commits are
documentation/provenance updates only.

ALPHAX 1.0.0 PUBLISHED SUCCESSFULLY
