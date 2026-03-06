import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

final _log = Logger('SshPairingService');

/// Events emitted by [SshPairingService].
sealed class SshPairingEvent {
  const SshPairingEvent();
}

/// A new pairing code was received (initial or rotated).
class PairingCodeEvent extends SshPairingEvent {
  final String code;
  const PairingCodeEvent(this.code);

  @override
  String toString() => 'PairingCodeEvent($code)';
}

/// The key was consumed and the remote client's identity was received.
/// This is the final event before the stream closes.
///
/// The relay sends either `username@ip` or just `ip`.
class PairingConnectedEvent extends SshPairingEvent {
  final String ipAddress;
  final String? username;
  const PairingConnectedEvent(this.ipAddress, {this.username});

  /// Parse the connected event data which is either `username@ip` or just `ip`.
  factory PairingConnectedEvent.parse(String data) {
    final atIndex = data.indexOf('@');
    if (atIndex > 0) {
      return PairingConnectedEvent(
        data.substring(atIndex + 1),
        username: data.substring(0, atIndex),
      );
    }
    return PairingConnectedEvent(data);
  }

  @override
  String toString() => 'PairingConnectedEvent($ipAddress, username: $username)';
}

/// An error occurred. The service will attempt reconnection automatically
/// unless [dispose] has been called.
class PairingErrorEvent extends SshPairingEvent {
  final String message;
  const PairingErrorEvent(this.message);

  @override
  String toString() => 'PairingErrorEvent($message)';
}

/// The service is reconnecting after a failure.
class PairingReconnectingEvent extends SshPairingEvent {
  final int attempt;
  final Duration delay;
  const PairingReconnectingEvent(this.attempt, this.delay);

  @override
  String toString() =>
      'PairingReconnectingEvent(attempt: $attempt, delay: ${delay.inSeconds}s)';
}

/// Handles SSH public key pairing via the relay server's SSE endpoint.
///
/// Posts a public key to the relay, then listens for SSE events containing
/// rotating pairing codes and the final connection IP. Automatically
/// reconnects with Fibonacci backoff on failure.
///
/// Usage:
/// ```dart
/// final service = SshPairingService(relayBaseUrl: 'https://relay.example.com');
/// service.start(publicKey);
/// service.events.listen((event) {
///   switch (event) {
///     case PairingCodeEvent(:final code):
///       // Show code to user
///     case PairingConnectedEvent(:final ipAddress):
///       // Pairing complete
///     case PairingErrorEvent(:final message):
///       // Show error
///     case PairingReconnectingEvent(:final attempt, :final delay):
///       // Show reconnecting status
///   }
/// });
/// // When done:
/// service.dispose();
/// ```
class SshPairingService {
  final String relayBaseUrl;

  final _controller = StreamController<SshPairingEvent>.broadcast();
  Dio? _dio;
  StreamSubscription<String>? _sseSubscription;
  bool _disposed = false;
  bool _connected = false;
  String? _publicKey;

  SshPairingService({required this.relayBaseUrl});

  /// Stream of pairing events. Safe to listen to from Flutter widgets.
  Stream<SshPairingEvent> get events => _controller.stream;

  /// Whether the pairing completed successfully (connected event received).
  bool get isConnected => _connected;

  /// Start the pairing process by posting the given public key.
  ///
  /// Any previous session is cancelled first.
  void start(String publicKey) {
    _publicKey = publicKey;
    _connected = false;
    _cancelCurrentSession();
    _connect(publicKey, attempt: 0);
  }

  /// Stop the pairing process and release resources.
  void dispose() {
    _disposed = true;
    _cancelCurrentSession();
    _controller.close();
  }

  void _cancelCurrentSession() {
    _sseSubscription?.cancel();
    _sseSubscription = null;
    _dio?.close(force: true);
    _dio = null;
  }

  void _connect(String publicKey, {required int attempt}) {
    if (_disposed) return;

    _cancelCurrentSession();
    _dio = Dio(BaseOptions(
      baseUrl: relayBaseUrl,
      connectTimeout: const Duration(seconds: 10),
    ));

    _postAndListen(publicKey, attempt: attempt);
  }

  Future<void> _postAndListen(
    String publicKey, {
    required int attempt,
  }) async {
    try {
      final response = await _dio!.post<ResponseBody>(
        '/pubkey',
        data: {'public_key': publicKey},
        options: Options(responseType: ResponseType.stream),
      );

      if (response.statusCode != 200) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response as Response<dynamic>,
          message: 'Unexpected status ${response.statusCode}',
        );
      }

      // Successfully connected — reset attempt counter.
      attempt = 0;

      final stream = response.data!.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      bool sawConnectedEvent = false;

      _sseSubscription = stream.listen(
        (line) {
          if (_disposed) return;

          if (line == 'event: connected') {
            sawConnectedEvent = true;
            return;
          }

          if (line.startsWith('data: ')) {
            final value = line.substring(6).trim();
            if (sawConnectedEvent) {
              _connected = true;
              _controller.add(PairingConnectedEvent.parse(value));
              // Final event — clean up without reconnecting.
              _cancelCurrentSession();
            } else {
              _controller.add(PairingCodeEvent(value));
            }
          }
        },
        onError: (Object error) {
          if (_disposed) return;
          _log.warning('SSE stream error: $error');
          _controller.add(PairingErrorEvent(error.toString()));
          _scheduleReconnect(publicKey, attempt: attempt);
        },
        onDone: () {
          if (_disposed || _connected) return;
          // Stream closed unexpectedly — reconnect.
          _log.info('SSE stream closed unexpectedly, reconnecting');
          _scheduleReconnect(publicKey, attempt: attempt);
        },
        cancelOnError: false,
      );
    } on DioException catch (e) {
      if (_disposed) return;
      final message = e.message ?? e.toString();
      _log.warning('Failed to connect to relay: $message');
      _controller.add(PairingErrorEvent(message));
      _scheduleReconnect(publicKey, attempt: attempt);
    } catch (e) {
      if (_disposed) return;
      _log.warning('Unexpected error: $e');
      _controller.add(PairingErrorEvent(e.toString()));
      _scheduleReconnect(publicKey, attempt: attempt);
    }
  }

  void _scheduleReconnect(String publicKey, {required int attempt}) {
    if (_disposed || _connected) return;
    // Only reconnect if this is still the active public key.
    if (publicKey != _publicKey) return;

    final delay = _fibonacciDelay(attempt);
    _log.info('Reconnecting in ${delay.inSeconds}s (attempt ${attempt + 1})');
    _controller.add(PairingReconnectingEvent(attempt + 1, delay));

    Future.delayed(delay, () {
      if (_disposed || _connected || publicKey != _publicKey) return;
      _connect(publicKey, attempt: attempt + 1);
    });
  }

  /// Fibonacci backoff: 1, 1, 2, 3, 5, 8, 13, 21, 34, capped at 60s.
  static Duration _fibonacciDelay(int attempt) {
    if (attempt <= 0) return const Duration(seconds: 1);
    int a = 1, b = 1;
    for (int i = 1; i < attempt; i++) {
      final next = a + b;
      a = b;
      b = next;
    }
    final seconds = b.clamp(1, 60);
    return Duration(seconds: seconds);
  }
}
