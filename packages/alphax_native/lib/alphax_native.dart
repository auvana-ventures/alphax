/// Experimental native transport boundary for AlphaX.
library;

import 'package:alphax/alphax.dart';

/// Placeholder transport used until Phase 0 selects a native implementation.
final class ExperimentalAlphaXNativeTransport implements AlphaXTransport {
  /// Creates a placeholder native transport.
  const ExperimentalAlphaXNativeTransport();

  @override
  Future<AlphaXResponse> send(AlphaXRequest request) {
    return Future<AlphaXResponse>.error(
      const AlphaXNativeTransportException(
        'The production native transport is not selected during Phase 0',
      ),
    );
  }

  @override
  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request) => Stream<AlphaXEvent>.error(
    const AlphaXNativeTransportException(
      'The production native transport is not selected during Phase 0',
    ),
  );

  @override
  Future<void> close() async {}
}
