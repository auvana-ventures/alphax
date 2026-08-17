# AlphaX 1.0 RC Review

Review date: 2026-08-17
Proposed version: `1.0.0-rc.1`
Review scope: final release-candidate preparation after the frozen policy API.
No transport architecture change, benchmark rerun, publication, tag, or
post-1.0 feature work is included.

## 1. Commit and HEAD

The policy-freeze source, tests, ADRs, and package documentation are committed
in `c9a750d` (`feat: freeze AlphaX 1.0 policy contracts`). The final release-gate
documentation commit and pushed `origin/main` HEAD are recorded in the final
task outcome and maintainer handoff after validation. Historical release and
audit commits are preserved and are not rewritten.

## 2. Proposed RC and package publication set

The proposed version is `1.0.0-rc.1`. All five packages contain useful
functionality and are classified `PUBLISH_RC`:

| Package | RC decision | Functionality | Notes |
| --- | --- | --- | --- |
| `alphax` | `PUBLISH_RC` | Pure-Dart transport-neutral client contracts, policies, errors, streams, and files | Core runtime package; no Flutter dependency |
| `alphax_native` | `PUBLISH_RC` | Dart IO, Android Cronet/HttpEngine, and Apple URLSession adapters | Flutter plugin boundary; platform/provider limits are explicit |
| `alphax_test` | `PUBLISH_RC` | Deterministic fakes, fixtures, and shared conformance helpers | Intended as a development dependency, not a runtime transport |
| `alphax_web` | `PUBLISH_RC` | Browser Fetch adapter | Useful ordinary Web HTTP adapter; browser protocol/security controls remain browser-owned |
| `alphax_dio` | `PUBLISH_RC` | Focused Dio 5.x `HttpClientAdapter` over an injected AlphaX client | Real adapter and tests; not full Dio API compatibility |

`alphax_dio` is not an empty boundary: it maps Dio requests, response streams,
cancellation, timeouts, redirects, progress, errors, and AlphaX completion
metadata. `alphax_web` is not a name-reservation skeleton: its Fetch adapter
has VM/Chrome tests and browser compilation coverage.

No package is published by this review. No package is intentionally withheld
from the first RC publication set; maintainer naming clearance and approval
remain required.

## 3. Publication order and dependency graph

Runtime dependencies form this graph:

```text
alphax
├── alphax_native
├── alphax_web
└── alphax_dio ── dio 5.x

alphax_test ── alphax   (development/test utility package)
```

`alphax_native` and `alphax_dio` use `alphax_test` only in development
dependencies. The deterministic publication order is:

1. `alphax`
2. `alphax_test`
3. `alphax_native`
4. `alphax_web`
5. `alphax_dio`

Every package is `1.0.0-rc.1`; internal package constraints use
`^1.0.0-rc.1`, so no package requires an unpublished stable `1.0.0`.

## 4. Public API freeze

The 1.0 public API is frozen. The inventory in
[`docs/phase1a-public-api-inventory.md`](phase1a-public-api-inventory.md) was
checked against the scope, requirements audit, release gate, and policy-freeze
review. The freeze includes:

- core: `AlphaXClient`, transport contract, request/response models, headers,
  body/file abstractions, streaming, cancellation, timeouts, redirects, and
  middleware;
- protocols: protocol enum, preference, requirement, fallback, and
  actual/completion protocol reporting;
- security/network: TLS policy, trust anchors, SPKI pins, proxy policy,
  capability reporting, and normalized security/network errors;
- policies: authentication/token middleware, retry middleware, cookie
  middleware, `AlphaXCookieStore`, in-memory `AlphaXCookieJar`, cache
  middleware, variant-aware cache store/key/metadata contracts, and the
  resilience/circuit-breaker primitive;
- testing: fake transport and shared conformance utilities.

Barrel exports were reviewed. No native handle, Flutter type, Cronet,
URLSession, C++, Rust, libcurl, certificate object, or machine-specific type
crosses the pure-Dart `alphax` boundary. Any later change to these contracts is
a potential breaking 1.0 API change.

## 5. ADR status

All implemented foundational decisions applicable to this RC are Accepted:

| ADR | Decision | Status |
| --- | --- | --- |
| 0004 | Platform-native mobile transports | Accepted |
| 0005 | Completion-time protocol metadata | Accepted |
| 0006 | Protocol preference versus requirement | Accepted |
| 0007 | TLS policy and pinning | Accepted |
| 0008 | Proxy policy semantics | Accepted |
| 0009 | Asynchronous cookie-store persistence boundary | Accepted |
| 0010 | Private variant-aware HTTP cache contract | Accepted |

The Phase 0 ADRs remain historical `Accepted for Phase 0` decisions. The ADR
template remains Proposed by design and is not an architectural decision.

## 6. Platform and protocol matrix

