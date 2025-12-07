import 'dart:async';
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
  String? _currentGlobalUrl;

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
  int _reconnectAttempts = 0;

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
      final project = ref.read(currentProjectProvider);
      _connectGlobal(next, project?.serverUrl);
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
      // Handle Project Sync update
      if (next != null &&
          previous?.id == next.id &&
          previous?.serverUrl != next.serverUrl) {
        final projectDb = ref.read(projectDatabaseProvider);
        if (projectDb != null) {
          _connectProject(projectDb, next.id);
        }
      }

      // Handle Global Sync update
      if (previous?.id != next?.id || previous?.serverUrl != next?.serverUrl) {
        _connectGlobal(ref.read(globalDatabaseProvider), next?.serverUrl);
      }
    });

    // Initial connection
    final nodeId = ref.read(nodeIdProvider);
    developer.log('SyncService: Initializing with nodeId: $nodeId');

    final project = ref.read(currentProjectProvider);
    _connectGlobal(ref.read(globalDatabaseProvider), project?.serverUrl);

    final projectDb = ref.read(projectDatabaseProvider);
    final projectId = ref.read(currentProjectIdProvider);
    if (projectDb != null && projectId != null) {
      _connectProject(projectDb, projectId);
    }
  }

  Future<void> _connectGlobal(GlobalDatabase db, String? serverUrl) async {
    if (serverUrl == _currentGlobalUrl && _globalSync != null) return;

    _disconnectGlobal();
    _currentGlobalUrl = serverUrl;

    if (serverUrl == null || serverUrl.isEmpty) {
      developer.log('SyncService: No server URL for global sync.');
      return;
    }

    try {
      // Ensure DB is open so that crdt instance is available
      await db.customSelect('SELECT 1').get();

      final crdt = db.crdt;
      // Remove trailing slash if present
      final cleanUrl = serverUrl.endsWith('/')
          ? serverUrl.substring(0, serverUrl.length - 1)
          : serverUrl;
      final uri = Uri.parse('$cleanUrl/sync/global');

      developer.log('SyncService: Connecting to global sync at $uri');
      _globalChannel = MultiplexedWebSocketChannel(
        WebSocketChannel.connect(uri),
      );
      _globalSubscription = _globalChannel!.onCustomMessage.listen((msg) {
        developer.log('SyncService (Global): Received custom message: $msg');
      });
      _globalSync = CrdtSync.client(
        crdt,
        _globalChannel!,
        verbose: true,
        validateRecord: (table, record) {
          if (table == 'projects') {
            final remoteUrl = record['server_url'] as String?;
            if (remoteUrl == null || remoteUrl.isEmpty) return false;
          }
          return true;
        },
        changesetBuilder:
            ({
              exceptNodeId,
              modifiedAfter,
              modifiedOn,
              onlyNodeId,
              onlyTables,
            }) async {
              final changeset = await crdt.getChangeset(
                onlyTables: onlyTables,
                onlyNodeId: onlyNodeId,
                exceptNodeId: exceptNodeId,
                modifiedOn: modifiedOn,
                modifiedAfter: modifiedAfter,
              );

              if (changeset.containsKey('projects')) {
                final records = changeset['projects']!;
                final filteredRecords = records.where((record) {
                  final recordUrl = record['server_url'] as String?;
                  return recordUrl != null && recordUrl == serverUrl;
                }).toList();

                if (filteredRecords.isEmpty) {
                  changeset.remove('projects');
                } else {
                  changeset['projects'] = filteredRecords;
                }
              }
              return changeset;
            },
      );
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
        _reconnectAttempts = 0;
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
      _projectSync = CrdtSync.client(crdt, _projectChannel!, verbose: true);
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

    final delaySeconds = _getFibonacciDelay(_reconnectAttempts);
    developer.log(
      'SyncService: Scheduling reconnect in $delaySeconds seconds (attempt $_reconnectAttempts)...',
    );

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_currentProjectId != null && _currentProjectDb != null) {
        _reconnectAttempts++;
        _connectProject(_currentProjectDb!, _currentProjectId!);
      }
    });
  }

  int _getFibonacciDelay(int attempt) {
    if (attempt <= 0) return 1;
    if (attempt == 1) return 1;
    int a = 1, b = 1;
    for (int i = 2; i <= attempt; i++) {
      int temp = a + b;
      a = b;
      b = temp;
      if (b >= 5) return 5;
    }
    return b;
  }

  void _resetProjectSync() {
    _reconnectTimer?.cancel();
    _connectionToken?.cancel();
    _currentProjectId = null;
    _currentProjectDb = null;
    _reconnectAttempts = 0;
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
