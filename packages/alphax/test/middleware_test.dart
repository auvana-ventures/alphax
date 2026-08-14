import 'dart:async';

import 'package:alphax/alphax.dart';
import 'package:test/test.dart';

final class _RecordingTransport extends AlphaXTransport {
  @override
  AlphaXCapabilities get capabilities => const AlphaXCapabilities(
    http11: AlphaXSupport.supported,
  );

  final List<String> order = <String>[];

  @override
  Future<AlphaXResponse> send(AlphaXRequest request) async {
    order.add('transport');
    return AlphaXResponse(statusCode: 200);
  }

  @override
  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request) async* {
    order.add('transport');
    yield AlphaXResponseStarted(statusCode: 200);
    yield const AlphaXResponseCompleted(bytesReceived: 0);
  }

  @override
  Future<void> close() async {}
}

final class _Middleware extends AlphaXMiddleware {
  _Middleware(this.name, this.order);

  final String name;
  final List<String> order;

  @override
  Future<AlphaXResponse> intercept(AlphaXRequest request, AlphaXNext next) async {
    order.add('$name:in');
    final response = await next(request.copyWith(headers: request.headers.add('x-$name', '1')));
    order.add('$name:out');
    return response;
  }
}

final class _DelayedMiddleware extends AlphaXMiddleware {
  _DelayedMiddleware(this.started, this.resume);

  final Completer<void> started;
  final Completer<void> resume;

  @override
  Future<AlphaXResponse> intercept(AlphaXRequest request, AlphaXNext next) async {
    started.complete();
    await resume.future;
    return next(request);
  }
}

void main() {
  test('middleware enters in order and unwinds in reverse order', () async {
    final order = <String>[];
    final transport = _RecordingTransport()..order.addAll(order);
    final client = AlphaXClient(
      transport: transport,
      middleware: <AlphaXMiddleware>[
        _Middleware('one', order),
        _Middleware('two', order),
      ],
    );

    await client.get(Uri.parse('https://example.com'));

    expect(order, <String>['one:in', 'two:in', 'two:out', 'one:out']);
    expect(transport.order, <String>['transport']);
  });

  test('client close is idempotent and prevents new requests', () async {
    final transport = _RecordingTransport();
    final client = AlphaXClient(transport: transport);

    final first = client.close();
    final second = client.close();

    expect(identical(first, second), isTrue);
    await first;
    await expectLater(
      client.get(Uri.parse('https://example.com')),
      throwsA(isA<AlphaXClientClosedException>()),
    );
  });

  test('middleware cannot resume into a closed client', () async {
    final started = Completer<void>();
    final resume = Completer<void>();
    final client = AlphaXClient(
      transport: _RecordingTransport(),
      middleware: <AlphaXMiddleware>[_DelayedMiddleware(started, resume)],
    );
    final request = client.get(Uri.parse('https://example.com'));
    await started.future;
    await client.close();
    resume.complete();

    await expectLater(request, throwsA(isA<AlphaXClientClosedException>()));
  });
}
