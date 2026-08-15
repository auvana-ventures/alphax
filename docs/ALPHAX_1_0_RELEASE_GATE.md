# AlphaX 1.0 Release Gate

Gate date: 2026-08-15
Architecture: Android Cronet/HttpEngine; iOS/macOS URLSession; Dart IO
fallback; pure-Dart transport-independent `alphax` API.

This is the final closure record for the current worktree. It does not start
Phase 1G, restart benchmarking, change the accepted architecture, publish a
package, or create a release tag.

## 1. Exact public API inventory

`alphax` exports only transport-neutral contracts:

- `AlphaXClient`, `AlphaXTransport`, `AlphaXRequest`, `AlphaXResponse`, and
  `AlphaXResponseBody`;
- `HttpMethod`, `AlphaXHeaders`, `AlphaXBody` and empty/bytes/text/JSON/stream/
  file/multipart body forms;
- `AlphaXFileSource`, `AlphaXFileTarget`, `AlphaXFileSink`, transfer results,
  progress, cancellation, timeout, redirect, and middleware models;
- `AlphaXProtocol`, `AlphaXProtocolPreference`,
  `AlphaXProtocolRequirement`, and `AlphaXProtocolFallback`;
- `AlphaXCapabilities`, `AlphaXCapability`, and `AlphaXSupport`;
- `AlphaXRequestMetrics` with best-known and completion-time semantics;
- `AlphaXTlsPolicy`, `AlphaXTrustAnchor`, `AlphaXSpkiPin`,
  `AlphaXClientIdentity`, `AlphaXProxyPolicy`, and proxy credentials;
- normalized AlphaX exceptions, including protocol requirement, TLS/pin,
  proxy, proxy-authentication, unsupported-policy, body, cancellation, and
  transport errors.

`alphax` has no Flutter SDK dependency and exports no Cronet, URLSession,
Foundation, Rust, libcurl, C++, FFI handle, socket, certificate-object, or
native error type. `alphax_native` exports only Dart IO, Android Cronet, and
Apple URLSession adapters. `alphax_test` exports fakes and conformance
fixtures. `alphax_dio` remains an optional boundary without an adapter.

## 2. Exact platform/protocol matrix

| Platform/transport | HTTP/1.1 | HTTP/2 | HTTP/3 | Actual protocol reporting | Fallback reporting |
| --- | --- | --- | --- | --- | --- |
| Dart IO | SUPPORTED | UNSUPPORTED | UNSUPPORTED | UNSUPPORTED; completed protocol remains `unknown` | UNSUPPORTED when actual protocol cannot be observed |
| Android Cronet/HttpEngine, non-fallback provider | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED from Cronet response metadata | SUPPORTED from final actual protocol |
| Android fallback provider | SUPPORTED | UNSUPPORTED | UNSUPPORTED | SUPPORTED only for values the provider reports | SUPPORTED for known lower-protocol result |
| iOS URLSession 15+ | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED from URLSession task metrics at completion | SUPPORTED from completion metrics |
| macOS URLSession 12+ | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED from URLSession task metrics at completion | SUPPORTED from completion metrics |
| Linux | SUPPORTED through Dart IO | UNSUPPORTED | UNSUPPORTED | Dart IO limitation | UNSUPPORTED |
| Windows | SUPPORTED through Dart IO | UNSUPPORTED | UNSUPPORTED | Dart IO limitation | UNSUPPORTED |
| Web | UNSUPPORTED IN 1.0 | UNSUPPORTED IN 1.0 | UNSUPPORTED IN 1.0 | UNSUPPORTED IN 1.0 | UNSUPPORTED IN 1.0 |

The Android H3 fixture and Apple H3/fallback evidence remain preserved in the
Phase 1C/1D/1E reports. Final release-path Android and iPhone reruns were not
completed in this environment.

## 3. TLS policy matrix

| TLS behavior | Dart IO | Android Cronet | iOS/macOS URLSession |
| --- | --- | --- | --- |
| Platform default trust | SUPPORTED | SUPPORTED | SUPPORTED |
| Hostname/validity checks | PLATFORM-MANAGED | PLATFORM-MANAGED | PLATFORM-MANAGED |
| Trust-all / accept-any certificate | INTENTIONALLY UNSUPPORTED IN 1.0 | INTENTIONALLY UNSUPPORTED IN 1.0 | INTENTIONALLY UNSUPPORTED IN 1.0 |
| Invalid certificate normalization | IMPLEMENTED; focused tests pass | IMPLEMENTED; native TLS errors normalized | IMPLEMENTED; macOS/iPhone historical invalid-TLS checks pass |
| Policy immutability | SUPPORTED in pure Dart | SUPPORTED at policy boundary | SUPPORTED at policy boundary |

