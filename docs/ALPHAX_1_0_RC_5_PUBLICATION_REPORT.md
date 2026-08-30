# AlphaX 1.0.0-rc.5 publication report

State: **ALPHAX 1.0.0-RC.5 PUBLISHED SUCCESSFULLY**

Publication date: **2026-08-30** (UTC)

AlphaX `1.0.0-rc.5` is the final feature RC before `1.0.0`. All eight
approved packages were published sequentially, and clean consumers resolved
them from pub.dev without path dependencies, dependency overrides, or workspace
resolution.

## 1. Source and freeze evidence

- Prepared package source: `d4595e5699070671c1d12bba6852a227335e2f2e`.
- Publication source: `53bc4f4b4989f30c3875dd4f94a4d1f02c6c38fa`, a
  documentation-only Task 55 reservation commit after the prepared source.
- `git diff d4595e5699070671c1d12bba6852a227335e2f2e -- packages` was empty
  before publication.
- All eight package manifests were `1.0.0-rc.5`, with coordinated internal
  AlphaX constraints.
- Feature-freeze governance remained intact. No feature, tag, GitHub release,
  benchmark, or stable `1.0.0` publication was performed.
- The final repository HEAD at hosted/example verification was
  `9cf20baca21e80770362d86af0b505a02a9284d2`; the report and task updates are
  documentation-only commits after that state.

## 2. Published package set

All eight packages were approved as `PUBLISH_RC5` and published in this exact
order:

| Order | Package | Version | Published (UTC) | Hosted archive | SHA-256 |
| ---: | --- | --- | --- | ---: | --- |
| 1 | `alphax` | `1.0.0-rc.5` | 13:10:40.756521Z | 68,799 bytes / 67 KB | `a5ad5293241c94e73e871cc5e7a73ffa6b428a5e09557c1c42b591aea7f7876a` |
| 2 | `alphax_test` | `1.0.0-rc.5` | 13:12:52.666235Z | 12,996 bytes / 12 KB | `dd90510d89612fa66773bd87512233ef9e9d28ee3ed49a1a7ca8538f68db5238` |
| 3 | `alphax_native` | `1.0.0-rc.5` | 13:15:13.701398Z | 106,602 bytes / 104 KB | `e398e45a0374ffc00273e108909b9df323e4ac154fc2a1898fb87475ce9ea794` |
| 4 | `alphax_web` | `1.0.0-rc.5` | 13:15:44.413496Z | 18,082 bytes / 17 KB | `9fc5d4c62055c68c580cf68e22c41937beabb401b06a7a3fb132067d40dddb42` |
| 5 | `alphax_dio` | `1.0.0-rc.5` | 13:18:15.394592Z | 16,322 bytes / 15 KB | `728d0d81cbd8de9a9844f26d5925116f8332eec4bf4a4bfe34828fe0b473ea0f` |
| 6 | `alphax_transform` | `1.0.0-rc.5` | 13:22:38.078005Z | 14,628 bytes / 14 KB | `02c4601923024c9c3e9327aaecd4e25e93532a9a9900c638db3dc2a6c1b48ad9` |
| 7 | `alphax_http` | `1.0.0-rc.5` | 13:27:07.822339Z | 12,606 bytes / 12 KB | `a5757a7406c141c8f186238ad71cd6d354861965d589e83f509948b248a8cdd5` |
| 8 | `alphax_generator` | `1.0.0-rc.5` | 13:27:38.515891Z | 17,787 bytes / 17 KB | `3d46ebc789145f0c434d8f3df6c56bbe56b773c0c2ee5fa306ee24c993bbb524` |

Each upload was followed by pub.dev metadata inspection, archive download and
checksum verification, and a fresh-cache hosted dependency-resolution check
before the next package was published.

## 3. Dependency graph and publication order

The hosted runtime graph is:

```text
alphax
├── alphax_test       → alphax, package:test
├── alphax_native     → alphax, Flutter SDK, web_socket
├── alphax_web        → alphax, http, web_socket
├── alphax_dio        → alphax, dio
├── alphax_transform  → alphax
└── alphax_http       → alphax, http

alphax_generator      → alphax plus analyzer/build/source-generation tooling
```

`alphax_generator` is a dev-time tooling dependency in generated consumers.
Analyzer, source_gen, build_runner, GraphQL, Chopper, Retrofit, OpenAPI, and
Protobuf fixture dependencies did not enter AlphaX runtime packages. The
mandatory publication order was used because it also makes every coordinated
AlphaX dependency available before its dependent package is checked.

## 4. Per-package hosted verification

- `alphax`: hosted archive includes core contracts, annotations, SSE, WebSocket,
  and typed REST support types; fresh hosted resolution selected rc.5.
