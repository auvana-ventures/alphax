import 'dart:typed_data';

import 'alpha_x_capabilities.dart';
import 'alpha_x_cancellation.dart';
import 'alpha_x_errors.dart';

/// The lifecycle state of an AlphaX WebSocket session.
enum AlphaXWebSocketState {
  /// The connector is establishing a session. A session object is not returned
  /// while it is in this state.
  connecting,

  /// The session can send and receive messages.
  open,

  /// A local close has started and the session is waiting for termination.
  closing,

  /// The session is terminal and cannot be reopened.
  closed,
}

/// The source of a terminal WebSocket close.
enum AlphaXWebSocketCloseOrigin {
  /// The application or its cancellation token initiated close.
  local,

  /// The peer sent a close notification.
  peer,

  /// The provider reported an abnormal termination or terminal error.
  error,
}

/// Information available when an AlphaX WebSocket session terminates.
///
/// [code] and [reason] remain `null` when the provider did not report them.
/// AlphaX does not invent a normal close code for an abnormal termination.
final class AlphaXWebSocketCloseInfo {
  /// Creates terminal close information.
  const AlphaXWebSocketCloseInfo({
    required this.origin,
    this.code,
    this.reason,
  });

  /// Whether the close was initiated locally, by the peer, or by an error.
  final AlphaXWebSocketCloseOrigin origin;

  /// The provider-reported or locally requested close code, when available.
  final int? code;

  /// The provider-reported or locally requested close reason, when available.
  final String? reason;

  @override
  bool operator ==(Object other) =>
      other is AlphaXWebSocketCloseInfo &&
      other.origin == origin &&
      other.code == code &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(origin, code, reason);

  @override
  String toString() => 'AlphaXWebSocketCloseInfo(origin: $origin, code: $code)';
}

/// A complete text or binary message received from or sent to a WebSocket.
sealed class AlphaXWebSocketMessage {
  const AlphaXWebSocketMessage._();

  /// Creates a text message.
  const factory AlphaXWebSocketMessage.text(String text) = AlphaXWebSocketTextMessage;

  /// Creates a binary message. The input bytes are copied.
  factory AlphaXWebSocketMessage.binary(List<int> bytes) = AlphaXWebSocketBinaryMessage;
}

/// A WebSocket text message.
final class AlphaXWebSocketTextMessage extends AlphaXWebSocketMessage {
  /// Creates a text message.
  const AlphaXWebSocketTextMessage(this.text) : super._();

  /// UTF-16 Dart text represented by the message.
  final String text;

  @override
  bool operator ==(Object other) => other is AlphaXWebSocketTextMessage && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'AlphaXWebSocketTextMessage(${text.length} code units)';
}

/// A WebSocket binary message.
final class AlphaXWebSocketBinaryMessage extends AlphaXWebSocketMessage {
  /// Creates a binary message and copies [bytes].
  AlphaXWebSocketBinaryMessage(List<int> bytes) : _bytes = Uint8List.fromList(bytes), super._();

  final Uint8List _bytes;

  /// A defensive copy of the message bytes.
  ///
  /// The returned buffer can be mutated by the caller without changing the
  /// message retained by AlphaX.
  Uint8List get bytes => Uint8List.fromList(_bytes);

