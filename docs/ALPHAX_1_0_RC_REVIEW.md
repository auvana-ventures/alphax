# AlphaX 1.0 RC Review

Review date: 2026-08-16  
Proposed version: `1.0.0-rc.1`  
Review scope: release-candidate preparation only. No new feature, transport
architecture, benchmark, publication, tag, or GitHub release work is included.

## 1. Proposed version and publication set

The proposed first release candidate is `1.0.0-rc.1`.

Packages intended for RC publication:

- `alphax`
- `alphax_test`
- `alphax_native`

`alphax_dio` was evaluated and is deliberately not part of the RC. It remains
version `0.1.0`, has `publish_to: none`, and is documented as an unpublished
skeleton until it contains a real compatibility adapter. An effectively empty
package will not be published without a separate maintainer decision.

## 2. Publication order

The dependency-aware order is:

1. `alphax`
2. `alphax_test`
3. `alphax_native`

The order follows the package manifests: `alphax_test` depends on `alphax`,
and `alphax_native` depends on `alphax` at runtime and `alphax_test` for
development/conformance testing. No package was published during this review.

## 3. Git state and release commits

The final release-gate work and retained focused device evidence are captured
in these logical commits:

- `7cbe8db` — `test: complete AlphaX 1.0 release acceptance`
- `896ddb0` — `docs: close AlphaX 1.0 release gate`

The RC review document and final task record are committed separately as the
RC closeout. The final handoff reports that commit together with the two
release-gate commits after push verification.

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
pins, proxy policy, and normalized errors.

The barrel review found no accidental exports. `alphax` exports only its
transport-neutral contracts; `alphax_native` exports the Dart IO, Android
Cronet, Apple URLSession, and local-file entry points; `alphax_test` exports
deterministic fakes, file fixtures, and conformance helpers; `alphax_dio`
exports no production adapter. No native handle, Flutter channel, Cronet,
URLSession, C++, Rust, libcurl, or machine-specific type crosses the core
public boundary. No public API was added during RC preparation. Any later API
change is treated as a potential 1.0 breaking change.

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
- **Web:** Unsupported in 1.0.

The release does not claim HTTP/3 on all platforms, always-on HTTP/3, or a
universal performance advantage.

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

The three intended packages use `1.0.0-rc.1`, describe shipped functionality,
declare repository/homepage/issue metadata, use the repository license, and
have compatible SDK/platform declarations. `alphax_dio` is excluded from the
publication set as described above.

The clean publication dry-runs completed with zero warnings and zero errors:

| Package | Command | Compressed archive |
| --- | --- | ---: |
| `alphax` | `dart pub publish --dry-run` | 28 KB |
| `alphax_test` | `dart pub publish --dry-run` | 8 KB |
| `alphax_native` | `flutter pub publish --dry-run` | 72 KB |

The archives contained only expected package source, tests, documentation,
metadata, and native plugin files. No generated build output, benchmark data,
local fixture output, signing configuration, or machine-specific file was
included. `alphax_dio` was not dry-run because `publish_to: none` intentionally
keeps it unpublished.

## 10. Dependency graph and third-party notices

The RC dependency graph is:

```text
alphax
├── alphax_test
└── alphax_native
    └── Flutter host integration
```

`alphax_native` uses Google Play Services Cronet `18.0.1` on Android. The
resolved upstream AAR carries its third-party license data and the local Maven
metadata identifies the Android Software Development Kit License. AlphaX does
not copy third-party source or binary code into the package, so no additional
project NOTICE entry was required. Apple integration uses the system URLSession
framework through CocoaPods; Swift Package Manager remains deferred. The
package license and dependency review found no missing redistribution notice.

## 11. Example status

The example was reviewed to use released APIs only and demonstrates:

- GET and response display;
- cancellation;
- the release API surface for protocol preference and strict requirement;
- actual protocol/fallback reporting; and
- capability discovery.

The example source also retains the released streaming and file-transfer
interfaces in the documented API path. TLS/pinning/proxy examples were not
added because safe, non-secret examples would not demonstrate provider-specific
behavior accurately. The example has no platform host project; its
platform-independent bundle build and widget test passed, and the README
states this boundary.

## 12. Documentation and migration status

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

## 13. Validation evidence

The consolidated RC validation completed for the affected packages and release
surfaces:

- `dart format --set-exit-if-changed`: passed;
- Dart analysis for all four packages: passed;
- Flutter analysis for the mobile gate and example: passed;
- all package tests: passed;
- shared package and benchmark/conformance scripts: passed;
- deterministic JSON fixture validation: passed;
- Dartdoc with link validation for all four packages: passed with zero
  warnings and zero errors;
- Markdown link checks: passed;
- example widget test and host-independent bundle build: passed;
- Android production release/plugin APK build: passed;
- iOS no-code-sign build: passed;
- macOS no-code-sign build: passed;
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

## 14. Known limitations

- Linux and Windows are H1-only through Dart IO in 1.0.
- Web is unsupported in 1.0.
- mTLS is not implemented.
- Explicit HTTPS proxy endpoint parity is unavailable on affected provider
  paths.
- Android custom trust anchors are unsupported by the selected provider.
- Dart IO SPKI pinning is unsupported.
- Swift Package Manager packaging is deferred; CocoaPods is used for Apple
  packaging.
- Android H3 remains dependent on the selected provider, server, and network;
  the current retained H3 path is evidence, not a guarantee.

## 15. Outstanding non-gating follow-ups

The optional H3 runner can be exercised later on a validated UDP/443 and
QUIC-permissive path. That is evidence follow-up only; no production hint or
force behavior is needed for this RC. Naming clearance and maintainer approval
remain publication prerequisites. Neither item requires another implementation
phase or changes the frozen transport architecture.

## 16. Final verdict

READY TO PUBLISH 1.0.0-rc.1

Publication was intentionally not performed. Wait for maintainer approval and
naming clearance before publishing the packages in the order listed above.
