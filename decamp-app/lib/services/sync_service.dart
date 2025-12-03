import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crdt_sync/crdt_sync.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:agent_core/agent_core.dart';
import '../providers/database_provider.dart';
import '../providers/project_selection_provider.dart';
import '../providers/project_provider.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

class SyncService {
  final Ref ref;
  CrdtSync? _globalSync;
  MultiplexedWebSocketChannel? _globalChannel;
  StreamSubscription? _globalSubscription;

  CrdtSync? _projectSync;
  MultiplexedWebSocketChannel? _projectChannel;
  StreamSubscription? _projectSubscription;

  final StreamController<SyncConnectionState> _connectionStateController =
      StreamController<SyncConnectionState>.broadcast();
  final StreamController<bool> _isSyncingController =
      StreamController<bool>.broadcast();
  Timer? _syncDebounceTimer;
  SyncConnectionState _currentConnectionState =
      SyncConnectionState.disconnected;

  Stream<SyncConnectionState> get connectionState =>
      _connectionStateController.stream;
  SyncConnectionState get currentConnectionState => _currentConnectionState;
  Stream<bool> get isSyncing => _isSyncingController.stream;

  Timer? _reconnectTimer;
  String? _currentProjectId;
  ProjectDatabase? _currentProjectDb;
  _CancellationToken? _connectionToken;

  SyncService(this.ref) {
    _init();
  }

  void _updateConnectionState(SyncConnectionState state) {
    _currentConnectionState = state;
    _connectionStateController.add(state);
  }

  void _init() {
    // Watch for database changes
    ref.listen(globalDatabaseProvider, (previous, next) {
      _connectGlobal(next);
    });

    ref.listen(projectDatabaseProvider, (previous, next) {
      if (next != null) {
        final projectId = ref.read(currentProjectIdProvider);
        if (projectId != null) {
          _connectProject(next, projectId);
        }
      } else {
        _resetProjectSync();
      }
    });

    // Watch for project settings changes (specifically serverUrl)
    ref.listen<ProjectEntity?>(currentProjectProvider, (previous, next) {
      if (next != null &&
          previous?.id == next.id &&
          previous?.serverUrl != next.serverUrl) {
        final projectDb = ref.read(projectDatabaseProvider);
        if (projectDb != null) {
          _connectProject(projectDb, next.id);
        }
      }
    });

    // Initial connection
    _connectGlobal(ref.read(globalDatabaseProvider));
    final projectDb = ref.read(projectDatabaseProvider);
    final projectId = ref.read(currentProjectIdProvider);
    if (projectDb != null && projectId != null) {
      _connectProject(projectDb, projectId);
    }
  }

  String get _baseUrl {
    // TODO: Make this configurable via settings
    if (Platform.isAndroid) {
      return 'ws://10.0.2.2:3123';
    }
    return 'ws://localhost:3123';
  }

  Future<void> _connectGlobal(GlobalDatabase db) async {
    _disconnectGlobal();

    return; // Temporarily disable global sync.

    // ignore: dead_code
    try {
      // Ensure DB is open so that crdt instance is available
      await db.customSelect('SELECT 1').get();

      final crdt = db.crdt;
      final uri = Uri.parse('$_baseUrl/sync/global');

      developer.log('SyncService: Connecting to global sync at $uri');
      _globalChannel = MultiplexedWebSocketChannel(
        WebSocketChannel.connect(uri),
      );
      _globalSubscription = _globalChannel!.onCustomMessage.listen((msg) {
        developer.log('SyncService (Global): Received custom message: $msg');
      });
      _globalSync = CrdtSync.client(crdt, _globalChannel!);
    } catch (e) {
      developer.log('SyncService: Global DB not ready or error: $e');
    }
  }

