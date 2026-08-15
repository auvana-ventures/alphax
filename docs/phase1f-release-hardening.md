# Phase 1F — Release Hardening Review

Status: **BLOCKED FOR A 1.0 RELEASE CANDIDATE**

This report records the final planned release-hardening pass. It does not add
a transport, restart transport benchmarking, publish a package, or create a
release tag. The accepted architecture remains:

```text
Android       -> Cronet/HttpEngine
iOS/macOS     -> URLSession
Fallback      -> Dart IO
Public API    -> pure-Dart, transport-independent alphax contracts
```

The Phase 1E documentation and task record were pushed in commit
`4af24f3`. This report preserves the Phase 1F worktree evidence as a
historical release-hardening record; the strict 1.0 closure audit and policy
work are tracked separately in task 16.

## 1. Final API review

The public barrels were reviewed for accidental implementation leakage.

- `alphax` exports only transport-neutral requests, responses, bodies, files,
  streams, cancellation, timeouts, redirects, protocols, capabilities,
  metrics, middleware, and normalized errors.
- `alphax_native` exports only the three adapters and local-file helpers.
  Cronet, URLSession, Flutter-channel, FFI, C++, Rust, libcurl, and native
  handle types are not exported through `alphax`.
- `alphax_test` exports only deterministic test fakes, file fixtures, and the
  shared conformance helper.
- `alphax_dio` remains an empty optional boundary; no Dio adapter is included.
- The accidental public `AlphaXNativeTransportException` was removed from the
  pure-Dart package.
- The obsolete `ExperimentalAlphaXNativeTransport` placeholder and its test
  were removed from `alphax_native`.
- ADR 0005 remains Proposed; its completion-time metadata rules are preserved
  without changing the semantics.
  `AlphaXResponse.metrics` is best-known snapshot data; completion metrics and
  terminal stream metadata are authoritative when the provider reports late.

Final API freeze is **BLOCKED** by two scope/API mismatches that require a
maintainer decision before 1.0:

1. The accepted scope requires a transport-neutral certificate/trust policy
   surface (`AlphaXTlsPolicy` in the scope completion contract). The current
   API has secure platform defaults and capability reporting, but no public
   custom trust/certificate policy object.
2. The accepted scope requires an explicit proxy policy surface
   (`AlphaXProxyPolicy`) and a protocol preference/requirement distinction.
   The current API has `AlphaXProtocolPreference`, but no explicit “must use
   this protocol or fail” request contract and no proxy policy object.

These are not inferred implementation details. Adding them now would be a
public contract change affecting Dart IO, Cronet, and URLSession, so they are
recorded for maintainer review rather than invented during release hardening.

The reviewed inventory is in
[`docs/phase1a-public-api-inventory.md`](phase1a-public-api-inventory.md).

## 2. Capability and protocol matrix

The matrix uses only the release-scope classifications `SUPPORTED`,
`UNSUPPORTED`, `PLATFORM-MANAGED`, and `NOT APPLICABLE`.

| Capability | Dart IO | Android Cronet | iOS URLSession | macOS URLSession |
| --- | --- | --- | --- | --- |
| HTTP/1.1 | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED |
| HTTP/2 | UNSUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED |
| HTTP/3 | UNSUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED |
| actual protocol reporting | UNSUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED |
| preferred-protocol fallback reporting | UNSUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED |
| streamed request body | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED |
| streamed response body | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED |
| bounded backpressure | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED |
| file upload | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED |
| file download | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED |
| native file upload | UNSUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED |
| native file download | UNSUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED |
| upload progress | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED |
| download progress | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED |
| cancellation | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED |
| timeout semantics | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED |
| redirects | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED |
| TLS verification | PLATFORM-MANAGED | PLATFORM-MANAGED | PLATFORM-MANAGED | PLATFORM-MANAGED |
| proxy behavior | UNSUPPORTED | PLATFORM-MANAGED | PLATFORM-MANAGED | PLATFORM-MANAGED |
| explicit proxy configuration | UNSUPPORTED | UNSUPPORTED | UNSUPPORTED | UNSUPPORTED |
| certificate pinning | UNSUPPORTED | UNSUPPORTED | UNSUPPORTED | UNSUPPORTED |
| mTLS | UNSUPPORTED | UNSUPPORTED | UNSUPPORTED | UNSUPPORTED |
| connection migration | UNSUPPORTED | PLATFORM-MANAGED | UNSUPPORTED | UNSUPPORTED |
| background transfer | UNSUPPORTED | UNSUPPORTED | UNSUPPORTED | UNSUPPORTED |

Capability is not negotiation. A provider can support H3 while an individual
request correctly negotiates H2 or H1. A request preference is not an actual
protocol result. `unknown` is valid until a transport has authoritative
completion data and never means H1 or fallback.

