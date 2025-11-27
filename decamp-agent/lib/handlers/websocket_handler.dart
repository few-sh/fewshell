import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket handler for real-time client-server communication
final websocketHandler = webSocketHandler(_handleWebSocket);

void _handleWebSocket(WebSocketChannel webSocket, String? protocol) {
  developer.log('🔌 New WebSocket connection established', name: 'WebSocket');

  // Send welcome message
  webSocket.sink.add(
    jsonEncode({
      'type': 'connected',
      'message': 'Connected to Decamp Agent',
      'timestamp': DateTime.now().toIso8601String(),
    }),
  );

  // Listen to incoming messages
  webSocket.stream.listen(
    (dynamic message) {
      developer.log('📨 Received: $message', name: 'WebSocket');

      try {
        // Validate message is a string before parsing
        if (message is! String) {
          throw const FormatException(
            'Invalid message format: expected a string.',
          );
        }
        final data = jsonDecode(message);
        _handleMessage(webSocket, data as Map<String, dynamic>);
      } catch (e) {
        developer.log('❌ Error parsing message: $e', name: 'WebSocket');
        webSocket.sink.add(
          jsonEncode({
            'type': 'error',
            'message': 'Invalid message format',
          }),
        );
      }
    },
    onDone: () {
      developer.log('🔌 WebSocket connection closed', name: 'WebSocket');
    },
    onError: (dynamic error) {
      developer.log('❌ WebSocket error: $error', name: 'WebSocket');
    },
  );
}

void _handleMessage(WebSocketChannel webSocket, Map<String, dynamic> data) {
  final type = data['type'] as String?;

  switch (type) {
    case 'ping':
      // Respond to ping with pong
      webSocket.sink.add(
        jsonEncode({
          'type': 'pong',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      break;

    case 'command':
      // Placeholder for future shell command execution
      webSocket.sink.add(
        jsonEncode({
          'type': 'command_response',
          'message': 'Command execution not yet implemented',
          'status': 'pending',
        }),
      );
      break;

    default:
      webSocket.sink.add(
        jsonEncode({
          'type': 'error',
          'message': 'Unknown message type: $type',
        }),
      );
  }
}
