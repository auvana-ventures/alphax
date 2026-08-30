# AlphaX 1.0.0-rc.5 release preparation

Preparation date: 2026-08-30

This document records the frozen, coordinated AlphaX `1.0.0-rc.5` release
candidate. It is preparation evidence, not a publication record. No package is
published, no git tag is created, and no GitHub release is created by this task.

## 1. Source HEAD and feature-freeze evidence

Release preparation began from the approved frozen source HEAD:

```text
93cf03abe60da7bc695cb2001f37f71f1751a925
```

The final release-preparation commit and the post-push remote equality check
are recorded in the final history entry for this document and in
`tasks/54-alphax-1-0-rc-5-release-preparation.md`.

The freeze boundary is authoritative in
[`ALPHAX_1_0_FEATURE_FREEZE.md`](ALPHAX_1_0_FEATURE_FREEZE.md), with governing
evidence in the [rc.5 scope lock](ALPHAX_1_0_RC_5_SCOPE_LOCK.md),
[ADR-0011](decisions/0011-rc5-final-feature-candidate.md), and the
[bounded optionals review](ALPHAX_RC5_BOUNDED_OPTIONALS_REVIEW.md):

| Work | State |
| --- | --- |
| A — entry façades and package-role UX | `COMPLETE` |
| B — `alphax_http` compatibility seam | `COMPLETE` |
| C — first-class SSE | `COMPLETE` |
| D — first-class WebSocket | `COMPLETE` |
| E — direct typed REST generator | `COMPLETE` |
| F — OpenAPI template proof | `ACCEPTED` as a bounded proof |
| G — Protobuf ergonomics | `DOCUMENTATION SUFFICIENT` |
| H — ecosystem compatibility | `VALIDATED` with explicit classifications |

No feature, transport, protocol, package, or generator scope was added during
release preparation.

## 2. Publishable package set

All eight current workspace packages are selected as `PUBLISH_RC5`. The two
new rc.5 packages are included because they are part of the frozen package
family, have package-local READMEs/changelogs, and passed their package and
consumer validation. No workspace package is withheld.

| Package | Purpose | Version | Runtime dependencies | Development role | Archive | Readiness |
| --- | --- | --- | --- | --- | ---: | --- |
| `alphax` | Pure-Dart HTTP, policy, SSE, WebSocket, and typed-client contracts | `1.0.0-rc.5` | none | `lints`, `test` | 67 KB | `PUBLISH_RC5` |
| `alphax_test` | Deterministic fakes and conformance helpers | `1.0.0-rc.5` | `alphax`, `test` | `lints` | 12 KB | `PUBLISH_RC5` |
| `alphax_native` | Flutter/native transport and deployment façades | `1.0.0-rc.5` | `alphax`, Flutter SDK, `web_socket` | `alphax_test`, Flutter/test tooling, lints | 104 KB | `PUBLISH_RC5` |
| `alphax_web` | Browser Fetch/WebSocket deployment façade | `1.0.0-rc.5` | `alphax`, `http`, `web_socket` | lints, `test` | 17 KB | `PUBLISH_RC5` |
| `alphax_dio` | Dio 5.x adapter boundary | `1.0.0-rc.5` | `alphax`, `dio` | `alphax_test`, lints, `test` | 15 KB | `PUBLISH_RC5` |
| `alphax_transform` | Optional explicit one-shot JSON transform | `1.0.0-rc.5` | `alphax` | lints, `test` | 14 KB | `PUBLISH_RC5` |
| `alphax_http` | `package:http` `BaseClient` compatibility seam | `1.0.0-rc.5` | `alphax`, `http` | `alphax_test`, lints, `test` | 12 KB | `PUBLISH_RC5` |
| `alphax_generator` | Dev-time direct AlphaX typed REST source generator | `1.0.0-rc.5` | `alphax`, analyzer, build tooling, `source_gen`, `dart_style` | build_runner, source-gen test tooling, lints, test | 17 KB | `PUBLISH_RC5` |

`alphax_generator` is a tooling package. Its analyzer/source-generation
dependencies are required by the generator itself and are not inherited by an
ordinary generated application's runtime unless that application deliberately
uses the generator as a runtime dependency. No generator tooling dependency
was added to `alphax`, `alphax_native`, `alphax_web`, or another runtime
package.

## 3. Version preparation and reference classification