## 4. Pinning matrix

Pins are SPKI SHA-256 digests, support backup pins, apply after normal trust
evaluation, and preserve hostname and certificate validity checks.

| Transport | Pin implementation | Unsupported behavior | Validation |
| --- | --- | --- | --- |
| Dart IO | UNSUPPORTED_BY_PLATFORM_API; no safe stable `HttpClient` SPKI callback/parser | `AlphaXUnsupportedTlsPolicyException` | Constructor/policy tests pass; unsupported behavior is explicit |
| Android Cronet | SUPPORTED through provider public-key pin configuration; local-trust bypass disabled | Invalid/expired pins fail initialization | Native mapping/build pass; physical pin success/mismatch probe remains open |
| Apple URLSession | SUPPORTED through server-trust challenge and SPKI extraction | Invalid/expired pins fail initialization; mismatch cancels challenge | Focused macOS custom-CA, primary/backup/mismatch, and invalid-certificate fixture passed; iPhone probe remains open |

No configured pin silently falls back to ordinary trust.

## 5. Custom trust matrix

| Transport | Additional/replacement trust anchors | Exact limitation |
| --- | --- | --- |
| Dart IO | SUPPORTED through `SecurityContext` | Invalid DER is normalized as unsupported policy; no pinning through this path |
| Android Cronet | BLOCKED_BY_PLATFORM for the selected provider | Cronet provider does not expose a safe custom-anchor mapping in the selected API; configured anchors fail closed |
| Apple URLSession | SUPPORTED through `SecTrust` anchors | Trust evaluation remains enabled; invalid DER and failed chain validation fail closed; focused macOS fixture passed |

## 6. Proxy matrix

| Policy | Dart IO | Android Cronet | Apple URLSession |
| --- | --- | --- | --- |
| `system` | PLATFORM-MANAGED / supported | PLATFORM-MANAGED / supported | PLATFORM-MANAGED / supported |
| `direct` | SUPPORTED through `DIRECT` | BLOCKED_BY_PLATFORM; provider cannot guarantee direct-only routing | SUPPORTED through CFNetwork configuration |
| explicit HTTP proxy | SUPPORTED with optional Basic challenge | BLOCKED_BY_PLATFORM in selected provider API | SUPPORTED with optional Basic challenge, including HTTPS destinations through CONNECT where CFNetwork permits |
| explicit HTTPS proxy endpoint | BLOCKED_BY_PLATFORM in the shared mapping | BLOCKED_BY_PLATFORM | BLOCKED_BY_PLATFORM; rejected by the shared mapping |
| proxy authentication | SUPPORTED for Dart IO/Apple Basic flows | BLOCKED_BY_PLATFORM for explicit provider route | SUPPORTED for explicit HTTP Basic route; focused macOS success/failure fixture passed |
| H3 through proxy | Actual protocol remains authoritative | Actual protocol remains authoritative | Actual protocol remains authoritative |

An unsupported explicit policy returns a normalized unsupported-policy error;
it does not silently use direct or system routing. `http(...)` is an HTTP proxy
endpoint policy and may service HTTPS destinations through CONNECT; it is not an
HTTPS proxy endpoint. The focused macOS fixture observed HTTP routing, trusted
HTTPS CONNECT, Basic authentication, wrong-credential rejection, unreachable
proxy failure, and system/direct behavior. A local custom-CA tunnel failed
closed with a normalized TLS error and is not claimed as a supported combined
policy path.

## 7. mTLS decision and matrix

`AlphaXClientIdentity.platformReference` is an opaque security-boundary model;
raw private-key strings are not part of the API. The current adapters do not
resolve platform identity references.

| Transport | mTLS | State |
| --- | --- | --- |
| Dart IO | UNSUPPORTED | `OPTIONAL_NOT_IMPLEMENTED`; no raw-key API |
| Android Cronet | UNSUPPORTED_BY_SELECTED_PROVIDER | `OPTIONAL_NOT_IMPLEMENTED`; identity configuration fails closed |
| Apple URLSession | UNSUPPORTED_BY_CURRENT_ADAPTER | `OPTIONAL_NOT_IMPLEMENTED`; keychain identity mapping is not implemented |

