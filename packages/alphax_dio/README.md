# alphax_dio

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://github.com/auvana-ventures/alphax/raw/main/packages/alphax_dio/assets/branding/alphax-logo-light.svg">
    <img src="https://github.com/auvana-ventures/alphax/raw/main/packages/alphax_dio/assets/branding/alphax-logo-dark.svg" alt="AlphaX" width="300">
  </picture>
</p>

<p align="center"><strong>Keep Dio. Change the transport boundary.</strong><br>
Use AlphaX transports and policies underneath an existing Dio application.</p>

<p align="center">
  <a href="https://github.com/auvana-ventures/alphax/blob/main/docs/MIGRATION.md">Migration guide</a> ·
  <a href="https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_native">Native transports</a> ·
  <a href="https://github.com/auvana-ventures/alphax/blob/main/LICENSE">Apache-2.0</a>
</p>

## At a glance

| Existing Dio app | AlphaX adds at the adapter boundary |
| --- | --- |
| Keep | Dio methods, interceptors, transformers, `FormData`, `CancelToken`, progress callbacks, and response handling |
| Add | An injected `AlphaXClient` backed by Dart IO, Cronet/HttpEngine, or URLSession |
| Inspect | Actual completion-time protocol metadata and normalized transport/security behavior |
| Boundary | Focused Dio 5.x `HttpClientAdapter`; not full Dio source/API compatibility |

## Start here

