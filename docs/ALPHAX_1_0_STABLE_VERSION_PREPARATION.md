# AlphaX 1.0.0 Stable Version Preparation

State: `ALPHAX 1.0.0 PREPARED FOR PUBLICATION`

Date: 2026-08-30

This document records the release-preparation state for the frozen AlphaX 1.0
package family. It does not publish packages, create a tag, create a GitHub
release, add features, or change runtime behavior.

## 1. Preparation source HEAD

The frozen stabilization baseline was:

`b9cb39ed375f642d4a272b5f547ad90847a917a7`

The coordinated stable metadata batch was committed as:

`9ca4b31c0b97ff6043b228f8d00188bfb11e0bcf` (`chore: prepare AlphaX 1.0.0`)

The final evidence/report commit is the Task 57 commit containing this report
and its completed task record. The final pushed HEAD is reported with the task
completion evidence and must equal `origin/main`.

## 2. Frozen rc.5 baseline

The published `1.0.0-rc.5` candidate, the accepted feature freeze, and the
completed stabilization gate are unchanged. Stable preparation is limited to:

- package versions and coordinated internal constraints;
- stable package metadata and changelogs;
- current-facing documentation, migration wording, and release notes; and
- release validation and publication planning.

No package `lib/` or `test/` source changed from the stabilization baseline.

## 3. Package publication set

All eight approved packages are classified `PUBLISH_1_0`.

<!-- markdownlint-disable MD013 -->

| Package | Purpose | Role | Stable status |
| --- | --- | --- | --- |
| `alphax` | Pure-Dart core contracts, policies, SSE, WebSocket, and typed REST support | Runtime | `PUBLISH_1_0` |
| `alphax_test` | Public test fakes and conformance helpers | Dev/test | `PUBLISH_1_0` |
| `alphax_native` | Flutter native entry façade and native providers | Runtime | `PUBLISH_1_0` |
| `alphax_web` | Browser Fetch/WebSocket entry façade | Runtime | `PUBLISH_1_0` |
| `alphax_dio` | Dio compatibility adapter | Runtime | `PUBLISH_1_0` |
| `alphax_transform` | Optional one-shot transform helpers | Runtime | `PUBLISH_1_0` |
| `alphax_http` | `package:http` compatibility boundary | Runtime | `PUBLISH_1_0` |
| `alphax_generator` | Direct AlphaX typed REST source generation | Dev tooling | `PUBLISH_1_0` |

<!-- markdownlint-enable MD013 -->

No package is withheld.

## 4. Package versions and dependency constraints

Every package manifest is `1.0.0`. Internal AlphaX constraints use the stable
family (`^1.0.0`) where applicable; no stable package depends on an AlphaX
`rc.5` constraint.

The runtime dependency graph remains:

```text
alphax_test      -> alphax
alphax_native    -> alphax (+ Flutter, web_socket)
alphax_web       -> alphax (+ http, web_socket)
alphax_dio       -> alphax (+ dio)
alphax_transform -> alphax
alphax_http      -> alphax (+ http)
alphax_generator -> alphax (+ analyzer/build/build_config/dart_style/source_gen)
```

`alphax` remains dependency-free at runtime. Generator analysis/source
generation dependencies remain tooling dependencies of `alphax_generator`; an
ordinary generated application does not inherit them as runtime dependencies.

## 5. rc.5 to stable API comparison

The public Dart API is unchanged from the published rc.5 candidate. The
comparison of `packages/*/lib` and `packages/*/test` against the stabilization
baseline is empty. Stable preparation changes are metadata, documentation,
changelog, and version-constraint changes only.

The stable migration is therefore version-only. No public rename, removal,
signature change, or semantic change was introduced.

## 6. Source and behavior comparison

The package runtime implementation, tests, transport providers, adapters,
facades, SSE parser, WebSocket contract, and generator implementation are
unchanged from rc.5 stabilization. The stable commit contains no runtime
implementation changes.

## 7. Migration

`docs/MIGRATION.md` now states:

```yaml
# update the existing AlphaX package constraints
1.0.0-rc.5 -> 1.0.0
```

Users already on rc.5 need only update package constraints to `1.0.0`. No API
or source migration is required. The historical rc.4 to rc.5 migration remains
unchanged.

## 8. Changelogs

All eight publishable package changelogs contain a concise dated `1.0.0` entry
describing the first stable release and package-owned capability. Complete rc.5
history remains below each new entry; historical release references were not
rewritten.

## 9. Stable release notes

`docs/ALPHAX_1_0_RELEASE_NOTES.md` is the user-oriented stable release-note
draft. It covers the core, native/Web setup, protocol visibility, security and
policy, streaming/files, SSE, WebSocket, ecosystem compatibility, typed REST,
testing/transforms, supported platforms, known boundaries, and rc.5 migration.

The notes do not advertise OpenAPI proof as a complete SDK generator, do not
equate Protobuf with gRPC, and do not promise automatic SSE or WebSocket
reconnect.

