import 'package:alphax/alphax.dart';

/// Converts the raw Android provider capability result into AlphaX values.
///
/// The provider name is retained in the human-readable transport diagnostic so
/// a capability report cannot be mistaken for an unspecified Cronet runtime.
AlphaXCapabilities androidCapabilitiesFromNative(Object? raw) {
  final values = _map(raw);
  AlphaXSupport support(String name) => switch (values[name]?.toString()) {
    'supported' => AlphaXSupport.supported,
    'unsupported' => AlphaXSupport.unsupported,
    _ => AlphaXSupport.unknown,
  };
  final transportName = values['transportName']?.toString();
  final providerName = values['providerName']?.toString();
  final diagnosticName = switch ((transportName, providerName)) {
    (final String name, final String provider) when name.isNotEmpty && provider.isNotEmpty =>
      '$name ($provider)',
    (final String name, _) when name.isNotEmpty => name,
    (_, final String provider) when provider.isNotEmpty => provider,
    _ => null,
  };
  return AlphaXCapabilities(
    transportName: diagnosticName,
    transportVersion: values['transportVersion']?.toString(),
    http10: support('http10'),
    http11: support('http11'),
    http2: support('http2'),
    http3: support('http3'),
    streamingUpload: support('streamingUpload'),
    streamingDownload: support('streamingDownload'),
    nativeFileUpload: support('nativeFileUpload'),
    nativeFileDownload: support('nativeFileDownload'),
    uploadProgress: support('uploadProgress'),
    downloadProgress: support('downloadProgress'),
    proxyConfiguration: support('proxyConfiguration'),
    certificatePinning: support('certificatePinning'),
    mutualTls: support('mutualTls'),
    connectionMigration: support('connectionMigration'),
    backgroundTransfer: support('backgroundTransfer'),
    negotiatedProtocolReporting: support('negotiatedProtocolReporting'),
  );
}

/// Computes explicit fallback metadata from a preference and actual result.
AlphaXProtocolFallback? androidProtocolFallback(
  AlphaXProtocolPreference? requested,
  AlphaXProtocol negotiated,
) {
  if (requested == null || requested == AlphaXProtocolPreference.auto) {
    return null;
  }
  final desired = switch (requested) {
    AlphaXProtocolPreference.auto => AlphaXProtocol.unknown,
    AlphaXProtocolPreference.http10 => AlphaXProtocol.http10,
    AlphaXProtocolPreference.http11 => AlphaXProtocol.http11,
    AlphaXProtocolPreference.http2 => AlphaXProtocol.http2,
    AlphaXProtocolPreference.http3 => AlphaXProtocol.http3,
  };
  return desired == negotiated
      ? null
      : AlphaXProtocolFallback(requested: requested, negotiated: negotiated);
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map) return <String, Object?>{};
  return <String, Object?>{
    for (final entry in value.entries) entry.key.toString(): entry.value,
  };
}
