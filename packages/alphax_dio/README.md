# alphax_dio

`alphax_dio` is for an existing Dio application that wants to use AlphaX as its
transport. New applications can use `alphax` directly and do not need this
adapter.

## Start here

After the RC is published, add the packages:

```sh
flutter pub add dio alphax alphax_native alphax_dio
```

While the RC is unpublished, use the repository dependency block in the [root
README](../../README.md) and add `dio: ^5.9.2` to the same application.

Create one AlphaX client, give it to the adapter, and keep using Dio:

```dart
import 'dart:io';

import 'package:alphax/alphax.dart';
import 'package:alphax_dio/alphax_dio.dart';
import 'package:alphax_native/alphax_native.dart';
import 'package:dio/dio.dart';

Future<AlphaXTransport> createTransport() async {
  if (Platform.isAndroid) {
    return await AndroidCronetTransport.create();
  }
  if (Platform.isIOS || Platform.isMacOS) {
    return await AppleUrlSessionTransport.create();
  }
  return DartIoTransport();
}

Future<void> main() async {
  final alphaClient = AlphaXClient(transport: await createTransport());
  final dio = Dio()..httpClientAdapter = AlphaXDioAdapter(alphaClient);

  try {
    final response = await dio.get<String>('https://example.com/health');
    print('${response.statusCode}: ${response.data}');
  } finally {
    dio.close();
  }
}
```

The adapter keeps Dio's normal request methods, interceptors, form data,
cancellation, timeouts, progress callbacks, response transformers, and stream
handling. It passes the final request to AlphaX and returns a normal Dio
response.

## Ask for or read the actual protocol

Protocol preference is optional. It allows fallback:

```dart
Future<void> requestWithPreferredProtocol(Dio dio) async {
  final response = await dio.get<String>(
    'https://example.com/health',
    options: Options(
      extra: <String, Object>{
        AlphaXDioAdapter.protocolPreferenceExtraKey:
            AlphaXProtocolPreference.http3,
      },
    ),
  );

  final actualProtocol =
      response.extra[AlphaXDioAdapter.protocolExtraKey] as AlphaXProtocol?;
  print('actual protocol: ${actualProtocol?.name ?? 'unknown'}');
}
```

Use `protocolRequirementExtraKey` instead when the request must fail if the
requested protocol is not actually negotiated. A preference is not a promise
that H3 will be used.

`HttpClientAdapter.extraKeyHttpVersion` is also populated when AlphaX has a
concrete negotiated protocol (`1.0`, `1.1`, `2.0`, or `3.0`). Completion-time
metadata may update after a streamed response begins; `unknown` is not inferred
as H1. Use the configured AlphaX client's capabilities and policies for TLS,
trust anchors, SPKI pins, proxy routing, and provider limitations.

This is a focused compatibility boundary, not full Dio source/API
compatibility. It does not add automatic retries, a cookie jar, auth
orchestration, caching, or a new transport. AlphaX Web remains unsupported in
1.0 even though this package itself is pure Dart.
