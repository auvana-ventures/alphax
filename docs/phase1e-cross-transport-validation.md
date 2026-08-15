# Phase 1E — Cross-Transport Parity and Release Validation

Status: Complete for maintainer review. Phase 1F has not started.

This is a correctness, capability, packaging, security, and release-configuration
review. It is not a new transport-selection round and contains no new performance
measurements.

## 1. Final capability matrix

The cells use only the required classifications: `SUPPORTED`, `UNSUPPORTED`,
`PLATFORM-MANAGED`, and `NOT APPLICABLE`.

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
| timeout categories | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED |
| redirects | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED |
| TLS verification | PLATFORM-MANAGED | PLATFORM-MANAGED | PLATFORM-MANAGED | PLATFORM-MANAGED |
| proxy behavior | UNSUPPORTED | PLATFORM-MANAGED | PLATFORM-MANAGED | PLATFORM-MANAGED |
| certificate pinning | UNSUPPORTED | UNSUPPORTED | UNSUPPORTED | UNSUPPORTED |
| mTLS | UNSUPPORTED | UNSUPPORTED | UNSUPPORTED | UNSUPPORTED |
| connection migration | UNSUPPORTED | PLATFORM-MANAGED | UNSUPPORTED | UNSUPPORTED |
| background transfer | UNSUPPORTED | UNSUPPORTED | UNSUPPORTED | UNSUPPORTED |

`SUPPORTED` for Android H2/H3 means the selected non-fallback Cronet provider
can attempt the protocol. It does not mean every request negotiates it. The
accepted Phase 1C evidence contains an actual Android H3 negotiation; the
current profile rerun on the available path negotiated H2 and reported the H3
fallback accurately. `PLATFORM-MANAGED` proxy behavior means the underlying
system may apply proxy settings, not that AlphaX exposes explicit proxy
configuration. Android connection migration is left to the provider and is not
controlled or promised by AlphaX.

## 2. Validation environments and protocol evidence

The production transport architecture remains:

```text
Android  -> Google Play Services Cronet/HttpEngine provider
iOS      -> Foundation URLSession
macOS    -> Foundation URLSession
fallback -> dart:io HttpClient
```

No C++ engine, production Rust transport, or production libcurl transport was
added.

| Target | Environment | H1 | H2 | H3 | Fallback |
| --- | --- | --- | --- | --- | --- |
| Dart IO | Dart package integration fixture | verified | not supported | not supported | explicit H2/H3 preference rejected as unsupported |
| Android | physical `M2003J6A1G`, Android 15/API 35, arm64-v8a, Google Play Services Cronet `151.0.7922.29` | verified | verified | verified in retained Phase 1C focused evidence | current profile rerun: H3 preference → H2, reported truthfully |
| iPhone | physical iPhone, iOS 18.7.9, arm64 | verified | verified with `https://www.apple.com/` | verified with `https://cloudflare-quic.com/` | H3 preference → H1 on deterministic fixture |
| macOS | macOS 26.5.2 arm64 profile harness | verified | verified with `https://www.apple.com/` | verified with `https://cloudflare-quic.com/` | H3 preference → H1 on local fixture |

Android’s retained H3 fixture is preserved in
`benchmarks/mobile_gate/fixtures/phase1c_h3_cloudflare_verified.json` and
`docs/phase1c-android-transport-review.md`. The temporary QUIC hint used to
obtain that diagnostic evidence is not present in the provider implementation
or policy. The current Android rerun used the ordinary provider configuration;
its H3→H2 result is valid fallback evidence, not a protocol-reporting failure.

Apple’s signed physical-device run recorded actual `http3` task metrics and
actual H1 fallback. The macOS rerun after the focused `OPTIONS` body fix passed
H1, H2, H3, fallback, methods, streaming, files, cancellation, timeout, TLS,
progress, and lifecycle checks.

## 3. Shared conformance and required HTTP behavior

Validation results:

- `alphax`: 28 tests passed;
- `alphax_native`: 33 tests passed, including Dart IO conformance, protocol
  mapping, capability reporting, body forms, redirects, timeouts, cancellation,
  file transfer, TLS, and lifecycle checks;
