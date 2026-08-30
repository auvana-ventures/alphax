# Migration guidance

AlphaX 1.0.0-rc.5 is the final feature RC before stable 1.0. This guide maps
common `package:http` and Dio concepts; it is not a source-compatible port and
does not promise a full Dio adapter.

## rc.4 to rc.5

rc.5 is largely additive. Existing rc.4 constructors, explicit transports,
custom transports, and the Retrofit → Dio → `alphax_dio` path remain valid.

### Native

The rc.4 setup remains valid:

```dart
final client = AlphaXClient(
  transport: await createAlphaXTransport(),
);
```

For ordinary native Flutter setup, use the rc.5 façade:

```dart
import 'package:alphax_native/alphax_native.dart';

final client = await createAlphaXClient();
```

`alphax_native` selects the existing platform transport and owns its lifecycle
through the returned `AlphaXClient`. Explicit transport construction remains
the control path for custom provider configuration.

### Web

Use the browser deployment façade with one import and one creation call:

```dart
import 'package:alphax_web/alphax_web.dart';

final client = createAlphaXClient();
```

Fetch, CORS, TLS, proxy routing, cookies, and protocol reporting remain
browser-owned. `WebFetchTransport()` and direct `AlphaXClient` construction
remain valid for explicit assembly.

### `package:http` ecosystems

Applications using Chopper, GraphQL HTTP, generated clients, or another
library that accepts `http.Client` can add the optional `alphax_http` seam:

```dart
import 'package:alphax_http/alphax_http.dart';
import 'package:alphax_native/alphax_native.dart';

final alpha = await createAlphaXClient();
final httpClient = AlphaXHttpClient(alpha);
```

`AlphaXHttpClient` borrows `alpha`; closing the bridge does not close the
underlying client. Close the AlphaX client at the application-owned lifecycle
boundary.

### SSE

Import `package:alphax/sse.dart` and transform an existing AlphaX response
stream with `AlphaXSseParser`. The parser is incremental and surfaces event,
data, ID, and retry fields. Reconnection and `Last-Event-ID` remain caller
policy; no migration to an automatic reconnect API is needed.

### WebSocket

WebSocket is a separate connector/session contract rather than an HTTP client
method:

```dart
import 'package:alphax_native/alphax_native.dart';

final connector = createAlphaXWebSocketConnector();
final socket = await connector.connect(
  Uri.parse('wss://example.com/socket'),
  protocols: <String>['app.v1'],
);
```

The session carries ordered text/binary messages and terminal close information.
There is no automatic reconnect, replay, or universal custom-header support.
Use the native or Web connector from the deployment package.

### Direct typed REST

New typed clients can use `alphax_generator` as development tooling. Generated
services borrow a caller-owned `AlphaXClient` and call AlphaX directly; model
serialization remains caller-owned. Existing Retrofit users have no migration:

```text
Retrofit → Dio → AlphaXDioAdapter → AlphaX
```

Keep that path and use `alphax_dio` when Retrofit is already part of the
application.

## rc.5 to stable 1.0.0

The frozen rc.5 API is intended to carry forward to stable `1.0.0`. For the
published package family, the expected migration is version-only: update the
coordinated `1.0.0-rc.5` constraints to `1.0.0` when stable packages are
published. No source migration is required by the stabilization gate. Existing
explicit transports, custom transports, `alphax_http`, SSE, WebSocket, and
generated-client ownership paths remain valid.

## Client creation and methods

For normal native targets, let `alphax_native` choose the transport and pass it
to `AlphaXClient`:

```dart
import 'package:alphax/alphax.dart';
import 'package:alphax_native/alphax_native.dart';

Future<void> main() async {
  final client = AlphaXClient(
    transport: await createAlphaXTransport(),
  );
  try {
    final response = await client.get(Uri.https('example.com', '/users'));
    print(await response.readAsString());
  } finally {
    await client.close();
  }
}
```

Use `DartIoTransport()`, `AndroidCronetTransport.create()`, or
`AppleUrlSessionTransport.create()` for explicit native selection. Use
`WebFetchTransport()` from `alphax_web` for Web. The [usage and customization
guide](USAGE_AND_CUSTOMIZATION.md) explains package selection, defaults, and
the custom `AlphaXTransport` seam.

