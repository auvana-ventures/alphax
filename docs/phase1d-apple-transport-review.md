# Phase 1D Apple URLSession transport review

Status: Phase 1D Apple URLSession implementation and focused maintainer-review
closure are complete. macOS correctness, signed physical-iPhone validation,
and the shared Apple conformance runner passed. Phase 1E remains required
before AlphaX makes a release-wide H1/H2/H3 support claim.

No performance ranking was run, no platform-specific public API was added, and no
package was published. The only public-contract change is the additive,
transport-neutral completion-time protocol metadata documented in
`docs/decisions/0005-completion-time-protocol-metadata.md` and section 12.

## 1. Supported Apple targets

The adapter is one shared Swift/Foundation implementation used by both plugin
targets:

| Target | Deployment target | Build result |
| --- | ---: | --- |
| iOS | 15.0+ | Profile device build and signed physical-device validation passed |
| macOS | 12.0+ | Profile arm64 build succeeded through XcodeBuildMCP |

The source is shared through the Apple plugin targets rather than duplicated.
The current Flutter plugin integration uses CocoaPods; Flutter reports that
`alphax_native` does not yet support Swift Package Manager for Apple targets.
That packaging warning is a release/build-system follow-up, not a public API
dependency: `alphax` remains pure Dart.

Validation environment for the completed macOS run:

| Field | Value |
| --- | --- |
| OS | macOS 26.5.2 (Build 25F84) |
| Architecture | `macos_arm64` |
| Dart | 3.13.0 |
| Flutter | 3.47.0 |
| Build | Profile correctness harness; no benchmark ranking |
| Harness base commit | `fbdd5de` |
| H2 endpoint | `https://www.apple.com/` |
| H3 endpoint | `https://cloudflare-quic.com/` |
| H1/fallback endpoint | deterministic local server at `http://127.0.0.1:18080` |
| Invalid-TLS endpoint | `https://self-signed.badssl.com/` |

Validation environment for the signed physical iPhone run:

| Field | Value |
| --- | --- |
| OS | iOS 18.7.9 (Build 22H355) |
| Architecture | `ios_arm64` |
| Build | Profile correctness harness; no benchmark ranking |
| H1 endpoint | deterministic fixture at `http://192.168.50.204:18080` over the local LAN |
| H2 endpoint | `https://www.apple.com/` |
| H3 endpoint | `https://cloudflare-quic.com/` |
| Invalid-TLS endpoint | `https://self-signed.badssl.com/` |
| TLS policy | platform trust defaults; no trust-all override |

## 2. URLSession architecture and lifecycle

`AlphaXNativePlugin.swift` is shared by iOS and macOS. It exposes only the
existing `alphax_native/transport` method channel and
`alphax_native/events` event channel. Foundation types remain inside the
plugin; no URLSession task, delegate, native file handle, or platform error is
part of the `alphax` API.

Each attached Flutter engine owns one reusable `URLSession` and one serial
delegate queue. Operations are tracked by native task identifier and are
removed only after terminal success or failure. Closing the transport:

- cancels active operations;
- invalidates the shared URLSession;
- releases the event subscription on the Dart side;
- rejects new requests as client-closed; and
- waits for URLSession invalidation before completing the native close call; and
- is safe to repeat.

Concurrent Dart `close()` calls join the same completion future. After that
future completes, a later logical transport facade may initialize the plugin
again and receive a fresh URLSession; no active request is detached from the
old session. This allows the shared conformance runner to create an isolated
facade per test while preserving close semantics.

The provider policy is Foundation/URLSession. There is no manual QUIC hint,
custom QUIC implementation, trust-all path, C++ engine, Rust transport, or
libcurl dependency.

## 3. HTTP methods and body handling

The local macOS harness returned status 200 for all required methods:

`GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, and `OPTIONS`.

The adapter maps the Phase 1A body forms as follows:

- empty, bytes, text, and JSON bodies use URLSession data tasks where the body
  is already materialized;
- materialized `OPTIONS` bodies use URLSession's data-backed upload-task path
  because the current Foundation runtime can omit an `httpBody` attached to
  an `OPTIONS` data task;
- streamed Dart bodies use a bounded demand bridge and
  `uploadTask(withStreamedRequest:)`;
- local file bodies use `uploadTask(with:fromFile:)`; and
- multipart remains represented by the existing core body abstraction and is
  sent through the streaming/file mapping without exposing Foundation types.

The byte-body path deliberately uses a data task so response bytes remain on
the URLSession data-delegate path. It does not change the no-buffering rule for
stream or file bodies.

The macOS correctness harness also sent a three-byte, two-chunk Dart request
body through the streamed upload path and received the exact echoed bytes. This
keeps the streamed-body mapping covered separately from the materialized byte
and native file paths.

A focused macOS rerun initially detected that a materialized `OPTIONS` body was
not echoed by Foundation even though the request advertised its content length.
The adapter now uses the native upload-task initializer only for that method;
the rerun received the exact three-byte body and all required-method checks
passed. This is an Apple implementation detail and does not change the public
AlphaX contract.

When URLSession requests a replacement body stream for a redirect, the native
adapter resets a replayable Dart body cursor through the private channel before
creating the replacement stream. Single-consumption bodies are rejected by the
redirect policy and are never replayed.

## 4. Protocol matrix and negotiation evidence

The adapter reports the requested preference separately from the actual
protocol. Actual protocol values come from `URLSessionTaskMetrics` and are not
inferred from capability flags or `Alt-Svc`.

| Probe | Requested | Actual | Result |
| --- | --- | --- | --- |
| `https://www.apple.com/` | auto | HTTP/2 | verified, status 200 |
| `https://cloudflare-quic.com/` | HTTP/3 | HTTP/3 | verified, status 200; `Alt-Svc: h3=":443"` also observed |
| local deterministic H1 endpoint | HTTP/3 | HTTP/1.1 | verified fallback; AlphaX reports requested H3 and negotiated H1 |

The harness recorded `started_protocol: unknown` for streamed responses. This
is intentional: URLSession exposes the authoritative negotiated protocol in
task metrics at completion. The final `AlphaXResponseCompleted.metrics` and
fallback metadata are the authoritative stream result. For `send()`, the
immutable response contains the headers-time snapshot and exposes the same
final result through `AlphaXResponse.completionMetrics` and
`completionProtocolFallback`. A response may therefore transition from
`unknown` at headers/stream start to H1/H2/H3 at completion without buffering
the body or leaking Foundation types. The adapter never labels a response H3
from a preference or server advertisement alone.

The Apple capability model reports H1/H2/H3 as supported on iOS 15+ and macOS
12+ because those Foundation stacks can attempt those protocols. Per-request
metrics remain authoritative when a path falls back.

## 5. H3 evidence and physical iPhone validation

macOS and the signed physical iPhone both produced actual `http3`
task-metric results against `cloudflare-quic.com`; this is
capability/correctness evidence only, not a performance result. The iPhone
run also verified:

| Probe | Requested | Actual | Result |
| --- | --- | --- | --- |
| `https://www.apple.com/` | auto | HTTP/2 | status 200, body complete |
| `https://cloudflare-quic.com/` | HTTP/3 | HTTP/3 | status 200, body complete, `Alt-Svc: h3=":443"` observed |
| deterministic LAN fixture | HTTP/3 | HTTP/1.1 | status 200, truthful H3 fallback metadata |

The full signed iPhone correctness run also passed required methods and
bodies, streamed upload, bounded streaming pause/resume, cancellation,
request-timeout mapping, native file upload/download, deterministic file
hashes, TLS rejection, and close/reuse lifecycle. The emitted result recorded
`started_protocol: unknown` and authoritative completion protocols, matching
the transport-neutral metadata contract.

The validation app uses automatic signing configured on the local `Runner`
host application. This is host-app deployment configuration; it is not an
AlphaX public API or a signing requirement for the `alphax_native` plugin
source. Certificates and provisioning profiles remain outside the package
implementation.

Reproduce the focused device validation only (no benchmark matrix):

```sh
flutter run --profile --no-pub \
  -d <physical-iphone> \
  --target lib/phase1d_apple_main.dart \
  --dart-define=ALPHAX_PHASE1D_H1_URL=https://<trusted-h1-fixture>/resource \
  --dart-define=ALPHAX_PHASE1D_H2_URL=https://www.apple.com/ \
  --dart-define=ALPHAX_PHASE1D_H3_URL=https://cloudflare-quic.com/ \
  --dart-define=ALPHAX_PHASE1D_INVALID_TLS_URL=https://self-signed.badssl.com/ \
  --dart-define=ALPHAX_DEVICE_MODEL=<model> \
  --dart-define=ALPHAX_DEVICE_ARCH=arm64 \
  --dart-define=ALPHAX_GIT_COMMIT=<commit>
```

The fixture certificate must be trusted by the device; do not use a
trust-all override. Accept the run only when the emitted result records
actual H1, H2, and H3 task-metric protocols, and when an H3 preference against
the H1/H2 endpoint reports the lower actual protocol plus truthful fallback.
The same run retains the existing streaming, file, cancellation, timeout, and
TLS checks.

## 6. Streaming and bounded delivery

The native response path uses:

```text
4 credits × 64 KiB = 256 KiB queued delivery window
                     + one URLSession delegate callback
```

When credits are exhausted, the URLSession task is suspended. Dart stream
pause stops new credits; resume replenishes the window. Cancellation while
paused cancels the native task and releases the operation. URLSession controls
the size of an individual delegate callback, so the implementation documents
the callback as the additional bounded platform-owned buffer rather than
claiming an exact global byte ceiling independent of Foundation.

