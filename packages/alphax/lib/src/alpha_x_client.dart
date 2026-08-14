import 'alpha_x_body.dart';
import 'alpha_x_capabilities.dart';
import 'alpha_x_cancellation.dart';
import 'alpha_x_errors.dart';
import 'alpha_x_event.dart';
import 'alpha_x_file.dart';
import 'alpha_x_headers.dart';
import 'alpha_x_method.dart';
import 'alpha_x_middleware.dart';
import 'alpha_x_progress.dart';
import 'alpha_x_protocol.dart';
import 'alpha_x_request.dart';
import 'alpha_x_response.dart';
import 'alpha_x_redirect.dart';
import 'alpha_x_timeout.dart';
import 'alpha_x_transport.dart';

/// Transport-independent AlphaX client facade.
final class AlphaXClient {
  /// Creates a client backed by [transport] and an ordered middleware chain.
  AlphaXClient({
    required this.transport,
    Iterable<AlphaXMiddleware> middleware = const <AlphaXMiddleware>[],
  }) : middleware = List<AlphaXMiddleware>.unmodifiable(middleware);

  /// Transport used by this client.
  final AlphaXTransport transport;

  /// Middleware in entry order.
  final List<AlphaXMiddleware> middleware;

  bool _closed = false;
  Future<void>? _closeFuture;

  /// Capabilities of the configured transport.
  AlphaXCapabilities get capabilities => transport.capabilities;

  /// Whether [close] has been requested.
  bool get isClosed => _closed;

  /// Sends an already constructed request.
  Future<AlphaXResponse> send(AlphaXRequest request) async {
    _ensureOpen();
    request.cancellationToken?.throwIfCancelled();
    return _sendAt(0, request);
  }

  /// Sends a GET request.
  Future<AlphaXResponse> get(
    Uri uri, {
    AlphaXHeaders headers = const AlphaXHeaders.empty(),
    AlphaXBody body = const AlphaXEmptyBody(),
    AlphaXTimeouts? timeout,
    AlphaXCancellationToken? cancellationToken,
    AlphaXProtocolPreference protocolPreference = AlphaXProtocolPreference.auto,
    AlphaXRedirectPolicy redirectPolicy = const AlphaXRedirectPolicy(),
    AlphaXProgressCallback? onDownloadProgress,
  }) => _sendMethod(
    HttpMethod.get,
    uri,
    headers: headers,
    body: body,
    timeout: timeout,
    cancellationToken: cancellationToken,
    protocolPreference: protocolPreference,
    redirectPolicy: redirectPolicy,
    onDownloadProgress: onDownloadProgress,
  );

  /// Sends a POST request.
  Future<AlphaXResponse> post(
    Uri uri, {
    AlphaXHeaders headers = const AlphaXHeaders.empty(),
    AlphaXBody body = const AlphaXEmptyBody(),
    AlphaXTimeouts? timeout,
    AlphaXCancellationToken? cancellationToken,
    AlphaXProtocolPreference protocolPreference = AlphaXProtocolPreference.auto,
    AlphaXRedirectPolicy redirectPolicy = const AlphaXRedirectPolicy(),
    AlphaXProgressCallback? onUploadProgress,
    AlphaXProgressCallback? onDownloadProgress,
  }) => _sendMethod(
    HttpMethod.post,
    uri,
    headers: headers,
    body: body,
    timeout: timeout,
    cancellationToken: cancellationToken,
    protocolPreference: protocolPreference,
    redirectPolicy: redirectPolicy,
    onUploadProgress: onUploadProgress,
    onDownloadProgress: onDownloadProgress,
  );

  /// Sends a PUT request.
  Future<AlphaXResponse> put(
    Uri uri, {
    AlphaXHeaders headers = const AlphaXHeaders.empty(),
    AlphaXBody body = const AlphaXEmptyBody(),
    AlphaXTimeouts? timeout,
    AlphaXCancellationToken? cancellationToken,
    AlphaXProtocolPreference protocolPreference = AlphaXProtocolPreference.auto,
    AlphaXRedirectPolicy redirectPolicy = const AlphaXRedirectPolicy(),
    AlphaXProgressCallback? onUploadProgress,
    AlphaXProgressCallback? onDownloadProgress,
  }) => _sendMethod(
    HttpMethod.put,
    uri,
    headers: headers,
    body: body,
    timeout: timeout,
    cancellationToken: cancellationToken,
    protocolPreference: protocolPreference,
    redirectPolicy: redirectPolicy,
    onUploadProgress: onUploadProgress,
    onDownloadProgress: onDownloadProgress,
  );

