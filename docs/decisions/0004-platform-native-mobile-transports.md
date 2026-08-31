# ADR-0004: Platform-Native Mobile Transports

- Status: Accepted
- Date: 2026-08-14

## Context

AlphaX Phase 0 established a Dart IO recommendation for the measured
HTTP/1.1 workloads. That recommendation remains valid as a performance result
for those workloads, but it cannot be the sole AlphaX 1.0 transport because
HTTP/1.1, HTTP/2, and HTTP/3 are mandatory protocol goals on Android, iOS, and
macOS.

The existing Dart IO prototype provides the fallback/baseline behavior and does
not provide an AlphaX H3 path. The libcurl prototype demonstrates useful native
H1/H2 and file-transfer behavior, but a mobile H3 build would require AlphaX to
ship and maintain a complete curl/TLS/QUIC/HTTP2 dependency graph. The Rust
prototype is configured for reqwest H1/H2 and does not enable H3; its available
reqwest/h3 path remains an unstable/experimental production risk.

The public `alphax` package must remain pure Dart and must not expose Cronet,
URLSession, libcurl, Rust, or FFI types. Actual protocol negotiation and any
fallback must remain observable and accurate.

Evidence retained from Phase 0:

- [Final HTTP/1.1 transport decision](../../benchmarks/results/summaries/phase0-final-transport-decision.md)
- [Mobile HTTP/1.1 sanity gate](../../benchmarks/results/summaries/phase0-mobile-sanity-gate.md)
- [Protocol capability investigation](../../benchmarks/results/summaries/phase0-protocol-capability-investigation.md)
- [ADR-0003: public API transport independence](0003-public-api-transport-independence.md)

The maintainer approved the 1.0 scope and this ADR on 2026-08-14. The decision
authorizes the bounded Phase 1A contract work and later platform transport
phases described by the scope; it does not authorize Phase 1B–1F to begin
automatically.

## Decision

Adopt the following AlphaX 1.0 architecture:

1. Android uses a platform-native Cronet/HttpEngine-backed transport. The
   adapter owns one reusable engine/session policy, maps native callbacks to
   the transport-neutral AlphaX contract, and reports provider/protocol
   capabilities. It must not silently claim H2/H3 when the installed provider
   cannot provide them.
2. iOS and macOS use a shared URLSession-backed transport adapter. It maps data,
   streamed, upload, and download tasks to the same public contract and reports
   the protocol actually negotiated by URLSession.
3. Dart IO remains the fallback/baseline transport. It implements the common
   supported surface and reports its H2/H3 limitations explicitly. It is not
   selected as the 1.0 H3 solution.
4. Windows/Linux may use Dart IO initially. A native H3 backend for those
   targets requires a separate architecture decision and release validation.
5. The public API remains transport-independent. Platform selection is by target
   platform, not by workload benchmark category; applications do not choose
   Dart for uploads, Cronet for downloads, or another provider for streaming.
6. No AlphaX-owned C++ engine and no production Rust transport are part of this
   1.0 architecture.

The required public contract includes protocol/capability discovery, negotiated
protocol and fallback reporting, reusable client/session lifecycle, bounded
streaming, file transfers, cancellation, timeout/error semantics, secure TLS
defaults, proxy capability reporting, and transport-neutral metrics. The
current package and transport boundaries are summarized in the
[architecture overview](../architecture/overview.md) and
[transport contract](../architecture/transport_contract.md).

## Why Dart IO is not the sole 1.0 transport

Dart IO uses an asynchronous API and remains a valid low-complexity fallback.
However, the current `HttpClient` path does not provide the required AlphaX H3
capability. Keeping Dart IO as the sole production transport would either omit
the mandatory H3 goal or require a new protocol implementation outside the
validated Phase 0 architecture. The prior benchmark result is therefore
preserved as H1 evidence, not extended into an H2/H3 architecture claim.

## Why Android chooses Cronet/HttpEngine

Cronet/HttpEngine provides the closest Android-native path to the required H1,
H2, and H3/QUIC capability, with asynchronous callbacks, cancellation, native
stream handling, provider-level TLS/proxy controls, and documented QUIC
connection migration options. The provider policy must distinguish Google Play
Services, embedded, and fallback behavior so an unavailable H3 capability is
reported rather than hidden.

This decision consumes the platform networking implementation; it does not add
an AlphaX-owned C++ engine. Android packaging, provider availability, minimum
API levels, and device validation remain explicit release concerns.

