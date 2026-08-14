/// Protocol actually negotiated for an AlphaX response.
enum AlphaXProtocol {
  /// No protocol was reported by the transport.
  unknown,

  /// HTTP/1.0.
  http10,

  /// HTTP/1.1.
  http11,

  /// HTTP/2.
  http2,

  /// HTTP/3 over QUIC.
  http3,
}

/// Protocol preference supplied to a request.
///
/// This is a preference, not a statement about the protocol the server or
/// transport will negotiate. The response's [AlphaXProtocol] is authoritative.
enum AlphaXProtocolPreference {
  /// Let the transport and server choose the best available protocol.
  auto,

  /// Prefer HTTP/1.0 where supported.
  http10,

  /// Prefer HTTP/1.1.
  http11,

  /// Prefer HTTP/2.
  http2,

  /// Prefer HTTP/3; a lower protocol may be negotiated and reported.
  http3,
}

/// Why the negotiated protocol differed from the request preference.
enum AlphaXProtocolFallbackReason {
  /// The requested protocol is not supported by the selected provider.
  unsupported,

  /// The server did not negotiate the requested protocol.
  server,

  /// A proxy or intermediary selected another protocol.
  proxy,

  /// The network path prevented the preferred protocol.
  network,

  /// The transport reported a fallback without a more precise reason.
  unknown,
}

/// Explicit information about a preferred-protocol fallback.
final class AlphaXProtocolFallback {
  /// Creates fallback information.
  const AlphaXProtocolFallback({
    required this.requested,
    required this.negotiated,
    this.reason = AlphaXProtocolFallbackReason.unknown,
  });

  /// Protocol requested or preferred by the caller.
  final AlphaXProtocolPreference requested;

  /// Protocol actually negotiated.
  final AlphaXProtocol negotiated;

  /// Normalized reason when the transport can provide one.
  final AlphaXProtocolFallbackReason reason;
}
