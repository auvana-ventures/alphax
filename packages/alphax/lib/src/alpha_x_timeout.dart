/// Timeout phase understood by the AlphaX public contract.
enum AlphaXTimeoutKind {
  /// DNS, socket, and TLS connection establishment.
  connect,

  /// Request dispatch through response headers, including request upload.
  request,

  /// Maximum inactivity between response body chunks.
  read,

  /// End-to-end request lifetime through response completion.
  overall,
}

/// Optional timeout configuration shared by all AlphaX transports.
final class AlphaXTimeouts {
  /// Creates timeout values for phases that a transport can map reliably.
  const AlphaXTimeouts({
    this.connect,
    this.request,
    this.read,
    Duration? overall,
    Duration? total,
  }) : overall = overall ?? total;

  /// Maximum connection-establishment duration.
  final Duration? connect;

  /// Maximum time until response headers after request dispatch.
  final Duration? request;

  /// Maximum response-body inactivity interval.
  final Duration? read;

  /// Maximum end-to-end request duration.
  final Duration? overall;

  /// Compatibility alias for the former total-timeout name.
  Duration? get total => overall;

  /// Whether no timeout is configured.
  bool get isEmpty => connect == null && request == null && read == null && overall == null;

  /// Validates that configured durations are positive.
  void validate() {
    final values = <String, Duration?>{
      'connect': connect,
      'request': request,
      'read': read,
      'overall': overall,
    };
    for (final entry in values.entries) {
      final value = entry.value;
      if (value != null && value <= Duration.zero) {
        throw ArgumentError.value(value, entry.key, 'Timeouts must be positive');
      }
    }
  }

  /// Returns a copy with selected values replaced.
  AlphaXTimeouts copyWith({
    Duration? connect,
    Duration? request,
    Duration? read,
    Duration? overall,
  }) => AlphaXTimeouts(
    connect: connect ?? this.connect,
    request: request ?? this.request,
    read: read ?? this.read,
    overall: overall ?? this.overall,
  );
}

/// Compatibility alias for the Phase 0 timeout name.
typedef AlphaXTimeout = AlphaXTimeouts;
