import 'dart:async';

import 'package:alphax/alphax.dart';
import 'package:test/test.dart';

void main() {
  test('capabilities distinguish supported, unsupported, and unknown', () {
    const capabilities = AlphaXCapabilities(
      http11: AlphaXSupport.supported,
      http2: AlphaXSupport.unsupported,
      http3: AlphaXSupport.unknown,
      streamingDownload: AlphaXSupport.supported,
    );

    expect(capabilities.supports(AlphaXCapability.http11), isTrue);
    expect(capabilities.supports(AlphaXCapability.http2), isFalse);
    expect(capabilities.supportFor(AlphaXCapability.http3), AlphaXSupport.unknown);
  });

  test('responses report actual protocol and explicit fallback separately', () {
    const fallback = AlphaXProtocolFallback(
      requested: AlphaXProtocolPreference.http3,
      negotiated: AlphaXProtocol.http2,
      reason: AlphaXProtocolFallbackReason.network,
    );
    final response = AlphaXResponse(
      statusCode: 200,
      protocol: AlphaXProtocol.http2,
      requestedProtocol: AlphaXProtocolPreference.http3,
      protocolFallback: fallback,
    );

    expect(response.protocol, AlphaXProtocol.http2);
    expect(response.requestedProtocol, AlphaXProtocolPreference.http3);
    expect(response.protocolFallback?.negotiated, AlphaXProtocol.http2);
  });

  test('unknown is valid until final completion metrics prove the protocol', () async {
    final completion = Completer<AlphaXRequestMetrics>();
    final response = AlphaXResponse(
      statusCode: 200,
      requestedProtocol: AlphaXProtocolPreference.http3,
      completionMetrics: completion.future,
    );

    expect(response.protocol, AlphaXProtocol.unknown);
    expect(response.protocolFallback, isNull);

    final fallbackFuture = response.completionProtocolFallback;
    completion.complete(
      const AlphaXRequestMetrics(negotiatedProtocol: AlphaXProtocol.http2),
    );
    expect(
      (await response.completionMetrics).negotiatedProtocol,
      AlphaXProtocol.http2,
    );
    final fallback = await fallbackFuture;
    expect(fallback?.requested, AlphaXProtocolPreference.http3);
    expect(fallback?.negotiated, AlphaXProtocol.http2);
    expect(fallback?.reason, AlphaXProtocolFallbackReason.unknown);
  });

  test('a transport may report a protocol at response start when it knows it', () async {
    final response = AlphaXResponse(
      statusCode: 200,
      protocol: AlphaXProtocol.http2,
      metrics: const AlphaXRequestMetrics(negotiatedProtocol: AlphaXProtocol.http2),
    );

    expect(response.protocol, AlphaXProtocol.http2);
    expect(
      (await response.completionMetrics).negotiatedProtocol,
      AlphaXProtocol.http2,
    );
    expect(await response.completionProtocolFallback, isNull);
  });

  test('stream completion carries final protocol and fallback metadata', () {
    const fallback = AlphaXProtocolFallback(
      requested: AlphaXProtocolPreference.http3,
      negotiated: AlphaXProtocol.http2,
    );
    const completed = AlphaXResponseCompleted(
      metrics: AlphaXRequestMetrics(negotiatedProtocol: AlphaXProtocol.http2),
      bytesReceived: 0,
      requestedProtocol: AlphaXProtocolPreference.http3,
      protocolFallback: fallback,
    );

    expect(completed.metrics.negotiatedProtocol, AlphaXProtocol.http2);
    expect(completed.requestedProtocol, AlphaXProtocolPreference.http3);
    expect(completed.protocolFallback, fallback);
  });

  test('method parser only accepts the required HTTP surface', () {
    expect(HttpMethod.parse('patch'), HttpMethod.patch);
    expect(HttpMethod.tryParse('CONNECT'), isNull);
    expect(HttpMethod.options.value, 'OPTIONS');
  });
}
