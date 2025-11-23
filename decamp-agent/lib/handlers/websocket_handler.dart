import 'dart:convert';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket handler for real-time client-server communication
final websocketHandler = webSocketHandler(_handleWebSocket);

void _handleWebSocket(WebSocketChannel webSocket) {
  print('🔌 New WebSocket connection established');

  // Send welcome message
  webSocket.sink.add(jsonEncode({
    'type': 'connected',
    'message': 'Connected to Decamp Agent',
    'timestamp': DateTime.now().toIso8601String(),
  }));

  // Listen to incoming messages
  webSocket.stream.listen(
    (dynamic message) {
      print('📨 Received: $message');

      try {
        final data = jsonDecode(message as String);
        _handleMessage(webSocket, data);
      } catch (e) {
        print('❌ Error parsing message: $e');
        webSocket.sink.add(jsonEncode({
          'type': 'error',
          'message': 'Invalid message format',
        }));
      }
    },
    onDone: () {
      print('🔌 WebSocket connection closed');
    },
    onError: (dynamic error) {
      print('❌ WebSocket error: $error');
    },
  );
}

void _handleMessage(WebSocketChannel webSocket, Map<String, dynamic> data) {
  final type = data['type'] as String?;

  switch (type) {
    case 'ping':
      // Respond to ping with pong
      webSocket.sink.add(jsonEncode({
        'type': 'pong',
        'timestamp': DateTime.now().toIso8601String(),
      }));
      break;

    case 'command':
      // Placeholder for future shell command execution
      webSocket.sink.add(jsonEncode({
        'type': 'command_response',
        'message': 'Command execution not yet implemented',
        'status': 'pending',
      }));
      break;

    default:
      webSocket.sink.add(jsonEncode({
        'type': 'error',
        'message': 'Unknown message type: $type',
      }));
  }
}