## 3. Security assertions

The deterministic server now provides a two-origin redirect fixture. The target
reports whether it received `Authorization`, `Proxy-Authorization`, or
`Cookie`. The server unit test passed and all three values were absent after a
cross-origin redirect using the fixture client.

The focused Flutter assertion is in
`benchmarks/mobile_gate/integration_test/phase1f_redirect_security_test.dart`.
It uses the Android Cronet or Apple URLSession adapter and asserts all three
headers are absent. The Apple adapter has an explicit sanitizer. Cronet's
public redirect API only exposes provider-managed `followRedirect()`, so the
Android assertion is required to establish the selected provider's behavior;
physical execution was attempted but is an environment blocker (see Section
6). Android cross-origin stripping is therefore not claimed complete.

TLS verification remains enabled by default. No trust-all callback, development
certificate, signing material, benchmark endpoint, or diagnostic QUIC hint was
added to a production package.

## 4. Release H3 and device evidence

### Android

Retained Phase 1C evidence remains authoritative historical evidence:

- device: Xiaomi M2003J6A1G;
- Android 15 / API 35 / arm64-v8a;
- provider: Google Play Services Cronet;
- provider version: `151.0.7922.29`;
- QUIC enabled;
- actual HTTP/3 negotiation captured in
  `benchmarks/mobile_gate/fixtures/phase1c_h3_cloudflare_verified.json`;
- H3 preference fallback to H2 is reported accurately when the path does not
  permit H3;
- the temporary QUIC hint remains historical evidence only and is absent from
  the provider policy and public API.

The Phase 1F release/profile rerun built the Android APK successfully, but the
connected device package manager hung during installation (`adb install` and
streaming/`pm install` attempts). The app therefore did not reach the focused
Phase 1F redirect/H3 assertions. This is an environmental device-install
blocker, not evidence of a protocol or TLS failure. A 1.0 release gate still
needs one successful release/profile run on a QUIC-permissive path with the
provider/version and actual protocol retained.

### iOS

Retained signed iPhone evidence remains available from Phase 1D/1E:

- physical iPhone, iOS 18.7.9, arm64;
- H1, H2, H3, and H3-preference fallback were observed through URLSession;
- streaming, bounded delivery, files, progress, cancellation, timeouts, TLS
  rejection, and lifecycle checks passed;
- the signed shared conformance runner passed during Phase 1F.

The additional Phase 1F focused protocol/security runner built and installed,
but the current Flutter/Xcode attachment failed with `osascript: -2`. A final
focused security attempt later waited without attaching and ended with the
iPhone no longer available to Flutter. No TLS, signing, or transport workaround
was used. The focused device-only assertions remain pending environment
recovery; the prior signed protocol and fallback evidence is preserved
unchanged.

### macOS

The retained macOS URLSession validation covers H1/H2/H3, H3→H1 fallback,
streaming/backpressure, files, progress, cancellation, timeouts, TLS, and
lifecycle. The Phase 1F focused protocol runner verified H1, H2, H3, and H3
preference→H1 fallback, and the focused cross-origin sensitive-header
assertion passed. No new performance matrix was run in Phase 1F.

## 5. Proxy behavior

Proxy behavior is deliberately capability-specific:

| Behavior | Result |
| --- | --- |
| Dart IO system/environment proxy | PLATFORM-MANAGED by Dart/OS; no AlphaX explicit policy |
| Android system/provider proxy | PLATFORM-MANAGED by Cronet/provider |
| Apple system proxy | PLATFORM-MANAGED through `URLSessionConfiguration.default` |
| AlphaX explicit per-session proxy | UNSUPPORTED |
| AlphaX proxy credentials API | UNSUPPORTED |
| HTTP CONNECT control/inspection | PLATFORM-MANAGED where the provider uses it |
| H3 through a proxy | PLATFORM-MANAGED; QUIC may be unavailable and final H2/H1 must be reported |

No active proxy was available on the validation Mac, so no runtime proxy route
or authentication result is claimed. The current API cannot configure or
reliably inspect explicit proxy behavior. This is a concrete API/scope blocker
for the required `AlphaXProxyPolicy` surface, not a reason to claim unsupported
proxy modes are direct connections.

## 6. Package, metadata, and release configuration

Completed in the Phase 1F worktree:

- package descriptions, repository URLs, issue tracker URLs, homepage, topics,
  SDK constraints, platform metadata, and pre-release changelogs were reviewed;
- the Android plugin version was normalized from `1.0-SNAPSHOT` to `0.1.0`;
- README now includes installation, GET, streaming, cancellation, file
  transfer, capability/protocol reporting, platform matrix, fallback behavior,
  security defaults, timeout/error semantics, limitations, and migration links;
