/// Experimental native transport boundary for AlphaX.
library;

import 'package:alphax/alphax.dart';

export 'src/dart_io_transport.dart';
export 'src/android_cronet_transport.dart';
export 'src/apple_url_session_transport.dart';
export 'src/alpha_x_local_file.dart';

/// Platform transport adapters for AlphaX.
///
/// [DartIoTransport] is the pure-Dart fallback. [AndroidCronetTransport] and
/// [AppleUrlSessionTransport] are available when their Flutter plugin is
/// attached on the corresponding platform.
final class ExperimentalAlphaXNativeTransport extends AlphaXTransport {
  /// Creates a placeholder native transport.
  const ExperimentalAlphaXNativeTransport();

  @override
  AlphaXCapabilities get capabilities => const AlphaXCapabilities.unknown();

  @override
  Future<AlphaXResponse> send(AlphaXRequest request) {
    return Future<AlphaXResponse>.error(
      const AlphaXNativeTransportException(
        'The platform-native transport is not implemented yet',
      ),
    );
  }

  @override
  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request) => Stream<AlphaXEvent>.error(
    const AlphaXNativeTransportException(
      'The platform-native transport is not implemented yet',
    ),
  );

  @override
  Future<void> close() async {}
}
