# alphax

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://github.com/auvana-ventures/alphax/raw/main/packages/alphax/assets/branding/alphax-logo-light.svg">
    <img src="https://github.com/auvana-ventures/alphax/raw/main/packages/alphax/assets/branding/alphax-logo-dark.svg" alt="AlphaX" width="300">
  </picture>
</p>

<p align="center"><strong>The transport-neutral AlphaX API.</strong><br>
Write request code once and choose the transport at the application boundary.</p>

<p align="center">
  <a href="https://github.com/auvana-ventures/alphax/blob/main/docs/ALPHAX_1_0_SCOPE.md">1.0 scope</a> ·
  <a href="https://github.com/auvana-ventures/alphax/blob/main/docs/USAGE_AND_CUSTOMIZATION.md">Usage and customization</a> ·
  <a href="https://github.com/auvana-ventures/alphax/tree/main/examples/waypoint">Waypoint example</a> ·
  <a href="https://github.com/auvana-ventures/alphax/blob/main/LICENSE">Apache-2.0</a>
</p>

## At a glance

| You need | `alphax` provides |
| --- | --- |
| Request code | Transport-neutral requests, responses, headers, bodies, streams, files, cancellation, timeouts, redirects, and normalized errors |
| Protocol control | Preference, fail-closed requirement, capabilities, completion-time protocol metadata, and fallback information |
| Application policy | Opt-in authentication, replay-aware retry, cookies, private HTTP cache, and generic circuit-breaker middleware |
| Storage | In-memory cookie/cache implementations plus stable caller-owned store seams for persistence |
| Transport | HTTP and WebSocket contracts only; add `alphax_native`, `alphax_web`, or another provider implementation |

## Start here

