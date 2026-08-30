import 'dart:async';
import 'dart:convert';

import 'package:alphax/websocket.dart';
import 'package:web_socket/web_socket.dart' as provider;

/// Creates a connector backed by the maintained Dart native WebSocket API.
///
/// The connector uses `package:web_socket`'s Dart IO implementation on native
/// targets. It is separate from the HTTP transport selected by
/// `createAlphaXTransport()` because WebSockets have a different lifecycle.
AlphaXWebSocketConnector createAlphaXWebSocketConnector() => _AlphaXWebSocketConnector();

final class _AlphaXWebSocketConnector implements AlphaXWebSocketConnector {
  static const _capabilities = AlphaXWebSocketCapabilities(
    transportName: 'package:web_socket (Dart IO)',
    binaryMessages: AlphaXSupport.supported,
    subprotocolNegotiation: AlphaXSupport.supported,
    negotiatedSubprotocolReporting: AlphaXSupport.supported,
    customHeaders: AlphaXSupport.unsupported,
    manualPingPong: AlphaXSupport.unsupported,
    receivePauseResume: AlphaXSupport.unsupported,
  );

  @override
  AlphaXWebSocketCapabilities get capabilities => _capabilities;

  @override
  Future<AlphaXWebSocketSession> connect(
    Uri uri, {
    Iterable<String> protocols = const <String>[],
    AlphaXCancellationToken? cancellationToken,
    Duration? connectTimeout,
  }) async {
    _validateUri(uri);
    _validateConnectTimeout(connectTimeout);
    cancellationToken?.throwIfCancelled();

    final requestedProtocols = List<String>.unmodifiable(protocols);
    late final Future<provider.WebSocket> connection;

    try {
      connection = provider.WebSocket.connect(
        uri,
        protocols: requestedProtocols,
      );
      final socket = await _awaitConnection(
        connection,
        cancellationToken: cancellationToken,
        connectTimeout: connectTimeout,
      );
      try {
        cancellationToken?.throwIfCancelled();
      } catch (error, stackTrace) {
        _closeWhenReady(Future<provider.WebSocket>.value(socket));
        Error.throwWithStackTrace(error, stackTrace);
      }
      return _AlphaXWebSocketSession(
        socket,
        cancellationToken: cancellationToken,
      );
    } catch (error, stackTrace) {
      if (error is AlphaXException) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      final normalized = AlphaXWebSocketException(
        'WebSocket connection failed',
        cause: error,
        stackTrace: stackTrace,
      );
      Error.throwWithStackTrace(normalized, stackTrace);
    }
  }
}

Future<provider.WebSocket> _awaitConnection(
  Future<provider.WebSocket> connection, {
  required AlphaXCancellationToken? cancellationToken,
  required Duration? connectTimeout,
}) async {
  final alternatives = <Future<provider.WebSocket>>[connection];
  if (cancellationToken != null) {
    alternatives.add(
      cancellationToken.whenCancelled.then<provider.WebSocket>((_) {
        throw AlphaXCancelledException(
          cancellationToken.reason ?? 'The WebSocket connection was cancelled',
          reason: cancellationToken.cancellationReason,
        );
      }),
    );
  }
  if (connectTimeout != null) {
    alternatives.add(
      Future<void>.delayed(connectTimeout).then<provider.WebSocket>((_) {
        throw AlphaXTimeoutException(
          'The WebSocket connection exceeded its connect timeout',
          timeoutKind: AlphaXTimeoutKind.connect,
        );
      }),
    );
  }

  try {
    return await Future.any(alternatives);
  } catch (error) {
    if (error is AlphaXCancellationException || error is AlphaXTimeoutException) {
      _closeWhenReady(connection);
    }
    rethrow;
  }
}

void _closeWhenReady(Future<provider.WebSocket> connection) {
  unawaited(
    connection.then<void>(
      (socket) async {
        try {
          await socket.close();
        } catch (_) {
          // The connection may have failed or closed before the late cleanup.
        }
      },
      onError: (Object _, StackTrace __) {},
    ),
  );
}

void _validateUri(Uri uri) {
  if (!uri.isScheme('ws') && !uri.isScheme('wss')) {
    throw ArgumentError.value(uri, 'uri', 'Only ws: and wss: URIs are supported');
  }
}

