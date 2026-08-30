# AlphaX 1.0 stabilization and release gate

State: **READY_FOR_1_0_VERSION_PREPARATION**

Gate date: **2026-08-30**

This is the final stabilization record for the published `1.0.0-rc.5`
candidate. The feature freeze remains authoritative: no capability, package,
transport, provider, reconnect, generator, GraphQL, OpenAPI, Protobuf, or gRPC
work was added here.

## 1. Published rc.5 baseline

The eight coordinated packages are published and resolve from pub.dev at
`1.0.0-rc.5`:

`alphax`, `alphax_test`, `alphax_native`, `alphax_web`, `alphax_dio`,
`alphax_transform`, `alphax_http`, and `alphax_generator`.

The accepted publication report records the one benign `alphax` propagation
delay. The later immutable-version response, archive checksum, metadata, and
fresh-cache resolution confirmed that the package was already published. No
package-integrity or hosted-metadata issue remains.

Source at the start of this gate was `a46f98e3eb3b362794c77083dd65a252191b7a89`.
The published package source and manifests were unchanged from the prepared
rc.5 source. Stabilization-owned changes are limited to documentation
corrections, the two current-SDK formatter corrections in the retained OpenAPI
proof, this report, and Task 56. Protected benchmark/mobile/history changes
were not staged or modified.

The first stabilization commit containing this record is
`44b4d24` (`chore: complete AlphaX 1.0 stabilization gate`). The final pushed
HEAD is recorded in the completion history after the report metadata is
finalized.

## 2. Frozen public API review

The review compared the public barrels with the accepted rc.5 surface. There
were no source or manifest differences requiring a compatibility change.

| Public library | Frozen surface reviewed |
| --- | --- |
| `alphax.dart` | request/response/body/header/method contracts; transport/client; middleware and policies; cancellation, timeout, redirect, protocol/capability, TLS/proxy, file, progress, metrics, and errors |
| `annotations.dart` | AlphaX-owned typed REST declaration annotations |
| `sse.dart` | `AlphaXSseEvent` and incremental `AlphaXSseParser` |
| `websocket.dart` | connector/session lifecycle, text/binary messages, close information, capabilities, cancellation, and errors |
| `alphax_native.dart` | core re-exports, native transport selection/providers, local files, `createAlphaXClient()`, and native WebSocket connector |
| `alphax_web.dart` | core re-exports, browser Fetch façade, browser WebSocket connector, and browser capability boundaries |
| `alphax_dio.dart` | `AlphaXDioAdapter` |
| `alphax_transform.dart` | `decodeJson`, transform typedef, and transform exception |
| `alphax_http.dart` | `AlphaXHttpClient` |
| `alphax_generator.dart` | build-runner/source-generation builder and generator entry point |
| `alphax_test.dart` | fake transport, file fixtures, and transport conformance helpers |

The public export audit found no accidental private type, export cycle,
duplicate re-export identity, provider/tooling leak, or new breaking API. The
native and Web façades intentionally re-export the same core library identity;
the dedicated SSE and WebSocket sub-libraries remain separate. All findings
are therefore classified `POST_1_0` or already corrected documentation, with
zero `STABLE_BLOCKER` findings.

## 3. Core correctness and policy gates

The eight package suites passed in the final local run:

| Package | Result |
| --- | ---: |
| `alphax` | 95 tests passed |
| `alphax_dio` | 6 tests passed |
| `alphax_generator` | 4 tests passed; build runner wrote 0 outputs |
| `alphax_http` | 24 tests passed |
| `alphax_native` | 61 tests passed |
| `alphax_test` | 10 tests passed |
| `alphax_transform` | 11 tests passed |
| `alphax_web` | 10 tests passed |

The suite covers methods, headers, all body forms, streaming, cancellation,
timeouts, redirects, normalized errors, progress, client/transport reuse and
close, file transfer, multipart, retry/`Retry-After`, authentication,
cookies, cache/Vary/invalidation safety, resilience, TLS/custom trust/pinning,
proxy policy, protocol preference/requirement, capability and completion
metadata, SSE, WebSocket, package:http, and typed generation.

