import 'dart:async';

import 'alpha_x_errors.dart';
import 'alpha_x_method.dart';
import 'alpha_x_middleware.dart';
import 'alpha_x_policy_helpers.dart';
import 'alpha_x_request.dart';
import 'alpha_x_response.dart';

/// Calculates the delay before a retry attempt.
typedef AlphaXRetryDelay =
    Duration Function({
      required int retryNumber,
      required AlphaXResponse? response,
      required Object? error,
    });

/// Decides whether a failed operation may be retried.
typedef AlphaXRetryDecider =
    bool Function({
      required AlphaXRequest request,
      required AlphaXResponse? response,
      required Object? error,
      required int attempt,
    });

/// Safe, replay-aware retry settings.
final class AlphaXRetryPolicy {
  /// Creates retry settings.
  AlphaXRetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 100),
    this.maxDelay = const Duration(seconds: 5),
    this.backoffMultiplier = 2,
    Iterable<int> retryableStatusCodes = const <int>{
      408,
      425,
      429,
      500,
      502,
      503,
      504,
    },
    Iterable<AlphaXErrorKind> retryableErrorKinds = const <AlphaXErrorKind>{
      AlphaXErrorKind.dns,
      AlphaXErrorKind.connection,
      AlphaXErrorKind.timeout,
      AlphaXErrorKind.transport,
    },
    this.retryNonIdempotent = false,
    this.delay,
    this.shouldRetry,
  }) : retryableStatusCodes = Set<int>.unmodifiable(retryableStatusCodes),
       retryableErrorKinds = Set<AlphaXErrorKind>.unmodifiable(retryableErrorKinds) {
    if (maxAttempts < 1) {
      throw ArgumentError.value(maxAttempts, 'maxAttempts', 'Must be at least one');
    }
    if (initialDelay < Duration.zero) {
      throw ArgumentError.value(initialDelay, 'initialDelay', 'Cannot be negative');
    }
    if (maxDelay < Duration.zero) {
      throw ArgumentError.value(maxDelay, 'maxDelay', 'Cannot be negative');
    }
    if (backoffMultiplier < 1) {
      throw ArgumentError.value(backoffMultiplier, 'backoffMultiplier', 'Must be at least one');
    }
  }

  /// Maximum number of total attempts, including the first request.
  final int maxAttempts;

  /// Initial delay before retry number one.
  final Duration initialDelay;

  /// Upper bound for a calculated retry delay.
  final Duration maxDelay;

  /// Multiplier applied after each retry.
  final double backoffMultiplier;

  /// HTTP statuses eligible for retry by default.
  final Set<int> retryableStatusCodes;

  /// Normalized exception kinds eligible for retry by default.
  final Set<AlphaXErrorKind> retryableErrorKinds;

  /// Whether non-idempotent methods may be retried when their body is replayable.
  final bool retryNonIdempotent;

  /// Custom delay calculator.
  final AlphaXRetryDelay? delay;

  /// Optional final decision hook.
  final AlphaXRetryDecider? shouldRetry;

  /// Returns whether [request] is eligible for another attempt.
  bool canRetry({
    required AlphaXRequest request,
    required AlphaXResponse? response,
    required Object? error,
    required int attempt,
  }) {
    if (attempt >= maxAttempts || !request.body.isReplayable) {
      return false;
    }
    if (!retryNonIdempotent && !_isIdempotent(request.method)) {
      return false;
    }

    final defaultDecision = switch (response) {
      final value? => retryableStatusCodes.contains(value.statusCode),
      null => error is AlphaXException && retryableErrorKinds.contains(error.kind),
    };
    if (!defaultDecision) {
      return false;
    }
    return shouldRetry?.call(
          request: request,
          response: response,
          error: error,
          attempt: attempt,
        ) ??
        true;
  }

  /// Returns the bounded delay for a retry.
  Duration delayFor({
    required int retryNumber,
    required AlphaXResponse? response,
    required Object? error,
  }) {
    final retryAfter = _retryAfter(response);
    if (retryAfter != null) {
      return retryAfter > maxDelay ? maxDelay : retryAfter;
    }
    final customDelay = delay;
    if (customDelay != null) {
      final calculated = customDelay(retryNumber: retryNumber, response: response, error: error);
      return calculated > maxDelay ? maxDelay : calculated;
    }
    var calculated = initialDelay;
    for (var index = 1; index < retryNumber; index++) {
      final nextMicros = (calculated.inMicroseconds * backoffMultiplier).round();
      calculated = Duration(
        microseconds: nextMicros > maxDelay.inMicroseconds ? maxDelay.inMicroseconds : nextMicros,
      );
    }
    return calculated;
  }

  static bool _isIdempotent(HttpMethod method) => switch (method) {
    HttpMethod.get ||
    HttpMethod.head ||
    HttpMethod.options ||
    HttpMethod.put ||
    HttpMethod.delete => true,
    HttpMethod.post || HttpMethod.patch => false,
  };

  Duration? _retryAfter(AlphaXResponse? response) {
    final value = response?.headers['retry-after']?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    final seconds = int.tryParse(value);
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }
}

/// Exponential backoff helper with stable defaults, suitable for deterministic tests.
Duration defaultAlphaXRetryDelay({
  required int retryNumber,
  required AlphaXResponse? response,
  required Object? error,
}) {
  var delay = const Duration(milliseconds: 100);
  for (var index = 1; index < retryNumber; index++) {
    final next = delay * 2;
    delay = next > const Duration(seconds: 5) ? const Duration(seconds: 5) : next;
  }
  return delay;
}

/// Middleware that retries replayable buffered operations according to policy.
///
/// Streaming and file-transfer operations are intentionally not retried by
/// this middleware because their response or destination may already be
/// partially consumed when a failure becomes visible.
final class AlphaXRetryMiddleware extends AlphaXMiddleware {
  /// Creates retry middleware.
  AlphaXRetryMiddleware({AlphaXRetryPolicy? policy}) : policy = policy ?? AlphaXRetryPolicy();

  /// Retry settings.
  final AlphaXRetryPolicy policy;

  @override
  Future<AlphaXResponse> intercept(AlphaXRequest request, AlphaXNext next) async {
    var attempt = 1;
    while (true) {
      AlphaXResponse? response;
      try {
        response = await next(request);
        if (!policy.canRetry(
          request: request,
          response: response,
          error: null,
          attempt: attempt,
        )) {
          return response;
        }
        await drainAlphaXResponse(response);
        await _wait(
          request,
          policy.delayFor(retryNumber: attempt, response: response, error: null),
        );
      } catch (error, stackTrace) {
        if (!policy.canRetry(
          request: request,
          response: null,
          error: error,
          attempt: attempt,
        )) {
          rethrowAlphaX(error, stackTrace);
        }
        await _wait(request, policy.delayFor(retryNumber: attempt, response: null, error: error));
      }
      attempt++;
    }
  }

  Future<void> _wait(AlphaXRequest request, Duration delay) async {
    if (delay <= Duration.zero) {
      request.cancellationToken?.throwIfCancelled();
      return;
    }
    final timer = Future<void>.delayed(delay);
    final cancellation = request.cancellationToken?.whenCancelled;
    if (cancellation == null) {
      await timer;
    } else {
      await Future.any<void>(<Future<void>>[timer, cancellation]);
      request.cancellationToken!.throwIfCancelled();
    }
  }
}
