# AlphaX RC5 WebSocket Review

This review records the Task D implementation of a transport-neutral WebSocket
lifecycle seam. It does not add a WebSocket engine and does not route WebSocket
traffic through `AlphaXTransport.send()`.

## 1. Final public API

The core API is exposed by `package:alphax/websocket.dart`:

- `AlphaXWebSocketConnector.connect(...)` establishes one session.
- `AlphaXWebSocketSession` exposes state, negotiated subprotocol, ordered
  messages, terminal close information, `send`, and `close`.
- `AlphaXWebSocketMessage.text(...)` and `.binary(...)` preserve message kind.
- `AlphaXWebSocketCloseInfo` records close origin, nullable code, and nullable
  reason.
- `AlphaXWebSocketCapabilities` reports provider capabilities and limitations.
- `AlphaXWebSocketException` and `AlphaXWebSocketClosedException` normalize
  public connection/session failures.

Deployment packages expose one obvious connector factory:

```dart
import 'package:alphax_native/alphax_native.dart';

final connector = createAlphaXWebSocketConnector();
final socket = await connector.connect(Uri.parse('wss://example.test/socket'));
await socket.send(const AlphaXWebSocketMessage.text('hello'));
await socket.close();
```

The browser entry point uses the same factory name through
`package:alphax_web/alphax_web.dart`. No `connectWebSocket()` method was added
to `AlphaXClient`, because the HTTP client owns an HTTP request/response
contract and not every HTTP transport is a WebSocket provider.

## 2. Contract and package placement

The contract is in the pure-Dart `alphax` package and has no WebSocket runtime
dependency. The dedicated `websocket.dart` sub-library is intentionally not
re-exported by `package:alphax/alphax.dart`, keeping the default HTTP surface
small. `alphax_native` and `alphax_web` re-export the sub-library to preserve a
single deployment-family import for ordinary users.

No `alphax_websocket` package was created. The dependency direction remains:

```text
alphax contract
    ↑
alphax_native / alphax_web connector
    ↑
maintained package:web_socket provider
```

