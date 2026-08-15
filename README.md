# AlphaX

AlphaX is an experimental, transport-independent HTTP client API for Dart and
Flutter. It provides one request/response, streaming, file-transfer,
cancellation, capability, protocol, and error model over platform transports.

## Status

**Phase 1F release-candidate hardening is in progress.** AlphaX remains
pre-release and is not stable or published to pub.dev. The core API has been
reviewed for the release-candidate boundary, but final 1.0 freeze, maintainer
release approval, and naming clearance are still required.

AlphaX makes no unsupported fastest, zero-copy, universal HTTP/3, or always-H3
claims.

## Installation during pre-release review

Until package naming clearance and publication approval are complete, consume
the packages from the public repository:

```yaml
dependencies:
  alphax:
    git:
      url: https://github.com/auvana-ventures/alphax.git
      path: packages/alphax
  alphax_native:
    git:
      url: https://github.com/auvana-ventures/alphax.git
      path: packages/alphax_native
```

`alphax` has no Flutter SDK dependency. `alphax_native` is the Flutter plugin
that supplies Dart IO, Android Cronet/HttpEngine, and Apple URLSession adapters.

## Basic request

```dart
import 'package:alphax/alphax.dart';
import 'package:alphax_native/alphax_native.dart';

Future<void> main() async {
  final client = AlphaXClient(transport: DartIoTransport());
  try {
    final response = await client.get(Uri.https('example.com', '/'));
    print('${response.statusCode}: ${await response.readAsString()}');

    // A transport may learn the protocol only after the body completes.
    final finalMetrics = await response.completionMetrics;
    print('negotiated protocol: ${finalMetrics.negotiatedProtocol.name}');
  } finally {
    await client.close();
  }
}
```

On Android, create `AndroidCronetTransport`; on iOS/macOS, create
`AppleUrlSessionTransport`. The request and response API remains unchanged.

## Streaming and cancellation

Response streams are single-consumption and support Dart pause/resume
semantics. Native adapters use bounded delivery windows.

```dart
final token = AlphaXCancellationToken();
final pending = client.get(
  Uri.https('example.com', '/large-response'),
  cancellationToken: token,
);
token.cancel('screen closed');

try {
  final response = await pending;
  await for (final chunk in response.stream) {
    // Process each chunk without requiring a complete-body buffer.
    print('received ${chunk.length} bytes');
  }
} on AlphaXCancellationException {
  // Cancellation is distinct from transport failure.
}
```

## Upload and download

The public API is the same whether a platform uses a Dart stream or a native
file-backed task. `AlphaXLocalFileSource` and `AlphaXLocalFileTarget` are
provided by `alphax_native`.

```dart
final download = await client.download(
  Uri.https('example.com', '/archive.bin'),
  to: AlphaXLocalFileTarget('/tmp/archive.bin'),
);

final upload = await client.upload(
  Uri.https('example.com', '/upload'),
  from: AlphaXLocalFileSource('/tmp/archive.bin'),
  onUploadProgress: (progress) => print(progress.bytesTransferred),
);
print('${download.bytesTransferred} downloaded, ${upload.bytesTransferred} uploaded');
```

Native file-backed transfer is a minimal-copy implementation detail; AlphaX
does not call it zero-copy.

## Capabilities and protocol reporting

These concepts are deliberately separate:

- **Capability**: what the current provider can support.
- **Preference**: what a request asks the provider to prefer.
- **Negotiated protocol**: what the completed operation actually used.
- **Fallback**: metadata explaining why a preferred protocol was not used.

```dart
final request = AlphaXRequest(
  method: HttpMethod.get,
  uri: Uri.https('example.com', '/'),
  protocolPreference: AlphaXProtocolPreference.http3,
);
final response = await client.send(request);
final finalMetrics = await response.completionMetrics;
final fallback = await response.completionProtocolFallback;
print('capability: ${client.capabilities.http3.name}');
print('actual: ${finalMetrics.negotiatedProtocol.name}');
print('fallback: ${fallback?.reason.name ?? 'none'}');
```

