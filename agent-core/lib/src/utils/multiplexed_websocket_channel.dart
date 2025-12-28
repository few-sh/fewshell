import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class MultiplexedWebSocketChannel extends StreamChannelMixin
    implements WebSocketChannel {
  static final _log = Logger('MultiplexedWebSocketChannel');

  final WebSocketChannel _inner;
  final StreamController _inboundController = StreamController(sync: true);
  final StreamController<Map<String, dynamic>> _customMessageController =
      StreamController.broadcast();
  final Map<String, StreamController> _forkedControllers = {};

  // Use Unit Separator (ASCII 31) as a prefix to avoid collisions with JSON
  static const String _customPrefix = '\u001F';

  late final WebSocketSink _sink = _MultiplexedSink(_inner.sink);

  final Future<void> Function()? awaitSync;
  Future<void> _pending = Future.value();
  final List<Future<void> Function(Map<String, dynamic>)> _customHandlers = [];

  MultiplexedWebSocketChannel(this._inner, {this.awaitSync}) {
    _inner.stream.listen((data) {
      // Chain processing to ensure order.
      // We use catchError to ensure the chain continues even if a previous task failed.
      _pending = _pending.catchError((_) {}).then((_) async {
        try {
          // Check forked channels first
          bool handled = false;
          if (data is String) {
            for (final prefix in _forkedControllers.keys) {
              if (data.startsWith(prefix)) {
                final payload = data.substring(prefix.length);
                _forkedControllers[prefix]!.add(payload);
                handled = true;
                break;
              } else {
                if (data.isNotEmpty &&
                    prefix.isNotEmpty &&
                    data.codeUnitAt(0) == prefix.codeUnitAt(0)) {
                  _log.warning(
                      'Prefix match failed but first char matches? Data len: ${data.length}, Prefix len: ${prefix.length}');
                }
              }
            }

            if (!handled && data.isNotEmpty && data.codeUnitAt(0) == 29) {
              _log.warning(
                  'Received GS (29) but did not match any prefix. Registered prefixes: ${_forkedControllers.keys.map((k) => k.codeUnits).toList()}');
            }
          } else {
            _log.warning('Received non-string data: ${data.runtimeType}');
          }

          if (handled) return;

          if (data is String && data.startsWith(_customPrefix)) {
            // If it's a custom message, wait for any pending sync operations
            if (awaitSync != null) {
              try {
                await awaitSync!();
              } catch (e) {
                _log.warning('Error waiting for sync: $e');
              }
            }

            try {
              final payload = data.substring(_customPrefix.length);
              final decoded = jsonDecode(payload);
              if (decoded is Map<String, dynamic>) {
                // Wait for registered handlers to complete
                if (_customHandlers.isNotEmpty) {
                  await Future.wait(_customHandlers.map((h) async {
                    try {
                      await h(decoded);
                    } catch (e, st) {
                      _log.warning('Error in custom message handler', e, st);
                    }
                  }));
                }
                _customMessageController.add(decoded);
              } else {
                _log.warning('Custom message payload is not a Map: $decoded');
              }
            } catch (e, stackTrace) {
              // Ignore malformed custom messages
              _log.warning(
                'Error parsing custom message: $e',
                e,
                stackTrace,
              );
            }
          } else {
            if (!_inboundController.isClosed) {
              _inboundController.add(data);
            }
          }
        } catch (e, stackTrace) {
          _log.severe(
              'Error processing message in multiplexed channel', e, stackTrace);
        }
      });
    }, onError: (error, stackTrace) {
      _inboundController.addError(error, stackTrace);
      _customMessageController.addError(error, stackTrace);
      for (final controller in _forkedControllers.values) {
        controller.addError(error, stackTrace);
      }
    }, onDone: () {
      _inboundController.close();
      _customMessageController.close();
      for (final controller in _forkedControllers.values) {
        controller.close();
      }
    });
  }

  /// Forks the channel with a specific prefix.
  /// Messages sent to the returned channel will be prefixed.
  /// Incoming messages starting with the prefix will be routed to the returned channel (with prefix stripped).
  WebSocketChannel fork(String prefix) {
    if (_forkedControllers.containsKey(prefix)) {
      throw ArgumentError('Prefix $prefix is already in use');
    }
    final controller = StreamController(sync: true);
    _forkedControllers[prefix] = controller;

    return _ForkedWebSocketChannel(
      _inner,
      prefix,
      controller.stream,
    );
  }

  @override
  Stream get stream => _inboundController.stream;

  @override
  WebSocketSink get sink => _sink;

  void sendCustomMessage(Map<String, dynamic> message) {
    _inner.sink.add('$_customPrefix${jsonEncode(message)}');
  }

  Stream<Map<String, dynamic>> get onCustomMessage =>
      _customMessageController.stream;

  void registerCustomHandler(
      Future<void> Function(Map<String, dynamic>) handler) {
    _customHandlers.add(handler);
  }

  void unregisterCustomHandler(
      Future<void> Function(Map<String, dynamic>) handler) {
    _customHandlers.remove(handler);
  }

  @override
  String? get protocol => _inner.protocol;

  @override
  int? get closeCode => _inner.closeCode;

  @override
  String? get closeReason => _inner.closeReason;

  @override
  Future<void> get ready => _inner.ready;
}

class _MultiplexedSink implements WebSocketSink {
  final WebSocketSink _inner;

  _MultiplexedSink(this._inner);

  @override
  void add(event) => _inner.add(event);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future addStream(Stream stream) => _inner.addStream(stream);

  @override
  Future close([int? closeCode, String? closeReason]) =>
      _inner.close(closeCode, closeReason);

  @override
  Future get done => _inner.done;
}

class _ForkedWebSocketChannel extends StreamChannelMixin
    implements WebSocketChannel {
  final WebSocketChannel _inner;
  final String _prefix;
  final Stream _stream;
  late final WebSocketSink _sink;

  _ForkedWebSocketChannel(this._inner, this._prefix, this._stream) {
    _sink = _ForkedSink(_inner.sink, _prefix);
  }

  @override
  Stream get stream => _stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  String? get protocol => _inner.protocol;

  @override
  int? get closeCode => _inner.closeCode;

  @override
  String? get closeReason => _inner.closeReason;

  @override
  Future<void> get ready => _inner.ready;
}

class _ForkedSink implements WebSocketSink {
  final WebSocketSink _inner;
  final String _prefix;

  _ForkedSink(this._inner, this._prefix);

  @override
  void add(event) {
    if (event is String) {
      _inner.add('$_prefix$event');
    } else {
      throw UnsupportedError(
          'Only string messages are supported for forked channels');
    }
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future addStream(Stream stream) async {
    await for (final event in stream) {
      add(event);
    }
  }

  @override
  Future close([int? closeCode, String? closeReason]) {
    // We don't close the inner sink as it might be shared
    return Future.value();
  }

  @override
  Future get done => _inner.done;
}
