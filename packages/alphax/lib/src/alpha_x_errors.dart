import 'alpha_x_capabilities.dart';
import 'alpha_x_protocol.dart';
import 'alpha_x_timeout.dart';

/// Normalized categories exposed by AlphaX transports.
enum AlphaXErrorKind {
  /// DNS resolution failed.
  dns,

  /// A connection could not be established or was lost.
  connection,

  /// TLS verification or negotiation failed.
  tls,

  /// A configured timeout elapsed.
  timeout,

  /// The caller or client lifecycle cancelled the operation.
  cancellation,

  /// The peer or transport violated the HTTP protocol contract.
  protocol,

  /// A concrete protocol requirement was not met.
  protocolRequirement,

  /// Redirect policy or redirect resolution failed.
  redirect,

  /// A proxy connection or proxy authentication operation failed.
  proxy,

  /// The request body could not be opened, encoded, or sent.
  requestBody,

  /// The response body could not be read or decoded.
  responseBody,

  /// The selected transport cannot provide a requested capability.
  unsupportedCapability,

  /// An error occurred inside the selected transport.
  transport,

  /// A generic resilience policy rejected or terminated the operation.
  resilience,
}

/// Base exception for the AlphaX public API.
class AlphaXException implements Exception {
  /// Creates a normalized exception while retaining an optional diagnostic cause.
  const AlphaXException(
    this.message, {
    required this.kind,
    this.cause,
    this.stackTrace,
  });

  /// Normalized category.
  final AlphaXErrorKind kind;

  /// Human-readable explanation safe for ordinary application diagnostics.
  final String message;

  /// Optional implementation-level cause for logging or debugging.
  final Object? cause;

  /// Optional cause stack trace.
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType: $message';
}

/// DNS resolution failed.
class AlphaXDnsException extends AlphaXException {
  /// Creates a DNS failure.
  const AlphaXDnsException(super.message, {super.cause, super.stackTrace})
    : super(kind: AlphaXErrorKind.dns);
}

/// Connection establishment or persistence failed.
class AlphaXConnectionException extends AlphaXException {
  /// Creates a connection failure.
  const AlphaXConnectionException(super.message, {super.cause, super.stackTrace})
    : super(kind: AlphaXErrorKind.connection);
}

/// Compatibility spelling for the Phase 0 connection exception.
class AlphaXConnectException extends AlphaXConnectionException {
  /// Creates a connection failure.
  const AlphaXConnectException(super.message, {super.cause, super.stackTrace});
}

/// TLS negotiation, validation, or pinning failed.
class AlphaXTlsException extends AlphaXException {
  /// Creates a TLS failure.
  const AlphaXTlsException(super.message, {super.cause, super.stackTrace})
    : super(kind: AlphaXErrorKind.tls);
}

/// A configured timeout elapsed.
class AlphaXTimeoutException extends AlphaXException {
  /// Creates a timeout failure for [timeoutKind].
  const AlphaXTimeoutException(
    super.message, {
    required this.timeoutKind,
    super.cause,
    super.stackTrace,
  }) : super(kind: AlphaXErrorKind.timeout);

  /// Timeout phase that elapsed.
  final AlphaXTimeoutKind timeoutKind;
}

/// A caller or client lifecycle requested cancellation.
class AlphaXCancellationException extends AlphaXException {
  /// Creates a cancellation failure.
  const AlphaXCancellationException(
    super.message, {
    this.reason,
    super.cause,
    super.stackTrace,
  }) : super(kind: AlphaXErrorKind.cancellation);

  /// Optional caller-provided reason.
  final Object? reason;
}

/// Compatibility spelling for the Phase 0 cancellation exception.
class AlphaXCancelledException extends AlphaXCancellationException {
  /// Creates a cancellation failure.
  const AlphaXCancelledException(super.message, {super.reason, super.cause, super.stackTrace});
}

/// The peer returned data that violated the expected protocol.
class AlphaXProtocolException extends AlphaXException {
  /// Creates a protocol failure.
  const AlphaXProtocolException(super.message, {super.cause, super.stackTrace})
    : super(kind: AlphaXErrorKind.protocol);
}

/// The final negotiated protocol did not satisfy the request requirement.
class AlphaXProtocolRequirementException extends AlphaXException {
  /// Creates a protocol requirement failure.
  AlphaXProtocolRequirementException({
    required AlphaXProtocolRequirement requiredProtocol,
    required AlphaXProtocol actualProtocol,
    String? message,
    super.cause,
    super.stackTrace,
  }) : requiredProtocol = requiredProtocol,
       actualProtocol = actualProtocol,
       super(
         message ??
             'The request required ${requiredProtocol.name}, but the negotiated '
                 'protocol was ${actualProtocol.name}',
         kind: AlphaXErrorKind.protocolRequirement,
       );