`unknown` is a valid protocol state. It never means HTTP/1.1 and never proves
fallback. URLSession may report the authoritative protocol only through
completion metrics.

## Platform and protocol support

| Target | Transport | Protocol support in the 1.0 scope |
| --- | --- | --- |
| Android API 24+ | Supported Cronet/HttpEngine provider | H1/H2/H3, provider- and network-dependent |
| iOS 15+ | URLSession | H1/H2/H3, OS- and network-dependent |
| macOS 12+ | URLSession | H1/H2/H3, OS- and network-dependent |
| Linux | Dart IO fallback | H1 baseline |
| Windows | Dart IO fallback | H1 baseline |
| Web | No AlphaX 1.0 transport | Unsupported |

H3 preference may legitimately negotiate H2 or H1. The actual protocol and
fallback metadata must be inspected for each completed request. Dart IO is the
fallback/baseline and does not advertise H2 or H3.

## Packages

| Package | Purpose | 1.0 status |
| --- | --- | --- |
| [`alphax`](packages/alphax) | Pure-Dart transport-neutral contracts | Required core |
| [`alphax_native`](packages/alphax_native) | Dart IO, Cronet, and URLSession adapters | Required platform boundary |
| [`alphax_test`](packages/alphax_test) | Fakes and shared conformance helpers | Required test support |
| [`alphax_dio`](packages/alphax_dio) | Optional Dio compatibility boundary | Not required; no adapter yet |

There is no AlphaX-owned C++ engine, production Rust transport, libcurl
dependency, cache, retry/resilience module, telemetry SDK, GraphQL layer, REST
generator, WebSocket/SSE API, or browser transport in the 1.0 architecture.

## Security and known limitations

TLS certificate verification uses platform defaults and is enabled by default.
The Apple adapter explicitly strips `Authorization`, `Proxy-Authorization`,
and `Cookie` on cross-origin redirects. Android delegates redirect header
mutation to the selected Cronet provider and still requires the Phase 1F
physical-device assertion for the same three headers. Explicit per-session proxy configuration,
certificate pinning, and mTLS are not exposed by the current adapters; system
proxy behavior is platform-managed and documented in the package review.

Native/platform exceptions are retained only as diagnostic causes. Applications
should handle the public AlphaX error categories such as DNS, connection, TLS,
timeout, cancellation, redirect, request body, response body, unsupported
capability, and transport/internal errors.

Timeouts are AlphaX semantic timers. A transport may emulate a category, and
the API does not promise portable DNS/TCP/TLS phase precision.

## Migration and examples

See [migration guidance](docs/MIGRATION.md) for `package:http` and Dio mapping.
The small runnable-oriented example is in
[`examples/basic`](examples/basic/README.md) and its source is in
[`examples/basic/lib/main.dart`](examples/basic/lib/main.dart).

## Architecture and evidence

The public contract stays in `alphax`; platform processing is isolated in
`alphax_native`:

```text
Dart application
      │
      ▼
alphax (pure-Dart contracts)
      │
      ├── Dart IO fallback
      ├── Android Cronet/HttpEngine
      └── iOS/macOS URLSession
```

See the [1.0 scope](docs/ALPHAX_1_0_SCOPE.md),
[accepted transport ADR](docs/decisions/0004-platform-native-mobile-transports.md),
and [Phase 1E validation report](docs/phase1e-cross-transport-validation.md).
Historical Phase 0 benchmark results remain evidence for measured HTTP/1.1
workloads and were not rewritten as H2/H3 performance claims.

## Contributing and license

Read [CONTRIBUTING.md](CONTRIBUTING.md), [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md),
and the relevant architecture documents before changing a transport or public
contract. AlphaX is licensed under Apache-2.0; see [LICENSE](LICENSE).
