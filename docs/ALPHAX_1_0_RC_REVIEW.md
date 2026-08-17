# AlphaX 1.0 RC Review

Review date: 2026-08-17
Proposed version: `1.0.0-rc.1`  
Review scope: release-candidate preparation plus the deliberately bounded
optional Dio adapter package, non-H3 policy/Web capability preparation, and
release-validation blocker closure. No transport architecture, benchmark,
publication, tag, or GitHub release work is included.

## 1. Proposed version and publication set

The proposed first release candidate is `1.0.0-rc.1`.

Packages intended for RC publication:

- `alphax`
- `alphax_test`
- `alphax_dio`
- `alphax_native`

`alphax_dio` is now version `1.0.0-rc.1` and publishable as a focused Dio 5.x
`HttpClientAdapter` over an injected `AlphaXClient`. It is optional to the
native transport gate and does not claim full Dio source/API compatibility.

`alphax_web` is prepared as a separate browser Fetch adapter. It is not added
to the previously approved native RC publication set without maintainer
approval.

## 2. Publication order

The dependency-aware partial order is:

1. `alphax`
2. `alphax_test`
3. `alphax_dio` and `alphax_native` (independent branches)

The proposed linear publication order is `alphax` → `alphax_test` →
`alphax_dio` → `alphax_native`. The order follows the manifests:
`alphax_test` depends on `alphax`; `alphax_dio` depends on `alphax` at runtime
and `alphax_test` for development tests plus external Dio 5.x; and
`alphax_native` depends on `alphax` at runtime and `alphax_test` for
development/conformance testing. No package was published during this review.

## 3. Git state and release commits

The final release-gate work and retained focused device evidence are captured
in these logical commits:

- `7cbe8db` — `test: complete AlphaX 1.0 release acceptance`
- `896ddb0` — `docs: close AlphaX 1.0 release gate`
- `8b2975b` — `feat: add AlphaX Dio RC adapter`

The final task-18 traceability record is committed separately as the RC
closeout. The final handoff reports that closeout commit together with the
release-gate and Dio adapter commits after push verification.

The current release-preparation work is captured in these commits:

- `534b627` — `feat: complete AlphaX 1.0 RC capabilities`
- `25cb525` — `docs: finalize AlphaX 1.0 RC release gate`

No historical release commit is rewritten.

## 4. Public API freeze

The inventory in
[`docs/phase1a-public-api-inventory.md`](phase1a-public-api-inventory.md) is
marked `FROZEN FOR 1.0.0-RC.1` and was checked against:

- `docs/ALPHAX_1_0_SCOPE.md`
- `docs/ALPHAX_1_0_REQUIREMENTS_AUDIT.md`
- `docs/ALPHAX_1_0_RELEASE_GATE.md`

The frozen boundary covers `AlphaXClient`, request/response contracts,
transport-neutral body/file/stream abstractions, cancellation, timeouts,
redirects, middleware, protocol preference and requirement, actual protocol
and fallback metadata, capabilities, metrics, TLS policy, trust anchors, SPKI
pins, proxy policy, normalized errors, and the opt-in retry, authentication,
cookie, cache, and resilience policy contracts.

The barrel review found no accidental exports. `alphax` exports only its
transport-neutral contracts; `alphax_native` exports the Dart IO, Android
Cronet, Apple URLSession, and local-file entry points; `alphax_test` exports
deterministic fakes, file fixtures, and conformance helpers; `alphax_dio`
exports only `AlphaXDioAdapter` and its documented metadata keys. No native
handle, Flutter channel, Cronet, URLSession, C++, Rust, libcurl, or
machine-specific type crosses the core public boundary. The core `alphax`
public API did not change; the optional Dio adapter addition was deliberate and
is now frozen as part of this package review. Any later API change is treated
as a potential 1.0 breaking change.

The freeze also explicitly records what the interface does not promise:

- `alphax` does not contain a native transport implementation by itself;
  callers select a separate adapter through the `AlphaXTransport` seam.
- `alphax` itself does not include a Web transport. `alphax_web` provides
  ordinary browser Fetch support separately; browser protocol metadata is
  unknown and concrete protocol requirements fail closed.
- H3 is opportunistic, not universal. Provider, server, proxy, and network
  conditions determine the actual protocol; preference permits fallback and
  requirement fails closed.
- AlphaX provides opt-in replay-aware retries, caller-owned token
  authentication, in-memory cookies/cache, and a generic circuit breaker. It
  does not include persistent stores, unsafe replay, model-specific OAuth, or
  a vendor-specific resilience policy.
- AlphaX makes no universal speed, zero-copy, or “fastest client” claim.

## 5. ADR status

All final architecture decisions required by the release gate are Accepted:

- ADR 0004 — platform-native mobile transports: **Accepted**
- ADR 0005 — completion-time protocol metadata: **Accepted**
- ADR 0006 — protocol preference vs requirement: **Accepted**
- ADR 0007 — TLS policy and pinning: **Accepted**
- ADR 0008 — proxy policy semantics: **Accepted**

