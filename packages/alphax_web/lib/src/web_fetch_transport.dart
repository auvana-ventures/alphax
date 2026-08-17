import 'dart:async';

import 'package:alphax/alphax.dart';
import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

/// AlphaX transport backed by the browser Fetch API.
///
/// Browser Fetch does not expose authoritative negotiated-protocol metadata,
/// platform TLS configuration, or explicit proxy controls to Dart. The
/// transport therefore reports protocol values as unknown and fails closed for
/// protocol requirements rather than inferring H1, H2, or H3.
final class WebFetchTransport extends AlphaXTransport {
  /// Creates a browser Fetch transport.
  WebFetchTransport({this.withCredentials = false}) : _client = BrowserClient() {
    _client.withCredentials = withCredentials;
  }

  /// Whether browser-managed credentials may be sent cross-origin.
  final bool withCredentials;
  final BrowserClient _client;
  bool _closed = false;

  @override
  AlphaXCapabilities get capabilities => const AlphaXCapabilities(
    transportName: 'Browser Fetch',
    http10: AlphaXSupport.unsupported,
    http11: AlphaXSupport.unknown,
    http2: AlphaXSupport.unknown,
    http3: AlphaXSupport.unknown,
    streamingUpload: AlphaXSupport.unsupported,
    streamingDownload: AlphaXSupport.supported,
    nativeFileUpload: AlphaXSupport.unsupported,
    nativeFileDownload: AlphaXSupport.unsupported,
    uploadProgress: AlphaXSupport.unsupported,
    downloadProgress: AlphaXSupport.unknown,
    proxyConfiguration: AlphaXSupport.unknown,
    tlsDefaultTrust: AlphaXSupport.supported,
    customTrustAnchors: AlphaXSupport.unsupported,
    certificatePinning: AlphaXSupport.unsupported,
    mutualTls: AlphaXSupport.unsupported,
    systemProxy: AlphaXSupport.unknown,
    directConnectionPolicy: AlphaXSupport.unsupported,
    explicitHttpProxy: AlphaXSupport.unsupported,
    explicitHttpsProxy: AlphaXSupport.unsupported,
    proxyAuthentication: AlphaXSupport.unsupported,
    protocolRequirement: AlphaXSupport.unsupported,
    negotiatedProtocolReporting: AlphaXSupport.unsupported,
  );

