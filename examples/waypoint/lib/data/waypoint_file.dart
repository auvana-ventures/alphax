import 'package:alphax/alphax.dart';

final class WaypointMemoryFileSource implements AlphaXFileSource {
  WaypointMemoryFileSource(this.bytes, {this.name = 'waypoint-note.txt'});

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

final class WaypointMemoryFileTarget implements AlphaXFileTarget {
  WaypointMemoryFileTarget({this.name = 'waypoint-itinerary.pdf'});

  @override
  final String? name;
  final List<int> _bytes = <int>[];

  List<int> get bytes => List<int>.unmodifiable(_bytes);

  @override
  Future<AlphaXFileSink> openWrite() async {
    _bytes.clear();
    return _WaypointMemoryFileSink(_bytes);
  }
}

final class _WaypointMemoryFileSink implements AlphaXFileSink {
  _WaypointMemoryFileSink(this._bytes);

  final List<int> _bytes;
  bool _closed = false;

  @override
  void add(List<int> bytes) {
    if (_closed) {
      throw StateError('The Waypoint file sink is closed');
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