- `alphax_test`: hosted rc.5 resolved its rc.5 `alphax` dependency.
- `alphax_native`: hosted façade, WebSocket connector, SSE re-export, and
  native provider metadata were inspected; a clean Flutter consumer selected
  hosted `alphax_native` and transitive hosted `alphax` rc.5.
- `alphax_web`: hosted Fetch façade and browser WebSocket connector were
  inspected; a clean Web consumer selected hosted rc.5 dependencies.
- `alphax_dio`: hosted dependency resolution selected rc.5 with Dio and
  transitive AlphaX rc.5.
- `alphax_transform`: hosted dependency resolution selected rc.5 with
  transitive AlphaX rc.5.
- `alphax_http`: hosted `AlphaXHttpClient` archive and `http` dependency were
  verified; no Chopper or GraphQL runtime dependency is present.
- `alphax_generator`: hosted tooling package resolved with AlphaX rc.5 and its
  analyzer/build/source-generation dependencies; generated application runtime
  tests used AlphaX only.

## 5. Clean hosted consumers

All consumers used fresh temporary package caches and hosted constraints. No
consumer used `path:`, `dependency_overrides`, or workspace package resolution.

| Consumer | Result |
| --- | --- |
| Native minimal Flutter | `alphax_native: ^1.0.0-rc.5` was the only direct AlphaX dependency; one deployment import, façade creation, GET, close, `flutter pub get`, analysis, tests, and macOS debug build passed. `alphax` resolved transitively. |
| Web minimal Flutter | `alphax_web: ^1.0.0-rc.5`; one deployment import, synchronous façade creation, request, close, `flutter pub get`, analysis, tests, and Web build passed. |
| Pure Dart/custom | Hosted `alphax`; custom `AlphaXTransport`, request, annotations, SSE import/parser, WebSocket contract import/message, and close passed analysis, test, and execution. |
| Dio | Hosted `alphax` + `alphax_dio` + Dio; `AlphaXDioAdapter` request/response mapping passed. |
| Retrofit | Hosted Retrofit `4.10.0` and `retrofit_generator 10.2.9` generated a client through `Dio → AlphaXDioAdapter → AlphaX`; GET/path/query/header, typed JSON, POST body, and HTTP error behavior passed. |
| `package:http` | Hosted `AlphaXHttpClient` was accepted by a generic `http.Client` consumer; request mapping and borrowed-client close behavior passed. |
| Chopper | Hosted Chopper `8.7.0` generated service used its injected `AlphaXHttpClient`; GET/path/query, POST JSON, typed converter, interceptors, and error response passed. |
| GraphQL HTTP | Hosted `graphql 5.2.4`/`gql_http_link 1.2.0` `HttpLink` used the injected bridge; query/response and HTTP error behavior passed. |
| SSE | Hosted `package:alphax/sse.dart` parsed byte-by-byte UTF-8, CRLF, multiline data, ID, empty ID, retry, and rejected malformed UTF-8. No reconnect was present. |
| Native WebSocket | Hosted native connector passed the local deterministic server fixture for text, binary, ordering, subprotocol, close, cancellation, timeout, errors, and paused receive stream. |
| Browser WebSocket | Hosted browser connector passed Chrome tests against the local fixture for text, binary, subprotocol, peer close, and abnormal close. |
| Direct typed generator, pure Dart | Hosted `alphax_generator` resolved from pub.dev; build_runner generated source, analysis, runtime test, and forbidden-runtime audit passed. |
| Direct typed generator, native | Hosted native runtime plus hosted generator/build_runner and model tooling generated and tested the local native fixture. |
| Direct typed generator, Web | Hosted Web runtime plus hosted generator/build_runner generated, analyzed, tested, and compiled to JavaScript. |
| OpenAPI proof | Official OpenAPI Generator 7.24.0 template overlay regenerated the bounded declaration; the hosted AlphaX/native/generator consumer built and executed the documented GET/POST proof. |
| Protobuf recipe | Hosted `alphax` plus maintained `protobuf 6.0.0` fixture passed `GeneratedMessage → writeToBuffer → AlphaXBody.bytes` and response-byte decoding. This does not imply gRPC. |
| `alphax_transform` | Hosted one-shot transform consumer resolved and passed a native JSON transform. |
| `alphax_test` | Hosted as a development dependency in adapter and fixture consumers; fake transport tests passed. |

## 6. External example updates

After hosted validation, the current-facing examples were advanced from rc.4 to
rc.5:

- `examples/basic`: hosted `alphax`/`alphax_native`, analysis, tests, and debug
  bundle build passed. A redundant core import was removed because the native
  deployment entry point re-exports the public core API.
- `examples/waypoint`: hosted `alphax`, `alphax_dio`, `alphax_native`, and
  `alphax_test`; analysis, nine tests, and macOS debug build passed.