  /// Sends a PATCH request.
  Future<AlphaXResponse> patch(
    Uri uri, {
    AlphaXHeaders headers = const AlphaXHeaders.empty(),
    AlphaXBody body = const AlphaXEmptyBody(),
    AlphaXTimeouts? timeout,
    AlphaXCancellationToken? cancellationToken,
    AlphaXProtocolPreference protocolPreference = AlphaXProtocolPreference.auto,
    AlphaXRedirectPolicy redirectPolicy = const AlphaXRedirectPolicy(),
    AlphaXProgressCallback? onUploadProgress,
    AlphaXProgressCallback? onDownloadProgress,
  }) => _sendMethod(
    HttpMethod.patch,
    uri,
    headers: headers,
    body: body,
    timeout: timeout,
    cancellationToken: cancellationToken,
    protocolPreference: protocolPreference,
    redirectPolicy: redirectPolicy,
    onUploadProgress: onUploadProgress,
    onDownloadProgress: onDownloadProgress,
  );

  /// Sends a DELETE request.
  Future<AlphaXResponse> delete(
    Uri uri, {
    AlphaXHeaders headers = const AlphaXHeaders.empty(),
    AlphaXBody body = const AlphaXEmptyBody(),
    AlphaXTimeouts? timeout,
    AlphaXCancellationToken? cancellationToken,
    AlphaXProtocolPreference protocolPreference = AlphaXProtocolPreference.auto,
    AlphaXRedirectPolicy redirectPolicy = const AlphaXRedirectPolicy(),
    AlphaXProgressCallback? onUploadProgress,
    AlphaXProgressCallback? onDownloadProgress,
  }) => _sendMethod(
    HttpMethod.delete,
    uri,
    headers: headers,
    body: body,
    timeout: timeout,
    cancellationToken: cancellationToken,
    protocolPreference: protocolPreference,
    redirectPolicy: redirectPolicy,
    onUploadProgress: onUploadProgress,
    onDownloadProgress: onDownloadProgress,
  );

  /// Sends a HEAD request.
  Future<AlphaXResponse> head(
    Uri uri, {
    AlphaXHeaders headers = const AlphaXHeaders.empty(),
    AlphaXTimeouts? timeout,
    AlphaXCancellationToken? cancellationToken,
    AlphaXProtocolPreference protocolPreference = AlphaXProtocolPreference.auto,
    AlphaXRedirectPolicy redirectPolicy = const AlphaXRedirectPolicy(),
  }) => _sendMethod(
    HttpMethod.head,
    uri,
    headers: headers,
    timeout: timeout,
    cancellationToken: cancellationToken,
    protocolPreference: protocolPreference,
    redirectPolicy: redirectPolicy,
  );

  /// Sends an OPTIONS request.
  Future<AlphaXResponse> options(
    Uri uri, {
    AlphaXHeaders headers = const AlphaXHeaders.empty(),
    AlphaXBody body = const AlphaXEmptyBody(),
    AlphaXTimeouts? timeout,
    AlphaXCancellationToken? cancellationToken,
    AlphaXProtocolPreference protocolPreference = AlphaXProtocolPreference.auto,
    AlphaXRedirectPolicy redirectPolicy = const AlphaXRedirectPolicy(),
  }) => _sendMethod(
    HttpMethod.options,
    uri,
    headers: headers,
    body: body,
    timeout: timeout,
    cancellationToken: cancellationToken,
    protocolPreference: protocolPreference,
    redirectPolicy: redirectPolicy,
  );

