import 'dart:developer' as developer;
import 'dart:io';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:decamp_agent/router.dart';
import 'package:decamp_agent/services/database_manager.dart';

void main(List<String> args) async {
  // Get port from environment or use default
  final portEnv = Platform.environment['PORT'];
  final port = portEnv != null ? int.tryParse(portEnv) ?? 3123 : 3123;

  // Initialize DatabaseManager
  final dbManager = DatabaseManager('${Directory.current.path}/data');
  await dbManager.init();

  // Add middleware for logging and CORS
  final handler = const shelf.Pipeline()
      .addMiddleware(shelf.logRequests())
      .addMiddleware(_corsMiddleware())
      .addHandler(createRouter(dbManager).call);

  // Start the server
  final server = await shelf_io.serve(
    handler,
    InternetAddress.anyIPv4,
    port,
  );

  developer.log(
    '🚀 Decamp Agent server running on http://${server.address.host}:${server.port}',
    name: 'Server',
  );
}

/// CORS middleware for cross-origin requests
shelf.Middleware _corsMiddleware() {
  return shelf.createMiddleware(
    requestHandler: (shelf.Request request) {
      if (request.method == 'OPTIONS') {
        return shelf.Response.ok('', headers: _corsHeaders);
      }
      return null;
    },
    responseHandler: (shelf.Response response) {
      return response.change(headers: _corsHeaders);
    },
  );
}

final _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, PATCH, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
};
