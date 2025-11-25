import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'session_handler.dart';

/// WebSocket handler for real-time client-server communication
///
/// Accepts WebSocket connections and delegates to SessionHandler for
/// agent loop execution.
final websocketHandler = webSocketHandler(_handleWebSocket);

void _handleWebSocket(WebSocketChannel webSocket) {
  developer.log('🔌 New WebSocket connection established', name: 'WebSocket');

  // Send welcome message
  webSocket.sink.add(
    jsonEncode({
      'type': 'connected',
      'message': 'Connected to Decamp Agent',
      'timestamp': DateTime.now().toIso8601String(),
    }),
  );

  // Create session handler and start listening
  final handler = SessionHandler(webSocket);
  handler.start();
}
