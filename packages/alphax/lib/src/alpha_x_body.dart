import 'dart:async';
import 'dart:convert';

import 'alpha_x_file.dart';
import 'alpha_x_headers.dart';
import 'alpha_x_progress.dart';

/// Transport-neutral source of request bytes.
abstract interface class AlphaXBody {
  /// Creates an empty request body.
  const factory AlphaXBody.empty() = AlphaXEmptyBody;

  /// Creates an immutable byte request body.
  factory AlphaXBody.bytes(List<int> bytes, {String? contentType}) = AlphaXBytesBody;

  /// Creates a text request body.
  factory AlphaXBody.text(
    String text, {
    Encoding? encoding,
    String? contentType,
  }) = AlphaXTextBody;

  /// Creates a JSON request body using `dart:convert`.
  factory AlphaXBody.json(Object? value) = AlphaXJsonBody;

  /// Opens the body for incremental reading.
  Stream<List<int>> openStream();

  /// Encoded byte length, when known without consuming the body.
  int? get contentLength;

  /// Content type to apply when the caller has not supplied one.
  String? get contentType;

  /// Whether the body can be opened again for another attempt.
  bool get isReplayable;
}

/// Name used by the Phase 1A request API.
typedef AlphaXRequestBody = AlphaXBody;

/// An empty request body.
final class AlphaXEmptyBody implements AlphaXBody {
  /// Creates an empty body.
  const AlphaXEmptyBody();

  @override
  Stream<List<int>> openStream() => const Stream<List<int>>.empty();

  @override
  int get contentLength => 0;

  @override
  String? get contentType => null;

  @override
  bool get isReplayable => true;
}

/// An immutable byte request body.
final class AlphaXBytesBody implements AlphaXBody {
  /// Creates a byte body and copies [bytes].
  AlphaXBytesBody(List<int> bytes, {this.contentType}) : bytes = List<int>.unmodifiable(bytes);

  /// Immutable body bytes.
  final List<int> bytes;

  @override
  Stream<List<int>> openStream() => Stream<List<int>>.value(bytes);

  @override
  int get contentLength => bytes.length;

  @override
  final String? contentType;

  @override
  bool get isReplayable => true;
}

/// An encoded text request body.
final class AlphaXTextBody implements AlphaXBody {
  /// Creates a text body.
  AlphaXTextBody(
    this.text, {
    Encoding? encoding,
    String? contentType,
  }) : encoding = encoding ?? utf8,
       contentType = contentType ?? 'text/plain; charset=utf-8';

  /// Source text.
  final String text;

  /// Encoding used to produce [bytes].
  final Encoding encoding;

  /// Encoded body bytes.
  List<int> get bytes => List<int>.unmodifiable(encoding.encode(text));

  @override
  Stream<List<int>> openStream() => Stream<List<int>>.value(bytes);

  @override
  int get contentLength => bytes.length;

  @override
  final String contentType;

  @override
  bool get isReplayable => true;
}

/// A UTF-8 JSON request body.
final class AlphaXJsonBody implements AlphaXBody {
  /// Encodes [value] once so later transport reads are deterministic.
  AlphaXJsonBody(Object? value) : bytes = List<int>.unmodifiable(utf8.encode(jsonEncode(value)));

  /// Encoded JSON bytes.
  final List<int> bytes;

  @override
  Stream<List<int>> openStream() => Stream<List<int>>.value(bytes);

  @override
  int get contentLength => bytes.length;

  @override
  String get contentType => 'application/json; charset=utf-8';

  @override
  bool get isReplayable => true;
}

/// A request body backed by a caller-owned Dart stream.
final class AlphaXStreamBody implements AlphaXBody {
  /// Creates a single-use stream body.
  AlphaXStreamBody(
    this._stream, {
    this.contentLength,
    this.contentType,
    this.isReplayable = false,
  });

  final Stream<List<int>> _stream;
  bool _opened = false;

  @override
  final int? contentLength;

  @override
  final String? contentType;

  @override
  final bool isReplayable;

