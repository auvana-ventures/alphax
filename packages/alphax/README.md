# alphax

`alphax` is the transport-independent HTTP client foundation for Dart and
Flutter. Write request code once, then run it with Dart IO, Android Cronet,
Apple URLSession, or a separate browser adapter without changing your request,
response, streaming, file, cancellation, timeout, or error-handling code.

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

## When should I choose this package?

Choose `alphax` for a new HTTP integration or when you want to keep your
application independent of a particular networking engine. If you already use
Dio and want to preserve Dio request code, use
[`alphax_dio`](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_dio) instead. If you need deterministic
tests, add [`alphax_test`](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_test) as a development
dependency.

## Install

After the RC is published:

```sh
flutter pub add alphax alphax_native
```

While this RC is unpublished, use the repository dependencies shown in the
[root README](https://github.com/auvana-ventures/alphax#readme).

`alphax` itself has no Flutter SDK dependency and can be used from pure Dart.
The examples below use the Dart IO fallback supplied by `alphax_native`.

## Your first request

This is a complete small client: create a transport, send a request, read the
body, and close the client when the work is finished.

```dart
import 'package:alphax/alphax.dart';
import 'package:alphax_native/alphax_native.dart';

Future<void> main() async {
  final client = AlphaXClient(transport: DartIoTransport());
  try {
    final response = await client.get(Uri.https('example.com', '/'));
    print('${response.statusCode}: ${await response.readAsString()}');
  } finally {
    await client.close();
  }
}
```

For Android, create `AndroidCronetTransport`; for iOS and macOS, create
`AppleUrlSessionTransport`. The AlphaX request and response code remains the
same. See [`alphax_native`](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_native) for platform setup.

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

### Add the policies your application needs

Policies are explicit middleware. They are not enabled by `AlphaXClient` by
default, so an application can choose its retry, credential, cookie, cache,
and resilience behavior deliberately.

```dart
final client = AlphaXClient(
  transport: transport,
  middleware: <AlphaXMiddleware>[
    AlphaXAuthenticationMiddleware(
      accessToken: tokenStore.currentAccessToken,
      refreshAccessToken: tokenStore.refreshAccessToken,
    ),
    AlphaXCookieMiddleware(AlphaXCookieJar()),
    AlphaXRetryMiddleware(),
    AlphaXCacheMiddleware(store: AlphaXMemoryCacheStore()),
    AlphaXResilienceMiddleware(
      policy: const AlphaXResiliencePolicy(failureThreshold: 5),
    ),
  ],
);
```

Retries are limited to replayable, idempotent buffered requests by default.
Cache entries are in memory and cover buffered GET/HEAD responses. Authentication
refresh is single-flight and occurs once after a configured challenge; token
storage remains application-owned. Cookies are in memory, and resilience is a
generic circuit breaker rather than a vendor-specific reliability service.

## What this package includes

The frozen public API includes request and response types, headers and bodies,
streaming, file-transfer contracts, cancellation, timeouts, redirects,
middleware, capabilities, protocol preference and requirement, completion-time
metrics, TLS and proxy policy models, normalized errors, and the opt-in policy
modules documented above.

Use `AlphaXResponse.completionMetrics` and
`completionProtocolFallback` for authoritative final protocol metadata when a
platform reports negotiation only after the operation completes.
`AlphaXProtocol.unknown` is never silently treated as HTTP/1.1 or fallback.

## Boundaries to keep in mind

- It does not include a native transport implementation by itself.
- Web support is provided by the separate [`alphax_web`](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_web)
  package; importing `alphax` alone does not make Web available.
- It does not guarantee H3; provider, server, proxy, and network conditions
  decide the actual protocol.
- The policy middleware is deliberately bounded: no persistent cookie store,
  disk cache, unsafe replay, model-specific authentication framework, or
  vendor-specific resilience policy is included.
- It makes no universal speed, zero-copy, or “fastest client” claim.

## Continue learning

- [Choose a package in the root README](https://github.com/auvana-ventures/alphax#which-package-do-i-need)
- [Native platform transports](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_native)
- [Browser Fetch transport](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_web)
- [Dio adapter](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_dio)
- [Testing helpers](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_test)
- [Waypoint reference app](https://github.com/auvana-ventures/alphax/tree/main/examples/waypoint)
- [Migration guide](https://github.com/auvana-ventures/alphax/blob/main/docs/MIGRATION.md)

The `1.0.0-rc.1` candidate is prepared for maintainer review and is not
published until naming clearance and release approval are complete.