- `alphax_test`: 9 tests passed;
- the Apple `flutter drive` runner passed the shared transport conformance
  integration test on the signed iPhone;
- the Android physical correctness harness passed the transport-neutral checks
  for methods, headers, streams, redirects, cancellation, files, progress,
  reuse, and protocol reporting;
- the macOS correctness harness passed the corresponding Apple behaviors.

The required methods are covered across the adapters: `GET`, `POST`, `PUT`,
`PATCH`, `DELETE`, `HEAD`, and `OPTIONS`. Empty, bytes, text, JSON, stream,
file, and multipart body abstractions remain transport-neutral. Non-replayable
stream bodies are not silently replayed across redirects.

The Apple adapter uses a data-backed upload task for materialized `OPTIONS`
bodies because the current Foundation runtime can omit an `httpBody` attached
to an `OPTIONS` data task. This is an internal adapter detail; the public
contract is unchanged.

## 4. Completion-time protocol metadata

ADR 0005 is preserved and validated:

```text
AlphaXResponse.metrics
    -> best-known snapshot at response/header time

AlphaXResponse.completionMetrics
    -> authoritative final metrics future

AlphaXResponseCompleted
    -> authoritative terminal stream metadata
```

The tests prove that:

- `AlphaXProtocol.unknown` is valid at request start and response headers;
- a transport that knows the protocol early may report it early;
- a transport such as URLSession may report `unknown` at stream start and a
  concrete protocol at completion;
- fallback metadata is derived only from a known final protocol and a concrete
  preference; and
- unknown never means HTTP/1.1 and never implies fallback.

Dart IO retains unknown protocol metadata because it cannot honestly observe the
negotiated protocol. Cronet and URLSession supply authoritative completion
protocols when their providers expose them.

## 5. Streaming, backpressure, and file parity

All three transports expose progressive response delivery, consumer pause and
resume, cancellation, terminal completion, and normalized stream errors.

| Transport | Delivery/buffering model | File paths |
| --- | --- | --- |
| Dart IO | Dart stream subscription backpressure; no AlphaX-owned unbounded queue | network → Dart stream → file; file → Dart stream → network |
| Android Cronet | four 64 KiB native read credits, 256 KiB outstanding window | native file read/write for local file abstractions |
| Apple URLSession | four 64 KiB credits, 256 KiB queued window plus one bounded platform callback | `URLSessionDownloadTask`/upload task for local file abstractions |

The Android and Apple harnesses paused and resumed a bounded response, retained
complete bytes, and released resources on cancellation. The native file paths
validated exact byte counts and FNV-1a64 hash `4c568eccaeaf6c44` for the 1 MiB
fixture. Native paths are described as direct/native file-backed paths, not
zero-copy.

Upload and download progress is monotonic and capability-aware. Dart file
transfers remain valid fallback behavior; applications use the same public API
regardless of whether a native path is selected.

## 6. Cancellation, timeouts, redirects, and errors

Cancellation passed before start, during setup, upload/response work, streaming,
paused delivery, file transfer, and client close in the applicable platform
harnesses. Repeated cancellation and close are idempotent. Native cancellation
errors are normalized to `AlphaXCancellationException`.

### Timeout mapping

| Phase | Dart IO | Android Cronet | Apple URLSession |
| --- | --- | --- | --- |
| connect | EMULATED | EMULATED | EMULATED |
| request | EMULATED | EMULATED | EMULATED |
| read | EMULATED | EMULATED | EMULATED |
| overall | EMULATED | EMULATED | EMULATED |

Apple also applies URLSession’s native request timeout as a platform guard, but
AlphaX timers preserve the public phase category. None of the transports claims
portable DNS, TCP, or TLS phase precision that the provider does not expose.

Redirect behavior is supported with follow/manual/reject policy, limits,
relative locations, metadata, and non-replayable-body protection. The Apple
adapter strips `Authorization`, `Proxy-Authorization`, and `Cookie` on
cross-origin follow; same-origin behavior remains provider-managed.

The application-facing error mapping is transport-neutral:

