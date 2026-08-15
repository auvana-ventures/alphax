/// Transport-neutral TLS, proxy, and client-identity policies.
library;

import 'dart:convert';

/// A certificate/public-key pin scoped to one DNS host.
///
/// [sha256SpkiBase64] is the base64 encoding of the SHA-256 digest of the
/// certificate's DER-encoded SubjectPublicKeyInfo. A pin tightens normal
/// certificate validation; it never replaces hostname, validity, or trust
/// chain checks.
final class AlphaXSpkiPin {
  /// Creates a host-scoped SPKI pin.
  AlphaXSpkiPin({
    required this.host,
    required String sha256SpkiBase64,
    required this.expiresAt,
    this.includeSubdomains = false,
  }) : sha256SpkiBase64 = _validateDigest(sha256SpkiBase64) {
    if (host.trim().isEmpty || host.contains('/') || host.contains(':')) {
      throw ArgumentError.value(host, 'host', 'A pin host must be a DNS host name');
    }
  }

  /// DNS host to which the pin applies.
  final String host;

  /// Base64 SHA-256 digest of the certificate SPKI DER bytes.
  final String sha256SpkiBase64;

  /// Expiration required for native pinning configurations.
  final DateTime expiresAt;

  /// Whether subdomains are included.
  final bool includeSubdomains;

  /// Whether this pin is no longer valid for a new transport configuration.
  bool get isExpired => !expiresAt.isAfter(DateTime.now());

  static String _validateDigest(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'sha256SpkiBase64', 'A pin digest is required');
    }
    try {
      final bytes = base64Decode(normalized);
      if (bytes.length != 32) {
        throw const FormatException();
      }
    } on FormatException {
      throw ArgumentError.value(
        value,
        'sha256SpkiBase64',
        'A pin must be a base64-encoded SHA-256 digest',
      );
    }
    return normalized;
  }
}

/// An application-supplied DER-encoded trust anchor.
final class AlphaXTrustAnchor {
  /// Creates a trust anchor from a DER-encoded X.509 certificate.
  AlphaXTrustAnchor.der(List<int> derBytes)
    : derBytes = List<int>.unmodifiable(List<int>.from(derBytes, growable: false)) {
    if (this.derBytes.isEmpty) {
      throw ArgumentError.value(derBytes, 'derBytes', 'A trust anchor cannot be empty');
    }
  }

  /// DER-encoded X.509 certificate bytes.
  final List<int> derBytes;
}

/// An opaque reference to a platform-managed client certificate/private key.
///
/// Raw private-key strings are intentionally not part of the 1.0 public API.
/// A platform adapter may resolve [reference] through a secure keystore or
/// keychain, or reject it with an unsupported-capability error.
final class AlphaXClientIdentity {
  /// Creates a platform-managed identity reference.
  AlphaXClientIdentity.platformReference(this.reference) {
    if (reference.trim().isEmpty) {
      throw ArgumentError.value(reference, 'reference', 'An identity reference is required');
    }
  }

  /// Opaque platform identity/keychain reference.
  final String reference;
}

/// Immutable TLS policy used by an AlphaX transport instance.
final class AlphaXTlsPolicy {
  /// Uses the platform's normal verified trust store.
  const AlphaXTlsPolicy.platformDefault()
    : includePlatformTrust = true,
      trustAnchors = const <AlphaXTrustAnchor>[],
      pins = const <AlphaXSpkiPin>[],
      clientIdentity = null;

  /// Creates a verified policy with optional additional/replacement trust
  /// anchors, SPKI pins, and a platform client identity reference.
  AlphaXTlsPolicy({
    this.includePlatformTrust = true,
    Iterable<AlphaXTrustAnchor> trustAnchors = const <AlphaXTrustAnchor>[],
    Iterable<AlphaXSpkiPin> pins = const <AlphaXSpkiPin>[],
    this.clientIdentity,
  }) : trustAnchors = List<AlphaXTrustAnchor>.unmodifiable(trustAnchors),
       pins = List<AlphaXSpkiPin>.unmodifiable(pins) {
    if (!includePlatformTrust && this.trustAnchors.isEmpty) {
      throw ArgumentError(
        'Replacement trust requires at least one custom trust anchor',
      );
    }
    final hosts = <String>{};
    for (final pin in this.pins) {
      if (!hosts.add(
        '${pin.host.toLowerCase()}|${pin.includeSubdomains}|${pin.sha256SpkiBase64}',
      )) {
        throw ArgumentError('Duplicate SPKI pin: ${pin.host}');
      }
    }
  }

