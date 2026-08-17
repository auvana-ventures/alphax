# AlphaX 1.0 Requirements Audit

Audit date: 2026-08-17
Audit basis: `docs/ALPHAX_1_0_SCOPE.md`, the Phase 1A public API inventory,
the Phase 1E and Phase 1F reports, ADRs 0004 and 0005, ADRs 0006–0008, and
the public networking/security APIs in `alphax`, `alphax_native`, and
`alphax_test`.

This audit does not change the accepted scope. It records the implementation
state after the release-closure work. A required item is not reclassified to
avoid work; provider limitations and unavailable device validation are recorded
explicitly.

## Exact state vocabulary

- `IMPLEMENTED_AND_VALIDATED`: implementation, relevant tests/evidence, and
  documentation are complete for the stated boundary.
- `IMPLEMENTED_NEEDS_VALIDATION`: implementation exists, but an approved
  runtime, physical-device, security, or release-path check remains open.
- `REQUIRED_NOT_IMPLEMENTED`: approved required behavior or public API is
  absent.
- `OPTIONAL_NOT_IMPLEMENTED`: approved optional behavior is deliberately not
  included.
- `INTENTIONALLY_UNSUPPORTED_IN_1_0`: the approved scope excludes the item.
- `BLOCKED_BY_PLATFORM`: the selected platform/provider cannot safely provide
  the behavior; the capability and failure are explicit.
- `BLOCKED_BY_MAINTAINER_DECISION`: a required choice needs explicit
  maintainer direction before implementation can be considered complete.

## Frozen interface and claim boundaries

The following are deliberate 1.0 contract boundaries. They are not missing
required implementations, and the detailed capability rows below remain the
source of truth for the individual scope classification of retries, caching,
cookies, authentication, and Web support.

| Boundary | Exact 1.0 state | Evidence / limitation |
|---|---|---|
| Native transport implementation inside `alphax` | `INTENTIONALLY_UNSUPPORTED_IN_1_0` | `alphax` is pure Dart and transport-independent. `AlphaXClient` consumes an injected `AlphaXTransport`; native adapters live in `alphax_native`, and deterministic fakes live in `alphax_test`. |
| Web support | `IMPLEMENTED_NEEDS_VALIDATION` | `alphax_web` provides a separate browser Fetch transport for ordinary HTTP. Browser protocol metadata is unknown, concrete protocol requirements fail closed, and browser CORS/TLS/proxy rules remain platform-owned. Browser-runtime validation is separate from the native RC gate. |
| Universal H3 guarantee | `INTENTIONALLY_UNSUPPORTED_IN_1_0` | H3-capable Android/Apple adapters, preference/requirement semantics, actual protocol reporting, and fallback evidence are validated. The provider, server, proxy, and network path still determine each request’s actual protocol. |
| Automatic retries, authentication orchestration, cookies, caching, and vendor-specific resilience policy | `IMPLEMENTED_NEEDS_VALIDATION` | Opt-in pure-Dart middleware now provides replay-aware retry, caller-owned token injection with single-flight buffered challenge refresh, in-memory cookies, bounded buffered GET/HEAD caching, and a generic circuit breaker. Persistent stores, unsafe replay, model-specific OAuth, and vendor policies remain outside the implementation. |
| Universal speed, zero-copy, or “fastest client” claim | `INTENTIONALLY_UNSUPPORTED_IN_1_0` | Release documentation makes no universal performance claim. Native file-backed and bounded-transfer behavior is described only as an adapter capability with scoped evidence; it is not called zero-copy. |

## Protocols and transports