Use `AlphaXClient.get`, `post`, `put`, `patch`, `delete`, `head`, and `options`
for convenience, or construct `AlphaXRequest` for complete control. Methods
use `Uri`, not a string plus a separate query map; add query parameters to the
URI itself. Headers are immutable, case-insensitive, and may contain multiple
values.

| `package:http` | AlphaX |
| --- | --- |
| `Client` / `BaseClient` | `AlphaXClient` with a selected `AlphaXTransport` |
| `Request` | `AlphaXRequest` |
| `Response` | `AlphaXResponse` |
| `Request.method` | `HttpMethod` |
| `Request.headers` | `AlphaXHeaders` |
| `Request.bodyBytes` | `AlphaXBytesBody` |
| `Request.body` | `AlphaXTextBody` |
| `send()` byte stream | `AlphaXClient.send()` and `AlphaXResponse.stream` |
| `close()` | `AlphaXClient.close()` |

## Bodies and multipart

Use `AlphaXBytesBody`, `AlphaXTextBody`, `AlphaXJsonBody`,
`AlphaXStreamBody`, `AlphaXFileBody`, and `AlphaXMultipartBody` with
`AlphaXMultipartField` or `AlphaXMultipartFile`. A streamed request body is
single-use unless it explicitly declares replayability. Redirects and
middleware do not silently replay a single-use body.

## Cancellation and timeout

Replace `http` cancellation patterns with `AlphaXCancellationToken`:

```dart
final token = AlphaXCancellationToken();
final pending = client.get(uri, cancellationToken: token);
token.cancel('screen closed');
```

Use `AlphaXTimeouts` for `connect`, `request`, `read`, and `overall` limits.
Adapters may not expose every phase with identical precision; unavailable
precision remains documented rather than fabricated. Cancellation is normalized
as `AlphaXCancellationException` and is idempotent.

## Streaming and file transfer

`AlphaXResponse.stream` is a single-consumption Dart stream with pause/resume
semantics. For files, use the same public API regardless of whether the
selected adapter uses Dart streams or a native file task:

```dart
await client.download(uri, to: AlphaXLocalFileTarget('/tmp/result.bin'));
await client.upload(uri, from: AlphaXLocalFileSource('/tmp/source.bin'));
```

Progress callbacks are capability-dependent. AlphaX reports only measured
bytes and does not invent progress for unsupported transports.

## Middleware

Replace `package:http` wrappers or Dio interceptors with ordered
`AlphaXMiddleware`. Middleware can mutate a request through `copyWith`,
short-circuit, handle errors, and participate in streamed/file operations. The
chain is per operation. AlphaX also provides opt-in replay-aware retries,
caller-owned token authentication, in-memory cookies/cache, and a generic
circuit breaker. Unsafe or non-replayable operations are never silently
retried; persistent stores and model-specific authentication remain application
responsibilities.

Before adding middleware, remember the default behavior:

| Behavior | Default |
| --- | --- |
| Middleware | Empty list; no policy is enabled. |
| Retry | Off; one attempt. |
| Authentication | Off; token storage remains application-owned. |
| Cookies/cache | Off; the supplied implementations are in-memory when added. |
| Resilience | Off; no circuit breaker. |
| TLS/proxy | Verified platform trust and system proxy policy on the selected transport. |
| Protocol | `auto` preference; actual protocol comes from provider/server/proxy/network negotiation. |

For a starting policy set:

```dart
final client = AlphaXClient(
  transport: transport,
  middleware: <AlphaXMiddleware>[
    AlphaXAuthenticationMiddleware(accessToken: readAccessToken),
    AlphaXCookieMiddleware(AlphaXCookieJar()),
    AlphaXRetryMiddleware(),
    AlphaXCacheMiddleware(store: AlphaXMemoryCacheStore()),
    AlphaXResilienceMiddleware(),
  ],
);
```

