import 'alpha_x_event.dart';
import 'alpha_x_request.dart';
import 'alpha_x_response.dart';

/// Transport implementation consumed by [AlphaXClient].
abstract interface class AlphaXTransport {
  /// Sends [request] and buffers its response according to the implementation.
  Future<AlphaXResponse> send(AlphaXRequest request);

  /// Sends [request] and emits response metadata and bounded body chunks.
  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request);

  /// Releases transport resources and prevents new requests.
  Future<void> close();
}