## Why iOS/macOS choose URLSession

URLSession is the Apple system client with documented HTTP/1.1, HTTP/2, and
HTTP/3 support, native data/stream/upload/download task forms, cancellation,
system proxy behavior, and OS-managed TLS integration. It avoids bundling a
separate QUIC/TLS runtime into Apple application artifacts while allowing the
adapter to report the protocol actually negotiated by the OS.

The adapter must document deployment-target differences, ATS, signing,
background/file-task boundaries, and the fact that H3 may correctly fall back
when the server or network does not support it.

## Why Dart IO remains fallback/baseline

Dart IO has the smallest distribution and build footprint, a simple pure-Dart
integration, asynchronous request/response streams, and the strongest existing
Phase 0 evidence. It remains useful on Windows/Linux and on mobile/Apple when a
native provider is unavailable or a caller accepts the reported protocol
ceiling. Its capabilities must be discoverable and its lack of H3 must never be
masked.

## Why libcurl is not the mobile default

libcurl is a credible cross-platform native client and remains a useful research
and possible desktop option. H3 requires a coordinated libcurl,
ngtcp2, nghttp3, and QUIC-capable TLS build. On mobile, AlphaX would own ABI
packaging, TLS trust integration, dependency updates, proxy behavior, and the
security/build matrix for that entire stack. The small FFI bridge measured in
Phase 0 is not the complete deployable H3 artifact.

That cost is not justified as the default mobile architecture when the target
platforms already provide mature H1/H2/H3 clients.

## Why Rust H3 is not selected for 1.0

The Rust prototype currently enables reqwest H1/H2/streaming with rustls; it
does not enable an H3 feature or QUIC transport. Enabling H3 would add the
unstable reqwest/h3/QUIC path, a larger per-ABI stack, cross-compilation and C
ABI work, and a separate security/update surface. Rust remains a valid research
candidate, but its current H3 maturity and implementation cost do not meet the
1.0 decision gate.

## Why this is a platform strategy, not a workload-based hybrid

Android and Apple use different operating-system networking APIs because those
are the platform-native sources of the required protocol capability. The
selection boundary is the target platform, and every platform exposes the same
AlphaX contract. There is no request-level rule that picks a transport because
it wins a particular microbenchmark category.

This avoids shipping three interchangeable native engines on the same device,
reduces the mobile dependency graph, and keeps fallback behavior explicit. The
cost is platform adapter code and provider-specific capability differences;
those differences are contained behind the public contract and tested as part
of the 1.0 matrix.

## Consequences

Positive:

- AlphaX can satisfy the H1/H2/H3 capability goal on Android, iOS, and macOS
  without making the pure-Dart core depend on a native library.
- TLS, protocol framing, QUIC, connection management, and native file paths can
  remain outside the Dart isolate where the platform API supports them.
- Mobile distribution cost is lower than bundling a complete libcurl or Rust H3
  stack on every ABI, subject to the Android provider choice.
- Dart IO remains an honest, testable fallback rather than an invalid H3 claim.

Costs and risks:

- Android provider availability and versioning require an explicit capability
  and fallback policy.
- iOS/macOS deployment targets and OS behavior influence H3 availability and
  TLS/proxy controls.
- Two native adapter implementations increase CI, device testing, lifecycle,
  and debugging work compared with Dart IO alone.
- Streamed bodies still cross into Dart when the public API returns a Dart
  stream; native file-backed operations require separate API and lifecycle tests.
- Windows/Linux do not receive a native H3 guarantee under this decision.

## Revisit conditions

Reopen this ADR only if one of these concrete conditions occurs:

- A supported Android, iOS, or macOS OS/provider cannot meet the required
  protocol/correctness contract.
- A platform API removes a required lifecycle, security, proxy, streaming, or
  file capability that the public contract depends on.
- Windows/Linux H3 becomes a mandatory 1.0 platform requirement.
- A separately validated libcurl or Rust H3 implementation demonstrates a
  materially simpler, safer, and more maintainable cross-platform release
  architecture than the platform strategy.
- A public API compatibility change becomes necessary; that change requires a
  new ADR or an explicit revision to this one.

Any revisit must preserve the historical Phase 0 datasets and add correctness,
distribution, build, maintenance, and platform evidence. A performance result
alone is insufficient.