## 10. Platform matrix

<!-- markdownlint-disable MD013 -->

| Platform | HTTP | SSE | WebSocket | Stable claim |
| --- | --- | --- | --- | --- |
| Android | Cronet/HttpEngine; provider-dependent H1/H2/H3 and fallback truth | Native response stream | Maintained native/Dart connector path | Validated rc.5 behavior retained |
| iOS | URLSession; provider-dependent H1/H2/H3 and fallback truth | Native response stream | Maintained provider boundary | Validated rc.5 behavior retained |
| macOS | URLSession; provider-dependent H1/H2/H3 and fallback truth | Native response stream | Maintained provider boundary | Validated rc.5 behavior retained |
| Linux | Dart IO HTTP H1 scope | Dart stream where supported | Maintained provider where supported | No H2/H3 claim |
| Windows | Dart-compatible package behavior | Dart stream where supported | Maintained provider where supported | `WINDOWS_SUPPORTED_UNVERIFIED_IN_CURRENT_GATE` |
| Web | Browser Fetch; browser-owned TLS/CORS/proxy/origin/protocol | Fetch stream; browser CORS applies | Browser WebSocket | Browser authority boundaries apply |

<!-- markdownlint-enable MD013 -->

## 11. Ecosystem matrix

<!-- markdownlint-disable MD013 -->

| Ecosystem/capability | Classification | Integration path or boundary |
| --- | --- | --- |
| Direct AlphaX | `FIRST_CLASS` | `AlphaXClient` and transport/provider contracts |
| Typed REST generator | `FIRST_CLASS` | `alphax_generator` generates direct `AlphaXClient` calls |
| Dio | `SUPPORTED_VIA_ADAPTER` | Dio -> `AlphaXDioAdapter` -> AlphaX |
| Retrofit | `SUPPORTED_VIA_ADAPTER` | Retrofit -> Dio -> `AlphaXDioAdapter` -> AlphaX |
| `package:http` | `SUPPORTED_VIA_ADAPTER` | `AlphaXHttpClient` -> AlphaX |
| Chopper | `SUPPORTED_VIA_ADAPTER` | Chopper -> `AlphaXHttpClient` -> AlphaX |
| GraphQL HTTP | `SUPPORTED_VIA_ADAPTER` | GraphQL HTTP link -> `AlphaXHttpClient` -> AlphaX |
| GraphQL WebSocket/subscriptions | `PROOF_ONLY` | Caller-owned bridge proof; no GraphQL package |
| Direct OpenAPI template | `PROOF_ONLY` | Bounded official-template proof targeting the AlphaX generator seam |
| OpenAPI Dio client | `SUPPORTED_VIA_ADAPTER` | Generated client -> Dio -> `AlphaXDioAdapter` |
| OpenAPI `package:http` client | `SUPPORTED_VIA_ADAPTER` | Injectable generated client -> `AlphaXHttpClient` |
| `json_serializable` | `COMPATIBLE_CALLER_LAYER` | Caller-owned model serialization hooks |
| Freezed | `COMPATIBLE_CALLER_LAYER` | Caller-owned model serialization hooks |
| Protobuf | `COMPATIBLE_CALLER_LAYER` | Caller-owned `writeToBuffer`/`fromBuffer` byte mapping |
| SSE | `FIRST_CLASS` | Incremental `package:alphax/sse.dart` parser |
| WebSocket | `FIRST_CLASS` | Transport-neutral connector/session contract |
| gRPC | `DEFERRED_POST_1_0` | Protobuf interoperability does not provide gRPC |

<!-- markdownlint-enable MD013 -->

## 12. Known limitations

- Protocol capabilities vary by provider; Dart IO remains an H1 scope.
- Browser TLS, CORS, proxy, origin, and protocol behavior remains browser-owned.
- Direct OpenAPI integration is proof-only, not exhaustive OpenAPI support.
- GraphQL WebSocket is a caller-bridge proof, not a GraphQL adapter.
- Protobuf is a serialization format and is not gRPC.
- SSE and WebSocket do not perform automatic reconnect or replay.
- Provider-specific buffering, headers, ping/pong, and frame limits remain
  provider-dependent.
- Windows remains supported but unverified in the current local gate.

## 13. Security review

The stable-preparation audit found no security regression. The retained release
behavior confirms secure TLS defaults, fail-closed pinning and protocol
requirements, honest unsupported proxy/custom-trust behavior, redirect
credential stripping, auth refresh and cookie/cache boundaries, and explicit
browser/WebSocket authentication limitations.

The repository and package archives contain no private keys, certificates,
signing material, `DEVELOPMENT_TEAM`, local absolute paths, `pubspec_overrides`,
or benchmark credentials. Generated code does not log credentials or bodies.

## 14. Dependency review

