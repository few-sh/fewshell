import 'dart:developer' as developer;
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:crdt_sync/crdt_sync.dart';
import 'package:agent_core/agent_core.dart';
import '../services/database_manager.dart';

class SyncController {
  final DatabaseManager dbManager;

  SyncController(this.dbManager);

  Handler get handler {
    return (Request request) {
      final path = request.url.path;

      if (path == 'global') {
        return webSocketHandler((WebSocketChannel channel, String? protocol) {
          final multiplexed = MultiplexedWebSocketChannel(channel);
          _setupCustomMessageHandling(multiplexed, 'Global');
          CrdtSync.server(dbManager.globalDatabase.crdt, multiplexed);
        })(request);
      } else if (path.startsWith('project/')) {
        final segments = path.split('/');
        if (segments.length >= 2) {
          final projectId = segments[1];
          return webSocketHandler(
              (WebSocketChannel channel, String? protocol) async {
            final db = await dbManager.getProjectDatabase(projectId);
            final multiplexed = MultiplexedWebSocketChannel(channel);
            _setupCustomMessageHandling(multiplexed, 'Project');
            CrdtSync.server(db.crdt, multiplexed);
          })(request);
        }
      }

      return Response.notFound('Not found');
    };
  }

  void _setupCustomMessageHandling(
    MultiplexedWebSocketChannel channel,
    String context,
  ) {
    // The subscription will be automatically cancelled when the channel is closed
    // (connection dropped) as the stream will send a done event.
    channel.onCustomMessage.listen((msg) {
      developer.log('Server ($context): Received custom message: $msg');
      if (msg['type'] == 'PING') {
        channel.sendCustomMessage({
          'type': 'PONG',
          'payload': msg['payload'],
        });
      }
    });
  }
}
