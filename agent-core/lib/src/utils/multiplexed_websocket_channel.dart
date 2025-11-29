import 'dart:async';
import 'dart:convert';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class MultiplexedWebSocketChannel extends StreamChannelMixin
    implements WebSocketChannel {
  final WebSocketChannel _inner;
  final StreamController _inboundController = StreamController();
  final StreamController<Map<String, dynamic>> _customMessageController =
      StreamController.broadcast();
  static const String _customPrefix = '__CUSTOM__:';

  MultiplexedWebSocketChannel(this._inner) {
    _inner.stream.listen(
        (data) {
          if (data is String && data.startsWith(_customPrefix)) {
            try {
              final payload = data.substring(_customPrefix.length);
              final message = jsonDecode(payload) as Map<String, dynamic>;
              _customMessageController.add(message);
            } catch (e) {
              // Ignore malformed custom messages
              print('Error parsing custom message: $e');
            }
          } else {
            _inboundController.add(data);
          }
        },
        onError: _inboundController.addError,
        onDone: () {
          _inboundController.close();
          _customMessageController.close();
        });
  }

  @override
  Stream get stream => _inboundController.stream;

  @override
  WebSocketSink get sink => _MultiplexedSink(_inner.sink);

  void sendCustomMessage(Map<String, dynamic> message) {
    _inner.sink.add('$_customPrefix${jsonEncode(message)}');
  }

  Stream<Map<String, dynamic>> get onCustomMessage =>
      _customMessageController.stream;

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
