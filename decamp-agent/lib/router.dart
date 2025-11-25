import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:decamp_agent/handlers/health_handler.dart';
import 'package:decamp_agent/handlers/websocket_handler.dart';

/// Creates the main router for the application
Router createRouter() {
  final router = Router();

  // Health check endpoint
  router.get('/health', healthHandler);

  // WebSocket endpoint for real-time communication
  router.get('/ws', websocketHandler);

  // Catch-all for 404s
  router.all('/<ignored|.*>', (Request request) {
    return Response.notFound('Route not found');
  });

  return router;
}
