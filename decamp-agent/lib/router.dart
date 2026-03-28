import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:fewshell_agent/handlers/health_handler.dart';
import 'package:fewshell_agent/controllers/session_controller.dart';

/// Creates the main router for the application
Router createRouter(SessionController sessionController) {
  final router = Router();

  // Health check endpoint
  router.get('/health', healthHandler);
  // Sync endpoint
  router.mount('/sync/', sessionController.handler);

  // Catch-all for 404s
  router.all('/<ignored|.*>', (Request request) {
    return Response.notFound('Route not found');
  });

  return router;
}
