# alphax_transform

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://github.com/auvana-ventures/alphax/raw/main/packages/alphax_transform/assets/branding/alphax-logo-light.svg">
    <img src="https://github.com/auvana-ventures/alphax/raw/main/packages/alphax_transform/assets/branding/alphax-logo-dark.svg" alt="AlphaX" width="300">
  </picture>
</p>

<p align="center"><strong>Explicit one-shot JSON transforms for large buffered AlphaX payloads.</strong><br>
Keep ordinary response decoding simple, and opt into an isolate only when the
application's responsiveness measurements justify it.</p>

<p align="center">
  <a href="https://pub.dev/packages/alphax">Core API</a> ·
  <a href="https://github.com/auvana-ventures/alphax/blob/main/docs/USAGE_AND_CUSTOMIZATION.md">Usage and customization</a> ·
  <a href="https://github.com/auvana-ventures/alphax/blob/main/docs/USAGE_AND_CUSTOMIZATION.md#large-json-and-alphax_transform">Large JSON guidance</a> ·
  <a href="https://github.com/auvana-ventures/alphax/blob/main/LICENSE">Apache-2.0</a>
</p>

## Why this package exists

`alphax` keeps response JSON decoding explicit and transport-independent. That
is the right default, but decoding and mapping a large buffered payload on a
Flutter caller isolate can delay frame work. `alphax_transform` provides a
small, opt-in seam for moving one JSON decode and caller-supplied transform to
one fresh native Dart isolate.

This package is not a faster network transport. It deliberately starts after
the response has been buffered and returns a tradeoff: the caller isolate is
less occupied, while total latency, CPU, and memory can increase.

## Install

Add the package alongside `alphax`:

```sh
dart pub add alphax alphax_transform
```

`alphax_transform` is pure Dart and has no Flutter, native transport, Dio, or
browser-plugin dependency.

## Basic use

```dart
import 'dart:typed_data';

import 'package:alphax/alphax.dart';
import 'package:alphax_transform/alphax_transform.dart';

Map<String, Object?> userFromDecodedJson(Object? decodedJson) {
  final json = decodedJson! as Map<Object?, Object?>;
  return <String, Object?>{
    'id': json['id'],
    'name': json['name'],
  };
}

Future<void> loadUser(AlphaXResponse response) async {
  final bytes = Uint8List.fromList(await response.readAsBytes());
  final user = await decodeJson<Map<String, Object?>>(
    bytes: bytes,
    transform: userFromDecodedJson,
    debugName: 'user-json-transform',
  );
  print(user);
}
```

The caller explicitly chooses when to buffer and offload. The helper does not
consume an `AlphaXResponse`, subscribe to a response stream, control native
backpressure, cancel the network operation, own a file handle, or parse JSON
incrementally. Keep small payloads on the normal synchronous path, such as
`response.readAsJson()`, when profiling does not show caller-isolate pressure.

If the response API already returns a `Uint8List`, pass it directly. The
current AlphaX compatibility response API returns `List<int>`, so
`Uint8List.fromList` in the example is an explicit caller-owned conversion;
this package does not change that core API or claim that conversion is free.

A compile-tested package-local example is available at
[`example/main.dart`](example/main.dart).

## Related packages

- [Core AlphaX API](https://pub.dev/packages/alphax)
- [Native transports](https://pub.dev/packages/alphax_native)
- [Web transport](https://pub.dev/packages/alphax_web)
- [Testing helpers](https://pub.dev/packages/alphax_test)

## Native execution

On Dart VM and native Flutter targets, each call uses one fresh `Isolate.run`.
The implementation internally prepares the `Uint8List` as
`TransferableTypedData`, materializes it in the worker, UTF-8 decodes it,
calls `jsonDecode`, and then invokes the supplied transform.

`TransferableTypedData` is an isolate-transfer representation, not zero-copy
JSON. Preparing it still costs work proportional to the input, materializing
the bytes creates the worker view, and UTF-8/JSON/model objects are allocated in
the worker. The helper also does not promise that every platform or SDK
implementation will have identical memory behavior.

## Sendability

The transform and returned value must be safe to send across a Dart isolate.
Prefer a top-level function, static function, or a simple closure that captures
only sendable data.

Do not capture or return a `BuildContext`, socket, file handle, `AlphaXClient`,
plugin object, database handle, platform handle, native resource, or closure
that depends on one. Return portable values such as primitives, lists, maps,
and application DTOs that the current Dart target can send. If isolate
dispatch or result transfer fails, the isolate error is forwarded honestly;
the package does not serialize arbitrary objects or hide the failure as a
transport exception.

## Cancellation and discard

Pass the existing `AlphaXCancellationToken` when the caller owns a cancellation
scope:

```dart
final token = AlphaXCancellationToken();
final model = await decodeJson(
  bytes: bytes,
  transform: userFromDecodedJson,
  cancellationToken: token,
);
```

Cancellation is cooperative at the package boundary:

- cancellation before preparation fails with the normalized AlphaX
  cancellation exception;
- cancellation before dispatch prevents isolate creation;
- cancellation after dispatch completes the caller future as cancelled and
  discards a later worker result;
- the worker may continue until it returns, so post-dispatch cancellation is
  not an immediate CPU kill and does not cancel the network read automatically;
- a successful worker result that wins before cancellation is returned normally;
- no late success is delivered after the helper has completed as cancelled.

If the response is still being downloaded, cancel the AlphaX request separately.

## Web behavior

Web is intentionally fail-closed. `decodeJson` throws
`AlphaXTransformUnsupportedException` on browser targets because this package
does not provide background execution there. It does not silently run
`jsonDecode` on the browser event loop while implying that work moved off the
UI thread. Choose a clearly synchronous caller-owned implementation for Web if
that is appropriate for the application.

## Measured guidance

The following guidance comes from deterministic parsing measurements, not a
universal threshold:

| Payload | Measured direction |
| --- | --- |
| ~100 KiB | Synchronous work was cheaper. |
| ~1 MiB | Measure the actual schema and UI workload first. |
| ~5 MiB | Consider one-shot isolation during active UI work. |
| ~10 MiB | Likely frame-risk on the measured Android device class; measure before adopting. |

Payload shape, model mapping, device, concurrent work, and frame budget matter
more than byte size alone. This package never chooses automatically based on a
threshold. There is no persistent worker pool, automatic middleware, streaming
JSON parser, model registry, or Flutter-specific `compute` wrapper.

## When not to use it

Do not use this helper merely to chase a small wall-time difference, for small
payloads where isolate startup dominates, for a response that should remain
streamed, or when the transform needs a non-sendable application object. Use
the ordinary AlphaX response APIs for predictable synchronous behavior and
caller-owned `Isolate.run`/`compute` when a package helper does not add value.

## API and compatibility

The package adds no dependency from `alphax` to `alphax_transform` and does not
change any AlphaX transport, response, stream, cancellation, or protocol
contract. It is independently publishable and remains optional.

AlphaX 1.0.0 is the current stable release. This package remains an optional
extension for applications that have measured caller-isolate pressure while
decoding large buffered JSON responses.
