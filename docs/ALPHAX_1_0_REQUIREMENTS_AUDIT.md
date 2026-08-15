# AlphaX 1.0 Requirements Audit

Audit date: 2026-08-15
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

## Protocols and transports

| Capability | Scope class | Exact state | Evidence / limitation |
| --- | --- | --- | --- |
| HTTP/1.1 | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Dart IO, Android Cronet, Apple URLSession, and retained fallback correctness evidence pass. |
| HTTP/2 | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Actual H2 evidence is retained for Android, iPhone, and macOS; Dart IO reports unsupported. |
| HTTP/3 | REQUIRED FOR 1.0 | `IMPLEMENTED_NEEDS_VALIDATION` | H3 implementation and retained Android/iPhone/macOS evidence exist; final release-path Android and iPhone checks could not attach to the devices in this environment. |
| Negotiated protocol reporting | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | `AlphaXProtocol`, best-known snapshots, completion metrics, and terminal stream metadata preserve `unknown` and authoritative final values. |
| Fallback reporting | REQUIRED FOR 1.0 | `IMPLEMENTED_NEEDS_VALIDATION` | Core/native mapping tests pass; final Android/iPhone release-path security/protocol probes remain blocked by device tooling. |
| Protocol preference | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | A preference permits fallback; actual protocol is never inferred from preference or capability. |
| Protocol requirement | REQUIRED FOR 1.0 | `IMPLEMENTED_NEEDS_VALIDATION` | Immutable request requirement, fail-closed errors, native completion checks, and fake/core tests exist; focused device requirement probes remain open. |
| Android Cronet/HttpEngine transport | REQUIRED FOR 1.0 | `IMPLEMENTED_NEEDS_VALIDATION` | Shared engine, H1/H2/H3 capability, bounded delivery, files, cancellation, policy mapping, and historical device evidence exist; release-path device rerun is blocked. |
| iOS URLSession transport | REQUIRED FOR 1.0 | `IMPLEMENTED_NEEDS_VALIDATION` | Shared adapter, URLSession metrics, files, streaming, policy mapping, and signed historical evidence exist; current signed runner attach fails with `osascript: -2`. |
| macOS URLSession transport | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | H1/H2/H3, fallback, streams, files, cancellation, TLS rejection, lifecycle, and redirect checks pass on macOS. |
| Dart IO fallback | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Reusable `HttpClient`, H1 fallback, bodies, streams, files, TLS defaults/custom anchors, proxy routes, errors, and lifecycle tests pass; H2/H3 are not advertised. |
| Transport capability discovery | REQUIRED FOR 1.0 | `IMPLEMENTED_NEEDS_VALIDATION` | Expanded TLS/proxy/protocol/security capability model is implemented and mapped; provider-dependent policy snapshots need release-device confirmation. |
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
| Redirects | REQUIRED FOR 1.0 | `IMPLEMENTED_NEEDS_VALIDATION` | Apple sanitizes, Dart IO conservatively rejects unsafe cross-origin cases, and Android rejects unsafe cross-origin cases; focused physical Android/iPhone assertions remain open. |
| `multipart/form-data` | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Transport-neutral multipart fields/file parts and adapter tests pass. |

## Lifecycle, streaming, and files

| Capability | Scope class | Exact state | Evidence / limitation |
| --- | --- | --- | --- |
| Cancellation | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Pre-start, setup, upload, response, stream, paused stream, files, close, and idempotence are covered by existing tests/evidence. |
| Connect/request/read/overall timeout semantics | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | AlphaX semantic timers are mapped or emulated; unavailable phase precision is not fabricated. |
| Deterministic client close | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Repeated close, active close, post-close rejection, and native session cleanup are covered. |
| Request cleanup | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Terminal success/error/cancellation paths release request, stream, file, and native operation state. |
| Error normalization | REQUIRED FOR 1.0 | `IMPLEMENTED_NEEDS_VALIDATION` | Expanded protocol, TLS, pin, proxy, client-identity, and unsupported-policy mappings compile and have unit coverage; focused native runtime error probes remain open. |
| Bounded backpressure | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Native adapters retain the 64 KiB × 4 credit window; Dart pause/resume semantics are covered. |
| Upload progress | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Monotonic byte counts and completion are tested. |
| Download progress | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Monotonic byte counts and completion are tested. |
| File upload | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Exact byte count, deterministic hash, progress, cancellation, and cleanup pass. |
| File download | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Exact byte count, deterministic hash, progress, cancellation, and cleanup pass. |
| Native file-backed transfer where supported | REQUIRED FOR 1.0 | `IMPLEMENTED_NEEDS_VALIDATION` | Android and Apple direct native paths exist and are reported; final Android/iPhone release-path checks remain blocked. |
| Cancellation during upload/download | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Existing native and Dart transfer checks cover cancellation and resource release. |

## Security and network controls

