import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Native libcurl result layout.
final class NativeAxCurlResult extends Struct {
  /// HTTP status code.
  @Int64()
  external int statusCode;

  /// Number of response bytes.
  @Uint64()
  external int bytesReceived;

  /// DNS lookup duration in milliseconds.
  @Double()
  external double nameLookupMs;

  /// Connection duration in milliseconds.
  @Double()
  external double connectMs;

  /// TLS duration in milliseconds.
  @Double()
  external double tlsMs;

  /// Time to first byte in milliseconds.
  @Double()
  external double timeToFirstByteMs;

  /// Total duration in milliseconds.
  @Double()
  external double totalMs;

  /// libcurl result code.
  @Int32()
  external int curlCode;

  /// libcurl HTTP version code.
  @Int32()
  external int httpVersion;
}

typedef _GetNative = Int32 Function(Pointer<Utf8>, Pointer<NativeAxCurlResult>);
typedef _GetDart = int Function(Pointer<Utf8>, Pointer<NativeAxCurlResult>);
typedef _VersionNative = Pointer<Utf8> Function();
typedef _VersionDart = Pointer<Utf8> Function();

/// Dart wrapper around the libcurl prototype C ABI.
final class CurlFfiClient {
  /// Loads the shared library at [path].
  CurlFfiClient.fromPath(String path) : _library = DynamicLibrary.open(path) {
    _get = _library.lookupFunction<_GetNative, _GetDart>('ax_curl_get');
    _version = _library.lookupFunction<_VersionNative, _VersionDart>('ax_curl_version');
  }

  final DynamicLibrary _library;
  late final _GetDart _get;
  late final _VersionDart _version;

  /// Native libcurl version string.
  String get version => _version().toDartString();

  /// Performs one blocking GET through the libcurl multi interface.
  CurlFfiResult get(Uri url) {
    return using((arena) {
      final urlPointer = url.toString().toNativeUtf8(allocator: arena);
      final resultPointer = arena<NativeAxCurlResult>();
      final code = _get(urlPointer, resultPointer);
      final result = resultPointer.ref;
      if (code != 0) {
        throw StateError('libcurl prototype request failed with code $code');
      }
      return CurlFfiResult(
        statusCode: result.statusCode,
        bytesReceived: result.bytesReceived,
        totalMs: result.totalMs,
        curlCode: result.curlCode,
        httpVersion: result.httpVersion,
      );
    });
  }

  /// Opens the platform-default prototype library using an environment override.
  static CurlFfiClient fromEnvironment() {
    final path = Platform.environment['ALPHAX_CURL_LIBRARY'];
    if (path == null || path.isEmpty) {
      throw StateError('Set ALPHAX_CURL_LIBRARY to the libcurl prototype library path');
    }
    return CurlFfiClient.fromPath(path);
  }
}

/// Result returned by [CurlFfiClient].
final class CurlFfiResult {
  /// Creates a result.
  const CurlFfiResult({
    required this.statusCode,
    required this.bytesReceived,
    required this.totalMs,
    required this.curlCode,
    required this.httpVersion,
  });

  /// HTTP status code.
  final int statusCode;

  /// Number of response bytes received.
  final int bytesReceived;

  /// Total elapsed time in milliseconds.
  final double totalMs;

  /// libcurl result code.
  final int curlCode;

  /// libcurl HTTP version code.
  final int httpVersion;
}