| Capability | Scope class | Exact state | Evidence / limitation |
| --- | --- | --- | --- |
| HTTP/1.1 | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Dart IO, Android Cronet, Apple URLSession, and retained fallback correctness evidence pass. |
| HTTP/2 | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Actual H2 evidence is retained for Android, iPhone, and macOS; Dart IO reports unsupported. |
| HTTP/3 | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | H3 implementation, signed iPhone H3/requires-H3 evidence, retained Android provider/device H3 evidence, and truthful Android Wi-Fi/cellular fallback evidence pass; per-network H3 availability is opportunistic and non-gating. |
| Negotiated protocol reporting | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | `AlphaXProtocol`, best-known snapshots, completion metrics, and terminal stream metadata preserve `unknown` and authoritative final values. |
| Fallback reporting | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Core/native mapping tests and focused Android/iPhone/macOS fallback evidence pass; Android reports H2 accurately when H3 is unavailable. |
| Protocol preference | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | A preference permits fallback; actual protocol is never inferred from preference or capability. |
| Protocol requirement | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Immutable request requirement, fail-closed errors, core tests, Android H3-failure evidence, and signed iPhone success/failure evidence pass; Android success remains path-dependent follow-up evidence rather than a universal network guarantee. |
| Android Cronet/HttpEngine transport | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Shared engine, H1/H2/H3 capability, bounded delivery, files, cancellation, policy mapping, physical pinning/redirect/lifecycle evidence, and truthful fallback pass; live H3 remains dependent on the selected provider and network path. |
| iOS URLSession transport | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Shared adapter, URLSession metrics, files, streaming, policy mapping, signed H1/H2/H3, requirement, TLS, pinning, and redirect-security evidence pass. |
| macOS URLSession transport | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | H1/H2/H3, fallback, streams, files, cancellation, TLS rejection, lifecycle, and redirect checks pass on macOS. |
| Dart IO fallback | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Reusable `HttpClient`, H1 fallback, bodies, streams, files, TLS defaults/custom anchors, proxy routes, errors, and lifecycle tests pass; H2/H3 are not advertised. |
| Transport capability discovery | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Expanded TLS/proxy/protocol/security capability model is implemented, exposed by the physical Android provider, and covered by Dart/Apple/Android mapping tests; unsupported policies fail closed. |
| Client/session reuse | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Dart IO `HttpClient`, one Cronet engine, and one URLSession are reused; close/reuse tests and historical platform evidence pass. |

## Core HTTP surface

| Capability | Scope class | Exact state | Evidence / limitation |
| --- | --- | --- | --- |
| GET | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Shared and adapter correctness tests pass. |
| POST | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Byte, text, JSON, stream, file, multipart, cancellation, and response tests pass. |
| PUT | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Required-method fixtures pass on the maintained adapters. |
| PATCH | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Required-method fixtures pass on the maintained adapters. |
| DELETE | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Required-method fixtures pass on the maintained adapters. |
| HEAD | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Status/header behavior and empty-body semantics pass. |
| OPTIONS | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Empty/materialized response behavior passes. |
| Headers | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Immutable, case-insensitive, multi-value conversion is tested. |
| Query parameters | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | URI construction preserves repeated keys and encoding. |
| Byte body | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Exact bytes and content lengths pass. |
| Text body | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Explicit UTF-8 body behavior passes. |
| JSON helpers | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | `dart:convert` request/response helpers pass. |
| Streamed request body | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Single-consumption, bounded consumption, cancellation, and body hash checks pass for implemented adapters. |
| Streamed response body | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Progressive delivery, pause/resume, bounded queues, errors, and completion pass in the existing suites. |
| Redirects | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Apple/iPhone sanitizes, Dart IO conservatively rejects unsafe cross-origin cases, and focused Android physical rejection passes. |
| `multipart/form-data` | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Transport-neutral multipart fields/file parts and adapter tests pass. |

## Lifecycle, streaming, and files

