import 'alpha_x_body.dart';
import 'alpha_x_cancellation.dart';
import 'alpha_x_headers.dart';
import 'alpha_x_timeout.dart';

/// Scheduling priority hint for a request.
enum AlphaXPriority {
  /// Lowest scheduling priority.
  low,

  /// Normal scheduling priority.
  normal,

  /// Highest scheduling priority.
  high,
}

/// Immutable transport-independent HTTP request description.
class AlphaXRequest {
  /// Creates a request for an absolute HTTP or HTTPS [uri].
  AlphaXRequest({
    required String method,
    required this.uri,
    this.headers = const AlphaXHeaders.empty(),
    this.body,
    this.timeout,
    this.cancellationToken,
    this.priority = AlphaXPriority.normal,
  }) : method = _normalizeMethod(method) {
    if ((uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      throw ArgumentError.value(uri, 'uri', 'Requests require an absolute HTTP or HTTPS URI');
    }
    timeout?.validate();
  }

  /// Uppercase HTTP method token.
  final String method;

  /// Absolute request URI.
  final Uri uri;

  /// Immutable request headers.
  final AlphaXHeaders headers;

  /// Optional request body.
  final AlphaXBody? body;

  /// Optional timeout configuration.
  final AlphaXTimeout? timeout;

  /// Optional caller cancellation token.
  final AlphaXCancellationToken? cancellationToken;

  /// Optional scheduling hint.
  final AlphaXPriority priority;

  static String _normalizeMethod(String method) {
    final normalized = method.trim().toUpperCase();
    if (!RegExp(r"^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$").hasMatch(normalized)) {
      throw ArgumentError.value(method, 'method', 'Method must be a valid HTTP token');
    }
    return normalized;
  }
}
