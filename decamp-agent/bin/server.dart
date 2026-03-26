// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:convert';
import 'dart:ffi';

import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:agent_core/agent_core.dart';
import 'package:fewshell_agent/server_core.dart';
import 'package:fewshell_agent/services/notification_dispatcher.dart';
import 'package:fewshell_agent/certs.dart';
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

// FFI signature for umask(mode_t) -> mode_t
typedef UmaskC = Uint32 Function(Uint32);
typedef UmaskDart = int Function(int);

/// Sets the process umask, returns the previous value.
int _umask(int mask) {
  final dylib = DynamicLibrary.process();
  final umask = dylib.lookupFunction<UmaskC, UmaskDart>('umask');
  return umask(mask);
}

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
  if (args.contains('-v') || args.contains('--version')) {
    if (args.contains('--porcelain')) {
      // Print just the version number for machine parsing.
      print(packageVersion);
      exit(0);
    }
    print('Fewshell Server v$packageVersion');
    print('Copyright (c) 2026 Fewshot Corp. All Rights Reserved.');
    exit(0);
  }

  // Configure logging
  if (args.contains('--debug')) {
    Logger.root.level = Level.FINE;
  } else {
    Logger.root.level = Level.INFO;
  }

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
    // Load .env file if it exists (merges with Platform.environment)
    final env = dotenv.DotEnv(includePlatformEnvironment: true)..load();
    _log.info('Loaded environment variables from .env');

    // Initialize FFI for sqflite explicitly
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Parse LISTEN env var to determine socket type
    // Format: unix:///path/to/socket or tcp://host:port
    // Default: unix://$HOME/.fewshell/agent.sock
    final listenUri = env['LISTEN'] ?? '';
    final bool useTcp = listenUri.startsWith('tcp://');

    // Initialize NotificationDispatcher
    final notificationDispatcher = NotificationDispatcher.fromEnvironment(
      getEnv: (key) => env[key],
    );

    // Initialize all server services
    final dataPath = '${Directory.current.path}/data';
    final core = await startServerCore(
      dataPath: dataPath,
      notificationDispatcher: notificationDispatcher,
    );

    // Start the server
    await _startServer(listenUri, useTcp, core.handler);
  } catch (e, st) {
    _log.severe('CRITICAL FAILURE', e, st);
    exit(1);
  }
}

/// Binds and starts the HTTP server in either Unix socket or TCP (mTLS) mode.
Future<void> _startServer(
  String listenUri,
  bool useTcp,
  shelf.Handler handler,
) async {
  final HttpServer server;

  if (useTcp) {
    final tcpUri = Uri.parse(listenUri);
    final host = tcpUri.host.isEmpty ? '0.0.0.0' : tcpUri.host;
    final port = tcpUri.port > 0 ? tcpUri.port : 3123;

    _log.info('Initializing mTLS with embedded certificates');
    final securityContext = SecurityContext(withTrustedRoots: false)
      ..useCertificateChainBytes(utf8.encode(serverCert))
      ..usePrivateKeyBytes(utf8.encode(serverKey))
      ..setClientAuthoritiesBytes(utf8.encode(caCert))
      ..setTrustedCertificatesBytes(utf8.encode(caCert));

    _log.info('Starting server on tcp://$host:$port (mTLS)...');
    server = await HttpServer.bindSecure(
      InternetAddress.anyIPv6,
      port,
      securityContext,
      requestClientCertificate: true,
      v6Only: false,
    );
  } else {
    final socketPath = listenUri.startsWith('unix://')
        ? listenUri.substring('unix://'.length)
        : '${Platform.environment['HOME']}/.fewshell/agent.sock';

    // Ensure parent directory exists with owner-only permissions
    final socketDir = Directory(File(socketPath).parent.path);
    if (!socketDir.existsSync()) {
      socketDir.createSync(recursive: true);
    }
    Process.runSync('chmod', ['700', socketDir.path]);

    // Remove stale socket file
    final socketFile = File(socketPath);
    if (socketFile.existsSync()) {
      socketFile.deleteSync();
    }

    _log.info('Starting server on unix://$socketPath...');
    final address = InternetAddress(socketPath, type: InternetAddressType.unix);

    // Set restrictive umask so the socket is created with 0600 (owner-only)
    final previousUmask = _umask(0x3F); // 0077
    try {
      server = await HttpServer.bind(address, 0);
    } finally {
      _umask(previousUmask);
    }
  }

  server.listen(
    (HttpRequest request) async {
      try {
        final clientIp = request.connectionInfo?.remoteAddress.address;
        _log.info("REQ: [$clientIp] ${request.method} ${request.uri}");
        if (useTcp) {
          final cert = request.certificate;

          if (cert != null) {
            _log.info('  Client Cert Subject: ${cert.subject}');
            _log.info('  Client Cert Issuer:  ${cert.issuer}');
          } else {
            _log.warning(
              'Client connection from $clientIp - NO CERTIFICATE PRESENTED',
            );
            try {
              request.response
                ..statusCode = HttpStatus.unauthorized
                ..write('Unauthorized.');
              await request.response.close();
            } catch (e, st) {
              _log.severe('Error sending unauthorized response: $e', e, st);
            }
            return;
          }
        }

        await shelf_io.handleRequest(request, handler);
      } catch (e, st) {
        _log.severe('Error processing request: $e', e, st);
        try {
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..write('Internal Server Error');
          await request.response.close();
        } catch (e, st) {
          _log.severe('Error sending error response: $e', e, st);
        }
      }
    },
    onError: (e, st) {
      _log.severe('HttpServer stream error', e, st);
    },
    onDone: () => _log.severe('HttpServer stream closed. This is unexpected!'),
  );

  if (useTcp) {
    _log.info(
      '🚀 Decamp Agent server running on https://${server.address.host}:${server.port}',
    );
  } else {
    _log.info(
      '🚀 Decamp Agent server running on unix://${server.address.address}',
    );
  }
  _log.info('Server serving...');
}
