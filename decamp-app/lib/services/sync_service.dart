import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crdt_sync/crdt_sync.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:agent_core/agent_core.dart';
import 'package:decamp/certs.dart';
import 'package:decamp/providers/providers.dart';

final _log = Logger('SyncService');

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

class SyncService {
  static const defaultConnectionTimeout = Duration(seconds: 5);

  final Ref ref;
  CrdtSync? _globalSync;
  CrdtSync? _settingsSync;
  CrdtSync? _secretsSync;
  MultiplexedWebSocketChannel? _globalChannel;
  StreamSubscription? _globalSubscription;

  CrdtSync? _projectSync;
  MultiplexedWebSocketChannel? _projectChannel;
  StreamSubscription? _projectSubscription;
  String? _currentGlobalUrl;

  // Adapters for waiting on sync idle
  CrdtFlowAdapter? _globalAdapter;
  CrdtFlowAdapter? _projectAdapter;

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
  AppLifecycleListener? _lifecycleListener;

  SyncService(this.ref) {
    _init();
  }

  MultiplexedWebSocketChannel? getChannel(String projectId) {
    if (_currentProjectId == projectId) {
      return _projectChannel;
    }
    return null;
  }

  void _updateConnectionState(SyncConnectionState state) {
    _currentConnectionState = state;
    _connectionStateController.add(state);
  }

  void _init() {
    // Listen for app lifecycle changes to handle resume from background/suspend
    _lifecycleListener = AppLifecycleListener(onResume: _handleAppResume);

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
    _log.info('Initializing with nodeId: $nodeId');

    final project = ref.read(currentProjectProvider);
    _connectGlobal(ref.read(globalDatabaseProvider), project?.serverUrl);

    final projectDb = ref.read(projectDatabaseProvider);
    final projectId = ref.read(currentProjectIdProvider);
    if (projectDb != null && projectId != null) {
      _connectProject(projectDb, projectId);
    }
  }

  Future<void> connectGlobal(String url) async {
    final db = ref.read(globalDatabaseProvider);
    await _connectGlobal(db, url, rethrowErrors: true);
  }

