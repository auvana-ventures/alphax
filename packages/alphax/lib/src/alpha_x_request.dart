import 'alpha_x_body.dart';
import 'alpha_x_cancellation.dart';
import 'alpha_x_headers.dart';
import 'alpha_x_method.dart';
import 'alpha_x_progress.dart';
import 'alpha_x_protocol.dart';
import 'alpha_x_redirect.dart';
import 'alpha_x_timeout.dart';

/// Optional scheduling hint retained as a transport-neutral policy value.
enum AlphaXPriority {
  /// Lowest scheduling priority.
  low,

  /// Normal scheduling priority.
  normal,

  /// Highest scheduling priority.
  high,
}

/// Immutable request description passed to every AlphaX transport.
final class AlphaXRequest {
  /// Creates an absolute HTTP or HTTPS request.
  AlphaXRequest({
    required this.method,
    required this.uri,
    this.headers = const AlphaXHeaders.empty(),
    this.body = const AlphaXEmptyBody(),
    AlphaXTimeouts? timeout,
    AlphaXTimeouts? timeouts,
    this.cancellationToken,
    this.protocolPreference = AlphaXProtocolPreference.auto,
    this.protocolRequirement,
    this.redirectPolicy = const AlphaXRedirectPolicy(),
    this.priority = AlphaXPriority.normal,
    this.onUploadProgress,
    this.onDownloadProgress,
  }) : timeouts = _resolveTimeouts(timeout, timeouts) {
    if ((uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      throw ArgumentError.value(uri, 'uri', 'Requests require an absolute HTTP or HTTPS URI');
    }
    if (protocolRequirement != null &&
        protocolPreference != AlphaXProtocolPreference.auto &&
        protocolPreference != protocolRequirement!.preference) {
      throw ArgumentError(
        'protocolPreference and protocolRequirement must identify the same protocol',
      );
    }
    this.timeouts.validate();
  }

  /// HTTP method.
  final HttpMethod method;

  /// Absolute HTTP or HTTPS URI, including its query parameters.
  final Uri uri;

  /// Immutable request headers.
  final AlphaXHeaders headers;

  /// Request body. Empty requests use [AlphaXEmptyBody].
  final AlphaXBody body;

  /// Timeout configuration.
  final AlphaXTimeouts timeouts;

  /// Compatibility alias for the singular Phase 0 name.
  AlphaXTimeouts get timeout => timeouts;

  /// Caller-controlled cancellation source.
  final AlphaXCancellationToken? cancellationToken;

  /// Preferred protocol; it is not the negotiated protocol.
  final AlphaXProtocolPreference protocolPreference;

  /// Protocol that must be negotiated for the request to succeed.
  ///
  /// Unlike [protocolPreference], this value forbids fallback. A transport
  /// must fail if completion-time protocol metadata is unknown or differs.
  final AlphaXProtocolRequirement? protocolRequirement;

  /// Redirect policy.
  final AlphaXRedirectPolicy redirectPolicy;

  /// Optional scheduling hint.
  final AlphaXPriority priority;

  /// Upload progress callback, when the transport supports it.
  final AlphaXProgressCallback? onUploadProgress;

  /// Download progress callback, when the transport supports it.
  final AlphaXProgressCallback? onDownloadProgress;

  /// Whether this request has a non-empty body.
  bool get hasBody => body.contentLength != 0 || body is! AlphaXEmptyBody;

  /// Returns a request with selected immutable values replaced.
  AlphaXRequest copyWith({
    HttpMethod? method,
    Uri? uri,
    AlphaXHeaders? headers,
    AlphaXBody? body,
    AlphaXTimeouts? timeouts,
    AlphaXCancellationToken? cancellationToken,
    AlphaXProtocolPreference? protocolPreference,
    AlphaXProtocolRequirement? protocolRequirement,
    AlphaXRedirectPolicy? redirectPolicy,
    AlphaXPriority? priority,
    AlphaXProgressCallback? onUploadProgress,
    AlphaXProgressCallback? onDownloadProgress,
  }) => AlphaXRequest(
    method: method ?? this.method,
    uri: uri ?? this.uri,
    headers: headers ?? this.headers,
    body: body ?? this.body,
    timeouts: timeouts ?? this.timeouts,
    cancellationToken: cancellationToken ?? this.cancellationToken,
    protocolPreference: protocolPreference ?? this.protocolPreference,
    protocolRequirement: protocolRequirement ?? this.protocolRequirement,
    redirectPolicy: redirectPolicy ?? this.redirectPolicy,
    priority: priority ?? this.priority,
    onUploadProgress: onUploadProgress ?? this.onUploadProgress,
    onDownloadProgress: onDownloadProgress ?? this.onDownloadProgress,
  );

  static AlphaXTimeouts _resolveTimeouts(
    AlphaXTimeouts? timeout,
    AlphaXTimeouts? timeouts,
  ) {
    if (timeout != null && timeouts != null && timeout != timeouts) {
      throw ArgumentError('Specify either timeout or timeouts, not both');
    }
    return timeouts ?? timeout ?? const AlphaXTimeouts();
  }
}
