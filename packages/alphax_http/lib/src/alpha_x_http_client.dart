import 'dart:async';

import 'package:alphax/alphax.dart';
import 'package:http/http.dart' as http;

/// Adapts an existing [AlphaXClient] to the `package:http` [http.Client] API.
///
/// The adapter borrows [alphaXClient]. Calling [close] closes this adapter and
/// prevents new requests, but does not close the injected AlphaX client. The
/// caller that created the AlphaX client remains responsible for closing it.
/// Active response streams are allowed to finish after this adapter is closed.
///
/// The adapter preserves request and response streaming. Use AlphaX directly
/// when a request needs AlphaX-only protocol, timeout, cancellation, progress,
/// metrics, TLS, proxy, or native-file capabilities.
final class AlphaXHttpClient extends http.BaseClient {
  /// Creates a borrowed package:http view over [alphaXClient].
  AlphaXHttpClient(AlphaXClient alphaXClient) : _alphaXClient = alphaXClient;

  final AlphaXClient _alphaXClient;

  bool _closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed) {
      throw http.ClientException('AlphaXHttpClient is closed.', request.url);
    }

    try {
      final method = _methodFor(request);
      final cancellationToken = _cancellationTokenFor(request);

      // A completed Abortable trigger is delivered through a Future callback.
      // Give that callback a turn before finalizing or dispatching the request
      // so an already-completed trigger has the usual package:http meaning.
      if (cancellationToken != null) {
        await Future<void>.value();
      }

      final bodyStream = request.finalize();
      final alphaRequest = AlphaXRequest(
        method: method,
        uri: request.url,
        headers: AlphaXHeaders.fromEntries(request.headers.entries),
        body: AlphaXStreamBody(
          bodyStream,
          contentLength: request.contentLength,
          contentType: request.headers['content-type'],
        ),
        cancellationToken: cancellationToken,
        redirectPolicy: _redirectPolicyFor(request),
      );
      final response = await _alphaXClient.send(alphaRequest);
      final mappedResponseStream = _mapResponseStream(response.stream, request);
      final responseStream = cancellationToken != null && response.bufferedBodyBytes == null
          ? _mapAbortableResponseStream(mappedResponseStream, request, cancellationToken)
          : mappedResponseStream;

      return http.StreamedResponse(
        responseStream,
        response.statusCode,
        contentLength: response.body.contentLength,
        request: request,
        headers: response.headers.toMap(),
        isRedirect: response.isRedirect,
        // AlphaX deliberately does not expose a persistent-connection bit.
        // package:http requires a non-null bool, whose documented default is
        // true; this is an interface default, not an observed transport fact.
        persistentConnection: true,
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(_toClientException(error, request), stackTrace);
    }
  }

  /// Closes this adapter without taking ownership of the injected AlphaX client.
  @override
  void close() {
    _closed = true;
  }

  static HttpMethod _methodFor(http.BaseRequest request) {
    final method = HttpMethod.tryParse(request.method);
    if (method == null) {
      throw http.ClientException(
        'AlphaX does not support the HTTP method ${request.method}.',
        request.url,
      );
    }
    return method;
  }

  static AlphaXRedirectPolicy _redirectPolicyFor(http.BaseRequest request) {
    if (request.maxRedirects < 0) {
      throw http.ClientException('maxRedirects must not be negative.', request.url);
    }
    return AlphaXRedirectPolicy(
      mode: request.followRedirects ? AlphaXRedirectMode.follow : AlphaXRedirectMode.manual,
      maxRedirects: request.maxRedirects,
    );
  }

  static AlphaXCancellationToken? _cancellationTokenFor(http.BaseRequest request) {
    if (request case http.Abortable(:final abortTrigger?)) {
      final token = AlphaXCancellationToken();
      unawaited(
        abortTrigger.then<void>(
          (_) => token.cancel('The package:http request was aborted'),
          onError: (Object _, StackTrace __) =>
              token.cancel('The package:http request was aborted'),
        ),
      );
      return token;
    }
    return null;
  }

  static Stream<List<int>> _mapResponseStream(
    Stream<List<int>> stream,
    http.BaseRequest request,
  ) => stream.transform(
    StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleError: (Object error, StackTrace stackTrace, EventSink<List<int>> sink) {
        sink.addError(_toClientException(error, request), stackTrace);
      },
    ),
  );

  static Stream<List<int>> _mapAbortableResponseStream(
    Stream<List<int>> stream,
    http.BaseRequest request,
    AlphaXCancellationToken token,
  ) {
    late StreamController<List<int>> controller;
    StreamSubscription<List<int>>? subscription;
    var finished = false;

    Future<void> abort() async {
      if (finished || controller.isClosed) {
        return;
      }
      finished = true;
      final activeSubscription = subscription;
      if (activeSubscription != null) {
        unawaited(
          activeSubscription.cancel().then<void>(
            (_) {},
            onError: (Object _, StackTrace __) {},
          ),
        );
      }
      controller
        ..addError(http.RequestAbortedException(request.url))
        ..close();
    }

    controller = StreamController<List<int>>(
      sync: true,
      onListen: () {
        if (token.isCancelled) {
          unawaited(abort());
          return;
        }
        subscription = stream.listen(
          controller.add,
          onError: (Object error, StackTrace stackTrace) {
            if (!finished) {
              controller.addError(error, stackTrace);
            }
          },
          onDone: () {
            if (finished) {
              return;
            }
            finished = true;
            unawaited(controller.close());
          },
        );
        unawaited(token.whenCancelled.then<void>((_) => abort()));
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () {
        finished = true;
        return subscription?.cancel();
      },
    );
    return controller.stream;
  }

  static Object _toClientException(Object error, http.BaseRequest request) {
    if (error is http.ClientException) {
      return error;
    }
    if (error is AlphaXCancellationException) {
      return http.RequestAbortedException(request.url);
    }
    if (error is AlphaXException) {
      return http.ClientException(
        'AlphaX ${error.kind.name} error: ${error.message}',
        request.url,
      );
    }
    return http.ClientException('AlphaX request failed.', request.url);
  }
}
