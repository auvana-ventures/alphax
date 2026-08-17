import 'dart:convert';

/// Incrementally decodes newline-delimited JSON without splitting UTF-8
/// code points when a transport boundary falls in the middle of a character.
final class WaypointActivityStreamDecoder {
  WaypointActivityStreamDecoder() {
    _bytes = const Utf8Decoder().startChunkedConversion(
      StringConversionSink.withCallback(_acceptText),
    );
  }

  late final ByteConversionSink _bytes;
  final List<Object?> _ready = <Object?>[];
  String _pending = '';
  bool _closed = false;

  void add(List<int> bytes) {
    if (_closed) {
      throw StateError('The Waypoint activity decoder is closed');
    }
    _bytes.add(bytes);
  }

  List<Object?> drain() {
    if (_ready.isEmpty) {
      return const <Object?>[];
    }
    final values = List<Object?>.from(_ready, growable: false);
    _ready.clear();
    return values;
  }

  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    _bytes.close();
    _drainLines();
    final line = _pending.trim();
    if (line.isNotEmpty) {
      _ready.add(jsonDecode(line));
    }
    _pending = '';
  }

  void _acceptText(String text) {
    _pending += text;
    _drainLines();
  }

  void _drainLines() {
    var newline = _pending.indexOf('\n');
    while (newline >= 0) {
      final line = _pending.substring(0, newline).trim();
      if (line.isNotEmpty) {
        _ready.add(jsonDecode(line));
      }
      _pending = _pending.substring(newline + 1);
      newline = _pending.indexOf('\n');
    }
  }
}