The default retry policy covers replayable idempotent buffered requests and
honors bounded backoff/`Retry-After`; it does not replay a single-use stream or
an unsafe mutation silently. Authentication injects a caller-owned token and
can perform one single-flight refresh after a buffered challenge. Cookie and
cache state are in memory unless the application supplies its own store. The
resilience middleware is a generic circuit breaker, not an offline queue or
vendor-specific retry service. For step-by-step examples and customization
guidance, see [policy defaults and customization](POLICIES.md).

### Cookie persistence boundary

The old concrete `AlphaXCookieJar` middleware call remains source-compatible:

```dart
final jar = AlphaXCookieJar();
final client = AlphaXClient(
  transport: transport,
  middleware: <AlphaXMiddleware>[AlphaXCookieMiddleware(jar)],
);
await jar.clear(); // logout
```

Cookie store operations are asynchronous in AlphaX 1.0. `AlphaXCookieStore`
stores parsed `AlphaXCookie` values through `readCookies()`,
`writeCookies(...)`, atomic `updateCookies(...)`, and `clear()`. The middleware
continues to own parsing, domain/path matching, expiry, Secure, HttpOnly,
host-only, replacement, and deletion behavior, so a custom
encrypted/database/secure-storage adapter does not need to reimplement HTTP
cookie rules. The adapter must serialize `updateCookies` transactions, surface
failures, protect values at rest, and clear the session on logout. The
convenience methods `cookieHeaderFor(...)` and `storeFromResponse(...)` are now
asynchronous and must be awaited.
SameSite and browser cookie context remain outside the native core.

### HTTP-aware private cache boundary

`AlphaXCacheStore` is no longer keyed by `Uri` alone. A custom store must use
`AlphaXCacheKey` and `AlphaXCacheEntry`, preserving the method, URI, response
`Vary` fields, optional identity scope, validators, freshness metadata, and
response headers:

```dart
final store = AlphaXMemoryCacheStore(maxEntries: 100, maxBytes: 10 * 1024 * 1024);
final cachePolicy = const AlphaXCachePolicy(
  defaultMaxAge: Duration(minutes: 5),
  identityKey: 'account-42', // non-secret; use only for this identity
);
```

The default cache is private, opt-in, bounded, and in memory. AlphaX owns
variant selection and conservative `Cache-Control`/`Date`/`Age`/`Expires`
freshness, `Vary`, ETag/Last-Modified revalidation, 304 metadata merging,
authenticated-response isolation, and POST/PUT/PATCH/DELETE invalidation.
Authorization- or cookie-bearing requests bypass the cache unless an explicit
stable identity key is configured; proxy-authenticated requests always bypass;
responses that set cookies are not stored. Change the identity key or clear
the store on account switch. Custom stores own durability, encryption, access
control, corruption handling, and concurrent-write serialization. The cache is
not an offline queue or synchronization system, and request coalescing is not
promised.

## Dio mapping

| Dio | AlphaX |
| --- | --- |
| `Dio` | `AlphaXClient` |
| `Options.method` | `HttpMethod` |
| `Options.headers` | `AlphaXHeaders` |
| `CancelToken` | `AlphaXCancellationToken` |
| `Response<T>` | `AlphaXResponse` plus explicit body consumption |
| `ResponseType.stream` | `AlphaXResponse.stream` |
| `onSendProgress` | upload `AlphaXProgressCallback` |
| `onReceiveProgress` | download `AlphaXProgressCallback` |
| `FormData` | `AlphaXMultipartBody` and part types |
| `download()` | `AlphaXClient.download()` with `AlphaXFileTarget` |
| `uploadFile()` | `AlphaXClient.upload()` with `AlphaXFileSource` |
| interceptors | `AlphaXMiddleware` |

For applications that need to keep Dio interceptors, transformers, Retrofit
generated clients, and the normal Dio request API, use the optional
`alphax_dio` adapter with a configured AlphaX client:

```dart
final alphaClient = AlphaXClient(transport: configuredTransport);
final dio = Dio()
  ..httpClientAdapter = AlphaXDioAdapter(alphaClient);

final response = await dio.get<String>('https://example.com/users');
dio.close();
```

