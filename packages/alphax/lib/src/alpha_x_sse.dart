import 'dart:async';
import 'dart:convert';

/// One dispatched Server-Sent Event.
///
/// [event] is `null` when the wire event omitted the `event` field or supplied
/// an empty event type. In that case the SSE default event type is `message`.
/// [id] is `null` when this event block had no valid `id` field, and is an empty
/// string when the block contained an empty `id:` field. [retry] is the valid
/// non-negative `retry` field from this event block, in wire milliseconds.
///
/// The parser does not retain connection-level last-event-id or retry state.
/// Callers own reconnection and may retain these values if their protocol needs
/// them for a later request.
final class AlphaXSseEvent {
  /// Creates an immutable parsed Server-Sent Event.
  const AlphaXSseEvent({
    required this.data,
    this.event,
    this.id,
    this.retry,
  });

  /// Data after joining all `data` fields with newlines and removing the final
  /// field separator newline.
  final String data;

  /// The event type, or `null` for the standard `message` default.
  final String? event;

  /// The event block's ID, preserving the distinction between absent and empty.
  final String? id;

  /// The event block's valid retry hint in milliseconds, if present.
  final int? retry;

  @override
  bool operator ==(Object other) =>
      other is AlphaXSseEvent &&
      other.data == data &&
      other.event == event &&
      other.id == id &&
      other.retry == retry;

  @override
  int get hashCode => Object.hash(data, event, id, retry);

  @override
  String toString() => 'AlphaXSseEvent(data: $data, event: $event, id: $id, retry: $retry)';
}

/// Incrementally parses an AlphaX response body as Server-Sent Events.
///
/// Use it directly on an AlphaX response stream:
///
/// ```dart
/// await for (final event in response.stream.transform(AlphaXSseParser())) {
///   print(event.data);
/// }
/// ```
///
/// Input is decoded as strict UTF-8. Dart's streaming decoder retains an
/// incomplete multibyte code point between source chunks. The parser recognizes
/// LF, CRLF, and CR line endings, including a CRLF split across chunks.
///
/// The default one-megabyte line and eight-megabyte event-data limits are
/// deliberately generous while preventing an endless line or data block from
/// growing memory without bound. A limit violation emits [FormatException] and
/// terminates the parsed stream. The UTF-8 decoder itself buffers at most the
/// incomplete code point needed to complete the next character.
///
/// A stream ending without a terminating blank line does not dispatch its
/// incomplete event. A trailing CR is a line terminator and is processed before
/// the stream completes. The parser never reconnects and never sends
/// `Last-Event-ID` automatically.
final class AlphaXSseParser extends StreamTransformerBase<List<int>, AlphaXSseEvent> {
  /// Creates a parser with generous bounded line and event-data buffers.
  AlphaXSseParser({
    this.maxLineLength = 1024 * 1024,
    this.maxEventDataLength = 8 * 1024 * 1024,
  }) {
    if (maxLineLength <= 0) {
      throw ArgumentError.value(maxLineLength, 'maxLineLength', 'Must be positive');
    }
    if (maxEventDataLength <= 0) {
      throw ArgumentError.value(maxEventDataLength, 'maxEventDataLength', 'Must be positive');
    }
  }

  /// Maximum number of Dart string code units allowed in one input line.
  final int maxLineLength;

  /// Maximum number of Dart string code units buffered for one event's data,
  /// including the newline separators inserted between `data` fields.
  final int maxEventDataLength;

  @override
  Stream<AlphaXSseEvent> bind(Stream<List<int>> stream) async* {
    final state = _AlphaXSseParserState(
      maxLineLength: maxLineLength,
      maxEventDataLength: maxEventDataLength,
    );

    await for (final textChunk in stream.transform(utf8.decoder)) {
      for (var index = 0; index < textChunk.length; index++) {
        final event = state.addCodeUnit(textChunk.codeUnitAt(index));
        if (event != null) {
          yield event;
        }
      }
    }

    final event = state.finish();
    if (event != null) {
      yield event;
    }
  }
}

