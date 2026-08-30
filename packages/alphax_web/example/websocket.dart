import 'package:alphax_web/alphax_web.dart';

/// Connects to an explicitly supplied browser WebSocket endpoint.
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    print('Usage: flutter run -d chrome -t example/websocket.dart');
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
