import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:fewshell_agent/handlers/health_handler.dart';
import 'package:fewshell_agent/controllers/sync_controller.dart';
import 'package:fewshell_agent/services/database_manager.dart';

/// Creates the main router for the application
Router createRouter(DatabaseManager dbManager) {
  final router = Router();

  // Health check endpoint
  router.get('/health', healthHandler);
  // Sync endpoint
  router.mount('/sync/', SyncController(dbManager).handler);

  // Catch-all for 404s
  router.all('/<ignored|.*>', (Request request) {
    return Response.notFound('Route not found');
  });

  return router;
}
