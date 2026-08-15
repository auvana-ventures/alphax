import 'dart:typed_data';

import 'package:alphax/alphax.dart';

Map<String, Object?> alphaXTlsPolicyArguments(AlphaXTlsPolicy policy) => <String, Object?>{
  'includePlatformTrust': policy.includePlatformTrust,
  'trustAnchors': <Uint8List>[
    for (final anchor in policy.trustAnchors) Uint8List.fromList(anchor.derBytes),
  ],
  'pins': <Map<String, Object?>>[
    for (final pin in policy.pins)
      <String, Object?>{
        'host': pin.host,
        'sha256SpkiBase64': pin.sha256SpkiBase64,
        'expiresAtMs': pin.expiresAt.toUtc().millisecondsSinceEpoch,
        'includeSubdomains': pin.includeSubdomains,
      },
  ],
  'clientIdentityReference': policy.clientIdentity?.reference,
};

Map<String, Object?> alphaXProxyPolicyArguments(AlphaXProxyPolicy policy) => <String, Object?>{
  'mode': policy.mode.name,
  'scheme': policy.scheme?.name,
  'host': policy.host,
  'port': policy.port,
  'username': policy.credentials?.username,
  'password': policy.credentials?.password,
};