| AlphaX category | Dart IO | Android | Apple |
| --- | --- | --- | --- |
| DNS | normalized | normalized | normalized |
| connection | normalized | normalized | normalized |
| TLS | normalized | normalized | normalized |
| timeout | normalized | normalized | normalized |
| cancellation | normalized | normalized | normalized |
| protocol | normalized | normalized | normalized |
| redirect | normalized | normalized | normalized |
| request body | normalized | normalized | normalized |
| response body | normalized | normalized | normalized |
| unsupported capability | normalized | normalized | normalized |
| transport/internal | normalized | normalized | normalized |

SocketException, NSError, Cronet exceptions, and native codes remain optional
diagnostic causes only.

## 7. Lifecycle and capability accuracy

Each production adapter reuses one client/session/engine per logical transport:

- Dart IO owns one reusable `HttpClient`;
- Android owns one Cronet engine, bounded executor set, and active-operation
  registry;
- Apple owns one URLSession and serial delegate queue.

All applicable harnesses verified sequential/concurrent use, close with active
work, repeated close, request-after-close rejection, and cleanup. No adapter
creates a new engine or session per request.

Capability discovery is provider/runtime state, not per-request negotiation.
Android reports the selected provider name/version and does not silently replace
an unavailable native provider with Dart IO. Apple reports H1/H2/H3 as
attemptable on iOS 15+/macOS 12+; task metrics remain authoritative.

## 8. Dependency and artifact observations

The production dependency graph is:

```text
alphax              pure Dart; no Flutter dependency
alphax_test         alphax + package:test
alphax_native       alphax + Flutter plugin boundary
  Android           Google Play Services Cronet 18.0.1; provider/runtime managed
  iOS/macOS         Foundation URLSession through the CocoaPods plugin boundary
alphax_dio          skeleton only; no Dio runtime dependency
benchmarks/protos   separate workspace tooling; not production dependencies
```

There is no Rust, libcurl, C++, benchmark server, or benchmark client
dependency in the production transport packages. Package dry-run observations
were approximately 24 KiB compressed for `alphax`, 57 KiB for `alphax_native`,
7 KiB for `alphax_test`, and 4 KiB for `alphax_dio`. These are source-package
archives, not application artifact increments.

The disposable profile validation artifacts were approximately 78.6 MiB for
the current Android APK, 23.6 MiB for the iOS app, and 60.9 MiB for the macOS
app. They include Flutter application/runtime content and must not be used as
AlphaX incremental-size claims. Android’s selected provider is not an embedded
Chromium runtime in the AlphaX package; the host application must account for
the Play Services dependency in its own release artifact.

## 9. Platform support statement

The evidence-based 1.0 platform statement is:

- Android API 24+ can use the selected Cronet/HttpEngine provider for H1/H2/H3,
  with actual per-request protocol reporting and truthful fallback. A host must
  ship/use an H3-capable non-fallback provider for H3 capability.
- iOS 15+ uses URLSession for H1/H2/H3 where the Apple stack and network path
  permit them; actual protocol and fallback are reported at completion.
- macOS 12+ uses URLSession with the same H1/H2/H3 and completion-reporting
  semantics.
- Dart IO is the H1 fallback/baseline and does not advertise H2/H3.
- Linux and Windows initially use the Dart IO fallback and must not be
  described as AlphaX H2/H3 platforms.
- Web remains outside the current implementation and is supported only where a
  future browser transport can satisfy the contract.

This is not a claim that every request on every network uses HTTP/3.

## 10. Focused security review

