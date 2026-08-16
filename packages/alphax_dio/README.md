# alphax_dio

`alphax_dio` provides a focused Dio 5.x `HttpClientAdapter` backed by an
already configured `AlphaXClient`.

```dart
import 'package:alphax/alphax.dart';
import 'package:alphax_dio/alphax_dio.dart';
import 'package:dio/dio.dart';

final alphaClient = AlphaXClient(transport: configuredTransport);
final dio = Dio()
  ..httpClientAdapter = AlphaXDioAdapter(alphaClient);

final response = await dio.get<String>('https://example.com/health');
dio.close();
```

The adapter preserves Dio's normal request transformation, interceptors,
`FormData`, cancellation, timeout, progress, response transformers, and
streaming pipeline. It maps the resulting request stream to an AlphaX
single-use body and maps AlphaX responses to Dio `ResponseBody` values.

AlphaX-specific protocol controls are supplied through typed
`RequestOptions.extra` values:

```dart
final response = await dio.get<String>(
  'https://example.com/health',
  options: Options(
    extra: <String, Object>{
      AlphaXDioAdapter.protocolPreferenceExtraKey:
          AlphaXProtocolPreference.http3,
      // Use protocolRequirementExtraKey for fail-closed behavior.
    },
  ),
);

final actualProtocol =
    response.extra[AlphaXDioAdapter.protocolExtraKey] as AlphaXProtocol?;
final finalMetrics = response.extra[
  AlphaXDioAdapter.completionMetricsExtraKey
];
```

`HttpClientAdapter.extraKeyHttpVersion` is also populated when AlphaX has a
concrete negotiated protocol (`1.0`, `1.1`, `2.0`, or `3.0`). Completion-time
metadata may update after a streamed response begins; `unknown` is not inferred
as H1. Use the configured AlphaX client's capabilities and policies for TLS,
trust anchors, SPKI pins, proxy routing, and provider limitations.

This is a focused compatibility boundary, not full Dio source/API
compatibility. It does not add automatic retries, a cookie jar, auth
orchestration, caching, or a new transport. AlphaX Web remains unsupported in
1.0 even though this package itself is pure Dart.
