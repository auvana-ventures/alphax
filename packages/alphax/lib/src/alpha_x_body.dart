import 'dart:convert';

/// Immutable request body abstraction used by the Phase 0 contract.
sealed class AlphaXBody {
  const AlphaXBody._();

  /// Creates a byte body, copying [bytes] so callers can mutate their input safely.
  factory AlphaXBody.bytes(List<int> bytes) = AlphaXBytesBody;

  /// Creates a text body encoded with [encoding].
  factory AlphaXBody.text(String text, {Encoding? encoding}) =>
      AlphaXTextBody(text, encoding: encoding ?? utf8);

  /// Opens the body as a stream of owned byte chunks.
  Stream<List<int>> openStream();

  /// Number of encoded bytes, when known without consuming the body.
  int? get contentLength;
}

/// An immutable byte request body.
final class AlphaXBytesBody extends AlphaXBody {
  /// Creates a byte body and copies [bytes].
  AlphaXBytesBody(List<int> bytes) : bytes = List<int>.unmodifiable(bytes), super._();

  /// The immutable body bytes.
  final List<int> bytes;

  @override
  Stream<List<int>> openStream() => Stream<List<int>>.value(bytes);

  @override
  int get contentLength => bytes.length;
}

/// An immutable text request body.
final class AlphaXTextBody extends AlphaXBody {
  /// Creates a text body encoded with [encoding].
  AlphaXTextBody(this.text, {this.encoding = utf8}) : super._();

  /// The source text.
  final String text;

  /// Encoding used to produce [bytes].
  final Encoding encoding;

  /// Encoded immutable body bytes.
  List<int> get bytes => List<int>.unmodifiable(encoding.encode(text));

  @override
  Stream<List<int>> openStream() => Stream<List<int>>.value(bytes);

  @override
  int get contentLength => bytes.length;
}