  /// Whether normal platform trust roots remain enabled.
  final bool includePlatformTrust;

  /// Additional or replacement DER trust anchors.
  final List<AlphaXTrustAnchor> trustAnchors;

  /// Host-scoped SPKI pins.
  final List<AlphaXSpkiPin> pins;

  /// Optional opaque platform client identity.
  final AlphaXClientIdentity? clientIdentity;

  /// Whether this is the default policy without extra controls.
  bool get isPlatformDefault =>
      includePlatformTrust && trustAnchors.isEmpty && pins.isEmpty && clientIdentity == null;
}

/// Supported proxy route families.
enum AlphaXProxyScheme {
  /// HTTP proxy, including HTTP CONNECT for HTTPS destinations where the
  /// underlying client supports it.
  http,

  /// HTTPS proxy. Support is provider-dependent.
  https,
}

/// Credentials for a configured proxy.
final class AlphaXProxyCredentials {
  /// Creates basic proxy credentials.
  const AlphaXProxyCredentials.basic({required this.username, required this.password});

  /// User name; never include this object in ordinary diagnostics.
  final String username;

  /// Password; never log or serialize this value into diagnostics.
  final String password;
}

/// Immutable proxy routing policy.
final class AlphaXProxyPolicy {
  /// Uses the platform/environment proxy configuration.
  const AlphaXProxyPolicy.system()
    : mode = AlphaXProxyMode.system,
      scheme = null,
      host = null,
      port = null,
      credentials = null;

  /// Bypasses system proxy configuration where the provider supports it.
  const AlphaXProxyPolicy.direct()
    : mode = AlphaXProxyMode.direct,
      scheme = null,
      host = null,
      port = null,
      credentials = null;

  /// Configures an explicit HTTP proxy.
  factory AlphaXProxyPolicy.http({
    required String host,
    required int port,
    AlphaXProxyCredentials? credentials,
  }) => AlphaXProxyPolicy._(
    scheme: AlphaXProxyScheme.http,
    host: host,
    port: port,
    credentials: credentials,
  );

  /// Configures an explicit HTTPS proxy where the provider supports it.
  factory AlphaXProxyPolicy.https({
    required String host,
    required int port,
    AlphaXProxyCredentials? credentials,
  }) => AlphaXProxyPolicy._(
    scheme: AlphaXProxyScheme.https,
    host: host,
    port: port,
    credentials: credentials,
  );

  AlphaXProxyPolicy._({
    required this.scheme,
    required String host,
    required int port,
    required this.credentials,
  }) : mode = AlphaXProxyMode.explicit,
       host = _validateHost(host),
       port = _validatePort(port);

  /// Route selection mode.
  final AlphaXProxyMode mode;

  /// Explicit proxy scheme, or `null` for system/direct.
  final AlphaXProxyScheme? scheme;

  /// Explicit proxy host, or `null` for system/direct.
  final String? host;

  /// Explicit proxy port, or `null` for system/direct.
  final int? port;

  /// Optional basic credentials.
  final AlphaXProxyCredentials? credentials;

  static String _validateHost(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.contains('/') || normalized.contains(':')) {
      throw ArgumentError.value(value, 'host', 'A proxy host must be a host name or address');
    }
    return normalized;
  }

  static int _validatePort(int value) {
    if (value < 1 || value > 65535) {
      throw ArgumentError.value(value, 'port', 'A proxy port must be between 1 and 65535');
    }
    return value;
  }
}

/// Proxy routing mode.
enum AlphaXProxyMode {
  /// Use system/environment configuration.
  system,

  /// Make a direct connection.
  direct,

  /// Use the explicit host and port in the policy.
  explicit,
}