  /// Protocol required by the caller.
  final AlphaXProtocolRequirement requiredProtocol;

  /// Final protocol observed by the transport, or unknown.
  final AlphaXProtocol actualProtocol;
}

/// Redirect handling failed or violated the request policy.
class AlphaXRedirectException extends AlphaXException {
  /// Creates a redirect failure.
  const AlphaXRedirectException(super.message, {super.cause, super.stackTrace})
    : super(kind: AlphaXErrorKind.redirect);
}

/// A proxy operation failed.
class AlphaXProxyException extends AlphaXException {
  /// Creates a proxy failure.
  const AlphaXProxyException(super.message, {super.cause, super.stackTrace})
    : super(kind: AlphaXErrorKind.proxy);
}

/// A proxy requested by policy cannot be configured by the transport.
class AlphaXUnsupportedProxyPolicyException extends AlphaXUnsupportedCapabilityException {
  /// Creates an unsupported proxy-policy failure.
  const AlphaXUnsupportedProxyPolicyException(
    super.message, {
    required super.capability,
    super.cause,
    super.stackTrace,
  });
}

/// Proxy authentication failed or was rejected.
class AlphaXProxyAuthenticationException extends AlphaXProxyException {
  /// Creates a proxy-authentication failure.
  const AlphaXProxyAuthenticationException(super.message, {super.cause, super.stackTrace});
}

/// Certificate verification or pinning failed.
class AlphaXCertificateException extends AlphaXException {
  /// Creates a certificate failure.
  const AlphaXCertificateException(super.message, {super.cause, super.stackTrace})
    : super(kind: AlphaXErrorKind.tls);
}

/// A valid certificate chain did not contain a configured SPKI pin.
class AlphaXCertificatePinMismatchException extends AlphaXCertificateException {
  /// Creates a certificate pin mismatch.
  const AlphaXCertificatePinMismatchException(
    super.message, {
    this.host,
    super.cause,
    super.stackTrace,
  });

  /// Host whose pin set rejected the certificate.
  final String? host;
}

/// The requested TLS policy cannot be honored by the selected transport.
class AlphaXUnsupportedTlsPolicyException extends AlphaXUnsupportedCapabilityException {
  /// Creates an unsupported TLS-policy failure.
  const AlphaXUnsupportedTlsPolicyException(
    super.message, {
    required super.capability,
    super.cause,
    super.stackTrace,
  });
}

/// A configured client identity could not be used for mutual TLS.
class AlphaXClientCertificateException extends AlphaXTlsException {
  /// Creates a client-certificate failure.
  const AlphaXClientCertificateException(super.message, {super.cause, super.stackTrace});
}

/// A request body could not be opened, encoded, or sent.
class AlphaXRequestBodyException extends AlphaXException {
  /// Creates a request-body failure.
  const AlphaXRequestBodyException(super.message, {super.cause, super.stackTrace})
    : super(kind: AlphaXErrorKind.requestBody);
}

/// A response body could not be read or decoded.
class AlphaXResponseBodyException extends AlphaXException {
  /// Creates a response-body failure.
  const AlphaXResponseBodyException(super.message, {super.cause, super.stackTrace})
    : super(kind: AlphaXErrorKind.responseBody);
}

/// Compatibility base for body-related failures.
class AlphaXBodyException extends AlphaXRequestBodyException {
  /// Creates a body failure.
  const AlphaXBodyException(super.message, {super.cause, super.stackTrace});
}

/// A requested capability is unavailable for the selected transport.
class AlphaXUnsupportedCapabilityException extends AlphaXException {
  /// Creates an unsupported-capability failure.
  const AlphaXUnsupportedCapabilityException(
    super.message, {
    required this.capability,
    super.cause,
    super.stackTrace,
  }) : super(kind: AlphaXErrorKind.unsupportedCapability);

  /// Capability that could not be provided.
  final AlphaXCapability capability;
}

/// The transport failed without a more specific normalized category.
class AlphaXTransportException extends AlphaXException {
  /// Creates a transport failure.
  const AlphaXTransportException(super.message, {super.cause, super.stackTrace})
    : super(kind: AlphaXErrorKind.transport);
}

/// A generic resilience policy rejected a request before transport dispatch.
class AlphaXResilienceException extends AlphaXException {
  /// Creates a resilience-policy failure.
  const AlphaXResilienceException(super.message, {super.cause, super.stackTrace})
    : super(kind: AlphaXErrorKind.resilience);
}

/// The client was closed before the operation could start.
class AlphaXClientClosedException extends AlphaXException {
  /// Creates a client-lifecycle failure.
  const AlphaXClientClosedException([super.message = 'AlphaXClient is closed'])
    : super(kind: AlphaXErrorKind.transport);
}