  @override
  Stream<List<int>> openStream() {
    if (_opened && !isReplayable) {
      throw StateError('This AlphaX stream body is single-consumption');
    }
    _opened = true;
    return _stream;
  }
}

/// A request body backed by an abstract file source.
final class AlphaXFileBody implements AlphaXBody {
  /// Creates a file body.
  AlphaXFileBody(
    this.source, {
    this.contentType,
    this.onProgress,
  });

  /// File source used by the body.
  final AlphaXFileSource source;

  /// Optional content type.
  @override
  final String? contentType;

  /// Optional upload progress callback.
  final AlphaXProgressCallback? onProgress;

  @override
  Stream<List<int>> openStream() {
    var transferred = 0;
    return source.openRead().map((chunk) {
      transferred += chunk.length;
      onProgress?.call(
        AlphaXProgress(
          direction: AlphaXTransferDirection.upload,
          bytesTransferred: transferred,
          totalBytes: source.length,
          isComplete: source.length != null && transferred >= source.length!,
        ),
      );
      return chunk;
    });
  }

  @override
  int? get contentLength => source.length;

  @override
  bool get isReplayable => source.isReplayable;
}

/// A multipart part with a named content disposition.
abstract interface class AlphaXMultipartPart {
  /// Form field name.
  String get name;

  /// Additional part headers.
  AlphaXHeaders get headers;

  /// Known part length.
  int? get contentLength;

  /// Opens part bytes.
  Stream<List<int>> openStream();

  /// Whether this part can be replayed.
  bool get isReplayable;
}

/// A text form-data field.
final class AlphaXMultipartField implements AlphaXMultipartPart {
  /// Creates a text field.
  AlphaXMultipartField(this.name, this.value, {AlphaXHeaders? headers})
    : headers = headers ?? const AlphaXHeaders.empty();

  @override
  final String name;

  /// Field value.
  final String value;

  @override
  final AlphaXHeaders headers;

  @override
  int get contentLength => utf8.encode(value).length;

  @override
  Stream<List<int>> openStream() => Stream<List<int>>.value(utf8.encode(value));

  @override
  bool get isReplayable => true;
}

/// A file-backed form-data part.
final class AlphaXMultipartFile implements AlphaXMultipartPart {
  /// Creates a file part.
  AlphaXMultipartFile(
    this.name,
    this.source, {
    this.filename,
    this.contentType,
    AlphaXHeaders? headers,
  }) : headers = headers ?? const AlphaXHeaders.empty();

  @override
  final String name;

  /// File source for the part.
  final AlphaXFileSource source;

  /// Filename presented in the form-data disposition.
  final String? filename;

  /// Part media type.
  final String? contentType;

  @override
  final AlphaXHeaders headers;

  @override
  int? get contentLength => source.length;

  @override
  Stream<List<int>> openStream() => source.openRead();

  @override
  bool get isReplayable => source.isReplayable;
}

/// A multipart/form-data request body that streams parts sequentially.
final class AlphaXMultipartBody implements AlphaXBody {
  /// Creates a multipart body with a deterministic caller-visible boundary.
  AlphaXMultipartBody(
    Iterable<AlphaXMultipartPart> parts, {
    this.boundary = 'alphax-boundary',
  }) : parts = List<AlphaXMultipartPart>.unmodifiable(parts) {
    if (boundary.isEmpty || boundary.contains(RegExp(r'[\r\n ]'))) {
      throw ArgumentError.value(boundary, 'boundary', 'Boundary must be an HTTP token');
    }
  }

  /// Immutable multipart parts.
  final List<AlphaXMultipartPart> parts;

  /// MIME boundary.
  final String boundary;

  @override
  String get contentType => 'multipart/form-data; boundary=$boundary';

  @override
  bool get isReplayable => parts.every((part) => part.isReplayable);

  @override
  int? get contentLength {
    var total = 0;
    for (final part in parts) {
      final length = part.contentLength;
      if (length == null) {
        return null;
      }
      total += _partPrefix(part).length + length + 2;
    }
    return total + _closeBoundary.length;
  }

