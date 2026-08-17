import 'alpha_x_errors.dart';
import 'alpha_x_middleware.dart';
import 'alpha_x_request.dart';
import 'alpha_x_response.dart';
import 'alpha_x_retry.dart';

/// State of a generic circuit breaker.
enum AlphaXCircuitState {
  /// Requests flow normally.
  closed,

  /// Requests fail fast until the open interval elapses.
  open,

  /// One probe request is allowed to test recovery.
  halfOpen,
}

/// Generic resilience configuration with no vendor-specific behavior.
final class AlphaXResiliencePolicy {
  /// Creates resilience settings.
  const AlphaXResiliencePolicy({
    this.failureThreshold = 5,
    this.openDuration = const Duration(seconds: 30),
    this.retryPolicy,
  }) : assert(failureThreshold > 0);

  /// Consecutive failures needed to open the circuit.
  final int failureThreshold;

  /// Time the circuit stays open before a probe is allowed.
  final Duration openDuration;

  /// Optional retry behavior inside the circuit.
  final AlphaXRetryPolicy? retryPolicy;
}

/// Resilience policy rejected a request before transport dispatch.
final class AlphaXCircuitOpenException extends AlphaXResilienceException {
  /// Creates a circuit-open failure.
  const AlphaXCircuitOpenException() : super('The AlphaX resilience circuit is open');
}

/// Middleware implementing generic retry and circuit-breaker behavior for
/// buffered operations.
///
/// It does not replay partially consumed streams or file transfers and does
/// not encode a vendor-specific resilience policy.
final class AlphaXResilienceMiddleware extends AlphaXMiddleware {
  /// Creates resilience middleware.
  AlphaXResilienceMiddleware({this.policy = const AlphaXResiliencePolicy()})
    : _retry = policy.retryPolicy == null
          ? null
          : AlphaXRetryMiddleware(policy: policy.retryPolicy);

  /// Resilience settings.
  final AlphaXResiliencePolicy policy;
  final AlphaXRetryMiddleware? _retry;

  AlphaXCircuitState _state = AlphaXCircuitState.closed;
  int _consecutiveFailures = 0;
  DateTime? _openedAt;
  bool _probeInFlight = false;

  /// Current circuit state.
  AlphaXCircuitState get state => _state;

  @override
  Future<AlphaXResponse> intercept(AlphaXRequest request, AlphaXNext next) async {
    _beforeRequest();
    try {
      final response = _retry == null ? await next(request) : await _retry.intercept(request, next);
      if (response.statusCode >= 500) {
        _recordFailure();
      } else {
        _recordSuccess();
      }
      return response;
    } catch (error) {
      if (error is AlphaXCircuitOpenException) {
        rethrow;
      }
      if (error is AlphaXException &&
          const <AlphaXErrorKind>{
            AlphaXErrorKind.connection,
            AlphaXErrorKind.dns,
            AlphaXErrorKind.timeout,
            AlphaXErrorKind.transport,
          }.contains(error.kind)) {
        _recordFailure();
      }
      rethrow;
    } finally {
      if (_state == AlphaXCircuitState.halfOpen) {
        _probeInFlight = false;
      }
    }
  }

  void _beforeRequest() {
    if (_state == AlphaXCircuitState.closed) {
      return;
    }
    final openedAt = _openedAt;
    if (_state == AlphaXCircuitState.open &&
        openedAt != null &&
        DateTime.now().difference(openedAt) < policy.openDuration) {
      throw const AlphaXCircuitOpenException();
    }
    if (_state == AlphaXCircuitState.open) {
      _state = AlphaXCircuitState.halfOpen;
    }
    if (_state == AlphaXCircuitState.halfOpen) {
      if (_probeInFlight) {
        throw const AlphaXCircuitOpenException();
      }
      _probeInFlight = true;
    }
  }

  void _recordFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= policy.failureThreshold) {
      _state = AlphaXCircuitState.open;
      _openedAt = DateTime.now();
    }
  }

  void _recordSuccess() {
    _consecutiveFailures = 0;
    _openedAt = null;
    _state = AlphaXCircuitState.closed;
  }
}
