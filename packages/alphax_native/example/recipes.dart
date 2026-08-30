import 'package:alphax_native/alphax_native.dart';

/// The automatic setup used by the main package example.
Future<AlphaXClient> automaticClient() => createAlphaXClient();

/// Explicit adapter choices remain available for controlled environments.
Future<AlphaXTransport> explicitDartIo() async => DartIoTransport();

Future<AlphaXTransport> explicitAndroid() => AndroidCronetTransport.create();

Future<AlphaXTransport> explicitApple() => AppleUrlSessionTransport.create();

/// Shows portable protocol preference and a fail-closed requirement.
Future<AlphaXResponse> requireHttp3(AlphaXClient client, Uri uri) => client.get(
  uri,
  protocolPreference: AlphaXProtocolPreference.http3,
  protocolRequirement: AlphaXProtocolRequirement.http3,
);

/// Shows transport policy configuration without exposing provider types.
Future<AlphaXClient> pinnedClient({
  required String host,
  required String spkiSha256Base64,
  required DateTime pinExpiry,
}) async {
  final transport = await createAlphaXTransport(
    tlsPolicy: AlphaXTlsPolicy(
      pins: <AlphaXSpkiPin>[
        AlphaXSpkiPin(
          host: host,
          sha256SpkiBase64: spkiSha256Base64,
          expiresAt: pinExpiry,
        ),
      ],
    ),
    proxyPolicy: const AlphaXProxyPolicy.system(),
  );
  return AlphaXClient(transport: transport);
}

/// Shows the transport-neutral native-file API.
Future<AlphaXTransferResult> downloadFile(AlphaXClient client, String path) => client.download(
  Uri.https('example.com', '/archive.bin'),
  to: AlphaXLocalFileTarget(path),
);