| Area | Finding |
| --- | --- |
| TLS defaults | Dart IO, Cronet, and URLSession retain platform certificate verification; invalid-certificate checks rejected the test certificate where exercised. |
| Trust bypass | No trust-all callback, diagnostic QUIC hint, or certificate bypass exists in production transport code. |
| Redirect credentials | Apple strips sensitive headers on cross-origin redirects; Android/Dart retain provider/adapter redirect semantics. A dedicated cross-origin device assertion remains a release checklist item. |
| File paths | Native file operations use caller-provided AlphaX file abstractions; temporary URLSession download files are finalized before completion, and partial operations are cancelled/closed. |
| Native messages | Request IDs, operation maps, body maps, and capability maps are validated before use; unknown operations fail or are ignored deterministically. |
| Diagnostics/logging | Application-facing errors are normalized; no transport code intentionally logs authorization, cookie, or proxy credentials. |
| Provider updates | Android release apps inherit the Google Play Services Cronet provider update responsibility and must validate provider capability during release acceptance. |
| Test-only network policy | Cleartext/local-network allowances exist only in `benchmarks/mobile_gate`; the production plugin has no cleartext test manifest or development endpoint. |

The code review found no secret, credential, certificate, provisioning profile,
machine path, or signing-team identifier in the pushed Phase 1D commit. The local
validation Runner team setting is intentionally uncommitted developer
configuration.

## 11. Release-configuration findings

- Android H1 fixture cleartext permission is confined to the disposable mobile
  gate app and is not part of `alphax_native`.
- Apple invalid-TLS and local fixture endpoints are harness defines only.
- The temporary Android QUIC hint is historical evidence only; no
  `addQuicHint` call is part of the general provider policy or public API.
- Physical iPhone signing is host-application configuration. The repository
  commit contains no development-team ID, provisioning profile, certificate,
  or signing credential.
- Apple packaging currently uses CocoaPods. Flutter reports that the plugin
  does not yet support Swift Package Manager; this is a packaging follow-up,
  not a transport-contract difference.
- A direct XcodeBuildMCP workspace/no-code-sign invocation on this host hit a
  missing CocoaPods `Pods_Runner` aggregate-framework search path; the
  canonical `flutter build ios --profile --no-codesign --no-pub` path passed.
  This is a local tooling-integration issue, not a production transport or
  signing-secret issue.
- Package dry runs, Dart/Flutter analysis, profile builds, and test harness
  checks use the test fixtures explicitly and do not alter production defaults.

## 12. Remaining 1.0 blockers and risks

The transport layer is ready for AlphaX 1.0 hardening, but it is not a 1.0
release claim yet. The remaining required work is bounded to:

1. Phase 1F API/documentation/release hardening and maintainer review.
2. Release-app acceptance of the Android H3-capable provider on at least one
   QUIC-permissive physical device/network. The accepted Phase 1C H3 evidence
   satisfies the adapter capability investigation; the current rerun’s H2
   fallback shows why release claims must use actual negotiated metadata.
3. A focused cross-origin redirect security regression assertion before release,
   using the existing physical-platform harnesses; the stripping code path is
   implemented and reviewed but was not added as a new benchmark matrix here.
4. A packaging decision for CocoaPods versus future Swift Package Manager
   distribution if SPM support becomes a release requirement.

The following are not Phase 1E blockers because they are excluded or optional
in the approved 1.0 scope: explicit proxy configuration, certificate pinning,
mTLS, connection-migration control, background transfer, Dio integration,
caching, retry/resilience, observability, WebSocket/SSE, GraphQL, REST
generation, and Windows/Linux native H2/H3 transports.

## 13. Validation record

The consolidated validation pass completed with:

- `dart format --set-exit-if-changed .` and `git diff --check` — passed;
- Dart package analysis — passed for `alphax`, `alphax_native`, `alphax_test`,
  `alphax_dio`, and benchmark packages;
- package tests — passed;
- prototype analysis, benchmark contract, and benchmark harness tests — passed;
- `flutter analyze --no-pub` for the mobile gate — passed;
- `flutter build ios --profile --no-codesign --no-pub` — passed;
- macOS profile correctness harness — passed;
- signed iPhone `flutter drive` shared conformance — passed;
- Android profile physical correctness harness — H1/H2/stream/file/cancel/
  lifecycle checks passed; H3 preference correctly fell back to H2 on the
  current path, with retained Phase 1C actual H3 evidence;
- package dry-run publication validation — passed with only expected dirty-tree
  warnings;
- staged/commit audit — no signing material, credentials, machine paths, or
  production Rust/libcurl/C++ dependencies found.

No package was published. Phase 1F was not started.
