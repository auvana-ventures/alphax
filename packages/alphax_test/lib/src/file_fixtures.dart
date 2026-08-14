import 'dart:async';

import 'package:alphax/alphax.dart';

/// Replayable in-memory source for file-transfer tests.
final class InMemoryAlphaXFileSource implements AlphaXFileSource {
  /// Creates a source and copies [bytes].
  InMemoryAlphaXFileSource(Iterable<int> bytes, {this.name = 'memory.bin'})
    : bytes = List<int>.unmodifiable(bytes);

  /// Immutable source bytes.
  final List<int> bytes;

  @override
  final String? name;

  @override
  int get length => bytes.length;

  @override
  bool get isReplayable => true;

  @override
  Stream<List<int>> openRead() => Stream<List<int>>.value(bytes);
}

/// In-memory target for file-download tests.
final class InMemoryAlphaXFileTarget implements AlphaXFileTarget {
  /// Creates an empty target.
  InMemoryAlphaXFileTarget({this.name = 'memory.bin'});

  final List<int> _bytes = <int>[];

  /// Bytes written after a successful close.
  List<int> get bytes => List<int>.unmodifiable(_bytes);

  @override
  final String? name;

  @override
  Future<AlphaXFileSink> openWrite() async {
    _bytes.clear();
    return _InMemoryAlphaXFileSink(_bytes);
  }
}

final class _InMemoryAlphaXFileSink implements AlphaXFileSink {
  _InMemoryAlphaXFileSink(this._bytes);

  final List<int> _bytes;
  bool _closed = false;

  @override
  void add(List<int> bytes) {
    if (_closed) {
      throw StateError('The in-memory file sink is closed');
    }
    _bytes.addAll(bytes);
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {
    _closed = true;
  }

  @override
  Future<void> abort() async {
    _bytes.clear();
    _closed = true;
  }
}
