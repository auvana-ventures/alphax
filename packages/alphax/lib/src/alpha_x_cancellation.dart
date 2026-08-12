import 'dart:async';

import 'alpha_x_errors.dart';

/// A caller-controlled cancellation token for a request or stream.
class AlphaXCancellationToken {
  /// Creates an active cancellation token.
  AlphaXCancellationToken();

  bool _isCancelled = false;
  String? _reason;
  Completer<void>? _completer;

  /// Whether cancellation has been requested.
  bool get isCancelled => _isCancelled;

  /// Optional caller-provided cancellation reason.
  String? get reason => _reason;

  /// Completes when cancellation is requested.
  Future<void> get whenCancelled {
    if (_isCancelled) {
      return Future<void>.value();
    }
    return (_completer ??= Completer<void>()).future;
  }

  /// Requests cancellation. Repeated calls have no effect.
  void cancel([String reason = 'The operation was cancelled']) {
    if (_isCancelled) {
      return;
    }
    _isCancelled = true;
    _reason = reason;
    _completer?.complete();
  }

  /// Throws [AlphaXCancelledException] if cancellation has been requested.
  void throwIfCancelled() {
    if (_isCancelled) {
      throw AlphaXCancelledException(_reason ?? 'The operation was cancelled');
    }
  }
}