The coordinated version is `1.0.0-rc.5` for every selected package. Current
AlphaX constraints were updated consistently, including the native Android
Gradle plugin metadata and iOS/macOS CocoaPods metadata.

| Reference class | Disposition |
| --- | --- |
| `CURRENT_RELEASE` | Eight package manifest versions, internal `alphax`/`alphax_test` constraints, native platform metadata, current package/root pins, rc.5 changelog entries, and current release status were updated. |
| `HISTORICAL` | rc.4/rc.3 task records, release reports, ADR snapshots, architecture plans, old changelog entries, and historical audits remain unchanged. |
| `FIXTURE` | Local compile-tested fixtures and generated outputs retain their existing workspace/path setup; ignored lock/build state was not committed. |
| `EXTERNAL` | `examples/basic/pubspec.yaml` and `examples/waypoint/pubspec.yaml` remain hosted rc.4 consumers until rc.5 exists on pub.dev. They are not package-to-package release constraints. |

The rc.4 references in external examples are intentional: changing them before
publication would make normal hosted resolution fail. They are part of the
post-publication hosted-consumer plan, not current package metadata.

## 4. Dependency graph and publication order

The direct workspace graph is:

```text
alphax
├── no runtime AlphaX dependencies
alphax_test
└── alphax

alphax_native  ── alphax, Flutter SDK, web_socket
alphax_web     ── alphax, http, web_socket
alphax_dio     ── alphax, dio
alphax_transform ── alphax
alphax_http    ── alphax, http
alphax_generator ── alphax, analyzer/build/source-generation tooling
```

The exact topological publication order is:

1. `alphax`
2. `alphax_test`
3. `alphax_native`
4. `alphax_web`
5. `alphax_dio`
6. `alphax_transform`
7. `alphax_http`
8. `alphax_generator`

`alphax` must be visible first. `alphax_test` is next because it is the shared
development dependency of native, Dio, and `alphax_http`. The remaining
packages depend on the already published core and have no dependency edge on
one another that changes this order. External `http`, `dio`, Flutter, and
generator tooling packages are hosted dependencies.

## 5. Changelogs and release notes

Every selected package has a new `1.0.0-rc.5` changelog entry dated
2026-08-30. Entries describe only the package-owned changes since rc.4;
historical entries are retained.

The release-level position is:

> **FINAL FEATURE RC BEFORE ALPHAX 1.0.0**

rc.5 adds the simpler native/Web entry façades, the one-import deployment
experience, the optional `alphax_http` ecosystem seam, first-class SSE and
WebSocket contracts, direct typed REST generation, bounded OpenAPI proof and
Protobuf interoperability evidence, and validated Dio/Retrofit/
`package:http`/Chopper/GraphQL HTTP ecosystem paths. After rc.5, work is
stabilization only. No rc.6 feature cycle is promised.

The package changelogs assign those changes to their owning package. For
example, SSE/WebSocket contracts are recorded in `alphax`, platform façades in
the integration packages, compatibility behavior in `alphax_http`, and
generator behavior in `alphax_generator`; fixture-only F/G/H evidence is not
presented as a new runtime feature.

## 6. rc.4 to rc.5 migration

[`docs/MIGRATION.md`](MIGRATION.md) now contains the additive migration section:

```dart
// rc.4 explicit construction remains valid.
final oldClient = AlphaXClient(
  transport: await createAlphaXTransport(),
);

// rc.5 ordinary native setup.
final client = await createAlphaXClient();
```

It also documents the synchronous browser façade, optional `alphax_http`
wrapping, `package:alphax/sse.dart`, the separate WebSocket connector/session
contract, direct typed REST generation, and the unchanged Retrofit → Dio →
`AlphaXDioAdapter` → AlphaX path. No rc.4 constructor, explicit transport,
custom transport, or lifecycle ownership path is deprecated or removed.

## 7. Package-selection UX and current-facing documentation

The root README, usage guide, migration guide, and package READMEs now describe
deployment paths rather than presenting eight packages as eight required
products:

| User need | Recommended package/path |
| --- | --- |
| Native Flutter | `alphax_native`, one import and `await createAlphaXClient()` |
| Browser Web | `alphax_web`, one import and synchronous `createAlphaXClient()` |
| Pure Dart/custom transport | `alphax` and an explicit `AlphaXTransport` |
| Existing Dio/Retrofit | `alphax_dio` with the existing injected Dio path |
| Existing `package:http` consumer | optional `alphax_http` |
| Large buffered JSON | optional `alphax_transform` |
| Application tests | dev dependency `alphax_test` |
| New direct typed REST declarations | dev tooling `alphax_generator` |