| Capability | Scope class | Exact state | Evidence / limitation |
| --- | --- | --- | --- |
| Cancellation | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Pre-start, setup, upload, response, stream, paused stream, files, close, and idempotence are covered by existing tests/evidence. |
| Connect/request/read/overall timeout semantics | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | AlphaX semantic timers are mapped or emulated; unavailable phase precision is not fabricated. |
| Deterministic client close | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Repeated close, active close, post-close rejection, and native session cleanup are covered. |
| Request cleanup | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Terminal success/error/cancellation paths release request, stream, file, and native operation state. |
| Error normalization | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Expanded protocol, TLS, pin, proxy, client-identity, and unsupported-policy mappings compile, have unit coverage, and pass focused native protocol/pin error probes. |
| Bounded backpressure | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Native adapters retain the 64 KiB × 4 credit window; Dart pause/resume semantics are covered. |
| Upload progress | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Monotonic byte counts and completion are tested. |
| Download progress | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Monotonic byte counts and completion are tested. |
| File upload | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Exact byte count, deterministic hash, progress, cancellation, and cleanup pass. |
| File download | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Exact byte count, deterministic hash, progress, cancellation, and cleanup pass. |
| Native file-backed transfer where supported | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Android and Apple direct native paths exist, are reported, and pass focused deterministic file-transfer checks. |
| Cancellation during upload/download | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Existing native and Dart transfer checks cover cancellation and resource release. |

## Security and network controls

| Capability | Scope class | Exact state | Evidence / limitation |
| --- | --- | --- | --- |
| TLS verification by default | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Platform trust remains enabled; invalid-certificate fixtures reject; no trust-all callback exists. |
| Custom trust anchors / certificate configuration | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Immutable DER-anchor policy is implemented where supported; macOS and signed iPhone pass default-rejection, configured-success, and incorrect-anchor failure, while Android Cronet reports `UNSUPPORTED_BY_ANDROID_PROVIDER` fail-closed. |
| SPKI SHA-256 certificate pinning | REQUIRED FOR 1.0 WHERE THE TRANSPORT ADVERTISES SUPPORT | `IMPLEMENTED_AND_VALIDATED` | Immutable primary/backup pin model and Android/Apple enforcement exist after normal trust validation. Focused macOS, signed iPhone, and Android fixtures pass primary/backup/mismatch and invalid-certificate checks; Dart IO reports unsupported and fails closed. |
| Client certificates / mTLS | OPTIONAL FOR 1.0 | `OPTIONAL_NOT_IMPLEMENTED` | Opaque platform identity model exists, but Dart IO, selected Cronet, and URLSession adapters reject identity use; no raw private-key API is exposed. |
| System proxy behavior | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | System policy is preserved for Dart IO, Cronet, and URLSession; capability snapshots and focused macOS/Apple policy evidence pass, with provider-managed Android routing documented. |
| Direct/no-proxy policy | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Dart IO and Apple implement direct routing; selected Cronet provider reports unsupported instead of silently degrading. |
| Explicit HTTP proxy | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Dart IO and Apple HTTP proxy mappings and trusted HTTPS CONNECT pass focused fixtures; selected Cronet provider reports unsupported instead of silently degrading. |
| Explicit HTTPS proxy endpoint | OPTIONAL FOR 1.0 | `INTENTIONALLY_UNSUPPORTED_IN_1_0` | Explicit HTTPS-proxy endpoint parity is outside the approved 1.0 boundary. The shared model retains the scheme so unsupported requests fail with normalized policy errors rather than silently routing direct/system. HTTP proxy CONNECT to HTTPS remains supported where the transport validates it. |
| Proxy authentication | REQUIRED FOR 1.0 WHERE THE TRANSPORT ADVERTISES SUPPORT | `IMPLEMENTED_AND_VALIDATED` | Dart IO and Apple Basic mappings pass success, wrong-credential, and unreachable-proxy fixtures; Cronet reports explicit provider limitations rather than advertising unsupported auth. |
| Capability discovery for TLS/proxy/protocol controls | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Separate fields exist for default trust, custom anchors, pinning, mTLS, system/direct/explicit proxy, proxy auth, protocol support, and requirement enforcement; Android provider snapshots are retained. |

