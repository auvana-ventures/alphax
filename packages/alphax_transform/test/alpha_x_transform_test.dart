import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:alphax/alphax.dart';
import 'package:alphax_transform/alphax_transform.dart';
import 'package:test/test.dart';

const _isNative = bool.fromEnvironment('dart.library.io');

void main() {
  test('decodes JSON and applies a sendable transform on native targets', () async {
    final bytes = _jsonBytes(<String, Object?>{
      'id': 7,
      'name': 'AlphaX',
    });

    if (!_isNative) {
      await expectLater(
        decodeJson<Map<String, Object?>>(
          bytes: bytes,
          transform: _summarizeObject,
        ),
        throwsA(isA<AlphaXTransformUnsupportedException>()),
      );
      return;
    }

    final result = await decodeJson<Map<String, Object?>>(
      bytes: bytes,
      transform: _summarizeObject,
      debugName: 'alphax-transform-test',
    );

    expect(result, <String, Object?>{
      'id': 7,
      'name': 'AlphaX',
    });
  });

  test('forwards JSON parse errors without transport wrapping', () async {
    if (!_isNative) {
      return;
    }

    await expectLater(
      decodeJson<Object?>(
        bytes: Uint8List.fromList(utf8.encode('{not-json')),
        transform: _identity,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('forwards invalid UTF-8 errors without transport wrapping', () async {
    if (!_isNative) {
      return;
    }

    await expectLater(
      decodeJson<Object?>(
        bytes: Uint8List.fromList(<int>[0xc3, 0x28]),
        transform: _identity,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('forwards transform errors without transport wrapping', () async {
    if (!_isNative) {
      return;
    }

    await expectLater(
      decodeJson<Object?>(
        bytes: _jsonBytes(<String, Object?>{'ok': true}),
        transform: _throwTransform,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('surfaces isolate sendability failures without serializing arbitrary values', () async {
    if (!_isNative) {
      return;
    }

    await expectLater(
      decodeJson<Object?>(
        bytes: _jsonBytes(<String, Object?>{'ok': true}),
        transform: _nonSendableResult,
      ),
      throwsA(anything),
    );
  });

  test('fails immediately with AlphaX cancellation before preparation', () async {
    final token = AlphaXCancellationToken()..cancel('already cancelled');

    await expectLater(
      decodeJson<Object?>(
        bytes: _jsonBytes(<String, Object?>{'ok': true}),
        transform: _identity,
        cancellationToken: token,
      ),
      throwsA(
        allOf(
          isA<AlphaXCancelledException>(),
          predicate<AlphaXCancelledException>(
            (error) => error.reason == 'already cancelled',
          ),
        ),
      ),
    );
  });

  test('cancellation after dispatch discards a late worker result', () async {
    if (!_isNative) {
      return;
    }

    final token = AlphaXCancellationToken();
    final future = decodeJson<Object?>(
      bytes: _jsonBytes(<String, Object?>{'ok': true}),
      transform: _slowIdentity,
      cancellationToken: token,
      debugName: 'alphax-transform-cancel-test',
    );
    Timer(const Duration(milliseconds: 20), () => token.cancel('discard result'));

    await expectLater(
      future,
      throwsA(
        allOf(
          isA<AlphaXCancelledException>(),
          predicate<AlphaXCancelledException>(
            (error) => error.reason == 'discard result',
          ),
        ),
      ),
    );

    // The worker is allowed to finish after discard. Waiting here verifies the
    // late result does not change the already completed caller future.
    await Future<void>.delayed(const Duration(milliseconds: 180));
  });

  test('worker errors after cancellation remain discarded', () async {
    if (!_isNative) {
      return;
    }

    final token = AlphaXCancellationToken();
    final future = decodeJson<Object?>(
      bytes: _jsonBytes(<String, Object?>{'ok': true}),
      transform: _slowThrowTransform,
      cancellationToken: token,
    );
    Timer(const Duration(milliseconds: 20), () => token.cancel('discard error'));

    await expectLater(future, throwsA(isA<AlphaXCancelledException>()));
    await Future<void>.delayed(const Duration(milliseconds: 180));
  });

  test('a completed worker result wins before a later cancellation', () async {
    if (!_isNative) {
      return;
    }

    final token = AlphaXCancellationToken();
    final result = await decodeJson<Object?>(
      bytes: _jsonBytes(<String, Object?>{'value': 42}),
      transform: _identity,
      cancellationToken: token,
    );
    token.cancel('too late');

    expect(result, <String, Object?>{'value': 42});
  });

  test('decodes deterministic payload sizes without changing the input contract', () async {
    if (!_isNative) {
      return;
    }

    for (final targetSize in <int>[100 * 1024, 1024 * 1024, 5 * 1024 * 1024, 10 * 1024 * 1024]) {
      final fixture = _fixture(targetSize);
      final result = await decodeJson<_FixtureSummary>(
        bytes: fixture.bytes,
        transform: _summarizeFixture,
        debugName: 'alphax-transform-$targetSize',
      );

      expect(result.itemCount, fixture.itemCount);
      expect(result.totalCharacters, fixture.itemCount * fixture.itemWidth);
      expect(fixture.bytes.length, greaterThanOrEqualTo(targetSize));
    }
  }, timeout: Timeout(Duration(minutes: 2)));

  test('reports Web background execution as unsupported', () async {
    if (_isNative) {
      return;
    }

    await expectLater(
      decodeJson<Object?>(
        bytes: _jsonBytes(<String, Object?>{'web': true}),
        transform: _identity,
      ),
      throwsA(
        allOf(
          isA<AlphaXTransformUnsupportedException>(),
          predicate<AlphaXTransformUnsupportedException>(
            (error) => error.message.contains('Background isolate'),
          ),
        ),
      ),
    );
  });
}

Uint8List _jsonBytes(Object? value) => Uint8List.fromList(utf8.encode(jsonEncode(value)));

Object? _identity(Object? decodedJson) => decodedJson;

Map<String, Object?> _summarizeObject(Object? decodedJson) {
  final object = decodedJson! as Map<Object?, Object?>;
  return <String, Object?>{
    'id': object['id'],
    'name': object['name'],
  };
}

Object? _throwTransform(Object? decodedJson) {
  decodedJson;
  throw StateError('transform failed');
}

Object? _nonSendableResult(Object? decodedJson) {
  decodedJson;
  return Completer<void>();
}

Object? _slowIdentity(Object? decodedJson) {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsedMilliseconds < 150) {
    // Keep the worker occupied long enough for the cancellation timer to win.
  }
  return decodedJson;
}

Object? _slowThrowTransform(Object? decodedJson) {
  _slowIdentity(decodedJson);
  throw StateError('late worker failure');
}

final class _Fixture {
  const _Fixture({required this.bytes, required this.itemCount, required this.itemWidth});

  final Uint8List bytes;
  final int itemCount;
  final int itemWidth;
}

final class _FixtureSummary {
  const _FixtureSummary({required this.itemCount, required this.totalCharacters});

  final int itemCount;
  final int totalCharacters;
}

_Fixture _fixture(int targetSize) {
  const itemWidth = 1024;
  final item = 'a' * itemWidth;
  var itemCount = (targetSize / (itemWidth + 2)).ceil();
  var bytes = _jsonBytes(<String, Object?>{
    'items': List<String>.filled(itemCount, item, growable: false),
  });
  while (bytes.length < targetSize) {
    itemCount += 1;
    bytes = _jsonBytes(<String, Object?>{
      'items': List<String>.filled(itemCount, item, growable: false),
    });
  }
  return _Fixture(bytes: bytes, itemCount: itemCount, itemWidth: itemWidth);
}

_FixtureSummary _summarizeFixture(Object? decodedJson) {
  final object = decodedJson! as Map<Object?, Object?>;
  final items = object['items']! as List<Object?>;
  final totalCharacters = items.fold<int>(
    0,
    (sum, item) => sum + (item! as String).length,
  );
  return _FixtureSummary(itemCount: items.length, totalCharacters: totalCharacters);
}
