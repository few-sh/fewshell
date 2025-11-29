import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:crdt_sync/crdt_sync.dart';
import '../services/database_manager.dart';

class SyncController {
  final DatabaseManager dbManager;

  SyncController(this.dbManager);

  Handler get handler {
    return (Request request) {
      final path = request.url.path;

      if (path == 'global') {
        return webSocketHandler((WebSocketChannel channel, String? protocol) {
          CrdtSync.server(dbManager.globalDatabase.crdt, channel);
        })(request);
      } else if (path.startsWith('project/')) {
        final segments = path.split('/');
        if (segments.length >= 2) {
          final projectId = segments[1];
          return webSocketHandler(
              (WebSocketChannel channel, String? protocol) async {
            final db = await dbManager.getProjectDatabase(projectId);
            CrdtSync.server(db.crdt, channel);
          })(request);
        }
      }

      return Response.notFound('Not found');
    };
  }
}