Current-facing text accurately retains the platform truth: H1/H2/H3 are
provider/browser capabilities, preference may fall back, requirement fails
closed, actual protocol/fallback metadata is not guessed, and TLS/pinning,
proxy, retry, cache, cookie, resilience, file, and progress behavior remains
owned by the selected AlphaX/provider boundary.

OpenAPI is described as a bounded template proof, not a complete OpenAPI SDK
generator. Protobuf is described as caller-layer serialization, not gRPC.
GraphQL HTTP is an `alphax_http` compatibility path; GraphQL WebSocket is
caller-bridge proof only. gRPC is explicitly post-1.0.

## 8. Final public API freeze review

The final review checked only frozen-surface release risks:

- no accidental `src` exports or provider/tooling internals in public libraries;
- no export cycle or duplicate type identity in native/Web re-exports;
- dedicated `sse.dart` and `websocket.dart` boundaries remain intentional;
- public Dartdoc is present for the rc.5 symbols;
- native and Web factories remain consistently named `createAlphaXClient()`;
- the WebSocket connector remains separate from `AlphaXClient`;
- generated services borrow, rather than close, the supplied client; and
- no impossible capability, cancellation, timeout, redirect, or ownership
  promise was introduced by release preparation.

No `RELEASE_BLOCKING` finding was identified. Known capability gaps and
provider limitations remain `POST_1_0` or caller-owned behavior; none were
implemented here.

## 9. SSE final review

The accepted Task 50 surface remains the dedicated `package:alphax/sse.dart`
parser over an existing bounded `AlphaXResponse.stream`. The final checks
confirmed incremental strict UTF-8 decoding, BOM handling, LF/CRLF/CR parsing,
standard data/event/id/retry semantics, comments, blank-line dispatch,
deterministic EOF/error/cancellation behavior, and parser memory limits. The
parser does not reconnect, send `Last-Event-ID`, or impose a content-type gate;
reconnection remains caller-owned. Native Dart IO and browser Fetch response
stream fixtures remain the accepted validation evidence.

## 10. WebSocket final review

The accepted Task 51 contract remains a separate transport-neutral connector and
session lifecycle. It preserves ordered text/binary messages, negotiated
subprotocols, explicit close code/reason, cancellation, deterministic terminal
state, and provider capability truth. The Dart/native and browser providers do
not claim arbitrary browser headers, manual ping/pong, frame fragmentation,
network flush, or provider-independent queue limits. There is no automatic
reconnect, replay, or resend. Native local-server and Chrome validation remain
the accepted evidence.

## 11. Typed REST generator final review

`alphax_generator` emits direct `AlphaXClient`/`AlphaXRequest` code with no
Dio, Retrofit, Chopper, or `package:http` runtime path. Runtime annotations in
`alphax` are const metadata only; analyzer/source_gen/build_runner remain
tooling dependencies. Generated services borrow a caller-owned client, keep
serialization caller-owned, and preserve the existing AlphaX middleware,
request-options, TLS/proxy, protocol, cancellation, timeout, file, multipart,
and streaming boundaries. Native, Web, pure-Dart, json_serializable, and
Freezed consumers passed. Retrofit remains supported unchanged through
`alphax_dio`.

## 12. Bounded optional and ecosystem matrix

The matrix below preserves the exact terminal outcomes from
[`ALPHAX_RC5_BOUNDED_OPTIONALS_REVIEW.md`](ALPHAX_RC5_BOUNDED_OPTIONALS_REVIEW.md).

