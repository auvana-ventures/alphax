# Migration guidance

AlphaX 1.0.0-rc.1 exposes transport-neutral HTTP primitives. This guide maps
common `package:http` and Dio concepts; it is not a source-compatible port and
does not promise a full Dio adapter.

## Client creation and methods

Choose a transport at the application boundary and pass it to `AlphaXClient`:

```dart
final client = AlphaXClient(transport: DartIoTransport());
final response = await client.get(Uri.https('example.com', '/users'));
final text = await response.readAsString();
await client.close();
```

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
chain is per operation. AlphaX 1.0 does not add automatic retries, auth
refresh, caching, or resilience policy, and unsafe mutations are never silently
retried.

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
or API compatibility. It intentionally does not add automatic retries, a
cookie jar, auth orchestration, caching, resilience policy, or Web support.

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
security/routing controls fail closed, and automatic retry/auth/cache behavior
is not included.