| Target | Transport | 1.0 protocol boundary |
| --- | --- | --- |
| Android API 24+ | Supported non-fallback Cronet/HttpEngine provider | H1/H2/H3 where provider, server, proxy, and network permit; actual protocol is reported |
| iOS 15+ | URLSession | H1/H2/H3 where the OS/provider/server/network negotiate; completion metadata is authoritative where available |
| macOS 12+ | URLSession | H1/H2/H3 where the OS/provider/server/network negotiate; completion metadata is authoritative where available |
| Linux | Dart IO fallback | H1 only; H2/H3 are not advertised |
| Windows | Dart IO fallback | H1 only; H2/H3 are not advertised |
| Web | `alphax_web` browser Fetch | Ordinary HTTP is supported; browser protocol metadata is unknown and concrete protocol requirements fail closed |

Capability is not actual negotiation. Preference permits fallback; requirement
fails closed. AlphaX makes no universal H3 or performance claim.

## 7. Policy feature matrix

| Policy | 1.0 state | Default and boundary |
| --- | --- | --- |
| Retry | `IMPLEMENTED_AND_VALIDATED` | Opt-in; safe/idempotent replayable buffered requests only by default; cancellation-aware bounded backoff and numeric/HTTP-date `Retry-After`; no unsafe automatic mutation retry |
| Authentication | `IMPLEMENTED_AND_VALIDATED` | Opt-in token injection and single-flight refresh callback; token storage, OAuth flows, browser/session handling, and orchestration remain caller-owned |
| Cookies | `IMPLEMENTED_AND_VALIDATED` | Opt-in policy plus asynchronous transport-neutral `AlphaXCookieStore`; `AlphaXCookieJar` is the bounded in-memory default; persistence, encryption, serialization, and restore policy remain caller-owned |
| Cache | `IMPLEMENTED_AND_VALIDATED` | Opt-in private, bounded, in-memory HTTP cache; method + URI + Vary variants, freshness, validators, 304 merge, auth safety, Set-Cookie exclusion, and mutation invalidation are owned by AlphaX; durable stores remain caller-owned |
| Resilience | `IMPLEMENTED_AND_VALIDATED` | Opt-in generic in-memory circuit breaker and retry composition; no vendor/service-mesh/telemetry policy |

Cache reuse is private by default. Authorization/cookie-bearing requests bypass
storage and reuse unless the caller supplies an explicit identity scope, and
shared custom stores have additional isolation and durability responsibilities.
Browser-managed cookies are opaque to AlphaX; Web callers must not combine
`withCredentials: true` with AlphaX cache middleware unless they provide and
rotate a session identity scope, or they must leave AlphaX caching off.

## 8. Accepted platform and caller boundaries

- `alphax` does not include a native transport; adapters are separate packages.
- `alphax_web` does not override browser CORS, TLS, proxy, cookie, file, or
  protocol controls.
- H3 remains provider/server/proxy/network dependent and is never guaranteed.
- Explicit HTTPS proxy endpoints remain provider/mapping limited and fail
  closed; HTTP proxy CONNECT to an HTTPS destination is a distinct supported
  subset where advertised.
- Dart IO SPKI pinning remains unsupported and fail-closed. SPKI pinning on
  Android/Apple supports backup/rotation pins.
- mTLS/client identity mapping is not implemented in the 1.0 adapters.
- Persistence implementations for cookies and caches, OAuth orchestration,
  token storage, offline queue, background transfer lifecycle, vendor-specific
  resilience, OpenTelemetry/Sentry/Firebase integration, WebSocket/SSE,
  GraphQL, REST generation, and SPM packaging remain outside this RC.

## 9. Marker/TODO audit

The focused audit is recorded in
[`ALPHAX_1_0_RELEASE_MARKER_AUDIT.md`](ALPHAX_1_0_RELEASE_MARKER_AUDIT.md).
No marker was classified as a release blocker. Capability-state words such as
`unsupported` are intentional fail-closed states; old Phase 0/1, benchmark,
prototype, scaffold, and task wording is historical or harmless. No production
TODO/FIXME/HACK/XXX or deprecated shipped API remains.

## 10. Security review

The final read-only security review confirms:

- trust-all/accept-any TLS is not available;
- pin mismatch, unsupported TLS policy, unsupported proxy policy, and protocol
  requirement fail closed;
- redirect handling protects sensitive authorization, proxy-authorization, and
  cookie headers according to transport capability;
- cookie values, auth tokens, proxy credentials, body data, and private keys are
  not included in default diagnostics;
- cache matching respects Vary and identity scope, and `no-store` and
  Set-Cookie responses are not reused; browser-managed Web credentials remain
  an explicit caller-owned boundary because Fetch does not expose cookie values;
- mutation invalidation is serialized and an in-flight GET cannot repopulate a
  response after a concurrent mutation invalidates its resource;