- Separate commit: `9cf20baca21e80770362d86af0b505a02a9284d2`
  (`docs/examples: move AlphaX consumers to rc.5`).

## 7. Package archive and security audit

The eight downloaded pub.dev archives matched their API-reported SHA-256
values. Archive inspection found no `.dart_tool`, build output, disposable
fixture output, benchmark data, local absolute paths, secrets, certificates,
private keys, signing material, `DEVELOPMENT_TEAM`, or `pubspec_overrides`.

The immediate release audit reconfirmed secure TLS defaults, fail-closed
pinning/proxy/protocol requirements, redirect credential protection, middleware
authentication/cookie/cache boundaries, browser WebSocket header limitations,
and the absence of credential/body logging in generated code. No provider-native
exception was promoted as the public compatibility contract.

## 8. Platform and capability limitations

- Android HTTP remains provider-dependent H1/H2/H3 through the existing native
  boundary; iOS/macOS HTTP remains URLSession/provider-dependent; Linux and
  Windows use the truthful Dart IO H1 fallback.
- Browser Fetch and browser WebSocket behavior remains browser-owned for CORS,
  TLS, cookies, origin, CSP, protocol observation, and arbitrary headers.
- WebSocket has no automatic reconnect, replay, or universal manual ping/pong.
- SSE exposes incremental parsing, IDs, and retry hints; reconnection and
  `Last-Event-ID` remain caller-owned.
- The OpenAPI result is a bounded template proof, not exhaustive OpenAPI SDK
  support. Multipart/file template expansion remains deferred.
- Protobuf is caller-owned serialization only; gRPC remains post-1.0.
- GraphQL HTTP is adapter-supported through `alphax_http`; no GraphQL client is
  included. GraphQL WebSocket/subscriptions remain a caller-owned proof path,
  with a reusable framework adapter deferred post-1.0.
- The macOS example build emitted the existing non-blocking Swift Package
  Manager support warning for `alphax_native`; CocoaPods succeeded. Linux and
  Windows native builds were not available in this macOS environment and remain
  CI/OS gates rather than publication blockers.

## 9. Incidents and retries

The first `alphax` publish command did not display an immediate success result
while pub.dev propagation was still in progress. A later diagnostic invocation
was rejected with the immutable-version message that `1.0.0-rc.5` already
existed; the archive, metadata, and fresh hosted resolution then confirmed the
original upload. No duplicate version was created, and dependent publication
did not proceed until hosted verification succeeded. Other packages experienced
normal pub.dev/CDN propagation delay and were verified with fresh caches.

No package failed publication, no package was skipped, and no unsafe retry or
version mutation was attempted after acceptance.

## 10. Documentation and governance

Current-facing release status and package-selection text was updated in the root
README, user guide, feature-freeze document, and package READMEs. Historical
rc.4/rc.5 preparation reports and task records were not rewritten. The
publication report is the authoritative hosted-release record.

The proposed Git information is recorded only for later maintainer action:

```text
tag: v1.0.0-rc.5
release title: AlphaX 1.0.0-rc.5
```

Neither a tag nor a GitHub release was created in this task.

## 11. Validation

Completed release-oriented checks:

- all eight per-package `dart pub publish --dry-run` checks before publication,
  each with zero warnings;
- pub.dev metadata, hosted archives, SHA-256 checksums, dependency constraints,
  and archive security/path inspection for all eight packages;
- clean hosted native, Web, pure-Dart, Dio, Retrofit, `package:http`, Chopper,
  GraphQL HTTP, SSE, native WebSocket, browser WebSocket, typed generator,
  OpenAPI, Protobuf, transform, and test consumers;
- `dart pub get`/`flutter pub get`, analysis, tests, build_runner generation,
  JavaScript compilation, native macOS debug build, and Web Chrome tests in the
  disposable hosted consumers;
- hosted `examples/basic` analysis/tests/bundle build and hosted `examples/waypoint`
  analysis/tests/macOS debug build;
- final manifest/dependency comparison against the prepared source, security,
  signing, secret, path, and protected-worktree audits; and
- `git diff --check` for owned publication/example/documentation changes.

Task 54's complete rc.5 validation suite remains the source evidence for the
full pre-publication platform/package matrix; it was not needlessly repeated
after publication because package source and manifests were unchanged.

## 12. Next phase

The project is now **STABILIZATION ONLY**. Permitted work is limited to
correctness, security, frozen API consistency, compatibility regressions,
platform conformance, documentation/migration, packaging, and release fixes.

The exact next task is `ALPHAX 1.0 STABILIZATION AND RELEASE GATE`.

No rc.6 feature scope, gRPC, expanded OpenAPI, GraphQL adapter, SSE reconnect,
WebSocket reconnect, performance work, stable publication, or GitHub release
was started here.

ALPHAX 1.0.0-RC.5 PUBLISHED SUCCESSFULLY