| Ecosystem | Classification | Integration path | Validated version | Limitation |
| --- | --- | --- | --- | --- |
| Direct AlphaX | `FIRST_CLASS` | `AlphaXClient` → selected `AlphaXTransport` | rc.5 source | Provider capabilities remain authoritative. |
| AlphaX typed REST generator | `FIRST_CLASS` | AlphaX annotations → `alphax_generator` → `AlphaXClient` | rc.5 source | Serialization is caller/model-owned. |
| Dio | `SUPPORTED_VIA_ADAPTER` | Dio → `AlphaXDioAdapter` → AlphaX | Dio 5.11.0 | Adapter boundary, not full Dio ownership. |
| Retrofit | `SUPPORTED_VIA_ADAPTER` | Retrofit → Dio → `AlphaXDioAdapter` → AlphaX | Retrofit 4.10.0; generator 10.2.9 | Generator-specific features remain caller-owned. |
| `package:http` | `SUPPORTED_VIA_ADAPTER` | injected `http.Client` → `AlphaXHttpClient` → AlphaX | http 1.6.0 | BaseClient cannot carry all AlphaX-only facts. |
| Chopper | `SUPPORTED_VIA_ADAPTER` | Chopper → injected `AlphaXHttpClient` | Chopper/generator 8.7.0 | Requires Chopper's normal injectable client. |
| GraphQL HTTP | `SUPPORTED_VIA_ADAPTER` | `HttpLink` → `AlphaXHttpClient` → AlphaX | graphql 5.2.4; gql_http_link 1.2.0 | GraphQL parsing/cache/errors remain GraphQL-owned. |
| GraphQL WebSocket/subscriptions | `PROOF_ONLY` | caller bridge → AlphaX WebSocket session | gql_websocket_link 2.1.0; channel 3.0.3 | No shipped GraphQL adapter. |
| OpenAPI direct template | `PROOF_ONLY` | official template → AlphaX declaration → `alphax_generator` | OpenAPI Generator 7.24.0 | Bounded GET/POST proof, not exhaustive support. |
| OpenAPI-generated Dio client | `SUPPORTED_VIA_ADAPTER` | generated Dio client → `AlphaXDioAdapter` | OpenAPI Generator 7.24.0 | Requires injectable Dio. |
| OpenAPI-generated `package:http` client | `SUPPORTED_VIA_ADAPTER` | generated client → `AlphaXHttpClient` | OpenAPI Generator 7.24.0 | Requires injectable `http.Client`. |
| `json_serializable` | `COMPATIBLE_CALLER_LAYER` | caller model hooks | 6.14.1 | AlphaX does not own model generation. |
| Freezed | `COMPATIBLE_CALLER_LAYER` | caller model hooks | 4.0.1 | AlphaX does not own model generation. |
| Protobuf | `COMPATIBLE_CALLER_LAYER` | generated bytes ↔ AlphaX byte bodies | protobuf 6.0.0; plugin 25.0.0 | Serialization only; no gRPC semantics. |
| SSE | `FIRST_CLASS` | AlphaX response stream → `AlphaXSseParser` | rc.5 source | Reconnect and `Last-Event-ID` are caller-owned. |
| WebSocket | `FIRST_CLASS` | AlphaX connector/session → maintained provider | rc.5 source | No auto-reconnect, GraphQL protocol, or frame API. |
| gRPC | `DEFERRED_POST_1_0` | no rc.5 integration | not applicable | Separate RPC/runtime boundary. |

F is terminally **accepted as a bounded proof**. G is terminally
**documentation sufficient**. H is terminally **validated**; no optional item
remains pending or in review.

## 13. Platform matrix

The matrix separates transport families and distinguishes accepted provider
boundaries from local validation availability.

| Platform | HTTP | SSE | WebSocket |
| --- | --- | --- | --- |
| Android | `FIRST_CLASS`: Cronet/HttpEngine selection through `alphax_native`; H1/H2/H3 and TLS/proxy facts remain provider-reported. Build gate passed. | `FIRST_CLASS` parser over AlphaX streams; native Dart IO and prior Web/native stream fixtures are evidence; Android-specific SSE server run was not added. | `FIRST_CLASS` connector contract through maintained `web_socket`; native local-server contract evidence accepted; no Cronet WebSocket claim. |
| iOS | `FIRST_CLASS`: URLSession path through `alphax_native`; build gate passed. | `FIRST_CLASS` parser over the existing response stream; provider-specific SSE behavior remains URLSession-owned. | `FIRST_CLASS` connector contract through maintained provider; no URLSession WebSocket implementation claim. |
| macOS | `FIRST_CLASS`: URLSession path through `alphax_native`; build gate passed. | `FIRST_CLASS` parser over the existing response stream; provider-specific behavior remains URLSession-owned. | `FIRST_CLASS` connector contract through maintained provider; no native frame/control claim. |
| Linux | `FIRST_CLASS` pure-Dart/Dart IO fallback path; local package tests run on macOS and Linux CI remains the OS gate. | Core parser is platform-neutral; no dedicated Linux server fixture in this prep. | Connector contract is platform-neutral; no Linux-specific provider run in this prep. |
| Windows | `FIRST_CLASS` pure-Dart/Dart IO fallback where the Dart toolchain is available; no Windows runner was available locally. | Core parser is platform-neutral; Windows execution remains CI/consumer validation. | Connector contract is platform-neutral; no Windows-specific provider run was available. |
| Web | `FIRST_CLASS` browser Fetch; CORS, TLS, proxy, redirects, credentials, and protocol behavior remain browser-owned. Chrome gate passed. | `FIRST_CLASS` parser over Fetch streams; browser CORS and streaming availability remain browser-owned. | `FIRST_CLASS` browser WebSocket connector; Chrome gate passed; arbitrary custom headers remain unsupported by browsers. |

