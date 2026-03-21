import 'package:agent_core/agent_core.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

import 'package:e2e_tests/test_client.dart';
import 'package:e2e_tests/test_harness.dart';

void main() {
  Logger.root.level = Level.WARNING;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print('${record.level.name}: ${record.loggerName}: ${record.message}');
  });

  late TestServerHarness harness;
  late TestClient client;

  setUpAll(() async {
    harness = TestServerHarness();
    await harness.start();
    client = TestClient(harness.serverUrl);
  });

  tearDownAll(() async {
    await harness.stop();
  });

  group('Global sync', () {
    test('returns server node ID and version headers', () async {
      final conn = await client.connectGlobal();
      addTearDown(() => conn.close());

      expect(
        conn.responseHeaders[kNodeIdHeader.toLowerCase()],
        isNotEmpty,
      );
      expect(
        conn.responseHeaders[kServerVersionHeader.toLowerCase()],
        isNotEmpty,
      );
    });
  });

  group('Project sync', () {
    test('establishes multiplexed channels', () async {
      final conn = await client.connectProject('test-project');
      addTearDown(() => conn.close());

      expect(conn.channel, isNotNull);
      expect(conn.settingsChannel, isNotNull);
      expect(conn.secretsChannel, isNotNull);
    });

    test('responds to PING with PONG', () async {
      final conn = await client.connectProject('test-project-ping');
      addTearDown(() => conn.close());
      await conn.waitForReady();

      final pongFuture = conn.onCustomMessage
          .where((msg) => msg['type'] == 'PONG')
          .first
          .timeout(const Duration(seconds: 5));

      conn.sendCustomMessage({'type': 'PING', 'payload': 'test123'});

      final pong = await pongFuture;
      expect(pong['payload'], equals('test123'));
    });

    test('reconnects after disconnect', () async {
      const projectId = 'test-project-reconnect';

      // First connection — verify it works
      final conn1 = await client.connectProject(projectId);
      await conn1.waitForReady();
      final pong1 = conn1.onCustomMessage
          .where((msg) => msg['type'] == 'PONG')
          .first
          .timeout(const Duration(seconds: 5));
      conn1.sendCustomMessage({'type': 'PING', 'payload': 'first'});
      expect((await pong1)['payload'], equals('first'));
      await conn1.close();

      // Brief pause to let server process disconnect
      await Future.delayed(const Duration(milliseconds: 100));

      // Second connection — verify it also works
      final conn2 = await client.connectProject(projectId);
      addTearDown(() => conn2.close());
      await conn2.waitForReady();

      final pong2 = conn2.onCustomMessage
          .where((msg) => msg['type'] == 'PONG')
          .first
          .timeout(const Duration(seconds: 5));
      conn2.sendCustomMessage({'type': 'PING', 'payload': 'second'});
      expect((await pong2)['payload'], equals('second'));
    });
  });
}
