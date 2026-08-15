import 'dart:io';

import 'package:alphax/alphax.dart';

/// A replayable local file source that can be consumed by Dart or a native
/// platform adapter without exposing a file descriptor or native handle.
final class AlphaXLocalFileSource implements AlphaXFileSource {
  /// Creates a local file source from [path].
  AlphaXLocalFileSource(this.path, {this.isReplayable = true});

  /// Local path retained for native file-backed adapters.
  final String path;

  @override
  final bool isReplayable;

  @override
  String get name => path;

  @override
  int get length => File(path).lengthSync();

  @override
  Stream<List<int>> openRead() => File(path).openRead();
}

/// A local file destination that can be handled directly by a native adapter.
final class AlphaXLocalFileTarget implements AlphaXFileTarget {
  /// Creates a local file target from [path].
  AlphaXLocalFileTarget(this.path);

  /// Local path retained for native file-backed adapters.
  final String path;

  @override
  String get name => path;

  @override
  Future<AlphaXFileSink> openWrite() async => _AlphaXLocalFileSink(File(path).openWrite());
}

final class _AlphaXLocalFileSink implements AlphaXFileSink {
  _AlphaXLocalFileSink(this._sink);

  final IOSink _sink;

  @override
  void add(List<int> bytes) => _sink.add(bytes);

  @override
  Future<void> flush() => _sink.flush();

  @override
  Future<void> close() => _sink.close();

  @override
  Future<void> abort() async {
    await _sink.flush();
    await _sink.close();
  }
}