final class _AlphaXSseParserState {
  _AlphaXSseParserState({
    required this.maxLineLength,
    required this.maxEventDataLength,
  });

  final int maxLineLength;
  final int maxEventDataLength;
  final StringBuffer _line = StringBuffer();
  StringBuffer _data = StringBuffer();

  bool _atStreamStart = true;
  bool _pendingCarriageReturn = false;
  int _lineLength = 0;
  int _dataLength = 0;
  String? _eventType;
  String? _id;
  int? _retry;

  AlphaXSseEvent? addCodeUnit(int codeUnit) {
    if (_pendingCarriageReturn) {
      _pendingCarriageReturn = false;
      final event = _processLine();
      if (codeUnit == 0x0A) {
        return event;
      }

      _consumeCodeUnit(codeUnit);
      return event;
    }
    return _consumeCodeUnit(codeUnit);
  }

  AlphaXSseEvent? finish() {
    if (!_pendingCarriageReturn) {
      return null;
    }
    _pendingCarriageReturn = false;
    return _processLine();
  }

  AlphaXSseEvent? _consumeCodeUnit(int codeUnit) {
    if (_atStreamStart) {
      _atStreamStart = false;
      if (codeUnit == 0xFEFF) {
        return null;
      }
    }

    if (codeUnit == 0x0D) {
      _pendingCarriageReturn = true;
      return null;
    }
    if (codeUnit == 0x0A) {
      return _processLine();
    }

    if (_lineLength == maxLineLength) {
      throw FormatException('SSE line exceeds the $maxLineLength code-unit limit');
    }
    _line.writeCharCode(codeUnit);
    _lineLength++;
    return null;
  }

  AlphaXSseEvent? _processLine() {
    final line = _line.toString();
    _line.clear();
    _lineLength = 0;

    if (line.isEmpty) {
      return _dispatchEvent();
    }
    if (line.codeUnitAt(0) == 0x3A) {
      return null;
    }

    final colon = line.indexOf(':');
    final field = colon == -1 ? line : line.substring(0, colon);
    var value = colon == -1 ? '' : line.substring(colon + 1);
    if (colon != -1 && value.isNotEmpty && value.codeUnitAt(0) == 0x20) {
      value = value.substring(1);
    }

    switch (field) {
      case 'data':
        _appendData(value);
      case 'event':
        _eventType = value;
      case 'id':
        if (!value.contains('\u0000')) {
          _id = value;
        }
      case 'retry':
        final retry = _parseRetry(value);
        if (retry != null) {
          _retry = retry;
        }
      default:
        // Unknown fields are ignored by the SSE field parsing algorithm.
        break;
    }
    return null;
  }

  void _appendData(String value) {
    final addition = value.length + 1;
    if (addition > maxEventDataLength || _dataLength > maxEventDataLength - addition) {
      throw FormatException('SSE event data exceeds the $maxEventDataLength code-unit limit');
    }
    _data
      ..write(value)
      ..writeCharCode(0x0A);
    _dataLength += addition;
  }

  AlphaXSseEvent? _dispatchEvent() {
    if (_dataLength == 0) {
      _resetEvent();
      return null;
    }

    final fullData = _data.toString();
    final data = fullData.substring(0, fullData.length - 1);
    final event = AlphaXSseEvent(
      data: data,
      event: _eventType == null || _eventType!.isEmpty ? null : _eventType,
      id: _id,
      retry: _retry,
    );
    _resetEvent();
    return event;
  }

  void _resetEvent() {
    _data = StringBuffer();
    _dataLength = 0;
    _eventType = null;
    _id = null;
    _retry = null;
  }

  static int? _parseRetry(String value) {
    if (value.isEmpty) {
      return null;
    }
    for (final codeUnit in value.codeUnits) {
      if (codeUnit < 0x30 || codeUnit > 0x39) {
        return null;
      }
    }
    return int.tryParse(value);
  }
}
