import 'package:alphax_native/alphax_native.dart';

/// The Level 1 request options remain ordinary named arguments.
Future<AlphaXResponse> configuredGet(
  AlphaXAppClient client,
  AlphaXCancellationToken cancellationToken,
) => client.get(
  '/users',
  queryParameters: <String, Object?>{
    'page': 2,
    'status': 'active',
  },
  headers: <String, String>{'authorization': 'Bearer token'},
  timeout: const Duration(seconds: 30),
  cancellationToken: cancellationToken,
);

/// Absolute HTTP(S) targets are accepted when a request must bypass the base.
Future<AlphaXResponse> absoluteStatus(AlphaXAppClient client) =>
    client.get('https://status.example.com/health');

/// JSON data is encoded by the existing AlphaX JSON body implementation.
Future<AlphaXResponse> createUser(AlphaXAppClient client) => client.post(
  '/users',
  data: <String, Object?>{
    'name': 'Yuvraj',
    'role': 'admin',
  },
);

/// Explicit ownership is visible when wrapping an existing low-level client.
AlphaXAppClient ownedFacade(AlphaXClient client) => AlphaXAppClient.owned(
  client,
  baseUrl: 'https://api.example.com',
);

/// A borrowed facade never closes the caller-owned client.
AlphaXAppClient borrowedFacade(AlphaXClient client) => AlphaXAppClient.borrowed(
  client,
  baseUrl: 'https://api.example.com',
);
