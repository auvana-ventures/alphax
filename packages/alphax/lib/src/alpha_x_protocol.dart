/// Protocol negotiated for a request, when the transport can report it.
enum AlphaXProtocol {
  /// The protocol is not known or was not reported by the transport.
  unknown,

  /// HTTP/1.0 or HTTP/1.1.
  http1,

  /// HTTP/2.
  http2,

  /// HTTP/3 over QUIC.
  http3,
}