1. Install `alphax` with the transport package for your target.
2. Run [your first request](#your-first-request).
3. Choose a task from [common jobs](#common-jobs).
4. Add policies only after reading the [defaults](#understand-defaults-before-adding-policies)
   and [policy guide](https://github.com/auvana-ventures/alphax/blob/main/docs/POLICIES.md).

`alphax` is the transport-independent HTTP client foundation for Dart and
Flutter. Write request code once, then run it with Dart IO, Android Cronet,
Apple URLSession, or a separate browser adapter without changing your request,
response, streaming, file, cancellation, timeout, or error-handling code.
Its dedicated WebSocket sub-library defines the portable full-duplex lifecycle;
it does not select or implement a WebSocket provider.

## Why use it?

Use `alphax` when you want:

- one stable request/response API across different platform transports;
- the protocol that actually completed a request, instead of assuming H3;
- explicit H3 preference or fail-closed H3 requirement;
- streamed bodies and file transfers without forcing whole-body buffering;
- cancellation, timeouts, redirects, middleware, TLS, proxy, and normalized
  errors in transport-neutral types.
- opt-in retry, authentication, cookie, cache, and generic resilience
  middleware with safe replay defaults.

`alphax` does not open a network connection by itself. It defines the contracts
and client facade; choose a transport from
[`alphax_native`](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_native),
[`alphax_web`](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_web), or provide another
`AlphaXTransport` implementation.

For the normal native-platform choice, use
`createAlphaXTransport()` from `alphax_native`. That factory belongs outside
this pure-Dart package and selects Android Cronet/HttpEngine, Apple URLSession,
or Dart IO. Web remains an explicit `WebFetchTransport()` choice from
`alphax_web`; `AlphaXClient()` without a transport is not supported.

## When should I choose this package?

Choose `alphax` for a new HTTP integration or when you want to keep your
application independent of a particular networking engine. If you already use
Dio and want to preserve Dio request code, use
[`alphax_dio`](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_dio) instead. If you need deterministic
tests, add [`alphax_test`](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_test) as a development
dependency.

## Install

The coordinated `1.0.0-rc.4` release is published on pub.dev:

```sh
flutter pub add alphax alphax_native
```

`alphax` itself has no Flutter SDK dependency and can be used from pure Dart.
The example below uses the automatic factory supplied by `alphax_native`; a
pure-Dart application may inject its own `AlphaXTransport` instead.

## Your first request

This is a complete small client: create a transport, send a request, read the
body, and close the client when the work is finished.

```dart
import 'package:alphax/alphax.dart';
import 'package:alphax_native/alphax_native.dart';

Future<void> main() async {
  final client = AlphaXClient(transport: await createAlphaXTransport());
  try {
    final response = await client.get(Uri.https('example.com', '/'));
    print('${response.statusCode}: ${await response.readAsString()}');
  } finally {
    await client.close();
  }
}
```

The native factory removes platform branching from normal application setup.
Inject `DartIoTransport()`, `AndroidCronetTransport.create()`,
`AppleUrlSessionTransport.create()`, or `WebFetchTransport()` explicitly when
you need a deliberate provider. See [`alphax_native`](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_native)
and the [usage guide](https://github.com/auvana-ventures/alphax/blob/main/docs/USAGE_AND_CUSTOMIZATION.md)
for the selection boundary.

## Common jobs

### Prefer a protocol and inspect what happened

Preference is opportunistic. The server, provider, proxy, and network may
negotiate a lower protocol, and AlphaX reports the result.

```dart
final response = await client.get(
  Uri.https('example.com', '/health'),
  protocolPreference: AlphaXProtocolPreference.http3,
);
final metrics = await response.completionMetrics;
print('actual protocol: ${metrics.negotiatedProtocol.name}');
```

If H3 is mandatory, pass
`protocolRequirement: AlphaXProtocolRequirement.http3`; the request fails
closed unless H3 is actually negotiated.

### Stream and cancel work

Using the long-lived `client` from the first-request example:

```dart
final token = AlphaXCancellationToken();
final response = await client.get(
  Uri.https('example.com', '/large-response'),
  cancellationToken: token,
);

await for (final chunk in response.stream) {
  // Process each chunk without requiring a complete-body buffer.
}

// Call token.cancel('screen closed') from the UI when the work should stop.
```

Response streams are single-consumption and support Dart pause/resume
semantics. Native adapters use bounded delivery windows.

### Parse Server-Sent Events

The optional `package:alphax/sse.dart` sub-library parses an AlphaX response
stream incrementally:

```dart
import 'package:alphax/alphax.dart';
import 'package:alphax/sse.dart';

Future<void> consumeSse(AlphaXClient client, Uri uri) async {
  final response = await client.send(
    AlphaXRequest(
      method: HttpMethod.get,
      uri: uri,
      headers: AlphaXHeaders({'accept': 'text/event-stream'}),
    ),
  );

  await for (final event in response.stream.transform(AlphaXSseParser())) {
    print('${event.event ?? 'message'}: ${event.data}');
  }
}
```

`AlphaXSseEvent` exposes `data`, an optional event type, an optional ID, and a
valid non-negative `retry` hint in wire milliseconds. The parser handles
fragmented UTF-8 and all SSE line endings, ignores comments/unknown fields, and
does not reconnect or send `Last-Event-ID`. The caller owns the long-lived
client and its cancellation token. The complete compile-checked example is
[`example/sse.dart`](example/sse.dart).

### WebSocket lifecycle

Import `package:alphax/websocket.dart` when implementing or consuming the
transport-neutral WebSocket contract. It contains the connector/session
lifecycle, immutable text/binary messages, negotiated subprotocol, close
metadata, capabilities, and normalized WebSocket errors. It is deliberately
separate from `AlphaXClient` and `AlphaXTransport.send()` because a WebSocket
is a long-lived full-duplex session rather than an HTTP request/response.

Use `createAlphaXWebSocketConnector()` from `alphax_native` or `alphax_web` at
the deployment boundary; those packages adapt the maintained
`package:web_socket` Dart IO or browser provider. A custom provider can
implement `AlphaXWebSocketConnector` and `AlphaXWebSocketSession` directly.
There is no automatic reconnect, retry, message replay, or resend queue.
The common contract intentionally has no arbitrary connection-header argument:
built-in browser/native providers report custom headers as unsupported rather
than silently dropping authentication metadata. See the
[native example](../alphax_native/example/websocket.dart) and
[Web example](../alphax_web/example/websocket.dart).

### Transfer files

Use the transport-neutral `AlphaXFileSource` and `AlphaXFileTarget` contracts.
`alphax_native` also provides platform file implementations such as
`AlphaXLocalFileSource` and `AlphaXLocalFileTarget`.

```dart
final result = await client.download(
  Uri.https('example.com', '/archive.bin'),
  to: AlphaXLocalFileTarget('/tmp/archive.bin'),
  onDownloadProgress: (progress) {
    print('${progress.bytesTransferred} bytes received');
  },
);
print('downloaded ${result.bytesTransferred} bytes');
```

### Understand defaults before adding policies

`AlphaXClient` does not silently enable application policy. With the default
empty middleware list:

| Behavior | Default |
| --- | --- |
| Retry | Off; failed requests run once. |
| Authentication | Off; AlphaX does not create or store tokens. |
| Cookies | Off in the core; browser cookies are separately controlled by Fetch. |
| Cache | Off; no response is stored. |
| Resilience | Off; no circuit breaker is active. |
| TLS | Verified platform trust remains enabled. |
| Proxy | The selected transport uses its system proxy policy. |
| H3 | Never guaranteed; inspect completion metadata for the actual protocol. |

Add only what the application needs. For example:

```dart
final client = AlphaXClient(
  transport: transport,
  middleware: <AlphaXMiddleware>[
    AlphaXRetryMiddleware(),
    AlphaXAuthenticationMiddleware(
      accessToken: () async => 'token-from-app',
    ),
  ],
);
```

The default retry policy only repeats replayable, idempotent buffered requests.
Authentication refresh, cookies, cache storage, resilience settings, proxy
routing, and SPKI pinning all have additional configuration and platform
limits. Follow the [policy defaults and customization guide](https://github.com/auvana-ventures/alphax/blob/main/docs/POLICIES.md)
for copyable examples, cookie/cache store seams, authenticated-cache identity
scoping, proxy setup, pin rotation, and failure-closed handling.

`alphax` is also the custom-transport seam: implement `AlphaXTransport` and
inject it into `AlphaXClient` when a caller-owned transport is required. The
transport must report honest capabilities and preserve streaming,
cancellation, completion, and close semantics.

## What this package includes

The frozen public API includes request and response types, headers and bodies,
streaming, file-transfer contracts, cancellation, timeouts, redirects,
middleware, capabilities, protocol preference and requirement, completion-time
metrics, TLS and proxy policy models, normalized errors, the incremental SSE
parser sub-library, the dedicated WebSocket lifecycle sub-library, and the
opt-in policy modules documented above.

Use `AlphaXResponse.completionMetrics` and
`completionProtocolFallback` for authoritative final protocol metadata when a
platform reports negotiation only after the operation completes.
`AlphaXProtocol.unknown` is never silently treated as HTTP/1.1 or fallback.

## Boundaries to keep in mind

- It does not include a native transport implementation by itself.
- Web support is provided by the separate [`alphax_web`](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_web)
  package; importing `alphax` alone does not make Web available.
- WebSocket provider connectors are provided by the deployment packages; the
  core contract does not own native HTTP transport selection, browser policy,
  automatic reconnect, or a WebSocket engine.
- It does not guarantee H3; provider, server, proxy, and network conditions
  decide the actual protocol.
- The policy middleware is deliberately bounded: cookie persistence remains
  caller-owned through `AlphaXCookieStore`; cache persistence remains
  caller-owned through `AlphaXCacheStore`; credential-bearing cache reuse is
  identity-scoped and Set-Cookie responses are excluded; unsafe replay, model-specific
  authentication frameworks, and vendor-specific resilience policies are not
  included.
- To customize a policy, add the relevant middleware to `AlphaXClient`; to
  customize TLS or proxy routing, configure the selected transport before
  constructing the client. Unsupported provider controls fail closed.
- It makes no universal speed, zero-copy, or “fastest client” claim.

## Continue learning

- [Choose a package in the root README](https://github.com/auvana-ventures/alphax#which-package-do-i-need)
- [Usage and customization guide](https://github.com/auvana-ventures/alphax/blob/main/docs/USAGE_AND_CUSTOMIZATION.md)
- [Native platform transports](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_native)
- [Browser Fetch transport](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_web)
- [Dio adapter](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_dio)
- [Testing helpers](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_test)
- [Policy defaults and customization](https://github.com/auvana-ventures/alphax/blob/main/docs/POLICIES.md)
- [Waypoint reference app](https://github.com/auvana-ventures/alphax/tree/main/examples/waypoint)
- [Migration guide](https://github.com/auvana-ventures/alphax/blob/main/docs/MIGRATION.md)

The coordinated `1.0.0-rc.4` release is published on pub.dev. The public
AlphaX 1.0 API remains frozen; later changes to these contracts may be
breaking. `rc.3` is the historical predecessor.