## 6. Platform and protocol matrix

- **Android:** API 24+ through a supported non-fallback Cronet provider:
  H1/H2/H3. Provider, server, and network determine whether an individual
  request uses H3.
- **iOS:** iOS 15+ through URLSession. H1/H2/H3 are OS, provider, server, and
  network dependent.
- **macOS:** macOS 12+ through URLSession. H1/H2/H3 are OS, provider, server,
  and network dependent.
- **Linux:** Dart IO fallback, H1 only.
- **Windows:** Dart IO fallback, H1 only.
- **Web:** `alphax_web` Fetch adapter for ordinary HTTP. Browser protocol
  metadata is unknown; concrete protocol requirements fail closed.

The release makes no universal or always-on H3 claim and makes no universal
performance claim.

## 7. Capability and protocol boundaries

- Capability discovery describes transport support; it does not prove actual
  negotiation for a request.
- Protocol preference is opportunistic. It may fall back when provider,
  server, proxy, or network conditions prevent the preferred protocol.
- Protocol requirement is strict. If the required protocol is not negotiated,
  the request fails closed with a normalized requirement error.
- H3 fallback is reported with the actual protocol and normalized fallback
  metadata where the platform can report it.
- Dart IO can provide H1 behavior but cannot authoritatively report H2/H3.
- Provider-limited TLS, pinning, and proxy capabilities fail closed rather
  than silently weakening the requested policy.

## 8. Security status

The RC documentation and implementation retain verified platform TLS defaults,
reject trust-all configuration, redact credentials and body data from
diagnostics, and normalize TLS, certificate, pin, proxy, and transport errors.
SPKI pinning guidance requires a primary and backup/rotation pin. Proxy
credential guidance explicitly prohibits logging credentials. The security
audit found no signing credentials, `DEVELOPMENT_TEAM` value, certificate,
private key, machine-specific path, or production benchmark endpoint in the
release-visible source and documentation.

Known security capability limits are documented: mTLS is not implemented,
Android custom trust anchors are unsupported by the selected provider, and
Dart IO SPKI pinning is unsupported. Explicit HTTPS proxy endpoint parity is
also unavailable on the affected provider paths.

## 9. Package metadata and dry-runs

All four intended packages use `1.0.0-rc.1`, describe shipped functionality,
declare repository/homepage/issue metadata, use the repository license, and
have compatible SDK/platform declarations. `alphax_dio` depends on Dio 5.x and
the AlphaX core, and remains pure Dart.

The clean-state publication dry-runs completed with zero warnings, zero
package-content errors, and no generated or machine-specific files:

| Package | Command | Compressed archive |
| --- | --- | ---: |
| `alphax` | `dart pub publish --dry-run` | 40 KB |
| `alphax_test` | `dart pub publish --dry-run` | 9 KB |
| `alphax_dio` | `dart pub publish --dry-run` | 12 KB |
| `alphax_native` | `flutter pub publish --dry-run` | 72 KB |

The separately prepared `alphax_web` adapter also passed
`dart pub publish --dry-run` with zero warnings and zero errors; its compressed
archive is 8 KB. It is not part of the approved native RC publication set.

The archives contained only expected package source, tests, documentation,
metadata, and native plugin files. No generated build output, benchmark data,
local fixture output, signing configuration, or machine-specific file was
included. The separately prepared `alphax_web` dry-run also reported zero
warnings.

## 10. Dependency graph and third-party notices

The RC dependency graph is:

```text
alphax
├── alphax_test
├── alphax_dio
│   └── dio 5.x
└── alphax_native
    └── Flutter host integration

alphax_web
    ├── alphax
    └── package:http BrowserClient / Fetch
```

`alphax_native` uses Google Play Services Cronet `18.0.1` on Android. The
resolved upstream AAR carries its third-party license data and the local Maven
metadata identifies the Android Software Development Kit License. AlphaX does
not copy third-party source or binary code into the package, so no additional
project NOTICE entry was required. Apple integration uses the system URLSession
framework through CocoaPods; Swift Package Manager remains deferred. The
package license and dependency review found no missing redistribution notice.

## 11. Dio adapter status

`AlphaXDioAdapter` is implemented and tested as a focused Dio 5.x compatibility
boundary. The adapter maps Dio request streams, headers, methods, cancellation,
timeouts, redirects, normalized AlphaX errors, response streams, and Dio-owned
progress callbacks. It exposes the actual protocol, fallback, current metrics,
and completion-time metadata through documented `Response.extra` keys and
Dio's standard HTTP-version key.

It does not add a Dio-specific retry, cookie, auth, cache, or resilience policy;
those opt-in policies remain on the injected AlphaX client. It does not promise
full Dio API compatibility. Browser transport is provided separately by
`alphax_web`.

The non-H3 policy modules are implemented in `alphax` and covered by focused
pure-Dart tests: replay-aware retry, token authentication/refresh, in-memory
cookies, buffered cache behavior, and generic circuit breaking. They are
explicit middleware and do not change the transport architecture.

## 12. Example status

The example was reviewed to use released APIs only and demonstrates:

