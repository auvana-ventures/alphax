/// Experimental native transport boundary for AlphaX.
library;

import 'package:alphax/alphax.dart';

/// Placeholder transport used until a Phase 1 platform adapter is implemented.
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
