import 'dart:async';
import 'dart:convert';

import 'package:alphax/alphax.dart';
import 'package:alphax/sse.dart';
import 'package:test/test.dart';

void main() {
  group('AlphaXSseParser', () {
    test('parses the representative event fixture across chunk sizes', () async {
      final fixture = [
        ': keep-alive\r\n',
        ':\n',
        '\r\n',
        'data: first\r\n',
        ': between data\r\n',
        'data: second\r\n',
        '\r\n',
        'event: named\n',
        'id: event-1\n',
        'retry: 1500\n',
        'unknown: ignored\n',
        'data: hello\n',
        'data: 🌍\n',
        '\n',
        'id:\r',
        'data: cleared\r',
        '\r',
      ].join();
      const expected = <AlphaXSseEvent>[
        AlphaXSseEvent(data: 'first\nsecond'),
        AlphaXSseEvent(data: 'hello\n🌍', event: 'named', id: 'event-1', retry: 1500),
        AlphaXSseEvent(data: 'cleared', id: ''),
      ];

      for (final chunkSize in <int>[1, 2, 3, 5, 13]) {
        expect(await _parseText(fixture, chunkSize: chunkSize), expected);
      }
    });

    test('joins data fields, preserves one optional space, and handles no colon', () async {
      final events = await _parseText(
        'data: first\n'
        'data: second\n'
        'data\n'
        'data:\n'
        'data:  spaced\n'
        '\n',
        chunkSize: 1,
      );

      expect(events, <AlphaXSseEvent>[
        const AlphaXSseEvent(data: 'first\nsecond\n\n\n spaced'),
      ]);
    });

    test('dispatches an empty data field but not field-only or blank events', () async {
      final events = await _parseText(
        '\n\n'
        'event: ignored without data\n'
        'id: ignored-without-data\n'
        '\n'
        'data:\n'
        '\n\n',
      );

      expect(events, <AlphaXSseEvent>[const AlphaXSseEvent(data: '')]);
    });

    test('keeps LF, CRLF, and CR as one line-ending algorithm', () async {
      final events = await _parseText(
        'data: lf\n\n'
        'data: crlf\r\n\r\n'
        'data: cr\r\r'
        'data: final\n\n',
        chunkSize: 1,
      );

      expect(events, <AlphaXSseEvent>[
        const AlphaXSseEvent(data: 'lf'),
        const AlphaXSseEvent(data: 'crlf'),
        const AlphaXSseEvent(data: 'cr'),
        const AlphaXSseEvent(data: 'final'),
      ]);
    });

    test('does not dispatch an incomplete event at end of stream', () async {
      expect(await _parseText('data: no blank\n'), isEmpty);
      expect(await _parseText('data: no line terminator'), isEmpty);
      expect(await _parseText('data: line terminated by CR\r'), isEmpty);
      expect(
        await _parseText('data: complete\r\r'),
        <AlphaXSseEvent>[const AlphaXSseEvent(data: 'complete')],
      );
    });

    test('ignores comments and unknown fields without changing event data', () async {
      final largeComment = ':${'x' * 4096}\n';
      final events = await _parseText(
        '$largeComment'
        'data: first\n'
        ': between\n'
        'not-an-sse-field: ignored\n'
        'data: second\n'
        '\n'
        ': empty comment\n'
        '\n',
        chunkSize: 7,
      );

      expect(events, <AlphaXSseEvent>[
        const AlphaXSseEvent(data: 'first\nsecond'),
      ]);
    });

    test('preserves absent, empty, and valid IDs while ignoring null-containing IDs', () async {
      final events = await _parseText(
        'data: absent\n\n'
        'id: value\n'
        'id: invalid\u0000value\n'
        'data: value\n\n'
        'id:\n'
        'data: empty\n\n',
        chunkSize: 1,
      );

      expect(events, <AlphaXSseEvent>[
        const AlphaXSseEvent(data: 'absent'),
        const AlphaXSseEvent(data: 'value', id: 'value'),
        const AlphaXSseEvent(data: 'empty', id: ''),
      ]);
    });

    test('accepts valid retry milliseconds and ignores invalid values', () async {
      final events = await _parseText(
        'retry: 00015\n'
        'retry: invalid\n'
        'data: valid\n\n'
        'retry: -1\n'
        'retry: 2.5\n'
        'retry:  20\n'
        'retry: 20 \n'
        'retry:\n'
        'data: invalid\n\n',
        chunkSize: 2,
      );

      expect(events, <AlphaXSseEvent>[
        const AlphaXSseEvent(data: 'valid', retry: 15),
        const AlphaXSseEvent(data: 'invalid'),
      ]);
    });

    test('uses nullable event type for the standard message default', () async {
      final events = await _parseText(
        'event:\n'
        'data: default\n\n'
        'event: update\n'
        'data: named\n\n',
      );

      expect(events, <AlphaXSseEvent>[
        const AlphaXSseEvent(data: 'default'),
        const AlphaXSseEvent(data: 'named', event: 'update'),
      ]);
    });

    test('ignores one leading BOM and preserves a BOM in the event data', () async {
      expect(
        await _parseText('\uFEFFdata: leading\n\n', chunkSize: 1),
        <AlphaXSseEvent>[const AlphaXSseEvent(data: 'leading')],
      );
      expect(
        await _parseText('data: before\uFEFFafter\n\n', chunkSize: 1),
        <AlphaXSseEvent>[const AlphaXSseEvent(data: 'before\uFEFFafter')],
      );
    });

    test('decodes UTF-8 code points split across every small chunk size', () async {
      const expected = <AlphaXSseEvent>[
        AlphaXSseEvent(data: 'café 😀', event: 'unicode', id: 'π', retry: 42),
      ];
      const input =
          'event: unicode\n'
          'id: π\n'
          'retry: 42\n'
          'data: café 😀\n'
          '\n';

      for (final chunkSize in <int>[1, 2, 3, 4, 5]) {
        expect(await _parseText(input, chunkSize: chunkSize), expected);
      }
    });

    test('propagates malformed UTF-8 as a terminal FormatException', () async {
      final parsed = Stream<List<int>>.fromIterable(<List<int>>[
        <int>[0x64, 0x61, 0x74, 0x61, 0x3A, 0x20, 0xC3],
        <int>[0x28, 0x0A, 0x0A],
      ]).transform(AlphaXSseParser());

      await expectLater(parsed.toList(), throwsA(isA<FormatException>()));
    });

    test('propagates an AlphaX stream error without dispatching partial data', () async {
      const error = AlphaXConnectionException('stream disconnected');
      final source = StreamController<List<int>>();
      final parsed = source.stream.transform(AlphaXSseParser());
      final events = <AlphaXSseEvent>[];
      final completion = parsed.listen(events.add).asFuture<void>();

      source
        ..add(utf8.encode('data: partial'))
        ..addError(error)
        ..close();

      await expectLater(completion, throwsA(same(error)));
      expect(events, isEmpty);
    });

    test('propagates cancellation as a terminal stream error without late events', () async {
      const error = AlphaXCancellationException('cancelled');
      final source = StreamController<List<int>>();
      final parsed = source.stream.transform(AlphaXSseParser());
      final events = <AlphaXSseEvent>[];
      final completion = parsed.listen(events.add).asFuture<void>();

      source
        ..add(utf8.encode('data: partial'))
        ..addError(error)
        ..add(utf8.encode('\n\ndata: after\n\n'))
        ..close();

      await expectLater(completion, throwsA(same(error)));
      expect(events, isEmpty);
    });

    test('preserves source backpressure while a consumer is paused', () async {
      final source = StreamController<List<int>>();
      final events = <AlphaXSseEvent>[];
      final firstEvent = Completer<void>();
      final done = Completer<void>();
      late StreamSubscription<AlphaXSseEvent> subscription;

      subscription = source.stream
          .transform(AlphaXSseParser())
          .listen(
            (event) {
              events.add(event);
              if (!firstEvent.isCompleted) {
                subscription.pause();
                firstEvent.complete();
              }
            },
            onError: done.completeError,
            onDone: done.complete,
          );

      source.add(utf8.encode('data: first\n\n'));
      await firstEvent.future;
      source.add(utf8.encode('data: second\n\n'));
      await Future<void>.delayed(Duration.zero);
      expect(events, <AlphaXSseEvent>[const AlphaXSseEvent(data: 'first')]);

      source.close();
      subscription.resume();
      await done.future;
      expect(events, <AlphaXSseEvent>[
        const AlphaXSseEvent(data: 'first'),
        const AlphaXSseEvent(data: 'second'),
      ]);
    });

    test('enforces generous line and event-data limits deterministically', () async {
      expect(
        () => AlphaXSseParser(maxLineLength: 0),
        throwsArgumentError,
      );
      expect(
        () => AlphaXSseParser(maxEventDataLength: 0),
        throwsArgumentError,
      );
      await expectLater(
        _parseText('data: too long\n\n', parser: AlphaXSseParser(maxLineLength: 4)),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        _parseText(
          'data: abc\n'
          'data: def\n\n',
          parser: AlphaXSseParser(maxEventDataLength: 7),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('can be reused for independent response streams', () async {
      final parser = AlphaXSseParser();

      expect(
        await _parseText('data: one\n\n', parser: parser),
        <AlphaXSseEvent>[const AlphaXSseEvent(data: 'one')],
      );
      expect(
        await _parseText('data: two\n\n', parser: parser),
        <AlphaXSseEvent>[const AlphaXSseEvent(data: 'two')],
      );
    });
  });
}

Future<List<AlphaXSseEvent>> _parseText(
  String text, {
  int? chunkSize,
  AlphaXSseParser? parser,
}) {
  final bytes = utf8.encode(text);
  final chunks = chunkSize == null ? <List<int>>[bytes] : _split(bytes, chunkSize);
  return Stream<List<int>>.fromIterable(chunks).transform(parser ?? AlphaXSseParser()).toList();
}

Iterable<List<int>> _split(List<int> bytes, int chunkSize) sync* {
  for (var offset = 0; offset < bytes.length; offset += chunkSize) {
    final end = (offset + chunkSize).clamp(0, bytes.length);
    yield bytes.sublist(offset, end);
  }
}
