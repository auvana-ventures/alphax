/// Optional, explicit one-shot JSON transforms for buffered AlphaX payloads.
library;

import 'dart:typed_data';

import 'package:alphax/alphax.dart';

import 'src/alpha_x_transform_web.dart'
    if (dart.library.io) 'src/alpha_x_transform_native.dart'
    as implementation;

export 'src/alpha_x_transform_exception.dart';

/// Applies a caller-owned transform to JSON decoded from an isolate.
///
/// The function must be safe to send to a Dart isolate. Prefer a top-level or
/// static function, or a closure that captures only safely sendable values.
typedef AlphaXJsonTransform<T> = T Function(Object? decodedJson);

/// Decodes buffered UTF-8 JSON and applies [transform] in one native isolate.
///
/// The caller must buffer the response before calling this function. This
/// operation does not consume an AlphaX response stream, control transport
/// backpressure, own a file or network handle, or provide streaming JSON
/// decoding.
///
/// On native Dart VM and Flutter targets, the bytes are prepared for a single
/// [Isolate.run] invocation. The transform and returned value must obey Dart
/// isolate sendability rules. JSON and transform errors are forwarded without
/// being converted into transport errors.
///
/// Cancellation before dispatch prevents the isolate from being created. Once
/// dispatch has happened, cancellation completes the returned future with the
/// existing AlphaX cancellation exception and discards a later worker result;
/// it does not synchronously terminate the worker or stop its CPU work.
///
/// Web callers receive [AlphaXTransformUnsupportedException]. This package
/// does not claim browser background execution and does not silently fall back
/// to synchronous JSON decoding.
///
/// [debugName] is diagnostic metadata only. It must not contain payload data.
Future<T> decodeJson<T>({
  required Uint8List bytes,
  required AlphaXJsonTransform<T> transform,
  AlphaXCancellationToken? cancellationToken,
  String? debugName,
}) {
  return implementation.decodeJsonImpl<T>(
    bytes: bytes,
    transform: transform,
    cancellationToken: cancellationToken,
    debugName: debugName,
  );
}