No source-level correctness or compatibility defect was found.

## 4. Security gate

The focused audit passed. Secure TLS defaults, fail-closed pinning, honest
unsupported custom-trust and proxy behavior, fail-closed protocol requirements,
redirect sensitive-header stripping, authentication refresh, cookie/cache
boundaries, WebSocket header limitations, and generator body/credential
redaction remain intact. No trust-all behavior, secret logging, certificate,
private key, signing material, `DEVELOPMENT_TEAM`, temporary QUIC hint, or
absolute local path is in the publishable package set.

Static annotation headers remain caller-owned and are documented as unsuitable
for embedding secrets. Provider-native exception types are not the recommended
public error contract.

## 5. Platform gates

The matrix distinguishes current execution from accepted unchanged rc.5
evidence and does not widen platform claims.

| Platform | HTTP | SSE | WebSocket |
| --- | --- | --- | --- |
| Android | Existing `alphax_native` Cronet/HttpEngine selection and H1/H2/H3 capability evidence retained; current Waypoint debug APK build passed. | AlphaX stream parser and native fixture passed; no Android-specific claim beyond the existing HTTP stream. | Maintained native connector and local fixture evidence retained; WebSocket is not claimed as Cronet-owned. |
| iOS | Simulator no-code-sign build passed; unchanged URLSession/provider evidence retained for H1/H2/H3, TLS, pinning, redirects, files, streaming, and cancellation. | Existing parser/HTTP stream contract retained; provider behavior remains URLSession-owned. | Maintained provider contract retained; no URLSession WebSocket implementation is claimed. |
| macOS | Waypoint debug build passed; URLSession/provider evidence retained. | Existing parser/stream tests passed. | Maintained provider contract and native fixture evidence retained. |
| Linux | No local Linux host was available; package/Dart IO gates are covered by repository CI when green. Dart IO is H1-only and makes no H2/H3 claim. | Parser is pure Dart; native-provider execution remains OS-gate dependent. | Maintained Dart provider is supported where its platform is available; no local Linux execution claim is made. |
| Windows | `WINDOWS_SUPPORTED_UNVERIFIED_IN_CURRENT_GATE`: package/Dart IO code is platform-neutral and no Windows-specific implementation defect is known, but no Windows runner is configured. | Pure parser is platform-neutral; Windows runtime execution was unavailable. | No Windows runtime execution claim was added. |
| Web | Fetch/browser boundaries remain browser-owned; hosted and local Web compile/consumer checks passed. | Chrome/browser stream evidence passed; CORS remains browser-owned. | Chrome fixture passed for text, binary, subprotocol, peer close, and abnormal close; browser headers/TLS/origin remain browser-owned. |

Android device discovery in the local Flutter tool was not reliable, so the
accepted build and rc.5 evidence were used rather than inventing a device
claim. The available iOS simulator and macOS builds completed without code
signing changes. The existing Swift Package Manager warning for
`alphax_native` remains non-blocking; CocoaPods builds pass.

## 6. SSE gate

The dedicated `package:alphax/sse.dart` surface remains unchanged. Focused
tests passed for incremental strict UTF-8, split multibyte characters, BOM,
LF/CRLF/CR including split CRLF, standard field parsing, multiline data,
comments, empty IDs, valid/invalid retry values, unknown fields, blank-line
dispatch, EOF and stream errors, cancellation, paused consumers, generous
line/event limits, and native/Web response streams. No automatic reconnect or
`Last-Event-ID` behavior exists; retry and ID information remain caller-owned.

## 7. WebSocket gate

The accepted separate connector/session contract remains unchanged. Native and
Chrome checks cover connect, ordered text/binary messages, negotiated
subprotocol, local/peer close, close code/reason, cancellation, failure,
terminal stream behavior, and paused receive behavior. Provider buffering,
headers, ping/pong, fragmentation, and network flush semantics remain
capability/provider facts. There is no reconnect, replay, resend queue, or
frame-level API.