  @override
  bool operator ==(Object other) {
    if (other is! AlphaXWebSocketBinaryMessage || other._bytes.length != _bytes.length) {
      return false;
    }
    for (var index = 0; index < _bytes.length; index++) {
      if (other._bytes[index] != _bytes[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_bytes);

  @override
  String toString() => 'AlphaXWebSocketBinaryMessage(${_bytes.length} bytes)';
}

/// Capabilities and honest limitations of a WebSocket connector.
///
/// A capability describes the connector/provider, not a promise that every
/// server will accept a particular connection. `unknown` is used where a
/// provider cannot know a limit before connecting.
final class AlphaXWebSocketCapabilities {
  /// Creates a capability description.
  const AlphaXWebSocketCapabilities({
    required this.transportName,
    this.binaryMessages = AlphaXSupport.unknown,
    this.subprotocolNegotiation = AlphaXSupport.unknown,
    this.negotiatedSubprotocolReporting = AlphaXSupport.unknown,
    this.customHeaders = AlphaXSupport.unknown,
    this.manualPingPong = AlphaXSupport.unknown,
    this.receivePauseResume = AlphaXSupport.unknown,
    this.maximumMessageBytes,
  });

  /// Human-readable provider/connector name.
  final String transportName;

  /// Whether complete binary messages can be sent and received.
  final AlphaXSupport binaryMessages;

  /// Whether requested subprotocols can be offered to the peer.
  final AlphaXSupport subprotocolNegotiation;

  /// Whether the selected subprotocol is reported by the provider.
  final AlphaXSupport negotiatedSubprotocolReporting;

  /// Whether arbitrary connection request headers are supported.
  final AlphaXSupport customHeaders;

  /// Whether the caller can manually send or observe ping/pong control frames.
  final AlphaXSupport manualPingPong;

  /// Whether pausing the AlphaX receive stream can pause provider reads.
  final AlphaXSupport receivePauseResume;

  /// A provider-enforced maximum complete message size, when known.
  final int? maximumMessageBytes;
}

/// A transport-neutral WebSocket connector.
///
/// The connector owns no global session or reconnect policy. Each successful
/// [connect] returns one caller-owned session. The common contract intentionally
/// has no arbitrary headers because browser WebSocket implementations cannot
/// provide them consistently; connectors must fail rather than silently drop
/// security-sensitive connection metadata that is outside this API.
abstract interface class AlphaXWebSocketConnector {
  /// Capabilities and provider limitations for this connector.
  AlphaXWebSocketCapabilities get capabilities;

  /// Establishes one WebSocket session for [uri].
  ///
  /// [uri] must use `ws` or `wss`. [protocols] are offered for standard
  /// subprotocol negotiation; the result is exposed by
  /// [AlphaXWebSocketSession.negotiatedSubprotocol] and is never inferred from
  /// request order. [cancellationToken] applies while connecting and, for the
  /// built-in connectors, closes an open session if it is later cancelled.
  /// [connectTimeout] limits connection establishment only.
  Future<AlphaXWebSocketSession> connect(
    Uri uri, {
    Iterable<String> protocols = const <String>[],
    AlphaXCancellationToken? cancellationToken,
    Duration? connectTimeout,
  });
}

/// One full-duplex WebSocket session.
///
/// A session is returned in [AlphaXWebSocketState.open]. [messages] is a
/// single-subscription stream of complete text or binary messages. Consuming
/// that stream is the receive operation; its pause/resume and cancellation
/// behavior follows normal Dart stream semantics. [done] completes once with
/// terminal close information.
abstract interface class AlphaXWebSocketSession {
  /// Current lifecycle state.
  AlphaXWebSocketState get state;

  /// The provider-reported negotiated subprotocol, or `null` when none was
  /// selected or the provider did not report one.
  String? get negotiatedSubprotocol;

  /// Ordered complete messages received from the peer.
  ///
  /// The stream is single-subscription. Pausing its subscription is forwarded
  /// to the provider where that provider exposes a pausable stream. Cancelling
  /// the subscription stops receiving; it does not implicitly close the
  /// session, so the caller remains responsible for [close].
  Stream<AlphaXWebSocketMessage> get messages;

  /// Completes once when the session is terminal.
  Future<AlphaXWebSocketCloseInfo> get done;

  /// Sends one complete message in call order.
  ///
  /// Completion means that the provider accepted the message API call. It does
  /// not claim that the peer has acknowledged or flushed it to the network.
  /// Sending after the session starts closing fails with
  /// [AlphaXWebSocketClosedException]. No retry or replay is performed.
  Future<void> send(AlphaXWebSocketMessage message);

  /// Starts local close with an optional valid code and reason.
  ///
  /// Repeated calls are idempotent and return the same close operation. The
  /// public connector adapters accept code `1000` or application codes
  /// `3000..4999`, and a reason no longer than 123 UTF-8 bytes; a reason must
  /// be accompanied by a code. The requested local values are available from
  /// [done] if the provider does not report a different peer close first.
  Future<void> close({int? code, String? reason});
}

/// A normalized WebSocket connection or session failure.
class AlphaXWebSocketException extends AlphaXException {
  /// Creates a WebSocket failure while retaining the provider cause.
  const AlphaXWebSocketException(
    super.message, {
    super.cause,
    super.stackTrace,
  }) : super(kind: AlphaXErrorKind.connection);
}

/// A send or close operation was attempted after WebSocket termination began.
class AlphaXWebSocketClosedException extends AlphaXWebSocketException {
  /// Creates a predictable closed-session failure.
  const AlphaXWebSocketClosedException({
    String message = 'AlphaX WebSocket session is closed',
    Object? cause,
    StackTrace? stackTrace,
  }) : super(message, cause: cause, stackTrace: stackTrace);
}
