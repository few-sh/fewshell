import 'dart:developer' as developer;
import 'dart:ffi';
import 'dart:io';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:sqlite3/open.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:decamp_agent/router.dart';
import 'package:decamp_agent/services/database_manager.dart';

void main(List<String> args) async {
  try {
    // Ensure we can load libsqlite3.so via LD_LIBRARY_PATH (process-wide)
    // This is required because drift/sqlite_crdt uses background isolates,
    // and open.overrideFor is only effective in the current isolate.
    await _ensureRuntimeEnvironment(args);

    // Override sqlite3 open behavior to support libsqlite3.so.0 as a backup
    // for the main isolate (though the shim should have handled it).
    open.overrideFor(OperatingSystem.linux, () {
      try {
        return DynamicLibrary.open('libsqlite3.so');
      } catch (_) {
        return DynamicLibrary.open('libsqlite3.so.0');
      }
    });

    // Initialize FFI for sqflite explicitly
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

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
    );
    print('Server serving...');
  } catch (e, st) {
    print('CRITICAL FAILURE: $e\n$st');
    exit(1);
  }
}

/// Checks if we need to set LD_LIBRARY_PATH and re-exec
Future<void> _ensureRuntimeEnvironment(List<String> args) async {
  if (!Platform.isLinux) return;

  // 1. Check if we have a bundled libsqlite3.so in the same directory
  final bundledLib = File('${Directory.current.path}/libsqlite3.so');
  if (bundledLib.existsSync()) {
    final currentLdPath = Platform.environment['LD_LIBRARY_PATH'] ?? '';
    final newLdPath = '${Directory.current.path}:$currentLdPath';

    // Check if we are already patched with this path
    if (Platform.environment['DECAMP_SQLITE_PATCHED'] == 'true') {
      return;
    }

    // print('Using local libsqlite3.so (LD_LIBRARY_PATH augmented)');
    await _reExec(args, newLdPath);
    return;
  }

  // 2. Check if the system library is findable by standard loader
  // If we can open it now, we don't need to shim.
  // 2. Check if the library is findable by the DEFAULT name (libsqlite3.so)
  // which is what background isolates will try to load.
  // If we can open 'libsqlite3.so', we are good.
  try {
    DynamicLibrary.open('libsqlite3.so');
    return;
  } catch (_) {
    // If we can't open .so, we MUST shim, even if .so.0 exists.
  }

  // 3. Fallback: Check if we've already patched the environment (avoid infinite loop)
  if (Platform.environment['DECAMP_SQLITE_PATCHED'] == 'true') {
    return;
  }

  // 4. Look for libsqlite3.so.0 in specific system paths (for systems where loader misses it)
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

  // If we found the runtime library but the loader didn't pick it up...
  // We need to point LD_LIBRARY_PATH to its directory.
  // If we found the runtime library but the loader didn't pick it up...
  // We need to create a shim:
  // 1. Create a temp dir
  // 2. Symlink libsqlite3.so -> foundPath
  // 3. Add temp dir to LD_LIBRARY_PATH
  if (foundPath != null) {
    // print('Found system library at $foundPath, creating shim...');

    // Create a temporary directory for our shim
    final tempDir = Directory.systemTemp.createTempSync('decamp_libs_');
    final linkPath = '${tempDir.path}/libsqlite3.so';

    // Create symlink: libsqlite3.so -> foundPath
    await Link(linkPath).create(foundPath);

    // Re-execute with updated LD_LIBRARY_PATH
    final currentLdPath = Platform.environment['LD_LIBRARY_PATH'] ?? '';
    final newLdPath = '${tempDir.path}:$currentLdPath'; // Prepend shim dir

    await _reExec(args, newLdPath);
  }
}

Future<void> _reExec(List<String> args, String newLdPath) async {
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