The macOS harness delivered four chunks totaling 262,144 bytes, paused after
the first chunk, resumed, and completed without losing data. The same run
validated the streamed request body and completed with no native stream
lifecycle exception. A lifecycle fix also retains bounded pending chunks until
credits arrive, preventing tiny responses from disappearing when a task
completes before Dart attaches its body listener.

The same run closed the transport, verified that a request after close failed
with `AlphaXClientClosedException`, and verified that repeated close remained
safe after URLSession invalidation.

## 7. Native file transfer and progress

The tested native file paths are:

```text
download: URLSessionDownloadTask → native temporary file → target file
upload:   source file → URLSession upload task → network
```

The macOS harness validated a deterministic 1 MiB payload with exact byte count
and FNV-1a64 hash `4c568eccaeaf6c44` for both paths. The download emitted 16
monotonic progress events; the upload emitted one monotonic completion event.
The full payload did not need to cross Dart for these local-file paths.

Callers using a non-local `AlphaXFileSource` or `AlphaXFileTarget` continue to
use the transport-neutral Dart stream fallback. The public API does not expose
the optimized-path distinction as a platform-specific type.

## 8. Cancellation and timeouts

The macOS harness cancelled a delayed local request and received the normalized
`AlphaXCancellationException`. Native cancellation is also wired for response
streaming, file tasks, upload tasks, paused delivery, and session close.

The harness additionally set a 50 ms request timeout on a 500 ms delayed local
response and observed `AlphaXTimeoutKind.request`, confirming that the exact
AlphaX timer category is preserved rather than being collapsed into an overall
timeout.

The Phase 1A timeout categories are mapped as follows:

| Category | URLSession mapping |
| --- | --- |
| connect | AlphaX timer around connection/setup; URLSession does not expose a portable exact phase boundary |
| request | URLRequest request timeout plus AlphaX timer through response headers/body dispatch |
| read | AlphaX inactivity timer reset by response delivery |
| overall | AlphaX timer covering the operation through completion |

Unavailable phase detail remains unavailable rather than being fabricated.
Explicit AlphaX timer expirations preserve their own category in the native
event; a native `NSURLErrorTimedOut` without a phase distinction uses the
documented fallback classification.

## 9. Redirects and errors

Redirect policy is implemented in the URLSession task delegate. Follow mode
records redirect metadata and enforces the configured maximum; manual mode
returns the redirect response; reject mode raises a normalized redirect error.
Single-consumption request bodies are not replayed through a redirect.

Apple errors are normalized to the Phase 1A taxonomy: DNS, connection, TLS,
timeout, cancellation, protocol, redirect, request body, response body,
unsupported capability, and transport/internal. NSError domain/code details
remain diagnostic information only. The invalid-certificate probe against
`self-signed.badssl.com` was rejected as `AlphaXTlsException`.

Cross-origin redirect requests remove `Authorization`, `Proxy-Authorization`,
and `Cookie` headers before URLSession follows them. Same-origin redirects
retain URLSession's normal method/body semantics. The focused harness exercised
same-origin redirect follow and metadata; the cross-origin sensitive-header
guard remains a targeted security regression for the signed platform run.

## 10. Proxy behavior and capability output

URLSession inherits system proxy behavior by default. For the explicit
AlphaX HTTP-proxy policy, the native engine supplies the CFNetwork proxy
dictionary for HTTP destinations and HTTPS destinations through HTTP CONNECT.
Basic credentials are sent as a hop-by-hop `Proxy-Authorization` value for
the selected explicit proxy route; they are never copied into origin
`Authorization` and are not logged. A 407 response is normalized as
`AlphaXProxyAuthenticationException`.

The focused macOS security fixture is recorded in
`benchmarks/mobile_gate/fixtures/phase1f_macos_security_policy.json` and
produced the following results:

| Behavior | Result |
| --- | --- |
| System proxy settings | passed; inherited by default URLSession configuration |
| Direct/no-proxy policy | passed; local route bypassed the fixture proxy |
| Explicit HTTP proxy for HTTP | passed; local proxy observed the request |
| Explicit HTTP proxy for trusted HTTPS | passed; local proxy observed and completed CONNECT |
| Basic proxy authentication | passed; correct credentials accepted and wrong credentials failed closed as normalized proxy-authentication error |
| Unreachable explicit proxy | passed; failed closed |
| Local custom CA through CONNECT | failed closed with normalized TLS error; this route-specific combination is not claimed as supported |
| Explicit HTTPS proxy endpoint | unsupported and rejected by policy validation |
| H3 through a proxy | not guaranteed; final task metrics remain authoritative and may report H2/H1 fallback |