void _validateConnectTimeout(Duration? timeout) {
  if (timeout != null && timeout <= Duration.zero) {
    throw ArgumentError.value(timeout, 'connectTimeout', 'Must be positive');
  }
}

final class _AlphaXWebSocketSession implements AlphaXWebSocketSession {
  _AlphaXWebSocketSession(
    this._socket, {
    required AlphaXCancellationToken? cancellationToken,
  }) {
    _messagesController = StreamController<AlphaXWebSocketMessage>(
      onListen: _listenToProvider,
      onPause: _pauseProvider,
      onResume: _resumeProvider,
      onCancel: _cancelProviderSubscription,
    );
    if (cancellationToken != null) {
      unawaited(
        cancellationToken.whenCancelled.then<void>((_) {
          if (_state == AlphaXWebSocketState.open) {
            unawaited(_closeAfterCancellation());
          }
        }),
      );
    }
  }

  Future<void> _closeAfterCancellation() async {
    try {
      await close();
    } catch (_) {
      // Cancellation remains terminal even if the provider reports a close
      // race; the original provider failure is available through diagnostics.
    }
  }

  final provider.WebSocket _socket;
  late final StreamController<AlphaXWebSocketMessage> _messagesController;
  final Completer<AlphaXWebSocketCloseInfo> _doneCompleter = Completer<AlphaXWebSocketCloseInfo>();
  StreamSubscription<provider.WebSocketEvent>? _providerSubscription;
  AlphaXWebSocketState _state = AlphaXWebSocketState.open;
  Future<void>? _closeFuture;
  int? _requestedCloseCode;
  String? _requestedCloseReason;

  @override
  AlphaXWebSocketState get state => _state;

  @override
  String? get negotiatedSubprotocol => _socket.protocol.isEmpty ? null : _socket.protocol;

  @override
  Stream<AlphaXWebSocketMessage> get messages => _messagesController.stream;

  @override
  Future<AlphaXWebSocketCloseInfo> get done => _doneCompleter.future;

  void _listenToProvider() {
    if (_state == AlphaXWebSocketState.closed || _providerSubscription != null) {
      return;
    }
    _providerSubscription = _socket.events.listen(
      _handleProviderEvent,
      onError: _handleProviderError,
      onDone: _handleProviderDone,
    );
  }

  void _pauseProvider() {
    _providerSubscription?.pause();
  }

  void _resumeProvider() {
    _providerSubscription?.resume();
  }

  Future<void> _cancelProviderSubscription() async {
    final subscription = _providerSubscription;
    _providerSubscription = null;
    await subscription?.cancel();
  }

  void _handleProviderEvent(provider.WebSocketEvent event) {
    if (_state == AlphaXWebSocketState.closed) {
      return;
    }
    switch (event) {
      case provider.TextDataReceived(text: final text):
        if (_state == AlphaXWebSocketState.open) {
          _messagesController.add(AlphaXWebSocketMessage.text(text));
        }
      case provider.BinaryDataReceived(data: final data):
        if (_state == AlphaXWebSocketState.open) {
          _messagesController.add(AlphaXWebSocketMessage.binary(data));
        }
      case provider.CloseReceived(code: final code, reason: final reason):
        final closeInfo = AlphaXWebSocketCloseInfo(
          origin: code == null || code == 1006
              ? AlphaXWebSocketCloseOrigin.error
              : AlphaXWebSocketCloseOrigin.peer,
          code: code,
          reason: reason,
        );
        if (closeInfo.origin == AlphaXWebSocketCloseOrigin.error) {
          final error = AlphaXWebSocketException(
            'WebSocket closed abnormally',
            cause: closeInfo,
          );
          _terminateWithError(error, error.stackTrace ?? StackTrace.current, closeInfo: closeInfo);
        } else {
          _finish(closeInfo);
        }
    }
  }

  void _handleProviderError(Object error, StackTrace stackTrace) {
    if (_state == AlphaXWebSocketState.closed) {
      return;
    }
    final normalized = _normalizeError(error, stackTrace, 'WebSocket receive failed');
    _terminateWithError(normalized, normalized.stackTrace ?? stackTrace);
  }

