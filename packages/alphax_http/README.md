# alphax_http

`alphax_http` lets a library that expects a `package:http` `Client` use AlphaX
underneath it:

```text
package:http consumer → AlphaXHttpClient → AlphaXClient → AlphaX transport
```

Use it for Chopper, GraphQL HTTP clients, generated clients that accept an
injected `http.Client`, and ordinary SDKs built on `package:http`. Direct AlphaX
users do not need this package.

Related packages:

- [`alphax`](https://pub.dev/packages/alphax) for direct AlphaX usage;
- [`alphax_native`](https://pub.dev/packages/alphax_native) for native Flutter
  transport selection;
- [`alphax_web`](https://pub.dev/packages/alphax_web) for browser Fetch; and
- [`alphax_test`](https://pub.dev/packages/alphax_test) for deterministic test
  transports.

## Basic use

Create and configure AlphaX first, then wrap the long-lived client:

```dart
import 'package:alphax_http/alphax_http.dart';
import 'package:alphax_native/alphax_native.dart';

Future<void> main() async {
  final alpha = await createAlphaXClient();
  final httpClient = AlphaXHttpClient(alpha);
  try {
    final response = await httpClient.get(Uri.https('example.com', '/health'));
    print(response.statusCode);
  } finally {
    httpClient.close();
    await alpha.close();
  }
}
```

`AlphaXHttpClient` borrows `alpha`. Closing the adapter prevents new requests but
does not close AlphaX or active response streams. The caller that created AlphaX
owns it and must close it. Reuse one adapter and one underlying AlphaX client;
the adapter does not create a client or transport per request.

The pure-Dart shape is the same when a caller supplies a transport directly:

```dart
final alpha = AlphaXClient(transport: MyTransport());
final httpClient = AlphaXHttpClient(alpha);
```

## Chopper

Chopper services can receive the adapter through their normal `http.Client`
injection point. The Chopper converter, interceptors, generated service, and
typed response behavior remain Chopper responsibilities:

```dart
final alpha = await createAlphaXClient(
  middleware: <AlphaXMiddleware>[/* AlphaX policies */],
);
final httpClient = AlphaXHttpClient(alpha);
final chopper = ChopperClient(
  client: httpClient,
  services: <ChopperService>[UsersService.create()],
  converter: JsonConverter(),
);
```

Add `chopper` to the application that owns the service. It is not a runtime
dependency of `alphax_http` and there is no `alphax_chopper` package.

## Boundary and capability loss

The bridge implements `package:http`'s maintained `BaseClient.send` contract. It
maps standard methods, the original URI, headers, finalized request streams,
known/unknown content length, multipart output, redirect follow/max settings,
and streamed AlphaX responses to `StreamedResponse`. It does not re-encode a
`MultipartRequest` or buffer every request/response.

The `package:http` contract cannot carry the complete AlphaX surface. Through
this adapter, callers cannot observe AlphaX capabilities, actual protocol,
protocol preference/requirement, fallback metadata, completion metrics, native
file paths, progress callbacks, rich timeout phases, or rich cancellation
reasons. Configure TLS, proxy, middleware, authentication, cookies, caching,
retry, and resilience on the underlying AlphaX client before wrapping it.

`followRedirects` and `maxRedirects` map to AlphaX's follow/manual policy. The
bridge does not weaken AlphaX credential stripping or provider TLS/proxy policy.
Persistent-connection metadata, redirect-hop metadata, and reason phrases are
not invented when AlphaX cannot authoritatively provide them. Non-standard HTTP
methods are rejected because the AlphaX request contract has no corresponding
method value.

`AbortableRequest` cancellation is bridged to an AlphaX cancellation token and
is surfaced as `RequestAbortedException`. For a streamed request body, the
token is available to the AlphaX transport; cancellation of the package:http
body subscription itself is transport-dependent because `BaseClient` has no
separate body-cancellation hook. Cancelling a response subscription closes the
underlying stream when that transport supports stream cancellation.
`Client.close()` prevents new sends but, because the AlphaX client is borrowed,
does not cancel active AlphaX work or close the underlying client. `http.Client`
does not expose AlphaX's request-level timeout phases; no timeout policy is
installed by this adapter.

For protocol preferences, rich timeout/cancellation/progress controls, native
file transfers, metrics, and transport-specific capabilities, use
`AlphaXClient` directly.

The package is licensed under Apache-2.0.
