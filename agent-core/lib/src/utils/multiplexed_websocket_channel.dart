import 'dart:async';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class MultiplexedWebSocketChannel extends StreamChannelMixin
    implements WebSocketChannel {
  final WebSocketChannel _inner;
  final StreamController _inboundController = StreamController();
  final StreamController _customMessageController =
      StreamController.broadcast();
  static const String _customPrefix = '__CUSTOM__:';

  MultiplexedWebSocketChannel(this._inner) {
    _inner.stream.listen(
        (data) {
          if (data is String && data.startsWith(_customPrefix)) {
            _customMessageController.add(data.substring(_customPrefix.length));
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

  void sendCustomMessage(String message) {
    _inner.sink.add('$_customPrefix$message');
  }

  Stream get onCustomMessage => _customMessageController.stream;

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