## 8. `alphax_http`, Dio, and Retrofit

`AlphaXHttpClient` continues to map `BaseRequest` to AlphaX without buffering
responses, returning `StreamedResponse` and retaining borrowed-client ownership.
Request streaming, multipart, redirects, errors, cancellation limitations,
close, concurrency, Chopper, and GraphQL HTTP fixtures passed. The Dio adapter
and maintained Retrofit path remain:

```text
Retrofit → Dio → AlphaXDioAdapter → AlphaX
```

No framework-specific production code was added.

## 9. Typed generator gate

The frozen generator continues to emit direct `AlphaXClient` request code with
no Dio, Retrofit, `package:http`, or Chopper runtime path. Annotations remain
runtime metadata only; analyzer/source_gen/build_runner dependencies remain
tooling-only. Native, Web, pure-Dart, plain-model, `json_serializable`, and
Freezed-compatible fixtures passed. Generated services borrow the supplied
client and do not close it. Serialization and model hooks remain caller-owned.

## 10. OpenAPI and Protobuf boundaries

The OpenAPI result remains `PROOF_ONLY`: the official bounded template proof
continues to generate the AlphaX declaration consumed by `alphax_generator`.
It is not exhaustive OpenAPI support, and no parser, compiler, package, or
multipart/file template expansion was added.

The Protobuf result remains `COMPATIBLE_CALLER_LAYER` and
`PROTOBUF ERGONOMICS DOCUMENTATION SUFFICIENT`. The maintained protobuf fixture
round-trips `GeneratedMessage` bytes through `AlphaXBody.bytes`; no production
Protobuf API or dependency was added. Protobuf is serialization, not gRPC;
gRPC remains `DEFERRED_POST_1_0`.

## 11. Transform and test package gates

`alphax_transform` passed native one-shot JSON transform, cancellation/discard,
sendability-error, invalid UTF-8/JSON, and Web fail-closed checks. It does not
introduce a worker pool, threshold, or Web fallback. `alphax_test` public fake,
file-fixture, and conformance helpers passed without relying on inaccessible
private APIs.

## 12. Dependency and SDK review

All manifests remain coordinated at `1.0.0-rc.5`. Runtime dependency roles are
unchanged:

```text
alphax_native → alphax, Flutter SDK, web_socket
alphax_web    → alphax, http, web_socket
alphax_dio    → alphax, dio
alphax_http   → alphax, http
alphax_transform → alphax
alphax_test   → alphax, test
alphax_generator → alphax + analyzer/build/source-generation tooling
```

No analyzer, source-generation, build-runner, GraphQL, Chopper, Retrofit,
OpenAPI, Protobuf, or generator fixture dependency leaked into a runtime
package. No dependency upgrade was justified by security, compatibility,
publication, or SDK support. The existing minimum Dart/Flutter constraints
remain the validated constraints; they were not lowered or raised.

## 13. Package dry-runs and archive inspection

Clean-worktree dry-runs were run after the stabilization commit for every
publishable package. Each completed with **zero warnings**. The small 1 KB
differences from the rc.5 publication reference are normal compressed archive
metadata differences; no package contents changed in a release-significant way.

| Package | Version | Compressed archive | Result |
| --- | --- | ---: | --- |
| `alphax` | `1.0.0-rc.5` | 66 KB | 0 warnings |
| `alphax_test` | `1.0.0-rc.5` | 12 KB | 0 warnings |
| `alphax_native` | `1.0.0-rc.5` | 103 KB | 0 warnings |
| `alphax_web` | `1.0.0-rc.5` | 17 KB | 0 warnings |
| `alphax_dio` | `1.0.0-rc.5` | 15 KB | 0 warnings |
| `alphax_transform` | `1.0.0-rc.5` | 14 KB | 0 warnings |
| `alphax_http` | `1.0.0-rc.5` | 12 KB | 0 warnings |
| `alphax_generator` | `1.0.0-rc.5` | 17 KB | 0 warnings |

