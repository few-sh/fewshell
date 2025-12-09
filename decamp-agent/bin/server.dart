import 'dart:developer' as developer;
import 'dart:ffi';
import 'dart:io';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:sqlite3/open.dart';
import 'package:decamp_agent/router.dart';
import 'package:decamp_agent/services/database_manager.dart';

void main(List<String> args) async {
  // Override sqlite3 open behavior to support libsqlite3.so.0
  open.overrideFor(OperatingSystem.linux, () {
    // List of common library names to try in order of likelihood
    const candidates = [
      'libsqlite3.so.0', // Standard runtime name on Debian/Ubuntu/Fedora
      'libsqlite3.so', // Development name / Alpine Linux
    ];

    for (final candidate in candidates) {
      try {
        return DynamicLibrary.open(candidate);
      } catch (_) {
        // Continue to next candidate
      }
    }

    // If all fail, throw to trigger the friendly error handling below
    throw Exception('Could not find libsqlite3.so.0 or libsqlite3.so');
  });

  // Get port from environment or use default
  final portEnv = Platform.environment['PORT'];
  final port = portEnv != null ? int.tryParse(portEnv) ?? 3123 : 3123;

  // Initialize DatabaseManager
  final dbManager = DatabaseManager('${Directory.current.path}/data');
  try {
    await dbManager.init();
  } catch (e) {
    if (e.toString().contains('libsqlite3') ||
        e.toString().contains('cannot open shared object file')) {
      print('\n🔴 Error: Missing runtime dependency\n');
      print(
          'The agent requires "libsqlite3" to function, but it was not found on your system.');
      print('Please install it using your package manager:\n');
      print('  Ubuntu/Debian: sudo apt-get install libsqlite3-0');
      print('  Fedora:        sudo dnf install libsqlite3');
      print('  Alpine:        apk add sqlite-libs\n');
      exit(1);
    }
    rethrow;
  }

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
