import 'dart:async';

import 'alpha_x_errors.dart';

/// Idempotent caller-controlled cancellation source.
final class AlphaXCancellationToken {
  /// Creates an active token.
  AlphaXCancellationToken();

  bool _isCancelled = false;
  Object? _reason;
  Completer<void>? _completer;

  /// Whether cancellation has been requested.
  bool get isCancelled => _isCancelled;

  /// Original cancellation reason, when supplied.
  Object? get cancellationReason => _reason;

  /// String representation retained for Phase 0 source compatibility.
  String? get reason => _reason?.toString();

  /// Completes once when cancellation is requested.
  Future<void> get whenCancelled {
    if (_isCancelled) {
      return Future<void>.value();
    }
    return (_completer ??= Completer<void>()).future;
  }

  /// Requests cancellation. Repeated calls are no-ops.
  void cancel([Object? reason]) {
    if (_isCancelled) {
      return;
    }
    _isCancelled = true;
    _reason = reason;
    _completer?.complete();
  }

  /// Throws a normalized cancellation exception when already cancelled.
  void throwIfCancelled() {
    if (_isCancelled) {
      throw AlphaXCancelledException(
        _reason?.toString() ?? 'The operation was cancelled',
        reason: _reason,
      );
    }
  }
}