Archive listings contain intended metadata, public libraries, implementation
sources, tests/examples, and provider tooling only. The archive/path audit
found no `.dart_tool`, build output, disposable consumer output, benchmark raw
data, local logs, absolute local paths, secrets, certificates, private keys,
signing configuration, or `pubspec_overrides`.

## 14. Documentation, metadata, and migration

Stabilization corrected stale current-facing Phase 0/scope language in
`PROJECT_CONTEXT.md`, `CONTRIBUTING.md`, `docs/roadmap.md`, and the relevant
package/root links. `docs/ALPHAX_1_0_SCOPE.md` is explicitly historical, and
the rc.4-to-rc.5-to-1.0 migration section records a version-only stable move
unless a future bounded stabilization fix proves otherwise.

The stable user story remains deployment-oriented: `alphax_native` for native
Flutter, `alphax_web` for Web, `alphax` for pure Dart/custom transports,
`alphax_dio` for Dio/Retrofit, `alphax_http` for package:http ecosystems,
`alphax_transform` for optional large JSON, `alphax_test` for development, and
`alphax_generator` for dev-time typed REST generation. OpenAPI remains proof
only, GraphQL WebSocket remains a caller bridge, Protobuf does not imply gRPC,
and no SSE/WebSocket reconnect is promised.

## 15. Authoritative compatibility matrix

| Ecosystem | Classification | Path | Boundary |
| --- | --- | --- | --- |
| Direct AlphaX | `FIRST_CLASS` | `AlphaXClient` → selected transport | Provider capabilities are authoritative. |
| Typed REST generator | `FIRST_CLASS` | annotations → generator → `AlphaXClient` | Caller/model serialization. |
| Dio | `SUPPORTED_VIA_ADAPTER` | Dio → `AlphaXDioAdapter` → AlphaX | Adapter, not Dio API ownership. |
| Retrofit | `SUPPORTED_VIA_ADAPTER` | Retrofit → Dio → adapter → AlphaX | Existing path remains supported. |
| `package:http` | `SUPPORTED_VIA_ADAPTER` | injected client → `AlphaXHttpClient` → AlphaX | BaseClient cannot carry all AlphaX-only facts. |
| Chopper | `SUPPORTED_VIA_ADAPTER` | Chopper → injected `AlphaXHttpClient` | Normal client injection required. |
| GraphQL HTTP | `SUPPORTED_VIA_ADAPTER` | HTTP link → `AlphaXHttpClient` | GraphQL semantics remain caller-owned. |
| GraphQL WebSocket/subscriptions | `PROOF_ONLY` | caller bridge → AlphaX WebSocket session | No shipped GraphQL adapter. |
| SSE | `FIRST_CLASS` | AlphaX stream → `AlphaXSseParser` | Reconnect is caller-owned. |
| WebSocket | `FIRST_CLASS` | connector/session → maintained provider | No reconnect, frame API, or universal controls. |
| OpenAPI direct template | `PROOF_ONLY` | official template → AlphaX declaration → generator | Bounded proof only. |
| OpenAPI Dio client | `SUPPORTED_VIA_ADAPTER` | generated Dio → AlphaXDioAdapter | Injectable Dio required. |
| OpenAPI `package:http` client | `SUPPORTED_VIA_ADAPTER` | generated client → AlphaXHttpClient | Injectable `http.Client` required. |
| `json_serializable` | `COMPATIBLE_CALLER_LAYER` | caller model hooks | AlphaX owns no model generator. |
| Freezed | `COMPATIBLE_CALLER_LAYER` | caller model hooks | AlphaX owns no model generator. |
| Protobuf | `COMPATIBLE_CALLER_LAYER` | generated bytes ↔ AlphaX byte body | Serialization only. |
| gRPC | `DEFERRED_POST_1_0` | none in rc.5 | Separate RPC/runtime boundary. |

## 16. Final validation

The stabilization validation run passed:

- `dart format --set-exit-if-changed` for tracked Dart sources and retained
  examples, after formatting the two OpenAPI proof files;