  void _handleProviderDone() {
    if (_state == AlphaXWebSocketState.closed) {
      return;
    }
    if (_state == AlphaXWebSocketState.closing) {
      _finish(
        AlphaXWebSocketCloseInfo(
          origin: AlphaXWebSocketCloseOrigin.local,
          code: _requestedCloseCode,
          reason: _requestedCloseReason,
        ),
      );
      return;
    }
    final error = const AlphaXWebSocketException(
      'WebSocket provider ended without close information',
    );
    _terminateWithError(error, error.stackTrace ?? StackTrace.current);
  }

  @override
  Future<void> send(AlphaXWebSocketMessage message) async {
    if (_state != AlphaXWebSocketState.open) {
      throw const AlphaXWebSocketClosedException();
    }
    try {
      switch (message) {
        case AlphaXWebSocketTextMessage(text: final text):
          _socket.sendText(text);
        case AlphaXWebSocketBinaryMessage(bytes: final bytes):
          _socket.sendBytes(bytes);
      }
    } on provider.WebSocketConnectionClosed catch (error, stackTrace) {
      final normalized = AlphaXWebSocketClosedException(
        message: 'The WebSocket provider has closed the session',
        cause: error,
        stackTrace: stackTrace,
      );
      _terminateWithError(normalized, stackTrace);
      Error.throwWithStackTrace(normalized, stackTrace);
    } catch (error, stackTrace) {
      final normalized = _normalizeError(error, stackTrace, 'WebSocket send failed');
      _terminateWithError(normalized, stackTrace);
      Error.throwWithStackTrace(normalized, stackTrace);
    }
  }

  @override
  Future<void> close({int? code, String? reason}) {
    _validateCloseArguments(code, reason);
    final existing = _closeFuture;
    if (existing != null) {
      return existing;
    }
    if (_state == AlphaXWebSocketState.closed) {
      return Future<void>.value();
    }

    _state = AlphaXWebSocketState.closing;
    _requestedCloseCode = code;
    _requestedCloseReason = reason;
    return _closeFuture = _closeProvider(code, reason);
  }

  Future<void> _closeProvider(int? code, String? reason) async {
    try {
      await _socket.close(code, reason);
    } on provider.WebSocketConnectionClosed {
      // Close is idempotent at the AlphaX session boundary even if the peer
      // won the race before the provider observed our close call.
    } catch (error, stackTrace) {
      final normalized = _normalizeError(error, stackTrace, 'WebSocket close failed');
      _terminateWithError(normalized, stackTrace);
      Error.throwWithStackTrace(normalized, stackTrace);
    }
    _finish(
      AlphaXWebSocketCloseInfo(
        origin: AlphaXWebSocketCloseOrigin.local,
        code: code,
        reason: reason,
      ),
    );
  }

  void _terminateWithError(
    AlphaXWebSocketException error,
    StackTrace stackTrace, {
    AlphaXWebSocketCloseInfo? closeInfo,
  }) {
    if (_messagesController.hasListener && !_messagesController.isClosed) {
      _messagesController.addError(error, stackTrace);
    }
    _finish(closeInfo ?? const AlphaXWebSocketCloseInfo(origin: AlphaXWebSocketCloseOrigin.error));
  }

  void _finish(AlphaXWebSocketCloseInfo info) {
    if (_state == AlphaXWebSocketState.closed) {
      return;
    }
    _state = AlphaXWebSocketState.closed;
    final subscription = _providerSubscription;
    _providerSubscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete(info);
    }
    if (!_messagesController.isClosed) {
      unawaited(_messagesController.close());
    }
  }
}

void _validateCloseArguments(int? code, String? reason) {
  if (code != null && code != 1000 && (code < 3000 || code > 4999)) {
    throw ArgumentError.value(
      code,
      'code',
      'Close code must be 1000 or in the range 3000-4999',
    );
  }
  if (reason != null && code == null) {
    throw ArgumentError('A close reason requires a close code');
  }
  if (reason != null && utf8.encode(reason).length > 123) {
    throw ArgumentError.value(
      reason,
      'reason',
      'Close reason must be at most 123 UTF-8 bytes',
    );
  }
}

AlphaXWebSocketException _normalizeError(
  Object error,
  StackTrace stackTrace,
  String message,
) {
  if (error is AlphaXWebSocketException) {
    return error;
  }
  return AlphaXWebSocketException(message, cause: error, stackTrace: stackTrace);
}
