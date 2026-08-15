import 'alpha_x_protocol.dart';

/// A capability can be supported, unavailable, or not known by a transport.
enum AlphaXSupport {
  /// The transport can provide the capability under its current configuration.
  supported,

  /// The transport cannot provide the capability under its current configuration.
  unsupported,

  /// The transport cannot determine the capability before a request runs.
  unknown,
}

/// Capabilities that a transport may expose without leaking its implementation.
enum AlphaXCapability {
  /// HTTP/1.0 negotiation.
  http10,

  /// HTTP/1.1 negotiation.
  http11,

  /// HTTP/2 negotiation.
  http2,

  /// HTTP/3 negotiation.
  http3,

  /// Incremental request-body streaming.
  streamingUpload,

  /// Incremental response-body streaming.
  streamingDownload,

  /// Native file-backed request upload.
  nativeFileUpload,

  /// Native file-backed response download.
  nativeFileDownload,

  /// Upload progress callbacks.
  uploadProgress,

  /// Download progress callbacks.
  downloadProgress,

  /// Caller-configurable proxy behavior.
  proxyConfiguration,

  /// Platform/system trust with certificate verification enabled.
  tlsDefaultTrust,

  /// Caller-configurable additional or replacement trust anchors.
  customTrustAnchors,

  /// Caller-configurable certificate pinning.
  certificatePinning,

  /// Client certificate / mutual TLS configuration.
  mutualTls,

  /// Use the system proxy configuration.
  systemProxy,

  /// Explicitly bypass system proxy configuration.
  directConnectionPolicy,

  /// Explicit HTTP proxy configuration.
  explicitHttpProxy,

  /// Explicit HTTPS proxy configuration.
  explicitHttpsProxy,

  /// Explicit proxy authentication credentials.
  proxyAuthentication,

  /// Enforce a concrete negotiated protocol rather than preferring it.
  protocolRequirement,

  /// Connection migration, such as QUIC path migration.
  connectionMigration,

  /// Background transfer lifecycle.
  backgroundTransfer,

  /// Actual negotiated protocol reporting.
  negotiatedProtocolReporting,
}

/// Immutable, transport-neutral capability discovery result.
final class AlphaXCapabilities {
  /// Creates a capability set. Unknown is the default for every capability.
  const AlphaXCapabilities({
    this.transportName,
    this.transportVersion,
    this.http10 = AlphaXSupport.unknown,
    this.http11 = AlphaXSupport.unknown,
    this.http2 = AlphaXSupport.unknown,
    this.http3 = AlphaXSupport.unknown,
    this.streamingUpload = AlphaXSupport.unknown,
    this.streamingDownload = AlphaXSupport.unknown,
    this.nativeFileUpload = AlphaXSupport.unknown,
    this.nativeFileDownload = AlphaXSupport.unknown,
    this.uploadProgress = AlphaXSupport.unknown,
    this.downloadProgress = AlphaXSupport.unknown,
    this.proxyConfiguration = AlphaXSupport.unknown,
    this.tlsDefaultTrust = AlphaXSupport.unknown,
    this.customTrustAnchors = AlphaXSupport.unknown,
    this.certificatePinning = AlphaXSupport.unknown,
    this.mutualTls = AlphaXSupport.unknown,
    this.systemProxy = AlphaXSupport.unknown,
    this.directConnectionPolicy = AlphaXSupport.unknown,
    this.explicitHttpProxy = AlphaXSupport.unknown,
    this.explicitHttpsProxy = AlphaXSupport.unknown,
    this.proxyAuthentication = AlphaXSupport.unknown,
    this.protocolRequirement = AlphaXSupport.unknown,
    this.connectionMigration = AlphaXSupport.unknown,
    this.backgroundTransfer = AlphaXSupport.unknown,
    this.negotiatedProtocolReporting = AlphaXSupport.unknown,
  });

  /// Creates a capability result with every value unknown.
  const AlphaXCapabilities.unknown() : this();

  /// Human-readable transport family name, when useful for diagnostics.
  final String? transportName;

  /// Transport/provider version, when available.
  final String? transportVersion;

  /// HTTP/1.0 support.
  final AlphaXSupport http10;

  /// HTTP/1.1 support.
  final AlphaXSupport http11;