- `docs/MIGRATION.md` maps common `package:http` and Dio usage without
  promising a full Dio adapter;
- `examples/basic` demonstrates GET, cancellation, streaming, download/upload,
  and capability/protocol reporting;
- all shipped public symbols have Dartdoc coverage; dartdoc dry-run and link
  validation passed for `alphax`, `alphax_native`, `alphax_test`, and
  `alphax_dio`;
- CocoaPods remains the 1.0 Apple packaging path. Swift Package Manager is
  explicitly deferred and is not required for this release gate;
- production package manifests contain no Rust runtime, libcurl, C++ engine,
  benchmark server/client, or test fixture dependency;
- the local iOS development-team setting remains only in the uncommitted
  mobile-gate Xcode project and is not eligible for commit;
- Android cleartext fixture permissions, Apple local endpoints/ATS settings,
  diagnostic QUIC hints, and signing settings remain isolated from production
  plugin defaults.

Package archive sizes, where measured, are source-package observations and are
not final application-size claims. Native provider/runtime distribution remains
an application/platform responsibility and is documented separately.

## 7. Required 1.0 scope gate

The following table records every required category from
`docs/ALPHAX_1_0_SCOPE.md` as `COMPLETE` or `BLOCKED`; no vague planned state is
used.

| Required item | Status | Evidence or concrete blocker |
| --- | --- | --- |
| HTTP/1.1 | COMPLETE | Dart IO, Android, Apple, Linux/Windows fallback evidence. |
| HTTP/2 | COMPLETE | Android and Apple protocol evidence retained. |
| HTTP/3 | BLOCKED | Capability and retained H3 evidence exist, but Phase 1F release/profile Android acceptance could not install the APK; focused iPhone rerun could not attach. |
| Negotiated protocol reporting | COMPLETE | Completion-time metrics and retained Android/Apple actual protocol evidence; unknown is not coerced. |
| Fallback reporting | COMPLETE | H3→H2/H1 fallback evidence retained and tested. |
| Android Cronet/HttpEngine transport | BLOCKED | Adapter is implemented and H3-capable evidence exists; release-profile device acceptance is blocked by package-manager installation. |
| iOS URLSession transport | BLOCKED | Adapter and signed evidence exist; Phase 1F focused physical-device rerun is blocked by Flutter/Xcode attachment. |
| macOS URLSession transport | COMPLETE | H1/H2/H3, fallback, stream/file/lifecycle validation retained. |
| Dart IO fallback | COMPLETE | Phase 1B conformance and H1 fallback behavior pass. |
| Capability discovery | COMPLETE | Immutable capability model and provider-aware outputs are implemented. |
| Client/session reuse | COMPLETE | Reusable HttpClient/engine/URLSession lifecycle checks pass. |
| GET | COMPLETE | Shared and platform conformance evidence. |
| POST | COMPLETE | Shared and platform conformance evidence. |
| PUT | COMPLETE | Shared and platform conformance evidence. |
| PATCH | COMPLETE | Shared and platform conformance evidence. |
| DELETE | COMPLETE | Shared and platform conformance evidence. |
| HEAD | COMPLETE | Shared and platform conformance evidence. |
| OPTIONS | COMPLETE | Shared and platform conformance evidence. |
| Headers | COMPLETE | Immutable case-insensitive multi-value core and adapter tests. |
| Query parameters | COMPLETE | Immutable URI behavior and request tests. |
| Byte body | COMPLETE | Exact byte body tests. |
| Text body | COMPLETE | UTF-8 text body tests. |
| JSON helpers | COMPLETE | `dart:convert` request/response helper tests. |
| Streamed request body | COMPLETE | Shared request-stream lifecycle evidence. |
| Streamed response body | COMPLETE | Shared bounded streaming and body lifecycle evidence. |
| Redirects | BLOCKED | Core policy and Apple sanitizer exist; Cronet header mutation is provider-managed and the focused Android/iPhone sensitive-header assertions are blocked by device/tooling state. |
| Multipart/form-data | COMPLETE | Transport-neutral body model and adapter conformance evidence. |
| Cancellation | COMPLETE | Setup, upload, response, stream, file, pause, close cases retained. |
| Connect/request/read/overall timeout semantics | COMPLETE | AlphaX timers are emulated consistently; phase precision is not claimed. |
| Deterministic close and request cleanup | COMPLETE | Repeated close, post-close rejection, active cleanup, and resource checks. |
| Error normalization | COMPLETE | Stable public categories with platform causes diagnostic-only. |
| Bounded backpressure | COMPLETE | Dart stream semantics and native 256 KiB bounded windows. |
| Upload progress | COMPLETE | Monotonic upload progress and completion checks retained. |
| Download progress | COMPLETE | Monotonic download progress and completion checks retained. |
| File upload | COMPLETE | Exact bytes, deterministic hash, cancellation, and cleanup evidence. |
| File download | COMPLETE | Exact bytes, deterministic hash, cancellation, and cleanup evidence. |
| Native file-backed transfer where supported | COMPLETE | Android and Apple native paths validated in retained evidence. |
| TLS verification by default | COMPLETE | Platform trust defaults and invalid-certificate rejection evidence. |
| Certificate configuration where platform permits | BLOCKED | Required `AlphaXTlsPolicy`/custom trust surface is absent; no misleading API was added. |
| Proxy behavior and capability reporting | BLOCKED | Platform-managed behavior is documented, but required `AlphaXProxyPolicy`/explicit configuration surface is absent. |
| Transport-independent public API | COMPLETE | Pure-Dart `alphax` boundary and adapter-neutral contracts. |
| No native transport-specific public types | COMPLETE | Export review and accidental native export cleanup. |
| Capability model | COMPLETE | Protocol and optional capability states are explicit. |
| Protocol enum | COMPLETE | `unknown`, H1, H2, H3 and fallback models are transport-neutral. |
| Transport-neutral metrics | COMPLETE | Nullable metrics and authoritative completion snapshot. |
| Middleware/interceptor foundation | COMPLETE | Ordering, short-circuit, async, error, and stream restrictions tested. |
| Testing/fake transport support | COMPLETE | `alphax_test` fake and shared conformance suite. |
| Clear README examples | COMPLETE | Hardened README and runnable-oriented example. |
| Consistent errors | COMPLETE | Categories and diagnostic-cause policy documented. |
| Immutable request/response models | COMPLETE | Immutable metadata/headers with explicit stream/file lifecycle. |
| Package documentation | COMPLETE | Package READMEs, compatibility, security, migration, and release reports. |
| Migration guidance | COMPLETE | `package:http` and Dio mapping with unsupported boundaries stated. |

