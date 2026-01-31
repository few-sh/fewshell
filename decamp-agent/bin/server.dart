import 'dart:io';
import 'dart:convert';
import 'dart:ffi';

import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fewshell_agent/router.dart';
import 'package:fewshell_agent/services/database_manager.dart';
import 'package:fewshell_agent/services/notification_dispatcher.dart';
import 'package:fewshell_agent/controllers/sync_controller.dart';
import 'package:fewshell_agent/certs.dart';
import 'package:agent_core/agent_core.dart';
import 'package:fewshell_agent/version.dart';

final _log = Logger('FewshellAgent');

// FFI signature for signal(int, void (*)(int))
typedef SignalFunc = Void Function(Int32);
typedef SignalC = Pointer<NativeFunction<SignalFunc>> Function(
  Int32,
  Pointer<NativeFunction<SignalFunc>>,
);
typedef SignalDart = Pointer<NativeFunction<SignalFunc>> Function(
  int,
  Pointer<NativeFunction<SignalFunc>>,
);

// Keep listener alive
NativeCallable<SignalFunc>? _sigPipeListener;

void _setupSigPipeHandler() {
  try {
    if (Platform.isMacOS || Platform.isLinux) {
      final dylib = DynamicLibrary.process();
      final signal = dylib.lookupFunction<SignalC, SignalDart>('signal');

      // SIGPIPE is 13 on both macOS and Linux (x86/ARM).
      const sigPipe = 13;

      // Create a native callable listener.
      // This creates a function pointer that, when called, posts a message to the
      // current isolate to run the callback.
      // 1. Being a specific function address, exec() will reset SIGPIPE to SIG_DFL in children.
      // 2. Being a listener, it handles the signal in the parent without crashing.
      _sigPipeListener = NativeCallable<SignalFunc>.listener((int signal) {
        // No-op: Just ignore the signal.
        // The callback runs on the main isolate event loop, so it's thread-safe,
        // but we avoid logging to keep it lightweight.
        // ignore: avoid_print
        print("Received SIGPIPE (signal $signal), ignoring.");
      });

      signal(sigPipe, _sigPipeListener!.nativeFunction);
      _log.info('Set SIGPIPE handler to NativeCallable listener');
    }
  } catch (e) {
    _log.warning('Failed to setup SIGPIPE handler: $e');
  }
}

void main(List<String> args) async {
  // Configure logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    final timestamp = record.time.toIso8601String();
    final loggerName = record.loggerName;
    final level = record.level.name;
    final message = '$timestamp [$loggerName] [$level] ${record.message}';
    if (record.level >= Level.SEVERE) {
      stderr.writeln(message);
      if (record.error != null) stderr.writeln(record.error);
      if (record.stackTrace != null) stderr.writeln(record.stackTrace);
    } else {
      stdout.writeln(message);
    }
  });

  const version = packageVersion;
  _log.info('Starting Fewshell Agent v$version');

  // Configure custom SIGPIPE handler.
  // This ensures that child processes (via exec) reset to SIG_DFL (terminate on broken pipe),
  // while the server process itself logs and ignores it.
  _setupSigPipeHandler();

  // Initialize SqliteLogger
  // ignore: unused_local_variable
  final sqliteLogger = SqliteLogger(
    dbPath: '${Directory.current.path}/data/logs.db',
    tableName: 'logs',
    appVersion: version,
    processId: pid.toString(),
  );

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

    // Initialize CrdtSettingsService
    final settingsService = CrdtSettingsService(
      () async => Directory('${Directory.current.path}/data'),
      (projectId) async =>
          Directory('${Directory.current.path}/data/projects/$projectId'),
    );
    await settingsService.init();

    // Initialize SecretsService
    final secretsService = SecretsService(
      (projectId) async => MemoryStorageImpl(),
    );

    // Initialize NotificationDispatcher
    final notificationDispatcher = NotificationDispatcher.fromEnvironment();

    // Initialize SyncController
    final syncController = await SyncController.create(
      dbManager,
      settingsService,
      secretsService,
      notificationDispatcher,
    );

    // Configure SecurityContext for mTLS
    _log.info('Initializing mTLS with embedded certificates');

    final securityContext = SecurityContext(withTrustedRoots: false)
      ..useCertificateChainBytes(utf8.encode(serverCert))
      ..usePrivateKeyBytes(utf8.encode(serverKey))
      ..setClientAuthoritiesBytes(utf8.encode(caCert))
      ..setTrustedCertificatesBytes(utf8.encode(caCert));
    _log.info(
      'SecurityContext initialized successfully ${securityContext.toString()}',
    );

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
        .addHandler(createRouter(syncController).call);

    // Start the server
    _log.info('Starting server on port $port...');

    // Use anyIPv6 with v6Only=false to listen on both IPv4 and IPv6
    // This ensures localhost works regardless of whether it resolves to 127.0.0.1 or ::1
    final server = await HttpServer.bindSecure(
      InternetAddress.anyIPv6,
      port,
      securityContext,
      requestClientCertificate: true,
      v6Only: false,
    );

    server.listen(
      (HttpRequest request) {
        try {
          final clientIp = request.connectionInfo?.remoteAddress.address;
          final cert = request.certificate;

          if (cert != null) {
            _log.info('Client connection from $clientIp');
            _log.info('  Client Cert Subject: ${cert.subject}');
            _log.info('  Client Cert Issuer:  ${cert.issuer}');
          } else {
            _log.warning(
              'Client connection from $clientIp - NO CERTIFICATE PRESENTED',
            );
            request.response
              ..statusCode = HttpStatus.unauthorized
              ..write('Unauthized.')
              ..close();
            return;
          }
        } catch (e) {
          _log.warning('Error logging client info: $e');
        }

        shelf_io.handleRequest(request, handler);
      },
      onError: (e) {
        _log.severe('HttpServer stream error', e);
      },
      onDone: () =>
          _log.severe('HttpServer stream closed. This is unexpected!'),
    );

    final scheme = 'https';
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