  @override
  Future<AlphaXResponse> send(AlphaXRequest request) async {
    _ensureOpen();
    request.cancellationToken?.throwIfCancelled();
    final requirement = request.protocolRequirement;
    if (requirement != null) {
      throw AlphaXProtocolRequirementException(
        requiredProtocol: requirement,
        actualProtocol: AlphaXProtocol.unknown,
        message: 'Browser Fetch cannot authoritatively report the negotiated protocol',
      );
    }

    final abortState = _AbortState();
    final stopwatch = Stopwatch()..start();
    final browserRequest = await _toBrowserRequest(request, abortState);
    try {
      final response = await _sendWithTimeout(browserRequest);
      return _toAlphaXResponse(response, request, stopwatch);
    } catch (error, stackTrace) {
      if (request.cancellationToken?.isCancelled ?? false) {
        throw AlphaXCancelledException(
          request.cancellationToken?.reason ?? 'The operation was cancelled',
          cause: error,
          stackTrace: stackTrace,
        );
      }
      if (abortState.timedOut) {
        throw AlphaXTimeoutException(
          'The browser request exceeded its overall timeout',
          timeoutKind: AlphaXTimeoutKind.overall,
          cause: error,
          stackTrace: stackTrace,
        );
      }
      if (error is AlphaXException) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      throw AlphaXTransportException(
        'Browser Fetch failed: $error',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request) async* {
    final response = await send(request);
    yield AlphaXResponseStarted(
      statusCode: response.statusCode,
      headers: response.headers,
      protocol: response.protocol,
      requestedProtocol: response.requestedProtocol,
      requiredProtocol: response.requiredProtocol,
      protocolFallback: response.protocolFallback,
      redirects: response.redirects,
    );
    var bytesReceived = 0;
    await for (final chunk in response.body.stream) {
      bytesReceived += chunk.length;
      yield AlphaXResponseChunk(chunk);
    }
    yield AlphaXResponseCompleted(
      metrics: await response.completionMetrics,
      bytesReceived: bytesReceived,
      requestedProtocol: response.requestedProtocol,
      requiredProtocol: response.requiredProtocol,
      protocolFallback: response.protocolFallback,
    );
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _client.close();
  }

  Future<http.StreamedResponse> _sendWithTimeout(_BrowserRequest request) => _client.send(request);

  Future<_BrowserRequest> _toBrowserRequest(AlphaXRequest request, _AbortState abortState) async {
    final abortTrigger = <Future<void>>[];
    final cancellation = request.cancellationToken?.whenCancelled;
    if (cancellation != null) {
      abortTrigger.add(cancellation);
    }
    final timeout = request.timeouts.overall;
    if (timeout != null) {
      abortTrigger.add(
        Future<void>.delayed(timeout, () {
          abortState.timedOut = true;
        }),
      );
    }
    final trigger = abortTrigger.isEmpty ? null : Future.any<void>(abortTrigger);
    final browserRequest = _BrowserRequest(request.method.value, request.uri, trigger);
    browserRequest.followRedirects = request.redirectPolicy.mode == AlphaXRedirectMode.follow;
    browserRequest.maxRedirects = request.redirectPolicy.maxRedirects;
    for (final entry in request.headers.entries) {
      browserRequest.headers[entry.key] = request.headers.values(entry.key).join(', ');
    }
    final bodyBytes = <int>[];
    await for (final chunk in request.body.openStream()) {
      request.cancellationToken?.throwIfCancelled();
      bodyBytes.addAll(chunk);
    }
    browserRequest.bodyBytes = bodyBytes;
    if (!browserRequest.headers.containsKey('content-type') && request.body.contentType != null) {
      browserRequest.headers['content-type'] = request.body.contentType!;
    }
    return browserRequest;
  }

  AlphaXResponse _toAlphaXResponse(
    http.StreamedResponse response,
    AlphaXRequest request,
    Stopwatch stopwatch,
  ) {
    final completion = Completer<AlphaXRequestMetrics>();
    final stream = _trackBody(response.stream, stopwatch, completion);
    return AlphaXResponse(
      statusCode: response.statusCode,
      headers: AlphaXHeaders.fromEntries(response.headers.entries),
      body: AlphaXResponseBody.stream(stream, contentLength: response.contentLength),
      protocol: AlphaXProtocol.unknown,
      requestedProtocol: request.protocolPreference,
      requiredProtocol: request.protocolRequirement,
      metrics: const AlphaXRequestMetrics(),
      completionMetrics: completion.future,
    );
  }

  Stream<List<int>> _trackBody(
    Stream<List<int>> body,
    Stopwatch stopwatch,
    Completer<AlphaXRequestMetrics> completion,
  ) async* {
    var bytesReceived = 0;
    try {
      await for (final chunk in body) {
        bytesReceived += chunk.length;
        yield chunk;
      }
      if (!completion.isCompleted) {
        completion.complete(
          AlphaXRequestMetrics(
            downloadedBytes: bytesReceived,
            totalDuration: stopwatch.elapsed,
          ),
        );
      }
    } catch (error, stackTrace) {
      if (!completion.isCompleted) {
        completion.completeError(error, stackTrace);
      }
      rethrow;
    }
  }

  void _ensureOpen() {
    if (_closed) {
      throw const AlphaXClientClosedException();
    }
  }
}

final class _AbortState {
  bool timedOut = false;
}

final class _BrowserRequest extends http.Request implements http.Abortable {
  _BrowserRequest(super.method, super.url, this.abortTrigger);

  @override
  final Future<void>? abortTrigger;
}