The Apple capability output is therefore:

| Capability | Result |
| --- | --- |
| HTTP/1.1, HTTP/2, HTTP/3 | supported/attemptable on target OS |
| negotiated protocol reporting | supported |
| streaming upload/download | supported with bounded delivery |
| native file upload/download | supported for local file abstractions |
| upload/download progress | supported |
| system proxy | supported/platform-managed |
| direct connection policy | supported through CFNetwork configuration |
| explicit HTTP proxy | supported; HTTPS destinations use CONNECT where available |
| proxy authentication | supported for explicit HTTP Basic route |
| explicit HTTPS proxy endpoint | unsupported |
| certificate pinning | supported; normal trust remains required |
| custom trust anchors | supported for direct URLSession trust evaluation |
| mTLS | unsupported/not part of the 1.0 release gate |
| connection migration | unsupported/not exposed |
| background transfer | unsupported/not part of 1.0 |

No unsupported policy silently degrades to direct or system routing, and no
capability flag is treated as proof of an individual request's negotiated
protocol.

## 11. Binary and package impact

The profile macOS validation application was approximately 59.2 MB. The
profile iOS validation application was approximately 27.4 MB. These are
disposable harness artifacts, not incremental AlphaX transport-size claims.
The Apple adapter adds Swift/Foundation plugin source and CocoaPods target
metadata; it does not add a separately bundled third-party networking runtime.
Final release artifact accounting remains Phase 1E/release validation work.

## 12. Public contract decisions and known differences

The smallest transport-neutral API correction was made in `alphax`: immutable
`AlphaXResponse` now has `completionMetrics` and
`completionProtocolFallback` futures. `metrics` and `negotiatedProtocol` remain
headers-time snapshots; the completion futures are authoritative when a
transport learns protocol details only at completion.
`AlphaXResponseCompleted.metrics`, `requestedProtocol`, and
`protocolFallback` are the equivalent terminal source for `sendStreaming()`.
Unknown is a valid state, and callers are never required to interpret it as
HTTP/1.1 or fallback. Dart IO and native transports may provide a known protocol
at start when their provider exposes one earlier. The additive compatibility
record is `docs/decisions/0005-completion-time-protocol-metadata.md`.

`alphax_test` now accepts synchronous or asynchronous transport factories. The
mobile gate contains an isolated Flutter `integration_test` runner that calls
the same shared conformance suite after the platform plugin is attached. The
Apple plugin can safely reinitialize its shared engine after each awaited test
teardown. No Flutter dependency was added to `alphax`.

Other platform differences to carry forward are:

- Dart IO SPKI pinning, Apple/Android mTLS identity resolution, migration, and
  background transfer remain unsupported or provider-limited;
- Flutter currently uses CocoaPods for this plugin because Swift Package
  Manager support is not declared;
- physical iPhone signing/provisioning is environment-owned, not a package
  setting.

The close path now waits for URLSession invalidation after cancellation, so the
native close acknowledgement represents callback quiescence rather than only a
request to cancel. Replayable streamed-body redirect handling also resets the
Dart upload cursor before replacement-stream creation.

The plugin also invalidates its native session when an iOS Flutter engine
detaches and from the shared plugin deinitializer, so session ownership does
not depend solely on an application-level `close()` call.

During the final fresh macOS build, the custom streamed-upload
`InputStream` initially exposed missing Foundation abstract lifecycle hooks.
The adapter was corrected to implement stream status, delegate, property, and
run-loop scheduling hooks; the rerun passed the streamed upload and all other
macOS checks. This was an implementation correction, not a change to the
Phase 1A contract.

## 13. Focused release-closure addendum

The 2026-08-15 macOS fixture run passed all recorded checks for default trust
rejection, custom CA success/failure, primary and backup SPKI pins, pin
mismatch, invalid-certificate rejection despite a matching pin, direct and
explicit proxy routing, trusted HTTPS CONNECT, Basic proxy authentication,
wrong-credential rejection, unreachable-proxy failure, and system policy.

The signed iPhone runner attached successfully for one direct profile run and
verified actual H2 on `https://www.apple.com/`, actual H3 on
`https://cloudflare-quic.com/`, and invalid-certificate rejection. The local
plain-HTTP fixture was unreachable from the phone on both tested host
interfaces, so local H1/fallback, file, stream, and lifecycle checks were not
counted as new device evidence. A later `flutter drive` retry hit the existing
`osascript: -2` automation attachment failure. Historical signed Phase 1D/1E
evidence remains preserved and is not rewritten.

## 14. Phase 1E blockers

Before AlphaX 1.0 can claim the accepted platform strategy across Apple and
Android, Phase 1E must:

1. perform cross-transport parity and release-configuration validation;
2. validate final CocoaPods/Flutter packaging and release claims.

No Phase 1E work has been started by this task.