| Capability | Scope class | Exact state | Evidence / limitation |
| --- | --- | --- | --- |
| TLS verification by default | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Platform trust remains enabled; invalid-certificate fixtures reject; no trust-all callback exists. |
| Custom trust anchors / certificate configuration | REQUIRED FOR 1.0 | `IMPLEMENTED_NEEDS_VALIDATION` | Immutable DER-anchor policy is implemented for Dart IO and Apple; macOS passed default-rejection, configured-success, and incorrect-anchor failure; Android Cronet explicitly fails with `UNSUPPORTED_BY_ANDROID_PROVIDER`; iPhone focused runtime validation remains open. |
| SPKI SHA-256 certificate pinning | REQUIRED FOR 1.0 WHERE THE TRANSPORT ADVERTISES SUPPORT | `IMPLEMENTED_NEEDS_VALIDATION` | Immutable primary/backup pin model and Android/Apple enforcement exist after normal trust validation. The focused macOS fixture passed primary/backup/mismatch and invalid-certificate checks; Android and iPhone release-path checks remain open. Dart IO reports unsupported because stable `HttpClient` lacks a safe SPKI callback/parser and fails closed. |
| Client certificates / mTLS | OPTIONAL FOR 1.0 | `OPTIONAL_NOT_IMPLEMENTED` | Opaque platform identity model exists, but Dart IO, selected Cronet, and URLSession adapters reject identity use; no raw private-key API is exposed. |
| System proxy behavior | REQUIRED FOR 1.0 | `IMPLEMENTED_NEEDS_VALIDATION` | System policy is preserved for Dart IO, Cronet, and URLSession; the focused macOS system-policy fixture passed, while Android/iPhone release-path policy snapshots remain open. |
| Direct/no-proxy policy | REQUIRED FOR 1.0 | `IMPLEMENTED_NEEDS_VALIDATION` | Dart IO and Apple implement direct routing; selected Cronet provider cannot guarantee direct routing and reports unsupported instead of degrading. |
| Explicit HTTP proxy | REQUIRED FOR 1.0 | `IMPLEMENTED_NEEDS_VALIDATION` | Dart IO and Apple HTTP proxy mappings exist, including a focused macOS trusted HTTPS CONNECT path; selected Cronet provider cannot guarantee explicit routing and Android/iPhone release-path checks remain open. |
| Explicit HTTPS proxy endpoint | OPTIONAL FOR 1.0 | `INTENTIONALLY_UNSUPPORTED_IN_1_0` | Explicit HTTPS-proxy endpoint parity is outside the approved 1.0 boundary. The shared model retains the scheme so unsupported requests fail with normalized policy errors rather than silently routing direct/system. HTTP proxy CONNECT to HTTPS remains supported where the transport validates it. |
| Proxy authentication | REQUIRED FOR 1.0 WHERE THE TRANSPORT ADVERTISES SUPPORT | `IMPLEMENTED_NEEDS_VALIDATION` | Dart IO and Apple Basic mappings exist; the focused macOS fixture passed success, wrong-credential failure, and unreachable-proxy failure. Cronet provider does not expose a portable explicit-auth mapping and Android/iPhone release-path checks remain open. |
| Capability discovery for TLS/proxy/protocol controls | REQUIRED FOR 1.0 | `IMPLEMENTED_NEEDS_VALIDATION` | Separate fields exist for default trust, custom anchors, pinning, mTLS, system/direct/explicit proxy, proxy auth, protocol support, and requirement enforcement; provider snapshots need release-path checks. |

## Architecture, metrics, testing, and developer experience

| Capability | Scope class | Exact state | Evidence / limitation |
| --- | --- | --- | --- |
| Transport-independent public API | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | `alphax` remains pure Dart and exports policies/models/contracts only. |
| No native transport-specific public types | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Export audit finds no Cronet, URLSession, Rust, libcurl, C++, FFI handle, or native error requirement in `alphax`. |
| Capability model | REQUIRED FOR 1.0 | `IMPLEMENTED_NEEDS_VALIDATION` | Expanded immutable model and mapping tests exist; runtime provider-dependent rows remain release validation. |
| Protocol enum | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | `http10`, `http11`, `http2`, `http3`, and `unknown` are transport-neutral and documented. |
| Transport-neutral metrics | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Nullable timings/bytes/reuse/protocol data and completion-time authority are tested without invented values. |
| Middleware/interceptor foundation | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Ordering, async behavior, short-circuit, mutation, error handling, and stream ownership pass. |
| Testing/fake transport support | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | `alphax_test` fake, delay, failure, cancellation, protocol, file, and shared conformance foundations pass. |
| Clear README examples | REQUIRED FOR 1.0 | `IMPLEMENTED_NEEDS_VALIDATION` | Examples now cover request, stream, files, cancellation, capabilities, protocol preference/requirement, TLS, and proxy policies; final docs checks remain. |
| Consistent errors | REQUIRED FOR 1.0 | `IMPLEMENTED_NEEDS_VALIDATION` | Public categories include DNS, connection, TLS/trust/pin, timeout, cancellation, protocol/requirement, redirect, body, proxy/auth, unsupported, and transport; focused native runtime mappings remain open. |
| Immutable request/response models | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Headers, metadata, metrics, policies, and body ownership are immutable/lifecycle-controlled. |
| Package documentation | REQUIRED FOR 1.0 | `IMPLEMENTED_NEEDS_VALIDATION` | Package READMEs, migration notes, API inventory, architecture contract, and release gate exist; final doc/link checks remain. |
| Migration guidance from `package:http`/Dio | REQUIRED FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | `docs/MIGRATION.md` explains request, middleware, cancellation, timeout, TLS/pinning, proxy, files, and protocol semantics without promising a full adapter. |