  /// Sends a request as a bounded event stream.
  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request) {
    _ensureOpen();
    try {
      request.cancellationToken?.throwIfCancelled();
    } on AlphaXException catch (error, stackTrace) {
      return Stream<AlphaXEvent>.error(error, stackTrace);
    }
    return _streamAt(0, request);
  }

  /// Downloads a response to [to] without exposing native file handles.
  Future<AlphaXTransferResult> download(
    Uri uri, {
    required AlphaXFileTarget to,
    AlphaXHeaders headers = const AlphaXHeaders.empty(),
    AlphaXTimeouts? timeout,
    AlphaXCancellationToken? cancellationToken,
    AlphaXProtocolPreference protocolPreference = AlphaXProtocolPreference.auto,
    AlphaXRedirectPolicy redirectPolicy = const AlphaXRedirectPolicy(),
    AlphaXProgressCallback? onDownloadProgress,
  }) {
    final request = AlphaXRequest(
      method: HttpMethod.get,
      uri: uri,
      headers: headers,
      timeout: timeout,
      cancellationToken: cancellationToken,
      protocolPreference: protocolPreference,
      redirectPolicy: redirectPolicy,
      onDownloadProgress: onDownloadProgress,
    );
    return _downloadAt(0, request, to);
  }

  /// Uploads [from] without exposing native file handles.
  Future<AlphaXTransferResult> upload(
    Uri uri, {
    required AlphaXFileSource from,
    HttpMethod method = HttpMethod.post,
    AlphaXHeaders headers = const AlphaXHeaders.empty(),
    AlphaXTimeouts? timeout,
    AlphaXCancellationToken? cancellationToken,
    AlphaXProtocolPreference protocolPreference = AlphaXProtocolPreference.auto,
    AlphaXRedirectPolicy redirectPolicy = const AlphaXRedirectPolicy(),
    AlphaXProgressCallback? onUploadProgress,
  }) {
    final request = AlphaXRequest(
      method: method,
      uri: uri,
      headers: headers,
      timeout: timeout,
      cancellationToken: cancellationToken,
      protocolPreference: protocolPreference,
      redirectPolicy: redirectPolicy,
      onUploadProgress: onUploadProgress,
    );
    return _uploadAt(0, request, from);
  }

  /// Closes the client and its reusable transport exactly once.
  Future<void> close() {
    final existing = _closeFuture;
    if (existing != null) {
      return existing;
    }
    _closed = true;
    return _closeFuture = Future<void>.sync(transport.close);
  }

  Future<AlphaXResponse> _sendMethod(
    HttpMethod method,
    Uri uri, {
    AlphaXHeaders headers = const AlphaXHeaders.empty(),
    AlphaXBody body = const AlphaXEmptyBody(),
    AlphaXTimeouts? timeout,
    AlphaXCancellationToken? cancellationToken,
    AlphaXProtocolPreference protocolPreference = AlphaXProtocolPreference.auto,
    AlphaXRedirectPolicy redirectPolicy = const AlphaXRedirectPolicy(),
    AlphaXProgressCallback? onUploadProgress,
    AlphaXProgressCallback? onDownloadProgress,
  }) => send(
    AlphaXRequest(
      method: method,
      uri: uri,
      headers: headers,
      body: body,
      timeout: timeout,
      cancellationToken: cancellationToken,
      protocolPreference: protocolPreference,
      redirectPolicy: redirectPolicy,
      onUploadProgress: onUploadProgress,
      onDownloadProgress: onDownloadProgress,
    ),
  );

  Future<AlphaXResponse> _sendAt(int index, AlphaXRequest request) {
    _ensureOpen();
    if (index == middleware.length) {
      return transport.send(request);
    }
    final current = middleware[index];
    return current.intercept(request, (nextRequest) => _sendAt(index + 1, nextRequest));
  }

  Stream<AlphaXEvent> _streamAt(int index, AlphaXRequest request) {
    _ensureOpen();
    if (index == middleware.length) {
      return transport.sendStreaming(request);
    }
    final current = middleware[index];
    return current.interceptStream(request, (nextRequest) => _streamAt(index + 1, nextRequest));
  }

  Future<AlphaXTransferResult> _downloadAt(
    int index,
    AlphaXRequest request,
    AlphaXFileTarget target,
  ) {
    _ensureOpen();
    request.cancellationToken?.throwIfCancelled();
    if (index == middleware.length) {
      return transport.download(request, target);
    }
    final current = middleware[index];
    return current.interceptDownload(
      request,
      target,
      (nextRequest, nextTarget) => _downloadAt(index + 1, nextRequest, nextTarget),
    );
  }

  Future<AlphaXTransferResult> _uploadAt(
    int index,
    AlphaXRequest request,
    AlphaXFileSource source,
  ) {
    _ensureOpen();
    request.cancellationToken?.throwIfCancelled();
    if (index == middleware.length) {
      return transport.upload(request, source);
    }
    final current = middleware[index];
    return current.interceptUpload(
      request,
      source,
      (nextRequest, nextSource) => _uploadAt(index + 1, nextRequest, nextSource),
    );
  }

  void _ensureOpen() {
    if (_closed) {
      throw const AlphaXClientClosedException();
    }
  }
}