The provider choice is the Dart HTTP repository's maintained `web_socket`
package, which supplies consistent text/binary events, close events, protocol
reporting, and Dart IO/browser implementations:
[package:web_socket source](https://github.com/dart-lang/http/tree/master/pkgs/web_socket).

## 3. Connector/session lifecycle

`connect` validates `ws:`/`wss:` and returns a session only after the provider
has opened successfully. A returned session starts in `open`; the public state
model also defines `connecting`, `closing`, and terminal `closed` for lifecycle
implementations.

Each successful call creates exactly one provider connection and one caller-owned
session. There is no global session, provider cache, per-message connection, or
automatic reconnect. A session has one terminal `done` future and one final
close record. `close` is idempotent and repeated calls return the same in-flight
close operation.

## 4. Message model

`AlphaXWebSocketMessage` has only complete text and binary variants. Text stays
text; binary is copied into an immutable-by-convention `Uint8List` boundary and
the getter returns a defensive copy. Provider frame fragmentation is not part of
the portable API; the maintained provider reassembles complete messages.

## 5. Send semantics

`session.send(message)` dispatches text and binary messages through the provider
without coercion. Calls execute in caller order, and completion means that the
provider accepted the send call. It does not claim peer acknowledgement or
network flush. AlphaX does not intentionally drop, retry, replay, or resend a
message; a provider can still have a documented race in which a browser send is
accepted locally and discarded after an undetected peer disconnect. Sending
once closing or closed fails with `AlphaXWebSocketClosedException`.

## 6. Receive semantics

`session.messages` is a lazy, single-subscription stream of complete messages.
Provider messages are mapped incrementally and in order. A provider close or
terminal error ends the AlphaX stream, and no message is emitted after the
session reaches `closed`.

Cancelling the message subscription stops receiving but does not implicitly close
the session; the caller retains explicit close ownership. This keeps stream
cancellation from being confused with the lifecycle close operation.

## 7. Close semantics

Local close transitions `open -> closing -> closed` and records the requested
code/reason unless a provider error wins first. Peer close preserves the
provider-reported code/reason and is marked `peer` for normal reported close
codes. A missing or `1006` provider code is classified as `error`, emits a
normalized terminal error on the message stream, and preserves the abnormal
close facts in `done`; AlphaX does not invent a normal close code for abnormal
termination.

The maintained provider accepts close code `1000` or application codes
`3000..4999`, and reason values up to 123 UTF-8 bytes. The AlphaX adapters
validate this provider-supported subset, reject a reason without a code, and
reject invalid values before provider dispatch. The provider's more restrictive
outgoing close-code API is documented rather than hidden.

## 8. Subprotocols

`connect` accepts requested subprotocols and exposes the provider-reported
`negotiatedSubprotocol`, or `null` when no protocol was selected/reported. The
selection is never inferred from request order. Native and browser fixtures
negotiate `alpha.v1` authoritatively.

## 9. Cancellation

`AlphaXCancellationToken` is checked before dispatch and can cancel an in-flight
connect. If a provider connection completes after connect cancellation or
timeout, the late provider socket is closed and no partial session is returned.
For the built-in connectors, cancellation after open maps to an explicit local
close with no invented code/reason. There is no second WebSocket cancellation
system and no reconnect policy.

## 10. Error model

Connection, receive, send, and provider setup failures are normalized to
`AlphaXWebSocketException` while retaining the original cause and stack where
the AlphaX error surface permits. Closed-session sends use the deterministic
`AlphaXWebSocketClosedException`. Provider-native exceptions are not the
recommended public contract. Peer HTTP status failures and abrupt provider
termination do not become successful sessions.

## 11. Backpressure and buffering

The adapter does not eagerly consume the provider event stream or maintain an
additional AlphaX-owned message queue. The AlphaX message controller starts the
provider subscription when the caller listens, forwards pause/resume to that
subscription, and cancels it when the caller cancels the message stream.

The maintained provider's Dart IO/browser adapters continue reading the
underlying provider into their own event controller, so pausing the AlphaX
subscription does not pause provider reads. Built-in connectors therefore
report `receivePauseResume: AlphaXSupport.unsupported`. Provider-internal
buffering and queued-byte limits are not exposed; AlphaX does not claim network
backpressure or a provider-enforceable maximum message size
(`maximumMessageBytes` is unknown).
Outgoing completion has the provider-acceptance meaning described above; no
fictional flush or queue metric is exposed.

## 12. Ping/pong capability

Manual ping/pong is not a common method. Both built-in connectors report
`manualPingPong: AlphaXSupport.unsupported`. Provider-managed control frames
remain provider behavior and no fabricated pong events are emitted.

## 13. Header and authentication limitations

The portable request intentionally has no arbitrary headers because browser
WebSocket does not permit them. Both built-in connectors report
`customHeaders: AlphaXSupport.unsupported`; security-sensitive headers are not
silently dropped because they are not accepted by this common API.

Native callers must use an authentication mechanism supported by their chosen
provider/application protocol. Browser callers remain subject to browser
cookies, origin, CSP, and server authentication rules; subprotocol or an
application message may be appropriate where the protocol defines it. AlphaX
does not transform `Authorization` into a query parameter and does not add an
authentication framework.

`wss:` remains browser/Dart-provider TLS behavior. HTTP transport TLS and proxy
policy are not silently applied to this separate WebSocket connector, and no
trust-all or arbitrary certificate bypass was added.

## 14. Provider implementation strategy

Both integration packages use thin adapters over the maintained
`package:web_socket` API:

- `alphax_native` uses the provider's Dart IO implementation.
- `alphax_web` uses the provider's browser WebSocket implementation.

No Kotlin/Swift WebSocket engine, Cronet WebSocket path, URLSession WebSocket
adapter, or second custom engine was introduced. This keeps the Task D change
small while preserving a custom connector/session interface for deployments
that need another maintained provider.

## 15. Native validation

`packages/alphax_native/test/websocket_test.dart` uses a local deterministic
Dart HTTP/WebSocket fixture and validates:

- text and binary echo with ordered delivery;
- subprotocol negotiation;
- peer close code/reason;
- abnormal raw socket termination without a fabricated normal close;
- local close, repeated close, and send-after-close;
- close argument validation;
- setup failure normalization;
- pre-connect and in-connect cancellation;
- connect timeout and late provider cleanup;
- cancellation after open;
- paused receive stream ordering and provider subscription pause/resume.

The focused native suite passed 13 tests, and the full native package suite
passed 61 tests.

## 16. Web validation

`packages/alphax_web/test/websocket_test.dart` runs the same portable checks
against a local browser fixture when compiled with Chrome. The fixture covers
text, binary, negotiated subprotocol, peer close, and abnormal close. The
Chrome run passed all 3 browser tests. The VM run remains a no-op-gated 3-test
compatibility check because browser WebSocket is unavailable there.

The browser connector leaves TLS, origin, cookies, CSP, network policy, and
browser header limitations browser-owned. It does not claim EventSource or
native header parity.

## 17. Conformance suite

Core deterministic tests cover message buffer ownership, nullable close facts,
custom connector implementation, open/send/receive/close lifecycle, repeated
close, and send-after-close. Native provider tests cover the provider and local
fixture behavior listed above. Existing package conformance suites remain
unchanged; no duplicate HTTP transport conformance suite was added.

## 18. Custom provider support

Advanced users and tests can implement `AlphaXWebSocketConnector` and
`AlphaXWebSocketSession` without depending on either built-in adapter. The
portable contract contains no provider object types. A general fake was not
added to `alphax_test`: the core package's focused fake proves the interface,
and a reusable provider fake would add public surface without being required by
the approved boundary.

## 19. GraphQL-readiness without GraphQL coupling

The seam supports the transport-level needs of common subscription protocols:
requested/negotiated subprotocols, ordered full-duplex text messages, binary
messages where needed, and deterministic close. No GraphQL names, protocol
messages, framework dependencies, or subscription behavior were added. GraphQL
validation remains outside Task D.

## 20. Dependency and package impact

Runtime dependency graph:

```text
alphax_native -> alphax, web_socket, Flutter
alphax_web    -> alphax, http, web_socket
alphax        -> no WebSocket runtime dependency
```

No package was added. The existing `alphax_native` and `alphax_web` package
versions remain unchanged for coordinated rc.5 release preparation. No
GraphQL, generator, framework, or native WebSocket dependency leaked into
runtime packages.

## 21. Security review

The implementation keeps `ws:`/`wss:` explicit, does not add TLS bypass or
trust-all behavior, and does not claim that HTTP TLS/proxy policy configures a
separate WebSocket provider. Browser custom-header restrictions are reported
instead of silently losing credentials. Auth values, message bodies, and close
reasons are not logged by the adapters; `toString` for close information and
messages intentionally avoids including potentially sensitive content. No
provider-native exception is made the public compatibility contract.

## 22. Documentation and examples

Updated:

- root `README.md` with deployment-path guidance, connector usage, capability
  boundaries, and package roles;
- `docs/USAGE_AND_CUSTOMIZATION.md` with the lifecycle model and browser/native
  limitations;
- `packages/alphax/README.md` with the contract and custom-provider path;
- native and Web package READMEs with one-import examples and provider limits;
- compile-tested `packages/alphax_native/example/websocket.dart` and
  `packages/alphax_web/example/websocket.dart`.

The documentation explicitly says there is no automatic reconnect, no frame
fragmentation API, no universal manual ping/pong, and no browser arbitrary
header support.

## 23. Package dry-runs

All seven workspace package dry-runs passed with `--ignore-warnings`. The
affected archive sizes were:

| Package | Compressed archive |
|---|---:|
| `alphax` | 63 KB |
| `alphax_native` | 103 KB |
| `alphax_web` | 17 KB |

The remaining package dry-runs also passed: `alphax_dio` 15 KB,
`alphax_http` 12 KB, `alphax_test` 12 KB, and `alphax_transform` 14 KB.
The only warnings were expected dirty-worktree warnings for Task D-modified
README/entry/pubspec files. Archive listings contained intended package
examples/tests and no root WebSocket fixture tool, benchmark output, local
paths, secrets, or signing material.

## 24. Validation

Passed:

- `dart format --set-exit-if-changed` for all changed Dart sources;
- `dart analyze` for `alphax`, `alphax_dio`, `alphax_http`, `alphax_test`,
  `alphax_transform`, and `alphax_web`;
- `flutter analyze` for `alphax_native`;
- core WebSocket tests: 3 passed;
- native focused WebSocket tests: 13 passed;
- browser Chrome tests: 3 passed;
- VM-gated WebSocket tests: 3 passed;
- `./tooling/scripts/test_packages.sh`: all seven package suites passed;
- Dartdoc `--validate-links`: all seven packages completed with zero errors;
- package dry-runs and archive inspection;
- dependency graph, secret/path, and protected-file audits;
- `git diff --check`.

Dartdoc emitted existing repository-style warnings for relative example links
and generated documentation files (including baseline warnings in unaffected
packages), but no Dartdoc errors. No performance benchmarks were run.

The workspace contains seven package directories (`alphax`, `alphax_dio`,
`alphax_http`, `alphax_native`, `alphax_test`, `alphax_transform`, and
`alphax_web`), so seven package suites were run; there is no eighth package
directory to validate or claim.

## 25. Remaining limitations

- Browser WebSocket cannot provide arbitrary connection headers; authentication
  must use browser/provider-supported mechanisms or application protocol
  messages.
- Provider-internal receive buffering and network-level send flush state are
  not controllable or observable through the maintained common API.
- Manual ping/pong, frame fragmentation, compression controls, and provider
  maximum message limits are not portable API features.
- The built-in adapters expose the maintained provider's restricted outgoing
  close-code subset.
- Cancelling a receive subscription does not close the session; callers must
  retain and close their session explicitly.
- Automatic reconnect, backoff, replay, message resend, EventSource parity, and
  GraphQL protocol behavior remain intentionally out of scope.
- Platform-specific WebSocket providers beyond Dart IO and browser WebSocket
  were not added or claimed as validated.

## 26. Exact next task

Return for maintainer review. After approval, the next locked feature is
**Task E — direct typed REST generator**. Do not begin generator, OpenAPI,
Protobuf, GraphQL framework, gRPC, SSE, or any broader ecosystem work in this
task.

RC5 WEBSOCKET READY