## Architecture, metrics, testing, and developer experience

| Capability | Scope class | Exact state | Evidence / limitation |
| --- | --- | --- | --- |
| Transport-independent public API | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | `alphax` remains pure Dart and exports policies/models/contracts only. |
| No native transport-specific public types | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Export audit finds no Cronet, URLSession, Rust, libcurl, C++, FFI handle, or native error requirement in `alphax`. |
| Capability model | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Expanded immutable model, mapping tests, and Android/Apple runtime provider snapshots pass; provider-specific unsupported states remain explicit. |
| Protocol enum | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | `http10`, `http11`, `http2`, `http3`, and `unknown` are transport-neutral and documented. |
| Transport-neutral metrics | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Nullable timings/bytes/reuse/protocol data and completion-time authority are tested without invented values. |
| Middleware/interceptor foundation | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Ordering, async behavior, short-circuit, mutation, error handling, and stream ownership pass. |
| Testing/fake transport support | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | `alphax_test` fake, delay, failure, cancellation, protocol, file, and shared conformance foundations pass. |
| Clear README examples | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Examples cover request, stream, files, cancellation, capabilities, protocol preference/requirement, and negotiated metadata; TLS/pinning/proxy behavior is documented separately without unsafe configuration examples. |
| Consistent errors | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Public categories include DNS, connection, TLS/trust/pin, timeout, cancellation, protocol/requirement, redirect, body, proxy/auth, unsupported, and transport; focused native mappings pass. |
| Immutable request/response models | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Headers, metadata, metrics, policies, and body ownership are immutable/lifecycle-controlled. |
| Package documentation | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Package READMEs, migration notes, API inventory, architecture contract, benchmark runner guidance, and release gate exist; scoped doc/link checks pass. |
| Migration guidance from `package:http`/Dio | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | `docs/MIGRATION.md` explains request, middleware, cancellation, timeout, TLS/pinning, proxy, files, and protocol semantics without promising a full adapter. |
| Policy middleware contracts | OPTIONAL FOR 1.0 | `IMPLEMENTED_NEEDS_VALIDATION` | Retry, authentication, cookie, cache, and resilience middleware are transport-independent and covered by focused pure-Dart tests; persistent storage and provider-specific policy remain caller-owned. |
| Browser Fetch transport | OPTIONAL FOR 1.0 | `IMPLEMENTED_NEEDS_VALIDATION` | `alphax_web` provides a conditional Web adapter with truthful unknown protocol/capability reporting. Native-target analysis and tests pass; browser-runtime compilation/validation remains separate. |

## Optional, post-1.0, and explicit non-goals