## Optional, post-1.0, and explicit non-goals

| Capability | Scope class | Exact state | Deliberate decision |
| --- | --- | --- | --- |
| Dio adapter | OPTIONAL FOR 1.0 | `OPTIONAL_NOT_IMPLEMENTED` | Migration guidance exists; the adapter is not a release gate. |
| Cookie jar | OPTIONAL FOR 1.0 | `OPTIONAL_NOT_IMPLEMENTED` | No cross-platform persistent cookie store is included. |
| Request priorities | OPTIONAL FOR 1.0 | `IMPLEMENTED_AND_VALIDATED` | Retained as a transport-neutral hint with no provider-specific guarantee. |
| mTLS | OPTIONAL FOR 1.0 | `OPTIONAL_NOT_IMPLEMENTED` | Evaluated and explicitly capability-rejected by current adapters. |
| Cache | POST-1.0 | `INTENTIONALLY_UNSUPPORTED_IN_1_0` | No cache implementation or public cache contract. |
| Retry/resilience | POST-1.0 | `INTENTIONALLY_UNSUPPORTED_IN_1_0` | No retry or resilience middleware. |
| Circuit breaker | POST-1.0 | `INTENTIONALLY_UNSUPPORTED_IN_1_0` | No circuit-breaker behavior. |
| Offline queue | POST-1.0 | `INTENTIONALLY_UNSUPPORTED_IN_1_0` | No offline queue. |
| OpenTelemetry | POST-1.0 | `INTENTIONALLY_UNSUPPORTED_IN_1_0` | No telemetry SDK integration. |
| Sentry/Firebase Performance | EXPLICIT NON-GOAL | `INTENTIONALLY_UNSUPPORTED_IN_1_0` | No vendor observability integration. |
| DevTools extension | POST-1.0 | `INTENTIONALLY_UNSUPPORTED_IN_1_0` | No extension. |
| WebSocket | POST-1.0 | `INTENTIONALLY_UNSUPPORTED_IN_1_0` | HTTP client scope only. |
| SSE | POST-1.0 | `INTENTIONALLY_UNSUPPORTED_IN_1_0` | Raw streaming remains available; no SSE parser/reconnect layer. |
| Browser/web transport | POST-1.0 | `INTENTIONALLY_UNSUPPORTED_IN_1_0` | Web is unsupported in 1.0. |
| GraphQL | EXPLICIT NON-GOAL | `INTENTIONALLY_UNSUPPORTED_IN_1_0` | No GraphQL client. |
| REST generator | EXPLICIT NON-GOAL | `INTENTIONALLY_UNSUPPORTED_IN_1_0` | No generator. |
| Authentication framework | EXPLICIT NON-GOAL | `INTENTIONALLY_UNSUPPORTED_IN_1_0` | Headers and middleware are the boundary; no token orchestration. |

## Required-item audit result

No approved required item is currently classified
`REQUIRED_NOT_IMPLEMENTED`. Required behavior that is implemented but lacks
release evidence is explicitly `IMPLEMENTED_NEEDS_VALIDATION`; provider
limitations are explicitly `BLOCKED_BY_PLATFORM`. The following release-gate
checks remain open and are not scope changes:

1. Android release/profile physical-device validation after the package-manager
   stall and reboot, including H1/H2/H3, protocol requirement, TLS/pinning,
   redirect security, file, and cancellation checks. ADB visibility, APK push,
   and install-session write passed, but install commit stalled and the
   wireless endpoint did not reappear after reboot; no Android probe result is
   inferred.
2. iPhone signed release/profile attachment and a reachable release fixture.
   The attached profile run verified H2, H3, and invalid-TLS rejection, but
   local H1 was unreachable and a later automation retry hit `osascript: -2`.
3. Focused iPhone release-path validation for H1/fallback, protocol
   requirement success/failure, pin success/mismatch, custom-trust success/
   failure, and cross-origin redirect security. H2, H3, and invalid-TLS
   rejection already passed on the attached phone; local H1 was unreachable
   and a later automation retry hit `osascript: -2`.
4. Provider-limited Cronet direct/explicit proxy and custom trust, unsupported
   Dart IO pinning, optional mTLS, and explicit HTTPS proxy endpoint parity are
   accepted boundaries, not RC blockers.

## Conclusion

`alphax` and the three transport boundaries are substantially implemented,
but the approved AlphaX 1.0 contract is **not ready for an RC**. The exact
remaining blockers are focused Android/iPhone release-path evidence.
Provider-limited policies are documented as fail-closed capability boundaries,
not as unresolved decisions.