  /// HTTP/2 support.
  final AlphaXSupport http2;

  /// HTTP/3 support.
  final AlphaXSupport http3;

  /// Streaming upload support.
  final AlphaXSupport streamingUpload;

  /// Streaming download support.
  final AlphaXSupport streamingDownload;

  /// Native file upload support.
  final AlphaXSupport nativeFileUpload;

  /// Native file download support.
  final AlphaXSupport nativeFileDownload;

  /// Upload progress support.
  final AlphaXSupport uploadProgress;

  /// Download progress support.
  final AlphaXSupport downloadProgress;

  /// Proxy configuration support.
  final AlphaXSupport proxyConfiguration;

  /// Platform-default TLS trust support.
  final AlphaXSupport tlsDefaultTrust;

  /// Custom trust-anchor support.
  final AlphaXSupport customTrustAnchors;

  /// Certificate-pinning support.
  final AlphaXSupport certificatePinning;

  /// Mutual TLS support.
  final AlphaXSupport mutualTls;

  /// System proxy support.
  final AlphaXSupport systemProxy;

  /// Direct/no-proxy policy support.
  final AlphaXSupport directConnectionPolicy;

  /// Explicit HTTP proxy support.
  final AlphaXSupport explicitHttpProxy;

  /// Explicit HTTPS proxy support.
  final AlphaXSupport explicitHttpsProxy;

  /// Explicit proxy authentication support.
  final AlphaXSupport proxyAuthentication;

  /// Protocol requirement enforcement support.
  final AlphaXSupport protocolRequirement;

  /// Connection-migration support.
  final AlphaXSupport connectionMigration;

  /// Background-transfer support.
  final AlphaXSupport backgroundTransfer;

  /// Negotiated-protocol reporting support.
  final AlphaXSupport negotiatedProtocolReporting;

  /// Returns the state for [capability].
  AlphaXSupport supportFor(AlphaXCapability capability) => switch (capability) {
    AlphaXCapability.http10 => http10,
    AlphaXCapability.http11 => http11,
    AlphaXCapability.http2 => http2,
    AlphaXCapability.http3 => http3,
    AlphaXCapability.streamingUpload => streamingUpload,
    AlphaXCapability.streamingDownload => streamingDownload,
    AlphaXCapability.nativeFileUpload => nativeFileUpload,
    AlphaXCapability.nativeFileDownload => nativeFileDownload,
    AlphaXCapability.uploadProgress => uploadProgress,
    AlphaXCapability.downloadProgress => downloadProgress,
    AlphaXCapability.proxyConfiguration => proxyConfiguration,
    AlphaXCapability.tlsDefaultTrust => tlsDefaultTrust,
    AlphaXCapability.customTrustAnchors => customTrustAnchors,
    AlphaXCapability.certificatePinning => certificatePinning,
    AlphaXCapability.mutualTls => mutualTls,
    AlphaXCapability.systemProxy => systemProxy,
    AlphaXCapability.directConnectionPolicy => directConnectionPolicy,
    AlphaXCapability.explicitHttpProxy => explicitHttpProxy,
    AlphaXCapability.explicitHttpsProxy => explicitHttpsProxy,
    AlphaXCapability.proxyAuthentication => proxyAuthentication,
    AlphaXCapability.protocolRequirement => protocolRequirement,
    AlphaXCapability.connectionMigration => connectionMigration,
    AlphaXCapability.backgroundTransfer => backgroundTransfer,
    AlphaXCapability.negotiatedProtocolReporting => negotiatedProtocolReporting,
  };

  /// Whether [capability] is explicitly supported.
  bool supports(AlphaXCapability capability) => supportFor(capability) == AlphaXSupport.supported;

  /// Whether [protocol] is explicitly supported.
  bool supportsProtocol(AlphaXProtocol protocol) => switch (protocol) {
    AlphaXProtocol.http10 => http10 == AlphaXSupport.supported,
    AlphaXProtocol.http11 => http11 == AlphaXSupport.supported,
    AlphaXProtocol.http2 => http2 == AlphaXSupport.supported,
    AlphaXProtocol.http3 => http3 == AlphaXSupport.supported,
    AlphaXProtocol.unknown => false,
  };
}
