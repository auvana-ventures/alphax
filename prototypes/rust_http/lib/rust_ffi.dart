import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Native Rust result layout.
final class NativeAxRustResult extends Struct {
  /// HTTP status code.
  @Int64()
  external int statusCode;

  /// Number of response bytes.
  @Uint64()
  external int bytesReceived;

  /// Total elapsed milliseconds.
  @Double()
  external double totalMs;

  /// Prototype error code.
  @Int32()
  external int errorCode;
}

typedef _RustGetNative = Int32 Function(Pointer<Utf8>, Pointer<NativeAxRustResult>);
typedef _RustGetDart = int Function(Pointer<Utf8>, Pointer<NativeAxRustResult>);
typedef _VersionNative = Uint32 Function();
typedef _VersionDart = int Function();

/// Dart wrapper around the Rust prototype C ABI.
final class RustFfiClient {
  /// Loads the library from [path].
  RustFfiClient.fromPath(String path) : _library = DynamicLibrary.open(path) {
    _get = _library.lookupFunction<_RustGetNative, _RustGetDart>('ax_rust_get');
    _version = _library.lookupFunction<_VersionNative, _VersionDart>('ax_rust_ffi_version');
  }

  final DynamicLibrary _library;
  late final _RustGetDart _get;
  late final _VersionDart _version;

  /// ABI version exported by the native library.
  int get abiVersion => _version();

  /// Performs one blocking GET through the Rust C ABI.
  RustFfiResult get(Uri url) {
    return using((arena) {
      final urlPointer = url.toString().toNativeUtf8(allocator: arena);
      final resultPointer = arena<NativeAxRustResult>();
      final code = _get(urlPointer, resultPointer);
      if (code != 0) {
        throw StateError('Rust prototype request failed with code $code');
      }
      final result = resultPointer.ref;
      return RustFfiResult(
        statusCode: result.statusCode,
        bytesReceived: result.bytesReceived,
        totalMs: result.totalMs,
        errorCode: result.errorCode,
      );
    });
  }

  /// Opens the platform-default prototype library using an environment override.
  static RustFfiClient fromEnvironment() {
    final path = Platform.environment['ALPHAX_RUST_LIBRARY'];
    if (path == null || path.isEmpty) {
      throw StateError('Set ALPHAX_RUST_LIBRARY to the Rust prototype library path');
    }
    return RustFfiClient.fromPath(path);
  }
}

/// Result returned by [RustFfiClient].
final class RustFfiResult {
  /// Creates a result.
  const RustFfiResult({
    required this.statusCode,
    required this.bytesReceived,
    required this.totalMs,
    required this.errorCode,
  });

  /// HTTP status code.
  final int statusCode;

  /// Number of response bytes received.
  final int bytesReceived;

  /// Total elapsed time in milliseconds.
  final double totalMs;

  /// Native error code.
  final int errorCode;
}