- Dart and Flutter analysis for all eight packages;
- all eight package suites listed above;
- typed REST native/pure-Dart/Web consumers, OpenAPI proof, Protobuf fixture,
  basic, and Waypoint analysis/tests;
- Waypoint Android debug APK, macOS debug, and iOS simulator no-code-sign
  builds;
- Chrome WebSocket/Web package checks against the local deterministic fixture;
- hosted rc.5 metadata and fresh-cache dependency resolution for all eight
  packages;
- retained hosted Dio, Retrofit, package:http, Chopper, GraphQL HTTP, SSE,
  WebSocket, generator, transform, and test consumers;
- `dart doc --validate-links` for all eight packages with zero errors;
- local Markdown target validation for 146 tracked Markdown files;
- dependency, security, secret/signing/path, archive, and public-export audits;
  and
- `git diff --check`.

The post-push repository CI run `33319057837` for the stabilization commit was
fully green: Dart packages (format, analysis, tests, package metadata, FFI,
and contract/harness checks), native prototypes on Ubuntu and macOS, and the
Android plugin compile gate all passed. The only CI annotations were GitHub
Action Node.js 20 deprecation notices, unrelated to AlphaX behavior.

The two OpenAPI formatter changes correct a real current-SDK CI gate failure;
they do not change behavior. No benchmark was run.

## 17. Stable limitations

User-relevant limitations retained at the stable boundary are:

- protocol capability differs by native/browser provider; Dart IO is H1-only;
- browser CORS, TLS, proxy, cookies, origin, CSP, and arbitrary-header control
  remain browser-owned;
- OpenAPI direct generation is proof-only;
- GraphQL WebSocket is caller-bridge proof only;
- Protobuf is not gRPC;
- SSE and WebSocket reconnect/replay are caller-owned and absent; and
- provider-specific buffering, header, proxy, ping/pong, frame, and file
  capabilities remain explicit rather than guessed.

These are `POST_1_0`, not release blockers, and are not implemented here.

## 18. Stable migration and release-note draft

The intended path is:

```text
rc.4 → rc.5 → 1.0.0
```

The rc.5-to-stable migration is version-only for the frozen API. Native/Web
façades, explicit transports, custom transports, `alphax_http`, SSE,
WebSocket, generated clients, and Retrofit/Dio remain source-compatible.

Draft stable release positioning:

> AlphaX 1.0 provides transport-neutral Dart networking with native platform
> transports, truthful H1/H2/H3 capability reporting, secure request policies,
> streaming and file transfer, first-class SSE and WebSocket contracts,
> package:http and Dio ecosystem seams, direct typed REST generation, bounded
> OpenAPI proof, caller-owned Protobuf interoperability, deterministic testing,
> and an optional large-JSON transform.

After rc.5, work is stabilization only.

## 19. Stable publication order and hosted plan

The final manifest dependency order remains:

```text
alphax
→ alphax_test
→ alphax_native
→ alphax_web
→ alphax_dio
→ alphax_transform
→ alphax_http
→ alphax_generator
```

After stable versions are prepared and published by a separately authorized
task, clean hosted consumers will validate native, Web, pure Dart/custom,
Dio, Retrofit, package:http, Chopper, GraphQL HTTP, SSE, WebSocket, typed
generation, transform, test helpers, the bounded OpenAPI proof, and the
Protobuf recipe. No path dependency or override will be used.

## 20. Tag/release recommendation

Recommendation: leave rc.5 untagged and create only `v1.0.0` at stable
publication. The immutable hosted archives and recorded publication/source
commits already provide rc.5 provenance; no tag or GitHub release was created
in this gate.

## 21. Decision and exact next task

No `STABLE_BLOCKER` remains. The candidate is ready for the separate exact next
task: **ALPHAX 1.0 STABLE VERSION PREPARATION**. That task may prepare `1.0.0`
metadata, changelogs, dry-runs, and release validation; it may not add features.

**READY_FOR_1_0_VERSION_PREPARATION**
