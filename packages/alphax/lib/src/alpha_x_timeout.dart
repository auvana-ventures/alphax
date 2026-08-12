/// Optional request timeout configuration.
class AlphaXTimeout {
  /// Creates timeout values for the total request, connection, and read phases.
  const AlphaXTimeout({this.total, this.connect, this.read});

  /// Maximum total request duration, when configured.
  final Duration? total;

  /// Maximum connection establishment duration, when configured.
  final Duration? connect;

  /// Maximum read/inactivity duration, when configured.
  final Duration? read;

  /// Whether no timeout value is configured.
  bool get isEmpty => total == null && connect == null && read == null;

  /// Validates that configured durations are positive.
  void validate() {
    final values = <String, Duration?>{
      'total': total,
      'connect': connect,
      'read': read,
    };
    for (final entry in values.entries) {
      final value = entry.value;
      if (value != null && value <= Duration.zero) {
        throw ArgumentError.value(value, entry.key, 'Timeouts must be positive');
      }
    }
  }
}