The following scope boundaries remain deliberate and are not release blockers:

- `OPTIONAL FOR 1.0`: focused Dio adapter, cookie jar, request priorities,
  certificate pinning, and mTLS;
- `POST-1.0`: cache, retry/resilience, circuit breaker, offline queue,
  OpenTelemetry, DevTools extension, WebSocket, SSE, and browser/web
  transport;
- `EXPLICIT NON-GOAL`: Sentry/Firebase Performance integration, GraphQL, REST
  generation, and an authentication framework.

No deferred capability is being silently counted as complete, and no deferred
feature is being implemented as part of Phase 1F.

The explicit blockers are: release-profile physical acceptance on the current
Android/iPhone environments, the two missing policy/requirement API surfaces,
and the physical redirect-security assertion. They require maintainer review
or environment recovery; they do not justify a new benchmark round or a new
transport.

## 8. Final validation record

Completed focused checks:

- Dartdoc dry-run and link validation for all four packages — passed;
- deterministic server tests, including the cross-origin fixture — passed;
- Flutter basic example dependency resolution and analysis — passed;
- signed iPhone shared conformance runner — passed;
- Android Phase 1F profile APK build — passed, installation blocked;
- focused iPhone Phase 1F runner build/install — built and installed, attach
- focused iPhone Phase 1F runner — blocked by the local Flutter/Xcode
  attachment/device-availability issue (`osascript: -2`, then no supported
  device after the final focused attempt);
- macOS Phase 1F protocol and cross-origin security runners — passed;
- retained macOS, Android, and signed iPhone H3/fallback evidence preserved.

- formatting, Dart/Flutter analysis, package tests, benchmark/server tests,
  package dry-runs, dartdoc dry-run/link checks, example tests, mobile-gate
  analysis, macOS harnesses, iOS no-code-sign build, Android profile build,
  Markdown checks (with the repository’s long-table line-length rule disabled),
  `git diff --check`, and secret/signing/native-dependency audits — passed;
- package dry-runs report only expected dirty-worktree warnings, including the
  deleted obsolete placeholder file, and did not publish anything.

Any local iOS development-team setting must remain unstaged.

## 9. Release-candidate decision

**AlphaX is not ready for a 1.0 release candidate.** The transport architecture
is unchanged and the implementation evidence is substantial, but the release
gate cannot be honestly marked complete while the following remain unresolved:

1. maintainer decision on the missing transport-neutral TLS policy and explicit
   proxy/protocol-requirement surfaces;
2. one release/profile Android H3 run on a QUIC-permissive physical device;
3. verification of the selected Cronet provider's cross-origin stripping for
   Authorization, Proxy-Authorization, and Cookie, or a reviewed adapter
   change that makes the behavior explicit;
4. focused signed iPhone protocol and redirect-security execution after the
   Flutter/Xcode attachment environment is repaired.

No Phase 1G work, package publication, or 1.0 tag should begin until these
blockers are reviewed. No broad benchmark rerun is required.
