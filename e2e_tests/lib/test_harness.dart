import 'dart:io';

import 'package:fewshell_agent/server_core.dart';
import 'package:fewshell_agent/services/notification_dispatcher.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Starts an in-process Fewshell agent server for testing.
///
/// Uses a temp directory for data, plain HTTP (no mTLS), and an
/// ephemeral port. Call [start] before tests and [stop] after.
class TestServerHarness {
  late final ServerCore core;
  late final HttpServer _server;
  late final Directory _tempDir;

  /// The base URL of the test server (e.g. `http://localhost:12345`).
  Uri get serverUrl => Uri.parse('http://localhost:${_server.port}');

  Future<void> start() async {
    sqfliteFfiInit();

    _tempDir = await Directory.systemTemp.createTemp('e2e_test_');

    final notificationDispatcher = NotificationDispatcher.fromEnvironment(
      getEnv: (_) => null,
    );

    core = await startServerCore(
      dataPath: _tempDir.path,
      notificationDispatcher: notificationDispatcher,
    );

    _server = await shelf_io.serve(core.handler, 'localhost', 0);
  }

  Future<void> stop() async {
    await _server.close(force: true);
    try {
      await _tempDir.delete(recursive: true);
    } catch (_) {
      // Best-effort cleanup
    }
  }
}
