import 'dart:typed_data';

import 'package:alphax/alphax.dart';

import 'alpha_x_transform_exception.dart';

Future<T> decodeJsonImpl<T>({
  required Uint8List bytes,
  required T Function(Object? decodedJson) transform,
  AlphaXCancellationToken? cancellationToken,
  String? debugName,
}) async {
  cancellationToken?.throwIfCancelled();
  // Keep the parameters in the implementation signature so the conditional
  // import has the same interface. Web deliberately fails closed rather than
  // running synchronously on the browser event loop.
  bytes;
  transform;
  debugName;
  throw const AlphaXTransformUnsupportedException();
}
