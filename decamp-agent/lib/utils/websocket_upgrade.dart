import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Performs a manual WebSocket upgrade, injecting [headers] into the
/// HTTP 101 Switching Protocols response.
///
/// This is necessary because shelf_web_socket's `webSocketHandler` does
/// not expose a way to add custom headers to the upgrade response.
Response upgradeWebSocket(
  Request request, {
  required Map<String, String> headers,
  required void Function(WebSocketChannel channel) onConnection,
}) {
  // Validate WebSocket upgrade request
  final connection = request.headers['Connection'];
  if (connection == null ||
      !connection
          .toLowerCase()
          .split(',')
          .map((t) => t.trim())
          .contains('upgrade')) {
    return Response.notFound('Not found');
  }
  final upgrade = request.headers['Upgrade'];
  if (upgrade == null || upgrade.toLowerCase() != 'websocket') {
    return Response.notFound('Not found');
  }
  final version = request.headers['Sec-WebSocket-Version'];
  if (version != '13') {
    return Response(400, body: 'Invalid Sec-WebSocket-Version');
  }
  final key = request.headers['Sec-WebSocket-Key'];
  if (key == null) {
    return Response(400, body: 'Missing Sec-WebSocket-Key');
  }
  if (!request.canHijack) {
    throw StateError('Request does not support hijacking');
  }

  request.hijack((channel) {
    final sink = utf8.encoder.startChunkedConversion(channel.sink)
      ..add('HTTP/1.1 101 Switching Protocols\r\n'
          'Upgrade: websocket\r\n'
          'Connection: Upgrade\r\n'
          'Sec-WebSocket-Accept: ${WebSocketChannel.signKey(key)}\r\n');

    // Inject custom headers
    for (final entry in headers.entries) {
      sink.add('${entry.key}: ${entry.value}\r\n');
    }

    sink.add('\r\n');

    final socket = channel.sink as Socket;
    final webSocket = WebSocket.fromUpgradedSocket(socket, serverSide: true);
    onConnection(IOWebSocketChannel(webSocket));
  });
}
