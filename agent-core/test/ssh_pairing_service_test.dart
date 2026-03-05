@TestOn('vm')
@Tags(['integration'])
import 'dart:async';

import 'package:agent_core/agent_core.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

/// Integration test for [SshPairingService].
///
/// Requires the relay server running on localhost:8090.
void main() {
  const relayUrl = 'http://localhost:8090';
  const testKey =
      'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGtQRGwEMGaJNcGxIGJMfPMYhMIjbdMElANOqFBHrBfg test@dart';

  late SshPairingService service;

  setUp(() {
    service = SshPairingService(relayBaseUrl: relayUrl);
  });

  tearDown(() {
    service.dispose();
  });

  test('emits pairing codes, then connected event on GET', () async {
    final codes = <String>[];
    String? connectedIp;
    final codesCompleter = Completer<void>();
    final connectedCompleter = Completer<void>();

    service.events.listen((event) {
      switch (event) {
        case PairingCodeEvent(:final code):
          codes.add(code);
          if (codes.length == 2 && !codesCompleter.isCompleted) {
            codesCompleter.complete();
          }
        case PairingConnectedEvent(:final ipAddress):
          connectedIp = ipAddress;
          if (!connectedCompleter.isCompleted) {
            connectedCompleter.complete();
          }
        case PairingErrorEvent():
          break;
        case PairingReconnectingEvent():
          break;
      }
    });

    service.start(testKey);

    // Wait for two pairing codes (initial + one rotation).
    await codesCompleter.future.timeout(
      const Duration(seconds: 65),
      onTimeout: () => fail('Timed out waiting for 2 pairing codes'),
    );

    expect(codes.length, 2);
    expect(codes[0], isNot(equals(codes[1])),
        reason: 'Codes should rotate between events');

    // Old code should be invalid.
    final dio = Dio(BaseOptions(baseUrl: relayUrl));
    try {
      final staleResponse = await dio.get(
        '/pubkey',
        queryParameters: {'id': codes[0]},
        options: Options(validateStatus: (_) => true),
      );
      expect(staleResponse.statusCode, 404);

      // Current code should return the key and trigger connected event.
      final getResponse = await dio.get(
        '/pubkey',
        queryParameters: {'id': codes[1]},
        options: Options(headers: {'X-Forwarded-For': '10.0.0.1'}),
      );
      expect(getResponse.statusCode, 200);
      expect(getResponse.data['public_key'], testKey);
    } finally {
      dio.close();
    }

    // Wait for the connected event.
    await connectedCompleter.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => fail('Timed out waiting for connected event'),
    );

    expect(connectedIp, equals('10.0.0.1'));
    expect(service.isConnected, isTrue);
  }, timeout: Timeout(Duration(seconds: 75)));

  test('dispose stops the stream and cleans up', () async {
    final events = <SshPairingEvent>[];

    service.events.listen(events.add);
    service.start(testKey);

    // Wait for first code.
    await Future.delayed(const Duration(seconds: 2));
    expect(
        events.whereType<PairingCodeEvent>().length, greaterThanOrEqualTo(1));

    // Dispose should stop everything.
    service.dispose();

    final countAfterDispose = events.length;
    await Future.delayed(const Duration(seconds: 2));
    expect(events.length, countAfterDispose,
        reason: 'No events should arrive after dispose');
  }, timeout: Timeout(Duration(seconds: 15)));
}