- GET and response display;
- cancellation;
- the release API surface for protocol preference and strict requirement;
- actual protocol/fallback reporting; and
- capability discovery.

The example source also retains the released streaming and file-transfer
interfaces in the documented API path. TLS/pinning/proxy examples were not
added because safe, non-secret examples would not demonstrate provider-specific
behavior accurately. The Waypoint Flutter host project builds on macOS, and its
platform-independent bundle build, widget test, and data tests pass. Its README
states that demo mode is local and safe, while network mode requires an
explicit caller-provided fixture URL.

## 13. Documentation and migration status

The root README, package READMEs, scope, requirements audit, release gate,
public API inventory, migration guide, security policy, and changelogs were
reviewed for RC accuracy. The README states the platform matrix and avoids
universal H3, always-H3, fastest-client, and unqualified Phase 0 benchmark
claims.

`docs/MIGRATION.md` covers package:http and Dio users, including client
creation, methods, headers, bodies, multipart, cancellation, timeouts,
streaming, file transfer, middleware, protocol preference/requirement, actual
protocol reporting, TLS/pinning, proxy policy, errors, and intentional AlphaX
differences. It does not imply full Dio API compatibility.

Local Markdown links resolve. Newly authored prose documentation passes the
repository Markdown lint configuration. The large historical/table-heavy
release documents retain baseline line-length and table-column-style warnings;
these are non-functional documentation follow-ups and do not indicate broken
links or incorrect RC claims.

## 14. Validation evidence

The consolidated RC validation completed for the affected packages and release
surfaces:

- `dart format --set-exit-if-changed`: passed;
- Dart analysis for all four RC packages and the separately prepared
  `alphax_web` package: passed;
- root `dart analyze`: passed after excluding only the standalone
  `benchmarks/mobile_gate` app from the root package context;
- `alphax` policy middleware tests: passed;
- `alphax_web` VM and Chrome tests: passed;
- `alphax_web` JavaScript compilation: passed;
- `alphax_dio` adapter tests: passed;
- Flutter analysis for the resolved mobile gate and Waypoint example: passed;
- all RC package tests plus `alphax_web`: passed;
- shared package and benchmark/conformance scripts: passed;
- deterministic JSON fixture validation: passed;
- Dartdoc with link validation for all five prepared packages: passed with zero
  warnings and zero errors (written to temporary output directories);
- Markdown link checks: passed;
- Waypoint widget/data tests, host-independent bundle build, and macOS debug
  application build: passed;
- Android production release/plugin APK build: passed;
- iOS device no-code-sign build: passed;
- macOS release no-sign build through XcodeBuildMCP: passed;
- dependency, native dependency, signing/secret, endpoint, and path audits:
  passed;
- `git diff --check`: passed.

The Android/iPhone/macOS focused evidence retained from the release gate was
not rewritten. Representative Android reports include current H2 fallback and
strict H3 failure-closed behavior plus prior validated H3 evidence. iPhone
evidence includes H1/H2/H3 reporting, H3 requirement outcomes, TLS/pinning,
redirect, and security cases. These reports establish supported behavior and
truthful fallback semantics; they do not turn H3 into a universal platform
claim.

No broad transport performance benchmark was restarted.

## 15. Known limitations

- Linux and Windows are H1-only through Dart IO in 1.0.
- Browser Fetch is available through the separate `alphax_web` adapter, but
  browser protocol metadata, CORS, TLS, proxy, and native file controls remain
  platform-owned.
- mTLS is not implemented.
- Explicit HTTPS proxy endpoint parity is unavailable on affected provider
  paths.
- Android custom trust anchors are unsupported by the selected provider.
- Dart IO SPKI pinning is unsupported.
- Swift Package Manager packaging is deferred; CocoaPods is used for Apple
  packaging.
- `alphax_dio` is a focused Dio 5.x adapter, not full Dio source/API
  compatibility.
- `alphax_dio` uses the injected AlphaX client's TLS, pinning, proxy, and
  middleware policies; it does not add independent per-request native policy.
- Policy middleware is opt-in: retries are limited by replayability and method
  safety, cookies/cache are in memory, and authentication state is caller-owned.
- Android H3 remains dependent on the selected provider, server, and network;
  the current retained H3 path is evidence, not a guarantee.

## 16. Outstanding non-gating follow-ups

The optional H3 runner can be exercised later on a validated UDP/443 and
QUIC-permissive path. That is evidence follow-up only; no production hint or
force behavior is needed for this RC. `alphax_web` has passed its VM/Chrome
tests and JavaScript compilation; maintainer approval for its publication
decision and naming clearance remain follow-ups. The standalone mobile gate's
simulator-only build is not a 1.0 production requirement because its retained
FFI archives are device-built; physical-device evidence remains the accepted
gate. None of these follow-ups requires changing the frozen transport
architecture.

## 17. Final verdict

READY TO PUBLISH 1.0.0-rc.1

Publication was intentionally not performed. Wait for maintainer approval and
naming clearance before publishing the packages in the order listed above.
