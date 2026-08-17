import 'alpha_x_response.dart';

/// Drains a response that will be discarded before another attempt.
Future<void> drainAlphaXResponse(AlphaXResponse response) async {
  if (!response.body.isConsumed) {
    await response.body.stream.drain<void>();
  }
}

/// Rethrows [error] without replacing its original stack trace.
Never rethrowAlphaX(Object error, StackTrace stackTrace) {
  Error.throwWithStackTrace(error, stackTrace);
}