  @override
  Stream<List<int>> openStream() async* {
    for (final part in parts) {
      yield _partPrefix(part);
      yield* part.openStream();
      yield const <int>[13, 10];
    }
    yield _closeBoundary;
  }

  List<int> _partPrefix(AlphaXMultipartPart part) {
    final disposition = StringBuffer('Content-Disposition: form-data; name="')
      ..write(_quote(part.name))
      ..write('"');
    if (part case AlphaXMultipartFile(:final filename, :final contentType)) {
      if (filename != null) {
        disposition
          ..write('; filename="')
          ..write(_quote(filename))
          ..write('"');
      }
      final lines = <String>[disposition.toString()];
      if (contentType != null) {
        lines.add('Content-Type: $contentType');
      }
      lines.addAll(part.headers.entries.map((entry) => '${entry.key}: ${entry.value}'));
      return utf8.encode('--$boundary\r\n${lines.join('\r\n')}\r\n\r\n');
    }
    final lines = <String>[
      disposition.toString(),
      ...part.headers.entries.map((entry) => '${entry.key}: ${entry.value}'),
    ];
    return utf8.encode('--$boundary\r\n${lines.join('\r\n')}\r\n\r\n');
  }

  List<int> get _closeBoundary => utf8.encode('--$boundary--\r\n');

  String _quote(String value) => value.replaceAll(RegExp(r'["\\\r\n]'), '_');
}

/// A response body that may be buffered or consumed incrementally.
abstract class AlphaXResponseBody {
  /// Creates an empty replayable response body.
  const AlphaXResponseBody._();

  /// Creates a replayable response body from bytes.
  factory AlphaXResponseBody.bytes(List<int> bytes) = _BufferedResponseBody;

  /// Creates a single-consumption response body from a stream.
  factory AlphaXResponseBody.stream(Stream<List<int>> stream, {int? contentLength}) =
      _StreamingResponseBody;

  /// Creates an empty response body.
  factory AlphaXResponseBody.empty() = _EmptyResponseBody;

  /// Response bytes as a stream. Accessing a streamed body consumes it once.
  Stream<List<int>> get stream;

  /// Body length, when known.
  int? get contentLength;

  /// Whether this body has been consumed.
  bool get isConsumed;

  /// Reads and returns all response bytes.
  Future<List<int>> readAsBytes() async {
    final bytes = <int>[];
    await for (final chunk in stream) {
      bytes.addAll(chunk);
    }
    return List<int>.unmodifiable(bytes);
  }

  /// Reads the response as text.
  Future<String> readAsString({Encoding encoding = utf8}) async =>
      encoding.decode(await readAsBytes());

  /// Reads and decodes a JSON response.
  Future<Object?> readAsJson({Encoding encoding = utf8}) async =>
      jsonDecode(await readAsString(encoding: encoding));

  /// Returns buffered bytes synchronously, or `null` for a streamed body.
  List<int>? get bufferedBytes => null;
}

final class _EmptyResponseBody extends AlphaXResponseBody {
  const _EmptyResponseBody() : super._();

  @override
  Stream<List<int>> get stream => const Stream<List<int>>.empty();

  @override
  int get contentLength => 0;

  @override
  bool get isConsumed => false;

  @override
  List<int> get bufferedBytes => const <int>[];
}

final class _BufferedResponseBody extends AlphaXResponseBody {
  _BufferedResponseBody(List<int> bytes) : bytes = List<int>.unmodifiable(bytes), super._();

  final List<int> bytes;

  @override
  Stream<List<int>> get stream => Stream<List<int>>.value(bytes);

  @override
  int get contentLength => bytes.length;

  @override
  bool get isConsumed => false;

  @override
  List<int> get bufferedBytes => bytes;
}

final class _StreamingResponseBody extends AlphaXResponseBody {
  _StreamingResponseBody(this._source, {this.contentLength}) : super._();

  final Stream<List<int>> _source;
  bool _opened = false;

  @override
  final int? contentLength;

  @override
  Stream<List<int>> get stream {
    if (_opened) {
      throw StateError('This AlphaX response body is single-consumption');
    }
    _opened = true;
    return _source;
  }

  @override
  bool get isConsumed => _opened;
}
