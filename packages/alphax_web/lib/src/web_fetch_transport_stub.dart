import 'package:alphax/alphax.dart';

/// Browser Fetch transport is available when this package is compiled for Web.
final class WebFetchTransport extends AlphaXTransport {
  /// Creates a Web transport placeholder for non-Web analysis targets.
  WebFetchTransport({this.withCredentials = false});

  /// Whether browser-managed credentials may be sent cross-origin.
  final bool withCredentials;

  @override
  AlphaXCapabilities get capabilities => const AlphaXCapabilities(
    transportName: 'Browser Fetch (Web only)',
    http10: AlphaXSupport.unsupported,
    http11: AlphaXSupport.unknown,
    http2: AlphaXSupport.unknown,
    http3: AlphaXSupport.unknown,
    streamingUpload: AlphaXSupport.unsupported,
    streamingDownload: AlphaXSupport.supported,
    nativeFileUpload: AlphaXSupport.unsupported,
    nativeFileDownload: AlphaXSupport.unsupported,
    uploadProgress: AlphaXSupport.unsupported,
    downloadProgress: AlphaXSupport.unknown,
    proxyConfiguration: AlphaXSupport.unknown,
    tlsDefaultTrust: AlphaXSupport.supported,
    customTrustAnchors: AlphaXSupport.unsupported,
    certificatePinning: AlphaXSupport.unsupported,
    mutualTls: AlphaXSupport.unsupported,
    systemProxy: AlphaXSupport.unknown,
    directConnectionPolicy: AlphaXSupport.unsupported,
    explicitHttpProxy: AlphaXSupport.unsupported,
    explicitHttpsProxy: AlphaXSupport.unsupported,
    proxyAuthentication: AlphaXSupport.unsupported,
    protocolRequirement: AlphaXSupport.unsupported,
    negotiatedProtocolReporting: AlphaXSupport.unsupported,
  );

  @override
  Future<AlphaXResponse> send(AlphaXRequest request) => Future<AlphaXResponse>.error(
    const AlphaXUnsupportedCapabilityException(
      'WebFetchTransport is only available when compiled for Web',
      capability: AlphaXCapability.http11,
    ),
  );

  @override
  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request) => Stream<AlphaXEvent>.error(
    const AlphaXUnsupportedCapabilityException(
      'WebFetchTransport is only available when compiled for Web',
      capability: AlphaXCapability.streamingDownload,
    ),
  );

  @override
  Future<void> close() async {}
}
