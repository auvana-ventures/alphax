/// Experimental native transport boundary for AlphaX.
library;

import 'package:alphax/alphax.dart';

export 'src/dart_io_transport.dart';
export 'src/android_cronet_transport.dart';

/// Platform transport adapters for AlphaX.
///
/// [DartIoTransport] is the pure-Dart fallback. [AndroidCronetTransport] is
/// available only when the Android Flutter plugin is attached.
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
