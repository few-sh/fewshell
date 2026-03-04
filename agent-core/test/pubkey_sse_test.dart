@TestOn('vm')
@Tags(['integration'])
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:test/test.dart';

/// Integration test for the relay pubkey SSE endpoint.
///
/// Requires the relay server running on localhost:8080.
void main() {
  const baseUrl = 'http://localhost:8080';
  const testKey =
      'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGtQRGwEMGaJNcGxIGJMfPMYhMIjbdMElANOqFBHrBfg test@dart';

  late Dio dio;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: baseUrl));
  });

  tearDown(() {
    dio.close();
  });

  test('POST returns SSE stream with rotating IDs, GET consumes key', () async {
    // POST the public key and receive an SSE stream.
    final response = await dio.post<ResponseBody>(
      '/pubkey',
      data: {'public_key': testKey},
      options: Options(responseType: ResponseType.stream),
    );

    expect(response.statusCode, 200);

    final stream = response.data!.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    final ids = <String>[];
    final completer = Completer<void>();

    final subscription = stream.listen((line) {
      // SSE data lines look like: "data: 123456"
      if (line.startsWith('data: ')) {
        final id = line.substring(6).trim();
        ids.add(id);
        if (ids.length == 2) {
          completer.complete();
        }
      }
    });

    // Wait for two events (initial + one rotation).
    await completer.future.timeout(
      const Duration(seconds: 65),
      onTimeout: () => fail('Timed out waiting for 2 SSE events'),
    );

    expect(ids.length, 2);
    expect(ids[0], isNot(equals(ids[1])),
        reason: 'IDs should rotate between events');

    // The first ID should no longer be valid (removed on rotation).
    final staleResponse = await dio.get(
      '/pubkey',
      queryParameters: {'id': ids[0]},
      options: Options(validateStatus: (_) => true),
    );
    expect(staleResponse.statusCode, 404);

    // The second (current) ID should return the public key.
    final getResponse = await dio.get(
      '/pubkey',
      queryParameters: {'id': ids[1]},
    );
    expect(getResponse.statusCode, 200);
    expect(getResponse.data['public_key'], testKey);

    // After GET consumption the SSE stream should close.
    // Give it a moment, then cancel the subscription.
    await Future<void>.delayed(const Duration(seconds: 1));
    await subscription.cancel();
  }, timeout: Timeout(Duration(seconds: 75)));
}