- test certificates/keys remain in deterministic fixtures only;
- no signing credential, `DEVELOPMENT_TEAM`, machine-specific path, production
  benchmark endpoint, or production diagnostic QUIC hint is included.

`SECURITY.md` documents supported RC coverage, private reporting, secure
defaults, backup/rotation pins, proxy credential handling, and accepted
provider limitations.

## 11. Dependency audit and package metadata

All five package manifests have name, `1.0.0-rc.1` version, real description,
homepage, repository, issue tracker, topics, Apache-2.0 license, SDK/Flutter
constraints where applicable, dependencies, dev dependencies, and expected
platform declarations. No package uses `publish_to: none`.

The dependency review found no discontinued or retracted resolved dependency and
no advisory result from the available local package audit commands. Dart's
standalone `pub audit` and external scanners that are not installed in this
environment are recorded as unavailable rather than claimed as passed.

Android Cronet/Google Play Services and Apple system URLSession remain provider
or platform dependencies; AlphaX does not copy a third-party native binary into
the packages. Each package includes Apache-2.0 licensing, and no additional
NOTICE file was required by the distributed dependency review.

## 12. Package dry-runs

Each intended package passed its publish dry-run with no archive errors. Final
archive sizes and warnings are recorded after the consolidated dry-run in the
table below:

| Package | Dry-run | Compressed archive | Warnings/errors |
| --- | --- | ---: | --- |
| `alphax` | `dart pub publish --dry-run` | 50 KB | 0 warnings |
| `alphax_test` | `dart pub publish --dry-run` | 10 KB | 0 warnings |
| `alphax_native` | `flutter pub publish --dry-run` | 73 KB | 0 warnings |
| `alphax_web` | `dart pub publish --dry-run` | 9 KB | 0 warnings |
| `alphax_dio` | `dart pub publish --dry-run` | 12 KB | 0 warnings |

The archives must contain no benchmark results, local device fixtures,
generated native output, signing configuration, development certificates,
temporary files, secrets, or machine paths.

## 13. Example and documentation status

The released examples use public APIs and cover GET, streaming, cancellation,
file upload/download, protocol preference/requirement, actual protocol
reporting, and capability discovery. TLS/pinning/proxy examples use safe
placeholders and point to caller configuration; no real secret or production
pin is included.

The root and package READMEs explain what each package does, how a beginner can
start, default versus opt-in policies, platform/protocol limits, and migration
paths. `docs/POLICIES.md` is the canonical customization guide; `docs/MIGRATION.md`
covers `package:http` and Dio without implying full Dio compatibility. Changelogs
for every RC package describe shipped functionality and known limitations.

## 14. Validation results

The final consolidated RC gate covers:

- format, Dart/Flutter analysis, all package tests, policy tests, conformance
  tests, deterministic fixtures, and example tests;
- Dartdoc, Markdown/internal links, and `git diff --check`;
- all five package publish dry-runs and archive inspection;
- Android release/plugin build and iOS/macOS no-code-sign builds;
- `alphax_web` VM tests, Chrome tests, and browser JavaScript compilation;
  the Waypoint Flutter example has no Web target, so its attempted Web build is
  recorded as not applicable rather than presented as a passing example build;
- dependency, native dependency, security/credential, signing, and endpoint
  audits.

No Phase 0 benchmark or broad transport performance run was repeated. Retained
Android/iPhone/macOS focused evidence was not rewritten, and no physical-device
matrix was rerun because no changed production transport path required it.

## 15. Known limitations

- H3 is opportunistic and not universal.
- Linux/Windows are H1-only through Dart IO.
- Web Fetch cannot report authoritative protocol metadata and remains subject to
  browser CORS/TLS/proxy/cookie/file controls.
- Browser-managed cookies are opaque to AlphaX cache selection; Web callers must
  provide an explicit rotating identity scope or leave AlphaX caching off for
  credentialed browser requests.
- mTLS is not implemented.
- Explicit HTTPS proxy endpoint parity is not available through the shared 1.0
  mapping.
- Android custom trust anchors are unsupported by the selected provider.
- Dart IO and browser SPKI pinning are unsupported and fail closed.
- CocoaPods is the Apple packaging path; SPM is deferred.
- `alphax_dio` is a focused adapter, not full Dio compatibility.
- Persistent cookie/cache implementations and request coalescing are not
  bundled.

## 16. Post-1.0 candidates and non-gating follow-ups

Potential later work includes durable caller-provided store implementations,
per-request retry/idempotency extensions, richer cache eviction/coalescing,
provider-specific proxy/TLS expansion, SPM packaging, background-transfer
integration, and separately scoped application/framework features. These are
not RC blockers and are not part of this task.

## 17. Remaining RC blockers

None identified. Publication, naming clearance, and maintainer approval remain
external release actions, not implementation blockers.

## Final verdict

READY TO PUBLISH ALPHAX 1.0.0-RC.1