mTLS is optional in the approved scope and is not a release-gate completion
criterion. It must not be enabled by passing private key material through Dart.

## 8. Protocol preference and requirement semantics

- `protocolPreference` is caller intent. It permits fallback.
- `protocolRequirement` is fail-closed intent. The final actual protocol must
  equal the required enum value; `unknown` never satisfies it.
- A preference for H3 followed by H2 succeeds and reports H3→H2 fallback when
  the final protocol is known.
- A requirement for H3 followed by H2 fails with
  `AlphaXProtocolRequirementException`.
- Dart IO allows preferences to fall back but rejects concrete H2/H3
  requirements because it cannot provide authoritative protocol reporting.
- URLSession uses completion-time task metrics as the authoritative result.
- Cronet uses final response metadata as the authoritative result.

ADR 0006 records this distinction. ADR 0005 is accepted: response metrics are
best-known snapshots, completion metrics are authoritative, and `unknown` is
neither H1 nor fallback.

## 9. Redirect security result

For cross-origin redirects, `Authorization`, `Proxy-Authorization`, and
`Cookie` are protected:

- Dart IO disables unsafe automatic following and returns a normalized redirect
  failure for sensitive or single-use-body cases.
- Apple URLSession explicitly removes the three headers before following.
- Android Cronet rejects the cross-origin redirect when those headers exist,
  because the selected public API cannot safely replace pending headers.

Deterministic server fixtures and macOS assertions pass. Android/iPhone
physical assertions remain release-path validation blockers.

Streamed request bodies are never silently replayed. File bodies are replayed
only when their source declares replayability and the adapter can reset it.

## 10. Android physical acceptance

Historical accepted evidence is preserved:

- Xiaomi M2003J6A1G, Android 15/API 35, arm64-v8a;
- Google Play Services Cronet `151.0.7922.29`;
- QUIC enabled and actual H3 captured in
  `benchmarks/mobile_gate/fixtures/phase1c_h3_cloudflare_verified.json`;
- H2 fallback reported accurately.

The current release/profile APK built successfully. On 2026-08-15 the physical
Android 15/API 35 device (`M2003J6A1G`, product `PHK110`) was visible over
wireless TLS ADB. APK push, install-session creation, and install-session write
all passed, but both `adb install`/`pm install` and explicit
`cmd package install-commit` stalled without a result. After the permitted
reboot, the wireless endpoint did not reappear. No Android transport probe is
claimed from this attempt; focused release acceptance remains
`IMPLEMENTED_NEEDS_VALIDATION`. Machine-readable evidence is retained in
`benchmarks/mobile_gate/fixtures/phase1f_android_release_attempt.json`.

## 11. iPhone physical acceptance

The signed iPhone runner attached successfully for one direct profile run and
verified actual HTTP/2 on `https://www.apple.com/`, actual HTTP/3 on
`https://cloudflare-quic.com/`, and invalid-certificate rejection. The local
plain-HTTP fixture was unreachable from the phone on both tested host
interfaces, so local H1/fallback, file, stream, and lifecycle checks were not
counted as new device evidence. A later `flutter drive` retry hit
`osascript: -2`. Retained Phase 1D/1E signed evidence remains preserved; the
current release-path security/protocol rerun is still
`IMPLEMENTED_NEEDS_VALIDATION`.

## 12. macOS acceptance

macOS URLSession validation is `IMPLEMENTED_AND_VALIDATED` for H1/H2/H3,
completion-time protocol reporting, H3 preference fallback, streaming and
bounded delivery, file upload/download, progress, cancellation, timeouts,
TLS rejection, lifecycle/reuse, and deterministic redirect security.

The focused macOS security fixture passed default trust rejection, custom-CA
success/failure, primary/backup pin success, pin mismatch, invalid-certificate
rejection despite a matching pin, direct/system/explicit HTTP proxy behavior,
trusted HTTPS CONNECT, Basic authentication, wrong-credential rejection, and
unreachable-proxy failure. The machine-readable evidence is retained in
`benchmarks/mobile_gate/fixtures/phase1f_macos_security_policy.json`.

## 13. Dart IO fallback status

Dart IO is `IMPLEMENTED_AND_VALIDATED` for its H1 fallback surface, methods,
bodies, multipart, progressive streams, pause/resume, file paths, progress,
cancellation, timeout semantics, redirect safety, default/custom trust anchors,
system/direct/HTTP proxy mapping, client reuse, and normalized errors. It
reports H2/H3 and negotiated protocol as unsupported/unknown rather than
claiming capabilities it cannot prove.

