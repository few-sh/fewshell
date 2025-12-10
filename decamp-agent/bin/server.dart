import 'dart:io';

import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:decamp_agent/router.dart';
import 'package:decamp_agent/services/database_manager.dart';

final _log = Logger('DecampAgent');

void main(List<String> args) async {
  // Configure logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    final timestamp = record.time.toIso8601String();
    final level = record.level.name;
    final message = '$timestamp [$level] ${record.message}';
    if (record.level >= Level.SEVERE) {
      stderr.writeln(message);
      if (record.error != null) stderr.writeln(record.error);
      if (record.stackTrace != null) stderr.writeln(record.stackTrace);
    } else {
      stdout.writeln(message);
    }
  });

  try {
    // Initialize FFI for sqflite explicitly
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Get port from environment or use default
    final portEnv = Platform.environment['PORT'];
    final port = portEnv != null ? int.tryParse(portEnv) ?? 3123 : 3123;

    // Initialize DatabaseManager
    final dbManager = DatabaseManager('${Directory.current.path}/data');
    await dbManager.init();

    // Configure SecurityContext for mTLS if enabled
    SecurityContext? securityContext;
    if (Platform.environment['ENABLE_MTLS'] == 'true') {
      final certsPath = Platform.environment['CERTS_PATH'] ?? 'certs';
      _log.info('mTLS enabled. Loading certs from $certsPath');

      try {
        securityContext = SecurityContext(withTrustedRoots: true)
          ..useCertificateChain('$certsPath/server.crt')
          ..usePrivateKey('$certsPath/server.key')
          ..setClientAuthorities('$certsPath/ca.crt');
        _log.info('SecurityContext initialized successfully');
      } on FileSystemException catch (e) {
        _log.severe(
          'Failed to load mTLS certificates from "$certsPath". Please check if the files exist and are readable.',
          e,
        );
        rethrow;
      } catch (e, st) {
        _log.severe('Failed to initialize SecurityContext', e, st);
        rethrow;
      }
    }

    // Add middleware for logging and CORS
    final handler = const shelf.Pipeline()
        .addMiddleware(
          shelf.logRequests(
            logger: (msg, isError) {
              if (isError) {
                _log.severe(msg);
              } else {
                _log.info(msg);
              }
            },
          ),
        )
        .addMiddleware(_corsMiddleware())
        .addHandler(createRouter(dbManager).call);

    // Start the server
    _log.info('Starting server on port $port...');
    final server = await shelf_io.serve(
      handler,
      InternetAddress.anyIPv4,
      port,
      securityContext: securityContext,
    );

    final scheme = securityContext != null ? 'https' : 'http';
    _log.info(
      '🚀 Decamp Agent server running on $scheme://${server.address.host}:${server.port}',
    );
    _log.info('Server serving...');
  } catch (e, st) {
    _log.severe('CRITICAL FAILURE', e, st);
    exit(1);
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
