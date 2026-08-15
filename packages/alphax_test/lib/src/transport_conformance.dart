import 'dart:async';

import 'package:alphax/alphax.dart';
import 'package:test/test.dart';

import 'file_fixtures.dart';

/// Creates one fresh transport instance for each conformance test.
typedef AlphaXTransportFactory = FutureOr<AlphaXTransport> Function();

/// Resolves the fixture URI when a conformance test starts.
typedef AlphaXTransportUriProvider = Uri Function();

/// Defines the shared contract tests for a transport implementation.
///
/// Adapter packages should call this from their own test entry point. The
/// factory may initialize an isolated transport asynchronously because each
/// test owns and closes its instance. Synchronous factories remain supported.
void defineAlphaXTransportConformanceTests(
  String name,
  AlphaXTransportFactory createTransport, {
  Uri? baseUri,
  AlphaXTransportUriProvider? baseUriProvider,
}) {
  group('AlphaXTransport conformance: $name', () {
    Uri uri() =>
        baseUriProvider?.call() ??
        baseUri?.resolve('/resource') ??
        Uri.parse('https://example.com/resource');

    test('sends a typed request and returns a response', () async {
      final transport = await createTransport();
      addTearDown(transport.close);

      final response = await transport.send(
        AlphaXRequest(method: HttpMethod.get, uri: uri()),
      );

      expect(response.statusCode, inInclusiveRange(100, 599));
    });

    test('streaming emits start before chunks and completion last', () async {
      final transport = await createTransport();
      addTearDown(transport.close);

      final events = await transport
          .sendStreaming(AlphaXRequest(method: HttpMethod.get, uri: uri()))
          .toList();

      expect(events, isNotEmpty);
      expect(events.first, isA<AlphaXResponseStarted>());
      expect(events.last, isA<AlphaXResponseCompleted>());
      final firstChunk = events.indexWhere((event) => event is AlphaXResponseChunk);
      final completion = events.indexWhere((event) => event is AlphaXResponseCompleted);
      expect(firstChunk == -1 || firstChunk < completion, isTrue);
    });

    test('pre-cancelled request fails before transport work', () async {
      final transport = await createTransport();
      addTearDown(transport.close);
      final token = AlphaXCancellationToken()..cancel('test');

      await expectLater(
        transport.send(
          AlphaXRequest(
            method: HttpMethod.get,
            uri: uri(),
            cancellationToken: token,
          ),
        ),
        throwsA(isA<AlphaXCancellationException>()),
      );
    });

    test('close is safe to call more than once', () async {
      final transport = await createTransport();

      await transport.close();
      await expectLater(transport.close(), completes);
    });

    test('default file transfer paths preserve deterministic bytes', () async {
      final transport = await createTransport();
      addTearDown(transport.close);
      final target = InMemoryAlphaXFileTarget();

      final result = await transport.download(
        AlphaXRequest(method: HttpMethod.get, uri: uri()),
        target,
      );

      expect(result.bytesTransferred, target.bytes.length);
    });
  });
}