  Future<void> _connectProject(ProjectDatabase db, String projectId) async {
    _reconnectTimer?.cancel();
    _connectionToken?.cancel();
    final token = _CancellationToken();
    _connectionToken = token;

    _currentProjectId = projectId;
    _currentProjectDb = db;
    _closeProjectConnection();

    try {
      // Ensure DB is open
      await db.customSelect('SELECT 1').get();

      if (token.isCancelled) return;

      // Get project settings to check for server URL
      final project = await ref
          .read(databaseProvider)
          .projectDao
          .getProject(projectId);

      if (token.isCancelled) return;

      final serverUrl = project?.serverUrl;

      if (serverUrl == null) {
        developer.log(
          'SyncService: No server URL configured for project $projectId. Skipping sync.',
        );
        return;
      }

      final crdt = db.crdt;
      final uri = Uri.parse('$serverUrl/sync/project/$projectId');

      developer.log('SyncService: Connecting to project sync at $uri');
      _updateConnectionState(SyncConnectionState.connecting);

      final wsChannel = WebSocketChannel.connect(uri);
      final monitoredChannel = _ActivityMonitorWebSocketChannel(
        wsChannel,
        onActivity: _handleSyncActivity,
        onDisconnect: () {
          if (_currentProjectId != projectId) return;
          _updateConnectionState(SyncConnectionState.disconnected);
          _scheduleReconnect();
        },
      );

      try {
        await monitoredChannel.ready;
        if (token.isCancelled) {
          monitoredChannel.sink.close();
          return;
        }
        _updateConnectionState(SyncConnectionState.connected);
      } catch (e) {
        if (token.isCancelled) return;
        _updateConnectionState(SyncConnectionState.disconnected);
        developer.log('SyncService: Connection failed: $e');
        _scheduleReconnect();
        return;
      }

      _projectChannel = MultiplexedWebSocketChannel(monitoredChannel);
      _projectSubscription = _projectChannel!.onCustomMessage.listen((msg) {
        developer.log('SyncService (Project): Received custom message: $msg');
        if (msg['type'] == 'PONG') {
          developer.log(
            'SyncService (Project): PONG received: ${msg['payload']}',
          );
        }
      });
      _projectSync = CrdtSync.client(crdt, _projectChannel!);
    } catch (e) {
      if (token.isCancelled) return;
      developer.log('SyncService: Project DB not ready or error: $e');
      _scheduleReconnect();
    }
  }

  void _disconnectGlobal() {
    _globalSync?.close();
    _globalSync = null;
    _globalChannel = null;
    _globalSubscription?.cancel();
    _globalSubscription = null;
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;
    if (_currentProjectId == null || _currentProjectDb == null) return;

    developer.log('SyncService: Scheduling reconnect in 5 seconds...');
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_currentProjectId != null && _currentProjectDb != null) {
        _connectProject(_currentProjectDb!, _currentProjectId!);
      }
    });
  }

  void _resetProjectSync() {
    _reconnectTimer?.cancel();
    _connectionToken?.cancel();
    _currentProjectId = null;
    _currentProjectDb = null;
    _closeProjectConnection();
  }

  void _closeProjectConnection() {
    _projectSync?.close();
    _projectSync = null;
    _projectChannel = null;
    _projectSubscription?.cancel();
    _projectSubscription = null;
    _updateConnectionState(SyncConnectionState.disconnected);
  }

  void dispose() {
    _disconnectGlobal();
    _resetProjectSync();
    _connectionStateController.close();
    _isSyncingController.close();
    _syncDebounceTimer?.cancel();
  }

  void _handleSyncActivity() {
    if (!_isSyncingController.hasListener) return;

    _isSyncingController.add(true);
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _isSyncingController.add(false);
    });
  }

  MultiplexedWebSocketChannel? get projectChannel => _projectChannel;

  void sendPing(String message) {
    if (_projectChannel != null) {
      developer.log('SyncService: Sending ping: $message');
      _projectChannel!.sendCustomMessage({'type': 'PING', 'payload': message});
    } else {
      developer.log('SyncService: Cannot send ping, no project connection');
    }
  }
}

enum SyncConnectionState { disconnected, connecting, connected }

class _ActivityMonitorWebSocketChannel
    with StreamChannelMixin
    implements WebSocketChannel {
  final WebSocketChannel _inner;
  final void Function() onActivity;
  final void Function() onDisconnect;
  late final WebSocketSink _sink;
  late final Stream _stream;

  _ActivityMonitorWebSocketChannel(
    this._inner, {
    required this.onActivity,
    required this.onDisconnect,
  }) {
    _sink = _ActivityMonitorSink(_inner.sink, onActivity);
    _stream = _inner.stream.transform(
      StreamTransformer.fromHandlers(
        handleData: (data, sink) {
          onActivity();
          sink.add(data);
        },
        handleError: (error, stackTrace, sink) {
          onDisconnect();
          sink.addError(error, stackTrace);
        },
        handleDone: (sink) {
          onDisconnect();
          sink.close();
        },
      ),
    );
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

class _ActivityMonitorSink implements WebSocketSink {
  final WebSocketSink _inner;
  final void Function() onActivity;

  _ActivityMonitorSink(this._inner, this.onActivity);

  @override
  void add(event) {
    onActivity();
    _inner.add(event);
  }

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

class _CancellationToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;
  void cancel() => _isCancelled = true;
}