| Capability | Scope class | Exact state | Deliberate decision |
| --- | --- | --- | --- |
| Dio adapter | OPTIONAL FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | `alphax_dio` provides a focused Dio 5.x `HttpClientAdapter` over an injected `AlphaXClient`; request/response lifecycle, cancellation, timeout/error mapping, progress, streaming, redirects, and protocol metadata are tested. It is not full Dio API compatibility and is not required by the native transport gate. |
| Cookie jar | OPTIONAL FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | `AlphaXCookieJar` and middleware implement in-memory host/path/secure/expiry matching and Set-Cookie storage. Persistent cookie storage is not included. |
| Request priorities | OPTIONAL FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Retained as a transport-neutral hint with no provider-specific guarantee. |
| mTLS | OPTIONAL FOR 1.0 | `OPTIONAL_NOT_IMPLEMENTED` | Evaluated and explicitly capability-rejected by current adapters. |
| Cache | OPTIONAL FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | `AlphaXCacheMiddleware` provides bounded in-memory freshness, conditional revalidation, and mutation invalidation for buffered GET/HEAD responses. |
| Retry/resilience | OPTIONAL FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | `AlphaXRetryMiddleware` applies cancellation-aware backoff to replayable, idempotent buffered requests by default; unsafe mutations and non-replayable streams are not silently retried. |
| Circuit breaker | OPTIONAL FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | `AlphaXResilienceMiddleware` provides a generic in-memory circuit breaker with optional retry composition and normalized circuit-open errors. |
| Offline queue | POST-1.0 | `INTENTIONALLY_UNSUPPORTED_IN_1_0` | No offline queue. |
| OpenTelemetry | POST-1.0 | `INTENTIONALLY_UNSUPPORTED_IN_1_0` | No telemetry SDK integration. |
| Sentry/Firebase Performance | EXPLICIT NON-GOAL | `INTENTIONALLY_UNSUPPORTED_IN_1_0` | No vendor observability integration. |
| DevTools extension | POST-1.0 | `INTENTIONALLY_UNSUPPORTED_IN_1_0` | No extension. |
| WebSocket | POST-1.0 | `INTENTIONALLY_UNSUPPORTED_IN_1_0` | HTTP client scope only. |
| SSE | POST-1.0 | `INTENTIONALLY_UNSUPPORTED_IN_1_0` | Raw streaming remains available; no SSE parser/reconnect layer. |
| Browser/web transport | OPTIONAL FOR 1.0 | `IMPLEMENTED_NEEDS_VALIDATION` | `alphax_web` provides browser Fetch for ordinary HTTP. It cannot expose authoritative protocol metadata or native TLS/proxy/file controls. |
| GraphQL | EXPLICIT NON-GOAL | `INTENTIONALLY_UNSUPPORTED_IN_1_0` | No GraphQL client. |
| REST generator | EXPLICIT NON-GOAL | `INTENTIONALLY_UNSUPPORTED_IN_1_0` | No generator. |
| Authentication orchestration | OPTIONAL FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Token injection and one single-flight buffered challenge refresh are available; credential storage and model-specific auth remain caller-owned. |

## Required-item audit result

No approved required item is classified `REQUIRED_NOT_IMPLEMENTED`. Required
behavior is implemented, tested, documented, and reconciled against the
transport-neutral contract. Provider limitations remain explicit
`BLOCKED_BY_PLATFORM` or unsupported capability results; they do not silently
degrade to a different security or routing policy.

The Android release evidence is intentionally split by responsibility:

1. The selected Cronet provider exposes H1/H2/H3 and negotiated-protocol
   reporting. Retained Phase 1C evidence captures actual H3 on the supported
   Android provider/device configuration, while the focused Wi-Fi and cellular
   release runs accurately report H2 fallback. The cellular report is retained
   in `benchmarks/mobile_gate/fixtures/phase1f_android_h3_cellular_fallback.json`;
   an unvalidated cellular path is rejected before probing in
   `benchmarks/mobile_gate/fixtures/phase1f_android_h3_cellular_unvalidated.json`.
2. The H3 preference check is opportunistic and the H3 requirement remains
   fail-closed. The signed iPhone success/failure evidence, Android failure
   evidence, core tests, and final protocol metadata rules validate those
   semantics. A live Android H3 success on a particular QUIC-permissive path is
   useful follow-up evidence, not a universal 1.0 network guarantee.
3. Android physical pinning, redirect, file-transfer, cancellation, lifecycle,
   and protocol-failure checks pass in
   `benchmarks/mobile_gate/fixtures/phase1f_android_final_release_focused.json`.
   The earlier package-manager stall remains preserved as historical
   environment evidence and is not a product blocker.

## Conclusion

`alphax` and the three transport boundaries satisfy the approved AlphaX 1.0
contract for maintainer RC review. H3 remains path-dependent by design:
responses report the actual protocol, preferences permit fallback, and
requirements fail closed. No universal Android H3 network claim is made.
Provider-limited policies are documented as fail-closed capability boundaries,
not as unresolved decisions. The explicit non-guarantees above are deliberate
scope decisions and do not block the 1.0 RC review.