Direct and transitive package roles were reviewed. No GraphQL, Chopper, OpenAPI,
Protobuf, or fixture-only dependency leaked into runtime packages. `alphax`
remains pure Dart and transport-independent. `alphax_generator` tooling
dependencies remain isolated to the development-time generator package.

## 15. SDK constraints

All package SDK and Flutter constraints were reviewed without lowering or
artificially raising the supported minimum. Native metadata versions are also
`1.0.0`. The existing minimum SDK policy remains the stable package policy.

## 16. Validation

The final release-oriented validation completed successfully for the stable
preparation state:

- `dart format --output=none --set-exit-if-changed packages`
- all eight package suites via `bash tooling/scripts/test_packages.sh`
- all package analysis via `bash tooling/scripts/analyze_dart_packages.sh`
- `git diff --check`
- source/API comparison against `b9cb39e` with no package `lib/` or `test/`
  differences
- typed REST Dart, Web, and Flutter consumers
- bounded OpenAPI template proof consumer using retained Task 53 evidence
- Protobuf byte recipe fixture
- `examples/basic` and `examples/waypoint`
- Android debug build
- macOS debug build
- iOS simulator/no-code-sign build
- Web Chrome tests with the deterministic WebSocket fixture
- Dartdoc for all eight packages (`0` errors; existing non-fatal README/doc-tree
  warnings are recorded below)
- Markdown validation for the new release notes and an internal target checker
  for current docs/package READMEs
- dependency, security, signing, and path audits

The retained rc.5 fixtures for Dio, Retrofit, `package:http`, Chopper, GraphQL
HTTP, SSE, WebSocket, generator, OpenAPI, and Protobuf remain green. No
performance experiments were rerun.

Dartdoc completed with zero errors. Existing relative README/doc-tree warnings
remain non-fatal and do not indicate a public API or archive defect; the new
stable release notes pass Markdown lint.

## 17. Package dry-runs

Clean detached-worktree dry-runs completed in the approved publication set with
zero warnings and no `--ignore-warnings`. Archive inspection found no
`.dart_tool`,
build output, disposable consumer output, local logs, secrets, signing files, or
local absolute paths.

## 18. Archive sizes

The measured stable-preparation archive sizes are:

| Package | Archive |
| --- | ---: |
| `alphax` | 66 KB |
| `alphax_test` | 12 KB |
| `alphax_native` | 103 KB |
| `alphax_web` | 17 KB |
| `alphax_dio` | 15 KB |
| `alphax_transform` | 14 KB |
| `alphax_http` | 12 KB |
| `alphax_generator` | 17 KB |

Small metadata-only differences from prior rc.5 measurements are expected.

## 19. Publication order

The final manifest dependency graph yields this conservative sequential order:

1. `alphax`
2. `alphax_test`
3. `alphax_native`
4. `alphax_web`
5. `alphax_dio`
6. `alphax_transform`
7. `alphax_http`
8. `alphax_generator`

Each dependent package's stable AlphaX constraint can resolve after the earlier
family package is hosted.

## 20. Hosted-consumer plan

After publication approval, use clean consumers with hosted `1.0.0` only and no
path dependencies or overrides. Validate native, Web, pure Dart/custom,
Dio, Retrofit, `package:http`, Chopper, GraphQL HTTP, SSE, native/browser
WebSocket, typed generator, transform, test helpers, the bounded OpenAPI proof,
and the Protobuf recipe.

The stable package set has not been published in this task, so no hosted stable
consumer was run prematurely.

## 21. External example update plan

Examples intentionally remain on hosted rc.5 until stable packages exist. After
successful stable publication, update current hosted example pins to `^1.0.0`
in a separate post-publication documentation/examples change and run their
normal gates. Historical rc.5 fixtures and reports remain unchanged.

## 22. Tag and GitHub release plan

The accepted stable provenance decision is to leave rc.5 untagged and create
only `v1.0.0` with the GitHub release title `AlphaX 1.0.0`. Neither the tag nor
the GitHub release was created during preparation. The release body is based on
`docs/ALPHAX_1_0_RELEASE_NOTES.md`.

## 23. Remaining blockers

None. There are no `STABLE_BLOCKER` findings. The remaining limitations listed
above are frozen support boundaries or post-1.0 items, not release blockers.

## 24. Exact publication procedure

After explicit maintainer approval:

1. Reconfirm the clean release-owned source and stable manifests.
2. Run each package's zero-warning `dart pub publish --dry-run` (Flutter dry-run
   where required) immediately before publication.
3. Publish the eight packages sequentially in the order in section 19.
4. Verify hosted metadata and dependency resolution after every package before
   continuing.
5. Run the clean hosted-consumer plan in section 20.
6. Update and commit current hosted examples to `^1.0.0` only after all hosted
   consumers pass.
7. Separately decide whether to create `v1.0.0` and the GitHub release.

No publication, tag, GitHub release, stable example pin update, or post-1.0
feature work is authorized by this preparation record.

ALPHAX 1.0.0 PREPARED FOR PUBLICATION