  Future<void> _connectGlobal(
    GlobalDatabase db,
    String? serverUrl, {
    bool rethrowErrors = false,
  }) async {
    if (serverUrl == _currentGlobalUrl && _globalSync != null) return;

    _disconnectGlobal();
    _currentGlobalUrl = serverUrl;

    if (serverUrl == null || serverUrl.isEmpty) {
      _log.info('No server URL for global sync.');
      return;
    }

    try {
      // Ensure DB is open so that crdt instance is available
      await db.customSelect('SELECT 1;').get();

      final crdt = db.crdt;
      _globalAdapter = CrdtFlowAdapter(crdt);
      // Remove trailing slash if present
      final cleanUrl = serverUrl.endsWith('/')
          ? serverUrl.substring(0, serverUrl.length - 1)
          : serverUrl;
      final uri = Uri.parse('$cleanUrl/sync/global');

      _log.info('Connecting to global sync at $uri');
      // Use a shorter timeout for manual connections (when rethrowErrors is true)
      final channel = _connectWebSocket(uri, timeout: defaultConnectionTimeout);
      await channel.ready;

      _globalChannel = MultiplexedWebSocketChannel(
        channel,
        awaitSync: () => _globalAdapter!.onIdle,
      );
      _globalSubscription = _globalChannel!.onCustomMessage.listen((msg) {
        _log.fine('Global sync received custom message: $msg');
      });

      _globalSync = CrdtSync.client(
        _globalAdapter!,
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
              final changeset = await _globalAdapter!.getChangeset(
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
      _log.warning('Global DB not ready or error: $e');
      if (rethrowErrors) rethrow;
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
      _log.info('Verifying project DB connection for $projectId...');
      // Ensure DB is open
      await db.customSelect('SELECT 1;').get();
      _log.info('Project DB connection verified for $projectId');

      if (token.isCancelled) return;

      // Get project settings to check for server URL
      final project = await ref
          .read(databaseProvider)
          .projectDao
          .getProject(projectId);

      if (token.isCancelled) return;

      final serverUrl = project?.serverUrl;

      if (serverUrl == null) {
        _log.info(
          'No server URL configured for project $projectId. Skipping sync.',
        );
        return;
      }

      final crdt = db.crdt;
      _projectAdapter = CrdtFlowAdapter(crdt);
      final uri = Uri.parse('$serverUrl/sync/project/$projectId');

      _log.info('Connecting to project sync at $uri');
      _updateConnectionState(SyncConnectionState.connecting);

      final wsChannel = _connectWebSocket(uri);
      final monitoredChannel = _ActivityMonitorWebSocketChannel(
        wsChannel,
        onActivity: _handleSyncActivity,
        onDisconnect: () {
          _log.info(
            'Project sync disconnected for $projectId (current: $_currentProjectId)',
          );
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
        _log.warning('Connection failed: $e');
        _scheduleReconnect();
        return;
      }

      _projectChannel = MultiplexedWebSocketChannel(
        monitoredChannel,
        awaitSync: () => _projectAdapter!.onIdle,
      );

      // Settings Sync
      final settingsService = ref.read(crdtSettingsServiceProvider);
      final settingsCrdt = await settingsService.getProjectCrdt(projectId);
      final settingsChannel = _projectChannel!.fork('\u001E');
      _settingsSync = CrdtSync.client(
        settingsCrdt,
        settingsChannel,
        verbose: true,
      );

      // Secrets Sync
      final secretsCrdt = ref.read(secretsCrdtProvider);
      await secretsCrdt.ready;
      secretsCrdt.resetInitialChangeset();
      final secretsChannel = _projectChannel!.fork('\u001D');
      _secretsSync = CrdtSync.client(
        secretsCrdt,
        secretsChannel,
        verbose: true,
        changesetBuilder:
            ({
              exceptNodeId,
              modifiedAfter,
              modifiedOn,
              onlyNodeId,
              onlyTables,
            }) async => await secretsCrdt.changesetFunction(
              projectId: projectId,
              onlyTables: onlyTables,
              onlyNodeId: onlyNodeId,
              exceptNodeId: exceptNodeId,
              modifiedOn: modifiedOn,
              modifiedAfter: modifiedAfter,
            ),
      );

      _projectSubscription = _projectChannel!.onCustomMessage.listen((msg) {
        _log.fine('Project sync received custom message: $msg');
        if (msg['type'] == 'PONG') {
          _log.fine('PONG received: ${msg['payload']}');
        }
      });
      _projectSync = CrdtSync.client(
        _projectAdapter!,
        _projectChannel!,
        verbose: true,
      );
    } catch (e) {
      if (token.isCancelled) return;
      _log.warning('Project DB not ready or error: $e');
      _scheduleReconnect();
    }
  }

  void _disconnectGlobal() {
    _globalSync?.close();
    _globalSync = null;
    _globalChannel = null;
    _globalSubscription?.cancel();
    _globalSubscription = null;
    _currentGlobalUrl = null;
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;
    if (_currentProjectId == null || _currentProjectDb == null) return;

    final delaySeconds = _getFibonacciDelay(_reconnectAttempts);
    _log.info(
      'Scheduling reconnect in $delaySeconds seconds (attempt $_reconnectAttempts)...',
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
    _settingsSync?.close();
    _settingsSync = null;
    _secretsSync?.close();
    _secretsSync = null;
    _projectSync?.close();
    _projectSync = null;
    _projectChannel = null;
    _projectSubscription?.cancel();
    _projectSubscription = null;
    _updateConnectionState(SyncConnectionState.disconnected);
  }

  void dispose() {
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    _disconnectGlobal();
    _resetProjectSync();
    _connectionStateController.close();
    _isSyncingController.close();
    _syncDebounceTimer?.cancel();
  }

  /// Called when the app resumes from background or device wakes from suspend.
  /// Forces a reconnection to ensure we have a fresh WebSocket connection
  /// and sync any changes that occurred while suspended.
  void _handleAppResume() {
    //TODO: This might not be the best solution, we might want to explore
    // dedicated packages that monitor internet connection state.
    // Alternatively, we could check how long the connection has been idle
    // and only reconnect when we have not heard from it.
    _log.info('App resumed - forcing reconnection to sync latest data');

    // Force reconnect global sync if we have a server URL
    if (_currentGlobalUrl != null) {
      _disconnectGlobal();
      final project = ref.read(currentProjectProvider);
      _connectGlobal(ref.read(globalDatabaseProvider), project?.serverUrl);
    }

    // Force reconnect project sync if we have an active project
    if (_currentProjectId != null && _currentProjectDb != null) {
      _closeProjectConnection();
      _reconnectAttempts = 0;
      _connectProject(_currentProjectDb!, _currentProjectId!);
    }
  }

  void _handleSyncActivity() {
    if (!_isSyncingController.hasListener) return;

    _isSyncingController.add(true);
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _isSyncingController.add(false);
    });
  }

  Future<void> waitForGlobalSync() async {
    if (_globalAdapter != null) {
      await _globalAdapter!.onIdle;
    }
  }

  Future<void> waitForProjectSync() async {
    if (_projectAdapter != null) {
      await _projectAdapter!.onIdle;
    }
  }

  MultiplexedWebSocketChannel? get projectChannel => _projectChannel;

  void sendPing(String message) {
    if (_projectChannel != null) {
      _log.fine('Sending ping: $message');
      _projectChannel!.sendCustomMessage({'type': 'PING', 'payload': message});
    } else {
      _log.warning('Cannot send ping, no project connection');
    }
  }

  WebSocketChannel _connectWebSocket(Uri uri, {Duration? timeout}) {
    _log.info('_connectWebSocket called for $uri with timeout: $timeout');

    try {
      _log.info('Configuring mTLS with embedded certificates');

      final context = SecurityContext(withTrustedRoots: false)
        ..useCertificateChainBytes(utf8.encode(clientCert))
        ..usePrivateKeyBytes(utf8.encode(clientKey))
        ..setTrustedCertificatesBytes(utf8.encode(caCert));

      _log.info('SecurityContext created successfully.');

      final client = HttpClient(context: context);

      // We rely on SecurityContext for validation, but use this callback
      // to log detailed errors if validation fails.
      client.badCertificateCallback = (cert, host, port) {
        _log.warning('Certificate verification failed for $host:$port');
        _log.warning('Subject: ${cert.subject}');
        _log.warning('Issuer: ${cert.issuer}');

        // Strict byte-for-byte pinning is fragile because Dart/BoringSSL may normalize
        // the certificate (e.g. re-encoding ASN.1), resulting in different bytes
        // than the file on disk.
        //
        // Instead, we validate the Certificate Subject and Issuer to ensure
        // it is the correct certificate issued by our CA.
        //
        // Note: SecurityContext has already validated the signature against the CA
        // (unless the error is related to the CA itself).

        // We might get a callback for the CA certificate (self-signed error)
        // or the Server certificate (hostname mismatch error).
        // We validate that the certificate is either our Server Cert or our CA Cert
        // by comparing the DER bytes.

        final isServerCert =
            cert.subject.contains('localhost') &&
            cert.issuer.contains('Decamp CA');

        final isCaCert =
            cert.subject.contains('Decamp CA') &&
            cert.issuer.contains('Decamp CA');

        if (!isServerCert && !isCaCert) {
          _log.severe(
            'Certificate validation FAILED: Unknown certificate subject/issuer.',
          );
          _log.severe('Subject: ${cert.subject}');
          _log.severe('Issuer: ${cert.issuer}');
          return false;
        }

        try {
          String pemToCompare;
          if (isServerCert) {
            // serverCert contains the chain, we only want the first cert (the server cert)
            final endMarker = '-----END CERTIFICATE-----';
            final endIndex = serverCert.indexOf(endMarker);
            if (endIndex == -1) {
              throw FormatException('Invalid serverCert format');
            }
            pemToCompare = serverCert.substring(0, endIndex + endMarker.length);
          } else {
            // caCert contains only the CA cert
            pemToCompare = caCert;
          }

          final cleanPem = pemToCompare
              .replaceAll(RegExp(r'-----.*-----'), '')
              .replaceAll(RegExp(r'\s+'), '');

          final pinnedBytes = base64.decode(cleanPem);
          final receivedBytes = cert.der;

          if (listEquals(pinnedBytes, receivedBytes)) {
            _log.info(
              'Certificate pinning successful: Trusted certificate encountered (${isServerCert ? "Server" : "CA"}). Allowing connection.',
            );
            return true;
          } else {
            _log.severe(
              'Certificate pinning FAILED: Certificate bytes do not match pinned certificate.',
            );
            _log.severe('Certificate type: ${isServerCert ? "Server" : "CA"}');
            return false;
          }
        } catch (e) {
          _log.severe('Error during certificate pinning check', e);
          return false;
        }
      };

      _log.info('Connecting with mTLS to $uri');
      return IOWebSocketChannel.connect(
        uri,
        customClient: client,
        connectTimeout: timeout,
        pingInterval: const Duration(seconds: 10),
      );
    } catch (e, st) {
      _log.severe('Error configuring mTLS', e, st);
      rethrow;
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
