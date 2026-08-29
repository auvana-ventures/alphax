import 'package:alphax/alphax.dart';

AlphaXCancelledException cancellationException(AlphaXCancellationToken token) {
  final reason = token.cancellationReason;
  return AlphaXCancelledException(
    reason?.toString() ?? 'The operation was cancelled',
    reason: reason,
  );
}
