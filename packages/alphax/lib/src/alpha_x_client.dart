import 'alpha_x_body.dart';
import 'alpha_x_cancellation.dart';
import 'alpha_x_event.dart';
import 'alpha_x_errors.dart';
import 'alpha_x_headers.dart';
import 'alpha_x_request.dart';
import 'alpha_x_response.dart';
import 'alpha_x_timeout.dart';
import 'alpha_x_transport.dart';

/// Small client facade over a transport-independent [AlphaXTransport].
class AlphaXClient {
  /// Creates a client backed by [transport].
  const AlphaXClient({required this.transport});

  /// Transport used for requests.
  final AlphaXTransport transport;

  /// Sends an already constructed request.
  Future<AlphaXResponse> send(AlphaXRequest request) {
    final token = request.cancellationToken;
    if (token?.isCancelled ?? false) {
      return Future<AlphaXResponse>.error(
        AlphaXCancelledException(token?.reason ?? 'The operation was cancelled'),
      );
    }
    return transport.send(request);
  }

  /// Sends a GET request.
  Future<AlphaXResponse> get(
    Uri uri, {
    AlphaXHeaders headers = const AlphaXHeaders.empty(),
    AlphaXTimeout? timeout,
    AlphaXCancellationToken? cancellationToken,
    AlphaXPriority priority = AlphaXPriority.normal,
  }) => send(
    AlphaXRequest(
      method: 'GET',
      uri: uri,
      headers: headers,
      timeout: timeout,
      cancellationToken: cancellationToken,
      priority: priority,
    ),
  );

  /// Sends a POST request with an optional [body].
  Future<AlphaXResponse> post(
    Uri uri, {
    AlphaXHeaders headers = const AlphaXHeaders.empty(),
    AlphaXBody? body,
    AlphaXTimeout? timeout,
    AlphaXCancellationToken? cancellationToken,
    AlphaXPriority priority = AlphaXPriority.normal,
  }) => send(
    AlphaXRequest(
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
      timeout: timeout,
      cancellationToken: cancellationToken,
      priority: priority,
    ),
  );

  /// Sends a request as a streaming event sequence.
  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request) {
    final token = request.cancellationToken;
    if (token?.isCancelled ?? false) {
      return Stream<AlphaXEvent>.error(
        AlphaXCancelledException(token?.reason ?? 'The operation was cancelled'),
      );
    }
    return transport.sendStreaming(request);
  }

  /// Closes the underlying transport.
  Future<void> close() => transport.close();
}
