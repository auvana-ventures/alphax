import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:alphax/alphax.dart';

import 'alpha_x_transform_common.dart';

Future<T> decodeJsonImpl<T>({
  required Uint8List bytes,
  required T Function(Object? decodedJson) transform,
  AlphaXCancellationToken? cancellationToken,
  String? debugName,
}) async {
  cancellationToken?.throwIfCancelled();

  // TransferableTypedData keeps the public seam as Uint8List while allowing
  // the isolate hand-off to use Dart's native transferable representation. It
  // is not zero-copy JSON: preparation and materialization still cost work,
  // and decoding allocates its own String and JSON graph.
  final transferable = TransferableTypedData.fromList(<TypedData>[bytes]);

  cancellationToken?.throwIfCancelled();

  // The call is intentionally made only after the second cancellation check.
  // A cancellation racing this call is handled by the discard race below.
  final worker = Isolate.run<T>(
    () => _decodeTransferredJson<T>(transferable, transform),
    debugName: debugName,
  );

  final token = cancellationToken;
  if (token == null) {
    return worker;
  }
  return _completeWithCancellation(worker, token);
}

T _decodeTransferredJson<T>(
  TransferableTypedData transferable,
  T Function(Object? decodedJson) transform,
) {
  final bytes = transferable.materialize().asUint8List();
  final text = utf8.decode(bytes);
  final decodedJson = jsonDecode(text);
  return transform(decodedJson);
}

Future<T> _completeWithCancellation<T>(
  Future<T> worker,
  AlphaXCancellationToken token,
) {
  final result = Completer<T>();
  var terminal = false;

  void completeValue(T value) {
    if (terminal) {
      return;
    }
    terminal = true;
    result.complete(value);
  }

  void completeError(Object error, StackTrace stackTrace) {
    if (terminal) {
      return;
    }
    terminal = true;
    result.completeError(error, stackTrace);
  }

  void completeCancellation() {
    if (terminal) {
      return;
    }
    terminal = true;
    result.completeError(cancellationException(token), StackTrace.current);
  }

  // The error handler remains attached after cancellation so a late worker
  // error is observed and cannot become an unhandled asynchronous error.
  unawaited(
    worker.then<void>(
      completeValue,
      onError: (Object error, StackTrace stackTrace) {
        completeError(error, stackTrace);
      },
    ),
  );
  unawaited(
    token.whenCancelled.then<void>((_) {
      completeCancellation();
    }),
  );

  // `whenCancelled` is already complete when cancellation won the narrow
  // race before its listener was attached. Complete eagerly as well; the
  // terminal guard makes the two paths idempotent.
  if (token.isCancelled) {
    completeCancellation();
  }

  return result.future;
}