## 14. Dependency graph and packaging

```text
alphax (pure Dart)
  ├── no Flutter SDK dependency
  └── transport-neutral contracts, policies, errors, metrics

alphax_native (Flutter plugin)
  ├── alphax
  ├── Dart IO fallback
  ├── Android Cronet/HttpEngine provider integration
  └── Apple Foundation URLSession integration

alphax_test
  └── alphax + deterministic test utilities

alphax_dio
  └── optional boundary; no production adapter
```

Production packages contain no Rust runtime, libcurl, C++ engine, benchmark
dependency, test-fixture dependency, signing material, or development team
configuration. CocoaPods is the 1.0 Apple packaging path; SPM is not required
for this release. Package source/archive observations are not final app-size
claims.

## 15. Security review

| Assertion | State |
| --- | --- |
| Secure trust defaults | IMPLEMENTED_AND_VALIDATED |
| Trust-all prohibition | IMPLEMENTED_AND_VALIDATED |
| SPKI pins and backup pins | IMPLEMENTED_NEEDS_VALIDATION; macOS passed, Android/iPhone focused checks remain |
| Custom trust anchors | IMPLEMENTED_NEEDS_VALIDATION; macOS passed, Android provider limitation is explicit, iPhone focused checks remain |
| Private-key handling | IMPLEMENTED_AND_VALIDATED; only opaque identity references are public |
| Cross-origin sensitive-header protection | IMPLEMENTED_NEEDS_VALIDATION for physical Android/iPhone; macOS/Dart IO pass |
| Proxy credential redaction/logging | IMPLEMENTED_AND_VALIDATED; macOS route/auth fixture passed and no credentials were logged |
| Native error sanitization | IMPLEMENTED_NEEDS_VALIDATION for focused device policy errors |
| File/temp cleanup | IMPLEMENTED_AND_VALIDATED in existing transfer suites |
| Diagnostic QUIC hint absent from production | IMPLEMENTED_AND_VALIDATED |

## 16. Documentation status

Present and updated:

- `docs/ALPHAX_1_0_SCOPE.md`;
- `docs/ALPHAX_1_0_REQUIREMENTS_AUDIT.md`;
- this release gate;
- `docs/architecture/transport_contract.md`;
- `docs/phase1a-public-api-inventory.md`;
- `docs/MIGRATION.md`;
- package READMEs;
- ADRs 0004–0008;
- retained Phase 0/Phase 1 historical reports.

The older Phase 1F report remains historical evidence and is not rewritten to
erase the pre-closure gap it recorded.

## 17. Required 1.0 item states

The authoritative per-capability list is in
[`ALPHAX_1_0_REQUIREMENTS_AUDIT.md`](ALPHAX_1_0_REQUIREMENTS_AUDIT.md). No
required item is silently reclassified. The exact non-complete states are:

| Required area | Exact state | Blocking evidence |
| --- | --- | --- |
| Android H3/release security acceptance | `IMPLEMENTED_NEEDS_VALIDATION` | Wireless ADB/package manager did not recover after reboot |
| iPhone H1/fallback, requirement, pin/trust, redirect release checks | `IMPLEMENTED_NEEDS_VALIDATION` | H2, H3, and invalid-TLS checks passed; local H1 was unreachable and a later automation retry hit `osascript: -2` |
| Android protocol requirement, pin/trust, redirect, file, and cancellation checks | `IMPLEMENTED_NEEDS_VALIDATION` | Device/package-manager access is unavailable |
| Final repository/package/security validation | `IMPLEMENTED_AND_VALIDATED` | Consolidated repository, package, security, dependency, build, and documentation checks passed |

## 18. Remaining blockers and alternatives

1. Recover Android ADB/package-manager access, install the existing profile
   runner, and run only H1, H2, H3, protocol requirement, TLS/pin, redirect,
   file, and cancellation checks.
2. Re-run the focused signed iPhone checks with a reachable H1 fixture (or a
   known H1-only endpoint): H1/fallback, protocol requirement, pin/custom
   trust, redirect security, and minimal file/cancellation sanity. H2/H3 and
   invalid-TLS evidence from the attached phone is already retained.

## 19. Final conclusion

# BLOCKED FOR 1.0 RC

The code and public contract are not eligible for an AlphaX 1.0 release
candidate until the focused Android/iPhone release-path evidence above is
complete. Provider-limited policies are accepted fail-closed boundaries and
are not RC blockers. No package has been published and no 1.0 tag has been
created.
