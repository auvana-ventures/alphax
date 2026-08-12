/// Base exception for errors exposed by the AlphaX public contract.
class AlphaXException implements Exception {
  /// Creates an AlphaX exception with an optional implementation-level cause.
  const AlphaXException(
    this.message, {
    this.cause,
    this.stackTrace,
  });

  /// Human-readable explanation safe for ordinary diagnostic output.
  final String message;

  /// Optional underlying error retained for diagnostic integrations.
  final Object? cause;

  /// Optional stack trace associated with the underlying error.
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType: $message';
}

/// A DNS lookup failed.
class AlphaXDnsException extends AlphaXException {
  /// Creates a DNS failure.
  const AlphaXDnsException(super.message, {super.cause, super.stackTrace});
}

/// A connection could not be established.
class AlphaXConnectException extends AlphaXException {
  /// Creates a connection failure.
  const AlphaXConnectException(super.message, {super.cause, super.stackTrace});
}

/// TLS negotiation or validation failed.
class AlphaXTlsException extends AlphaXException {
  /// Creates a TLS failure.
  const AlphaXTlsException(super.message, {super.cause, super.stackTrace});
}

/// A request exceeded a configured timeout.
class AlphaXTimeoutException extends AlphaXException {
  /// Creates a timeout failure.
  const AlphaXTimeoutException(super.message, {super.cause, super.stackTrace});
}

/// A request was cancelled by its caller.
class AlphaXCancelledException extends AlphaXException {
  /// Creates a cancellation failure.
  const AlphaXCancelledException(super.message, {super.cause, super.stackTrace});
}

/// The peer returned data that violated the expected protocol.
class AlphaXProtocolException extends AlphaXException {
  /// Creates a protocol failure.
  const AlphaXProtocolException(super.message, {super.cause, super.stackTrace});
}

/// A proxy operation failed.
class AlphaXProxyException extends AlphaXException {
  /// Creates a proxy failure.
  const AlphaXProxyException(super.message, {super.cause, super.stackTrace});
}

/// Certificate validation or pinning failed.
class AlphaXCertificateException extends AlphaXException {
  /// Creates a certificate failure.
  const AlphaXCertificateException(super.message, {super.cause, super.stackTrace});
}

/// A request or response body could not be read or encoded.
class AlphaXBodyException extends AlphaXException {
  /// Creates a body failure.
  const AlphaXBodyException(super.message, {super.cause, super.stackTrace});
}

/// A native transport failed before it could be represented by a more specific
/// public error type.
class AlphaXNativeTransportException extends AlphaXException {
  /// Creates a native transport failure.
  const AlphaXNativeTransportException(
    super.message, {
    this.nativeErrorCode,
    super.cause,
    super.stackTrace,
  });

  /// Optional native error code retained for diagnostics.
  final int? nativeErrorCode;
}
