import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:alphax_transform/alphax_transform.dart';

/// Runs a bounded local comparison for the deterministic payload shapes used
/// by the Task 37 parsing evidence. It emits JSON lines and does not contact a
/// network or write result files.
Future<void> main() async {
  const repetitions = 3;
  for (final targetSize in <int>[100 * 1024, 1024 * 1024, 5 * 1024 * 1024, 10 * 1024 * 1024]) {
    final fixture = _fixture(targetSize);
    final operations = <String, Future<Object?> Function()>{
      'sync': () => Future<Object?>.value(_decodeSynchronously(fixture.bytes)),
      'direct_isolate_string': () => _decodeWithStringIsolate(fixture.bytes),
      'direct_isolate_transferable': () => _decodeWithTransferable(fixture.bytes),
      'alphax_transform': () => decodeJson<Object?>(
        bytes: fixture.bytes,
        transform: _summarize,
        debugName: 'alphax-transform-benchmark',
      ),
    };

    for (final entry in operations.entries) {
      // Warm the operation once so the measured line is not its first-use
      // isolate or JSON runtime setup.
      await entry.value();
      for (var iteration = 1; iteration <= repetitions; iteration++) {
        final sample = await _measure(entry.value);
        print(
          jsonEncode(<String, Object?>{
            'payload_bytes': fixture.bytes.length,
            'target_bytes': targetSize,
            'arm': entry.key,
            'iteration': iteration,
            'total_us': sample.total.inMicroseconds,
            'event_loop_gap_us': sample.eventLoopGap.inMicroseconds,
            'rss_bytes_after': ProcessInfo.currentRss,
          }),
        );
      }
    }
  }
}

Future<_Sample> _measure(Future<Object?> Function() operation) async {
  final stopwatch = Stopwatch()..start();
  final gap = Completer<Duration>();
  Timer.run(() {
    if (!gap.isCompleted) {
      gap.complete(stopwatch.elapsed);
    }
  });

  await operation();
  stopwatch.stop();
  if (!gap.isCompleted) {
    gap.complete(stopwatch.elapsed);
  }
  return _Sample(total: stopwatch.elapsed, eventLoopGap: await gap.future);
}

Object? _decodeSynchronously(Uint8List bytes) {
  final decoded = jsonDecode(utf8.decode(bytes));
  return _summarize(decoded);
}

Future<Object?> _decodeWithStringIsolate(Uint8List bytes) async {
  final text = utf8.decode(bytes);
  return Isolate.run<Object?>(() => _decodeText(text));
}

Future<Object?> _decodeWithTransferable(Uint8List bytes) async {
  final transferable = TransferableTypedData.fromList(<TypedData>[bytes]);
  return Isolate.run<Object?>(() => _decodeTransferred(transferable));
}

Object? _decodeText(String text) => _summarize(jsonDecode(text));

Object? _decodeTransferred(TransferableTypedData transferable) {
  final bytes = transferable.materialize().asUint8List();
  return _decodeSynchronously(bytes);
}

Map<String, Object?> _summarize(Object? decodedJson) {
  final object = decodedJson! as Map<Object?, Object?>;
  final items = object['items']! as List<Object?>;
  final totalCharacters = items.fold<int>(
    0,
    (sum, item) => sum + (item! as String).length,
  );
  return <String, Object?>{
    'item_count': items.length,
    'total_characters': totalCharacters,
  };
}

_Fixture _fixture(int targetSize) {
  const itemWidth = 1024;
  final item = 'a' * itemWidth;
  var itemCount = (targetSize / (itemWidth + 2)).ceil();
  var bytes = _encodeFixture(itemCount, item);
  while (bytes.length < targetSize) {
    itemCount += 1;
    bytes = _encodeFixture(itemCount, item);
  }
  return _Fixture(bytes: bytes);
}

Uint8List _encodeFixture(int itemCount, String item) => Uint8List.fromList(
  utf8.encode(
    jsonEncode(<String, Object?>{
      'items': List<String>.filled(itemCount, item, growable: false),
    }),
  ),
);

final class _Fixture {
  const _Fixture({required this.bytes});

  final Uint8List bytes;
}

final class _Sample {
  const _Sample({required this.total, required this.eventLoopGap});

  final Duration total;
  final Duration eventLoopGap;
}
