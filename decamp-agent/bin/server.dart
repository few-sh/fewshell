import 'dart:developer' as developer;
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:decamp_agent/router.dart';
import 'package:decamp_agent/services/database_manager.dart';

void main(List<String> args) async {
  try {
    print(
        'DEBUG: Agent starting (PID: ${pid}, Patched: ${Platform.environment['DECAMP_SQLITE_PATCHED']})');

    // Ensure we can load libsqlite3.so even if only libsqlite3.so.0 exists
    await _ensureRuntimeEnvironment(args);

    print('DEBUG: Continuing execution...');

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

    // Initialize FFI for sqflite explicitly
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Get port from environment or use default
    final portEnv = Platform.environment['PORT'];
    final port = portEnv != null ? int.tryParse(portEnv) ?? 3123 : 3123;

    // Initialize DatabaseManager
    print('DEBUG: Initializing DatabaseManager...');
    final dbManager = DatabaseManager('${Directory.current.path}/data');
    try {
      await dbManager.init();
      print('DEBUG: DatabaseManager initialized.');
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
    );
    print('DEBUG: Server serving...');
  } catch (e, st) {
    print('CRITICAL FAILURE: $e\n$st');
    exit(1);
  }
}

/// Checks if we need to polyfill libsqlite3.so and re-exec
Future<void> _ensureRuntimeEnvironment(List<String> args) async {
  if (!Platform.isLinux) return;

  // 1. Check if we can already load libsqlite3.so
  try {
    DynamicLibrary.open('libsqlite3.so');
    return; // All good
  } catch (_) {}

  // 2. Check if we've already patched the environment (avoid infinite loop)
  if (Platform.environment['DECAMP_SQLITE_PATCHED'] == 'true') {
    return;
  }

  // 3. Look for libsqlite3.so.0
  final commonPaths = [
    '/usr/lib/aarch64-linux-gnu',
    '/usr/lib/x86_64-linux-gnu',
    '/usr/lib',
    '/usr/lib64',
    '/lib',
    '/lib64',
  ];

  String? foundPath;
  for (final path in commonPaths) {
    final file = File('$path/libsqlite3.so.0');
    if (file.existsSync()) {
      foundPath = file.path;
      break;
    }
  }

  // If we found the runtime library but not the dev link...
  if (foundPath != null) {
    print('Found $foundPath, creating symlink shim...');

    // Create a temporary directory for our shim
    final tempDir = Directory.systemTemp.createTempSync('decamp_libs_');
    final linkPath = '${tempDir.path}/libsqlite3.so';

    // Create symlink: libsqlite3.so -> foundPath
    await Link(linkPath).create(foundPath);

    // Re-execute with updated LD_LIBRARY_PATH
    final currentLdPath = Platform.environment['LD_LIBRARY_PATH'] ?? '';
    final newLdPath = '$currentLdPath:${tempDir.path}';

    final newEnv = Map<String, String>.from(Platform.environment);
    newEnv['LD_LIBRARY_PATH'] = newLdPath;
    newEnv['DECAMP_SQLITE_PATCHED'] = 'true';

    // We use a detached process to replace ourselves (wrapper style)
    // stdin/out/err inheritance is important
    final process = await Process.start(
      Platform.executable,
      args,
      environment: newEnv,
      mode: ProcessStartMode.inheritStdio,
    );
    exit(await process.exitCode);
  }
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
