/// Const metadata consumed by `alphax_generator`.
///
/// The declarations intentionally contain no build-runner, analyzer, or model
/// serialization dependency. Applications only need this library when they
/// declare an AlphaX-generated API.
library;

/// Marks an abstract API declaration for direct AlphaX client generation.
final class AlphaXApi {
  /// Creates API metadata with an absolute HTTP or HTTPS [baseUrl].
  const AlphaXApi({required this.baseUrl, this.headers = const <String, String>{}});

  /// Base URI used for relative endpoint paths.
  final String baseUrl;

  /// Static headers applied to every generated request.
  final Map<String, String> headers;
}

/// Marks a GET API method.
final class AlphaXGet {
  /// Creates GET metadata for [path].
  const AlphaXGet(this.path, {this.headers = const <String, String>{}});

  /// Relative or absolute endpoint path.
  final String path;

  /// Static headers applied to this method.
  final Map<String, String> headers;
}

/// Marks a POST API method.
final class AlphaXPost {
  /// Creates POST metadata for [path].
  const AlphaXPost(this.path, {this.headers = const <String, String>{}});

  /// Relative or absolute endpoint path.
  final String path;

  /// Static headers applied to this method.
  final Map<String, String> headers;
}

/// Marks a PUT API method.
final class AlphaXPut {
  /// Creates PUT metadata for [path].
  const AlphaXPut(this.path, {this.headers = const <String, String>{}});

  /// Relative or absolute endpoint path.
  final String path;

  /// Static headers applied to this method.
  final Map<String, String> headers;
}

/// Marks a PATCH API method.
final class AlphaXPatch {
  /// Creates PATCH metadata for [path].
  const AlphaXPatch(this.path, {this.headers = const <String, String>{}});

  /// Relative or absolute endpoint path.
  final String path;

  /// Static headers applied to this method.
  final Map<String, String> headers;
}

/// Marks a DELETE API method.
final class AlphaXDelete {
  /// Creates DELETE metadata for [path].
  const AlphaXDelete(this.path, {this.headers = const <String, String>{}});

  /// Relative or absolute endpoint path.
  final String path;

  /// Static headers applied to this method.
  final Map<String, String> headers;
}

/// Marks a HEAD API method.
final class AlphaXHead {
  /// Creates HEAD metadata for [path].
  const AlphaXHead(this.path, {this.headers = const <String, String>{}});

  /// Relative or absolute endpoint path.
  final String path;

  /// Static headers applied to this method.
  final Map<String, String> headers;
}

/// Binds a method parameter to a URI path placeholder.
final class AlphaXPath {
  /// Creates a path binding for [name].
  const AlphaXPath(this.name);

  /// Placeholder name, without braces.
  final String name;
}

/// Binds a method parameter to a repeated-safe URI query value.
final class AlphaXQuery {
  /// Creates a query binding for [name].
  const AlphaXQuery(this.name);

  /// Query parameter name.
  final String name;
}

/// Binds a method parameter to a request header.
final class AlphaXHeader {
  /// Creates a header binding for [name].
  const AlphaXHeader(this.name);

  /// Header name.
  final String name;
}

/// Selects how a method parameter becomes an [AlphaXBody].
enum AlphaXBodyEncoding {
  /// Encode the value as JSON, using `toJson()` for non-JSON-safe objects.
  json,

  /// Encode a String as text.
  text,

  /// Encode an iterable of bytes.
  bytes,

  /// Use a caller-owned `Stream<List<int>>`.
  stream,

  /// Use a caller-owned `AlphaXFileSource`.
  file,

  /// Use a caller-owned `AlphaXMultipartBody`.
  multipart,
}

/// Binds one method parameter to the request body.
///
/// The annotation is named `AlphaXBodyParam` to avoid colliding with the
/// runtime `AlphaXBody` and `AlphaXRequestBody` alias exported by
/// `package:alphax/alphax.dart`.
final class AlphaXBodyParam {
  /// Creates request-body metadata.
  const AlphaXBodyParam({this.encoding = AlphaXBodyEncoding.json, this.contentType});

  /// Body representation to construct.
  final AlphaXBodyEncoding encoding;

  /// Optional content type for text, bytes, stream, or file bodies.
  final String? contentType;
}

/// Supplies a callable Dart expression for typed response decoding.
///
/// [expression] must accept one decoded JSON value and return the declared
/// response type, for example `User.fromJson` or `parseUser`.
final class AlphaXDecode {
  /// Creates response-decoder metadata.
  const AlphaXDecode(this.expression);

  /// A callable expression emitted into generated source.
  final String expression;
}

/// Marks a parameter carrying request-scoped AlphaX policies.
final class AlphaXOptions {
  /// Creates request-options metadata.
  const AlphaXOptions();
}

/// Marks a parameter carrying an AlphaX cancellation token.
final class AlphaXCancellation {
  /// Creates cancellation metadata.
  const AlphaXCancellation();
}

/// Marks a parameter as the source for generated file upload operations.
final class AlphaXFileSourceParam {
  /// Creates file-source metadata.
  const AlphaXFileSourceParam();
}

/// Marks a parameter as the target for generated file download operations.
final class AlphaXFileTargetParam {
  /// Creates file-target metadata.
  const AlphaXFileTargetParam();
}