The adapter maps Dio's already-transformed request stream to an AlphaX
single-use body. Dio continues to own interceptors, `FormData`, request and
response transformation, and its progress callbacks. AlphaX owns transport
selection, cancellation propagation, timeout semantics, TLS/pinning, proxy
policy, middleware, and normalized transport errors.

The adapter accepts typed protocol controls through `Options.extra`:

```dart
final response = await dio.get<String>(
  'https://example.com/users',
  options: Options(
    extra: <String, Object>{
      AlphaXDioAdapter.protocolPreferenceExtraKey:
          AlphaXProtocolPreference.http3,
      // Replace with protocolRequirementExtraKey for fail-closed H3.
    },
  ),
);
final protocol = response.extra[AlphaXDioAdapter.protocolExtraKey];
final completion = response.extra[
  AlphaXDioAdapter.completionMetricsExtraKey
];
```

The adapter also populates Dio's `HttpClientAdapter.extraKeyHttpVersion` when
the actual protocol is known and exposes typed AlphaX fallback/metrics values.
Completion metadata may update after response headers for streamed operations;
`unknown` is never treated as H1. Configure TLS, trust anchors, SPKI pins, and
proxy policy on the injected AlphaX client. Unsupported provider controls fail
closed according to the AlphaX contract.

`alphax_dio` is a focused Dio 5.x compatibility boundary, not full Dio source
or API compatibility. Configure AlphaX retry, cookie, authentication, cache,
and resilience middleware on the injected client when those policies are
needed. Browser support is provided by the separate `alphax_web` adapter.

## Protocol preference, requirement, and actual reporting

Use `protocolPreference` when fallback is acceptable and
`protocolRequirement` when the exact protocol is mandatory. A capability says
what a provider may support; it does not prove that one request negotiated that
protocol. After consuming the response, await `completionMetrics` and
`completionProtocolFallback` for authoritative completion-time metadata.

An H3 preference may fall back to H2 or H1 and remains a successful request.
An H3 requirement fails closed if H3 is unsupported, unknown, or not
negotiated. Dart IO cannot authoritatively report H2/H3 and rejects concrete
H2/H3 requirements rather than guessing.

## TLS and pinning

`AlphaXTlsPolicy.platformDefault()` preserves normal platform trust and
hostname/validity checks. Custom DER trust anchors and host-scoped SPKI
SHA-256 pins are capability-dependent. Configure a primary and at least one
backup pin for planned key rotation. Pins are checked after ordinary chain
validation; a matching pin cannot make an expired or untrusted certificate
valid. Dart IO reports SPKI pinning unsupported and fails closed.

AlphaX intentionally has no trust-all callback and no raw private-key API.
mTLS/client-identity references are not implemented by the 1.0 adapters.

## Proxy policy

Use `AlphaXProxyPolicy.system()`, `direct()`, or an explicit `http(...)` proxy
where the selected provider advertises support. An HTTP proxy may service an
HTTPS destination through CONNECT; this is not the same as an explicit HTTPS
proxy endpoint. Unsupported proxy policies fail with a normalized error and do
not silently switch to direct or system routing.

Proxy credentials are hop-by-hop and must never be logged, copied into origin
headers, or included in request/response diagnostics. The selected Android
Cronet provider is system-proxy-only; Apple uses URLSession/CFNetwork for its
supported system/direct/HTTP mappings.

## Errors and intentional differences

Handle normalized `AlphaXException` categories such as DNS, connection, TLS,
pin, timeout, cancellation, protocol/requirement, redirect, body, proxy,
unsupported-capability, and transport errors. Native provider exception types
remain diagnostic causes only.

AlphaX 1.0 intentionally differs from both source clients: response bodies are
explicitly consumed, streamed bodies have ownership/replay rules, protocol
metadata may complete later, capability limitations are visible, unsupported
security/routing controls fail closed, and policy behavior is explicit
middleware rather than an implicit vendor-specific default. The [policy guide](POLICIES.md)
shows how to choose a transport, add one policy at a time, and provide custom
stores or application middleware when the built-in boundaries are not enough.
