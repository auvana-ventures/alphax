import 'package:alphax_native/alphax_native.dart';

/// Connects to an explicitly supplied native WebSocket endpoint.
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    print('Usage: dart run example/websocket.dart ws://127.0.0.1:PORT/echo');
    return;
  }

  final connector = createAlphaXWebSocketConnector();
  final socket = await connector.connect(Uri.parse(args.single));
  try {
    final firstMessage = socket.messages.first;
    await socket.send(const AlphaXWebSocketMessage.text('hello from AlphaX'));
    final message = await firstMessage;
    switch (message) {
      case AlphaXWebSocketTextMessage(text: final text):
        print('received text: $text');
      case AlphaXWebSocketBinaryMessage(bytes: final bytes):
        print('received binary message: ${bytes.length} bytes');
    }
  } finally {
    await socket.close();
  }
}