The release build gates were run with a clean disposable Flutter consumer using
path overrides only for local rc.5 verification; those overrides are not part of
the packages or release manifests.

## 14. Security review

The final security audit confirmed:

- secure TLS defaults remain enabled; no trust-all or certificate bypass was
  added;
- pinning and unsupported proxy modes remain fail-closed;
- protocol requirements remain fail-closed and are not converted to preference;
- cross-origin redirect credential stripping, auth middleware, cookies, cache,
  and resilience boundaries remain unchanged;
- browser WebSocket header/auth limitations are documented and sensitive
  headers are never silently moved into query parameters;
- generator code does not log credentials, request/response bodies, or secrets;
- static annotation credentials are discouraged and dynamic sensitive headers
  remain application-owned; and
- no certificates, private keys, signing material, `DEVELOPMENT_TEAM`, local
  machine paths, temporary QUIC hints, or benchmark credentials are in the
  release package scope or dry-run archives.

The only absolute paths observed during the audit were ignored Flutter-generated
environment files in the disposable/reference example build state; they are not
tracked release files and are not present in package archives.

## 15. Dependency review

All eight manifests were audited after version preparation. The expected
runtime graph is limited to AlphaX core, Flutter/provider dependencies for
native/Web deployment, `http` for browser/compatibility paths, and `dio` for
the Dio adapter. OpenAPI, GraphQL, Chopper, Retrofit, Protobuf, and model
tooling are absent from runtime package manifests except where the tool package
itself necessarily declares its generator dependencies.

`dart pub outdated --json` completed for the workspace with 19 resolved package
records, zero discontinued packages, and zero retracted packages. No dependency
override was added to any published package manifest. Disposable consumer path
overrides were used only outside the repository for local rc.5 verification.

## 16. API and compatibility validation

The consolidated release validation passed the following:

- workspace dependency resolution with coordinated rc.5 packages;
- `dart format --set-exit-if-changed packages` and the changed Waypoint source;
- Dart/Flutter analysis for all eight packages;
- all eight package suites: `alphax` (95), `alphax_dio` (6),
  `alphax_generator` (4), `alphax_http` (24), `alphax_native` (61),
  `alphax_test` (10), `alphax_transform` (11), and `alphax_web` (10);
- typed REST native (9 tests), pure-Dart, and Web consumers, including Web
  JavaScript compilation;
- the official OpenAPI Generator 7.24.0 template proof and its two runtime
  tests;
- the Protobuf byte fixture and round-trip test;
- browser Chrome tests for the Web package (11 tests);
- the Waypoint consumer's analysis, 9 tests, Android profile/release builds,
  macOS debug build, and iOS simulator no-code-sign build;
- retained Task B/C/D/E/F/G/H compatibility evidence, including Dio,
  Retrofit, `package:http`, Chopper, GraphQL HTTP, GraphQL WebSocket caller
  bridge, generated OpenAPI Dio/http clients, SSE, WebSocket, and model hooks;
- `dart pub outdated --json`, secret/signing/path audits, archive inspection,
  and protected-worktree review; and
- `git diff --check` after the final release-preparation batch.

No performance experiment or benchmark was run. Linux and Windows native build
jobs were not available in this macOS environment; the repository CI Dart job
is the corresponding Linux package gate, and no Windows CI runner is configured
in this repository. This is recorded as an environment limitation, not a new
release blocker for this frozen metadata/documentation preparation.

## 17. Documentation and link validation

Updated current-facing material includes:

- root `README.md` and `docs/USAGE_AND_CUSTOMIZATION.md` deployment/package
  selection and rc.5 status;
- `docs/MIGRATION.md` rc.4-to-rc.5 additive migration;
- all eight package README/changelog files where package ownership or current
  release status required it;
