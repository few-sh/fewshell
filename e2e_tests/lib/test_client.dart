import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:agent_core/agent_core.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Result of connecting to the global sync endpoint.
class GlobalSyncConnection {
  final WebSocketChannel channel;
  final Map<String, String> responseHeaders;

  GlobalSyncConnection({
    required this.channel,
    required this.responseHeaders,
  });

  Future<void> close() async {
    await channel.sink.close();
  }
}

/// Result of connecting to a project sync endpoint.
class ProjectSyncConnection {
  final MultiplexedWebSocketChannel channel;
  final WebSocketChannel settingsChannel;
  final WebSocketChannel secretsChannel;

  ProjectSyncConnection({
    required this.channel,
    required this.settingsChannel,
    required this.secretsChannel,
  });

  void sendCustomMessage(Map<String, dynamic> message) {
    channel.sendCustomMessage(message);
  }

  Stream<Map<String, dynamic>> get onCustomMessage => channel.onCustomMessage;

  /// Polls the server with PING until a PONG is received, confirming that
  /// the server has finished its async setup after the WebSocket upgrade.
  Future<void> waitForReady({
    Duration timeout = const Duration(seconds: 5),
    Duration interval = const Duration(milliseconds: 100),
  }) async {
    final completer = Completer<void>();

    final sub = onCustomMessage.listen((msg) {
      if (msg['type'] == 'PONG' && !completer.isCompleted) {
        completer.complete();
      }
    });

    final timer = Timer.periodic(interval, (_) {
      if (!completer.isCompleted) {
        sendCustomMessage({'type': 'PING', 'payload': 'ready'});
      }
    });

    // Send first PING immediately
    sendCustomMessage({'type': 'PING', 'payload': 'ready'});

    try {
      await completer.future.timeout(timeout);
    } finally {
      timer.cancel();
      await sub.cancel();
    }
  }

  Future<void> close() async {
    await channel.sink.close();
  }
}

/// Lightweight WebSocket client for E2E tests.
class TestClient {
  final Uri serverUrl;

  TestClient(this.serverUrl);

  /// Connects to `/sync/global` and captures HTTP upgrade response headers.
  ///
  /// Uses [HttpClient] to perform the WebSocket upgrade manually so we can
  /// read the custom headers (`X-Fewshell-Server-Node-Id`, etc.) that the
  /// server injects into the 101 response.
  Future<GlobalSyncConnection> connectGlobal() async {
    final uri = serverUrl.replace(path: '/sync/global');
    final client = HttpClient();

    final nonce = base64.encode(
      List.generate(16, (_) => Random().nextInt(256)),
    );

    final request = await client.openUrl('GET', uri);
    request.headers
      ..set(HttpHeaders.connectionHeader, 'Upgrade')
      ..set(HttpHeaders.upgradeHeader, 'websocket')
      ..set('Sec-WebSocket-Version', '13')
      ..set('Sec-WebSocket-Key', nonce);

    final response = await request.close();

    if (response.statusCode != HttpStatus.switchingProtocols) {
      throw Exception(
        'Global sync upgrade failed with status ${response.statusCode}',
      );
    }

    // Capture response headers (dart:io lowercases header names)
    final headers = <String, String>{};
    response.headers.forEach((name, values) {
      headers[name] = values.join(', ');
    });

    // Detach socket and upgrade to WebSocket
    final socket = await response.detachSocket();
    final ws = WebSocket.fromUpgradedSocket(socket, serverSide: false);
    final channel = IOWebSocketChannel(ws);

    return GlobalSyncConnection(
      channel: channel,
      responseHeaders: headers,
    );
  }

  /// Connects to `/sync/project/<projectId>` with multiplexed channels.
  Future<ProjectSyncConnection> connectProject(String projectId) async {
    final uri = serverUrl.replace(
      scheme: 'ws',
      path: '/sync/project/$projectId',
    );

    final channel = IOWebSocketChannel.connect(uri);
    await channel.ready;

    final multiplexed = MultiplexedWebSocketChannel(channel);
    final settingsChannel = multiplexed.fork('\u001E');
    final secretsChannel = multiplexed.fork('\u001D');

    return ProjectSyncConnection(
      channel: multiplexed,
      settingsChannel: settingsChannel,
      secretsChannel: secretsChannel,
    );
  }
}