1. Add `dio`, `alphax`, `alphax_native`, and `alphax_dio`.
2. Follow [replace the transport](#replace-the-transport-keep-dio).
3. Keep using Dio methods, interceptors, and response handling.
4. Add AlphaX policies to the injected client only when you need them.

`alphax_dio` lets an existing Dio application keep its Dio request code while
using an AlphaX transport underneath. You continue to use Dio methods,
interceptors, `FormData`, transformers, `CancelToken`, and progress callbacks;
AlphaX supplies the configured transport, TLS/proxy policy, streaming boundary,
and actual-protocol metadata.

## Why use it?

Use `alphax_dio` when your application already depends on Dio and you want to:

- keep existing `dio.get`, `dio.post`, interceptors, and response handling;
- move the transport choice to AlphaX without rewriting your API layer;
- use Android Cronet or Apple URLSession through the same Dio client;
- retain Dart IO fallback behavior on Linux and Windows;
- inspect the protocol that actually completed a request;
- use AlphaX cancellation, timeout, TLS, proxy, and normalized transport
  behavior at the adapter boundary.

This is a focused compatibility bridge, not a replacement for every Dio API
or a claim of full Dio source compatibility.

## When should I choose this package?

Choose `alphax_dio` for an existing Dio codebase. Choose
[`alphax`](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax) directly for a new application that does not
need Dio's API. Add [`alphax_native`](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_native) to select
platform transports, and add [`alphax_test`](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_test) as a
development dependency for deterministic tests.

## Install

The current RC is published on pub.dev:

```sh
flutter pub add dio alphax alphax_native alphax_dio
```

Add `dio: ^5.9.2` to the same application.

## Replace the transport, keep Dio

Create one AlphaX client, give it to `AlphaXDioAdapter`, and keep using Dio.

```dart
import 'dart:io';

import 'package:alphax/alphax.dart';
import 'package:alphax_dio/alphax_dio.dart';
import 'package:alphax_native/alphax_native.dart';
import 'package:dio/dio.dart';

Future<AlphaXTransport> createTransport() async {
  if (Platform.isAndroid) {
    return AndroidCronetTransport.create();
  }
  if (Platform.isIOS || Platform.isMacOS) {
    return AppleUrlSessionTransport.create();
  }
  return DartIoTransport();
}

Future<void> main() async {
  final alphaClient = AlphaXClient(transport: await createTransport());
  final dio = Dio(
    BaseOptions(baseUrl: 'https://example.com'),
  )..httpClientAdapter = AlphaXDioAdapter(alphaClient);

  try {
    final response = await dio.get<String>('/health');
    print('${response.statusCode}: ${response.data}');
  } finally {
    // The adapter closes the AlphaX client by default.
    dio.close(force: true);
  }
}
```

If the same AlphaX client is shared with code outside Dio, construct the
adapter with `closeClient: false` and close the AlphaX client yourself.

## What stays Dio-owned?

| Existing Dio behavior | AlphaX responsibility behind the adapter |
| --- | --- |
| `get`, `post`, `put`, `delete`, and request options | Selected native or Dart IO transport |
| Interceptors and transformers | TLS, trust, proxy, and redirect policy configured on AlphaX |
| `FormData` and Dio request streams | Bounded response streams and file-transfer boundary |
| `CancelToken` and Dio progress callbacks | Normalized transport, timeout, cancellation, and protocol metadata |
| `Response<T>` and `DioException` handling | Actual negotiated protocol and completion-time metrics |

## Common jobs

### Keep Dio cancellation

```dart
final cancelToken = CancelToken();
final pending = dio.get<String>(
  '/large-response',
  cancelToken: cancelToken,
);

// Call this from the screen/controller when the work is no longer needed.
cancelToken.cancel('screen closed');

try {
  await pending;
} on DioException catch (error) {
  if (error.type == DioExceptionType.cancel) {
    // AlphaX cancellation is mapped back to Dio cancellation.
  }
}
```

### Read a response stream

```dart
final response = await dio.get<ResponseBody>(
  '/large-response',
  options: Options(responseType: ResponseType.stream),
);

await for (final chunk in response.data!.stream) {
  print('received ${chunk.length} bytes');
}
```

### Use existing Dio file APIs

Dio's file-download and `FormData` upload flows continue to use the adapter's
AlphaX transport boundary. Progress callbacks remain Dio callbacks, while
AlphaX handles the underlying stream, cancellation, and platform file behavior.

```dart
await dio.download(
  '/archive.bin',
  '/tmp/archive.bin',
  onReceiveProgress: (received, total) {
    print('$received / $total bytes');
  },
);
```

### Ask for or read the actual protocol

A protocol preference may fall back. A protocol requirement fails closed when
the requested protocol is not actually negotiated.

```dart
final response = await dio.get<String>(
  '/health',
  options: Options(
    extra: <String, Object>{
      AlphaXDioAdapter.protocolPreferenceExtraKey:
          AlphaXProtocolPreference.http3,
    },
  ),
);

final actualProtocol =
    response.extra[AlphaXDioAdapter.protocolExtraKey] as AlphaXProtocol?;
print('actual protocol: ${actualProtocol?.name ?? 'unknown'}');
```

Use `AlphaXDioAdapter.protocolRequirementExtraKey` when the request must fail
unless H3 is actually negotiated. `HttpClientAdapter.extraKeyHttpVersion` is
also populated when AlphaX has a concrete negotiated protocol. Completion-time
metadata may update after a streamed response begins; `unknown` is never
inferred as H1.

### Add AlphaX policies to the injected client

Dio keeps its own interceptors and response behavior. AlphaX policies are
configured once on the client passed to the adapter. Nothing in this adapter
enables retries, authentication, cookies, caching, or resilience automatically:

```dart
final cookieJar = AlphaXCookieJar();
final alphaClient = AlphaXClient(
  transport: transport,
  middleware: <AlphaXMiddleware>[
    AlphaXAuthenticationMiddleware(
      accessToken: currentAccessToken,
      refreshAccessToken: refreshAccessToken,
    ),
    AlphaXCookieMiddleware(cookieJar),
    AlphaXRetryMiddleware(),
    AlphaXCacheMiddleware(
      store: AlphaXMemoryCacheStore(maxEntries: 100),
    ),
    AlphaXResilienceMiddleware(),
  ],
);
final dio = Dio()..httpClientAdapter = AlphaXDioAdapter(alphaClient);
```

The defaults are intentionally conservative: retries repeat only replayable
idempotent buffered requests; authentication uses the token provider supplied
by your application and refreshes only one replayable buffered challenge;
cookies and cache entries are in memory; and resilience is a generic circuit
breaker. Dio's own interceptors still run separately. For a step-by-step guide
covering custom retry decisions, token headers, persistent stores, proxy setup,
SPKI pin rotation, and unsupported-provider handling, read the [AlphaX policy
defaults and customization guide](https://github.com/auvana-ventures/alphax/blob/main/docs/POLICIES.md).

## Security and compatibility boundaries

TLS, trust anchors, SPKI pins, proxy routing, and middleware belong to the
injected AlphaX client/transport. The Dio adapter does not invent per-request
native security controls. Keep certificate verification enabled, never use
trust-all configuration, and never log proxy credentials or pin material.

Known 1.0 boundaries:

- not full Dio source/API compatibility;
- Web uses the separate `alphax_web` Fetch adapter; this Dio adapter does not
  itself provide browser transport support;
- AlphaX policy middleware is opt-in and bounded by replayability, in-memory
  storage, browser/provider limits, and caller-owned authentication state;
- no transport architecture change or universal H3 guarantee;
- provider-specific TLS and proxy limitations remain fail-closed.

## Continue learning

- [Core AlphaX API](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax)
- [Native platform transports](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_native)
- [Testing helpers](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_test)
- [Waypoint reference app](https://github.com/auvana-ventures/alphax/tree/main/examples/waypoint)
- [Dio and package:http migration guide](https://github.com/auvana-ventures/alphax/blob/main/docs/MIGRATION.md)

The current `1.0.0-rc.3` candidate is published on pub.dev. This remains a
focused Dio 5.x adapter, not full Dio source/API compatibility.