- `docs/ALPHAX_1_0_FEATURE_FREEZE.md` release-preparation linkage; and
- this release-preparation report.

The repository-standard Markdownlint baseline exclusions (`MD013`, `MD033`,
`MD060`) pass for the changed documentation. The local relative Markdown target
check passes for the changed documentation and report. Dartdoc link validation
passes for all eight packages with zero errors; existing repository-style
cross-package/example warnings are retained as non-blocking baseline warnings
and are listed with the final command output in the task record.

## 18. Package dry-runs and archive inspection

Before committing, every selected package passed a dry-run with the expected
single dirty-worktree warning for its intentional `CHANGELOG.md`, `README.md`,
and `pubspec.yaml` edits. Archive sizes were:

| Package | Compressed archive | Pre-commit result |
| --- | ---: | --- |
| `alphax` | 67 KB | pass; expected dirty-worktree warning |
| `alphax_test` | 12 KB | pass; expected dirty-worktree warning |
| `alphax_native` | 104 KB | pass; expected dirty-worktree warning |
| `alphax_web` | 17 KB | pass; expected dirty-worktree warning |
| `alphax_dio` | 15 KB | pass; expected dirty-worktree warning |
| `alphax_transform` | 14 KB | pass; expected dirty-worktree warning |
| `alphax_http` | 12 KB | pass; expected dirty-worktree warning |
| `alphax_generator` | 17 KB | pass; expected dirty-worktree warning |

The final clean post-commit dry-run evidence is appended here after the
preparation commit. It must contain zero warnings for all eight packages. Each
archive is inspected for intended package metadata/source/examples/tests only;
no `.dart_tool`, build output, fixture output, benchmark data, local absolute
paths, logs, secrets, signing config, certificates, or private keys is allowed.

## 19. Hosted-consumer plan after publication

After explicit publication approval, remove local workspace/path overrides and
validate hosted resolution in this order:

1. native minimal consumer with `alphax_native` and one entry import;
2. browser Web consumer with `alphax_web` and one entry import;
3. pure-Dart/custom-transport consumer with `alphax`;
4. Dio adapter consumer;
5. Retrofit generated client through Dio;
6. `package:http` consumer through `alphax_http`;
7. Chopper through `AlphaXHttpClient`;
8. GraphQL HTTP through `AlphaXHttpClient`;
9. SSE parser consumer;
10. WebSocket native/browser connector consumers;
11. direct typed generator consumer with hosted `alphax_generator` and
    `build_runner` as dev tooling;
12. bounded OpenAPI proof, if distributed as repository tooling;
13. Protobuf caller-layer recipe;
14. optional `alphax_transform`; and
15. `alphax_test` development helpers.

Each hosted consumer must resolve the published versions from pub.dev without
path overrides. The external rc.4 examples can then be advanced to rc.5 in a
separate post-publication documentation/example update.

## 20. Known limitations and remaining blockers

No release blocker is known for the frozen rc.5 package candidate.

Recorded non-blocking limitations are:

- no package publication, tag, or GitHub release has occurred;
- iOS/macOS Flutter builds emit the existing warning that `alphax_native` does
  not yet support Flutter Swift Package Manager; CocoaPods builds pass;
- Linux/Windows native build execution was not available in this macOS
  environment and remains an OS/CI consumer gate;
- OpenAPI direct generation is proof-only and does not cover multipart/file
  template expansion;
- GraphQL WebSocket is caller-bridge proof only, not a shipped GraphQL adapter;
- Protobuf is serialization interoperability only; gRPC remains post-1.0; and
- provider/browser limitations for TLS, proxy, protocol, headers, buffering,
  ping/pong, reconnect, and frame control remain as documented by the frozen
  API reviews.

These limitations are not to be fixed in release preparation. Any useful
non-blocking improvement is `POST_1_0`.

## 21. Exact publication sequence and release boundary

Publication requires a separate maintainer approval. Once approved, publish the
eight packages in the topological order in Section 4, verify each hosted version
and dependency resolution before continuing, then run the hosted-consumer plan.
This task does not publish, tag, or create a release.

The release sequence is:

```text
1.0.0-rc.5 preparation
  → explicit publication approval
  → rc.5 publication
  → stabilization only
  → 1.0.0
```

Final release-preparation commit and remote equality are recorded below after
the commit/push step.

ALPHAX 1.0.0-RC.5 PREPARED FOR PUBLICATION
