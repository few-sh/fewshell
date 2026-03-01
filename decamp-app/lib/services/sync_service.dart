import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crdt_sync/crdt_sync.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:agent_core/agent_core.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:decamp/certs.dart';
import 'package:decamp/models/app_event.dart';
import 'package:decamp/providers/providers.dart';
import 'package:decamp/providers/ssh_tunnel_provider.dart';
import 'package:decamp/services/app_event_bus.dart';
import 'package:decamp/services/remote_installer.dart';

final _log = Logger('SyncService');

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

class SyncService {
  static const defaultConnectionTimeout = Duration(seconds: 10);

  final Ref ref;
  CrdtSync? _globalSync;
  CrdtSync? _settingsSync;
  CrdtSync? _secretsSync;
  MultiplexedWebSocketChannel? _globalChannel;
  StreamSubscription? _globalSubscription;

  CrdtSync? _projectSync;
  MultiplexedWebSocketChannel? _projectChannel;
  StreamSubscription? _projectSubscription;

  _SshTunnel? _globalSshTunnel;
  _SshTunnel? _projectSshTunnel;

  /// A dedup key for the current global sync connection.
  /// Prevents redundant reconnections when the connection details haven't changed.
  String? _currentGlobalConnectionKey;

  /// The connection info used for the current global sync session.
  /// Stored so we can auto-map new projects to the same connection.
  Map<String, dynamic>? _currentGlobalConnectionInfo;

  /// The server's CRDT node ID discovered from the `X-Fewshell-Server-Node-Id`
  /// header during the most recent global sync WebSocket upgrade.
  String? _currentServerNodeId;

  /// The server's node ID from the last successful global sync connection.
  /// Accessible to other services for connection mapping / project matching.
  String? get currentServerNodeId => _currentServerNodeId;

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
  Timer? _globalReconnectTimer;
  String? _currentProjectId;
  ProjectDatabase? _currentProjectDb;
  _CancellationToken? _connectionToken;
  int _reconnectAttempts = 0;
  int _globalReconnectAttempts = 0;
  AppLifecycleListener? _lifecycleListener;
  AppLifecycleState? _lastLifecycleState;

  /// When true, [_checkProjectsForServer] is suppressed because
  /// [connectViaTunnel] is running its own polling + emission logic.
  bool _tunnelConnectInProgress = false;

  late final AppEventBus _appEventBus;

  SyncService(this.ref) {
    _appEventBus = ref.read(appEventBusProvider);
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
    // Listen for app lifecycle changes
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _handleLifecycleStateChange,
    );

    // Watch for database changes
    ref.listen(globalDatabaseProvider, (previous, next) {
      final project = ref.read(currentProjectProvider);
      _connectGlobal(next, project?.serverUrl);
    });

    ref.listen(projectDatabaseProvider, (previous, next) {
      if (next != null) {
        // Project DB changed — connect project if global is already up.
        _log.info('Project DB changed, connecting project if ready.');
        _connectProjectIfReady();
      } else {
        _log.info('Project DB cleared, resetting project sync.');
        _resetProjectSync();
      }
    });

    // Watch for project changes that affect sync connections.
    ref.listen<ProjectEntity?>(currentProjectProvider, (previous, next) {
      // Reconnect global sync when the project changes, or when identity/
      // connection fields change (serverNodeId arriving via CRDT replication,
      // or serverUrl as transitional fallback).
      if (previous?.id != next?.id ||
          previous?.serverNodeId != next?.serverNodeId ||
          previous?.serverUrl != next?.serverUrl) {
        _log.info(
          'Project changed (id: ${previous?.id} -> ${next?.id}, '
          'serverNodeId: ${previous?.serverNodeId} -> ${next?.serverNodeId}), '
          'reconnecting global sync.',
        );
        _connectGlobal(ref.read(globalDatabaseProvider), next?.serverUrl);
      } else {
        _log.fine(
          'Project provider changed but no relevant fields differ, skipping reconnect.',
        );
      }
    });

    // Initial connection — only start global; project follows on success.
    final nodeId = ref.read(nodeIdProvider);
    _log.info('Initializing with nodeId: $nodeId');

    final project = ref.read(currentProjectProvider);
    _connectGlobal(ref.read(globalDatabaseProvider), project?.serverUrl);
  }

  Future<void> connectGlobal(String url) async {
    final db = ref.read(globalDatabaseProvider);
    await _connectGlobal(db, url, rethrowErrors: true);
  }

  /// Connects to a remote agent via SSH tunnel, syncs, discovers projects,
  /// and switches to the first matching project.
  ///
  /// [onStatus] is called with progress messages for UI display.
  /// Throws on failure.
  Future<void> connectViaTunnel(
    String tunnelId, {
    void Function(String message)? onStatus,
  }) async {
    _tunnelConnectInProgress = true;
    try {
      onStatus?.call('Establishing SSH tunnel...');
      await reconnectGlobal(
        connectionInfo: {'type': 'tunnel', 'tunnelId': tunnelId},
      );

      onStatus?.call('Waiting for global sync...');
      await waitForGlobalSync();

      onStatus?.call('Checking projects...');
      final serverNodeId = _currentServerNodeId;
      if (serverNodeId == null) {
        throw Exception('Server did not provide a node ID.');
      }

      // If the current project already belongs to this server, skip discovery.
      final currentProject = ref.read(currentProjectProvider);
      if (currentProject != null &&
          currentProject.serverNodeId == serverNodeId) {
        _log.info(
          'Current project ${currentProject.id} already belongs to server $serverNodeId, skipping discovery.',
        );
        onStatus?.call('Syncing project data...');
        await Future.delayed(const Duration(milliseconds: 200));
        await waitForProjectSync();
        return;
      } else {
        _log.info(
          'No current project matches server $serverNodeId '
          '(current: ${currentProject?.serverNodeId}), proceeding with discovery.',
        );
      }

      final globalDb = ref.read(globalDatabaseProvider);
      List<ProjectEntity> matchingProjects = [];

      // Poll for projects for up to 10 seconds.
      for (int i = 0; i < 20; i++) {
        matchingProjects = await globalDb.projectDao.getProjectsByServerNodeId(
          serverNodeId,
        );
        if (matchingProjects.isNotEmpty) {
          _log.info(
            'Found ${matchingProjects.length} project(s) for server $serverNodeId after ${i + 1} poll(s).',
          );
          break;
        }
        _log.fine('No projects for $serverNodeId yet, poll ${i + 1}/20...');
        onStatus?.call('Waiting for projects to sync... (${i + 1}/20)');
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (matchingProjects.isEmpty) {
        _log.info(
          'No projects found for server $serverNodeId after polling, '
          'emitting NoProjectsForServer event.',
        );
        _appEventBus.emit(
          NoProjectsForServer(
            serverNodeId,
            connectionInfo: _currentGlobalConnectionInfo,
          ),
        );
        return;
      }

      // Switch to the first matching project.
      final targetProject = matchingProjects.first;
      onStatus?.call('Switching to project ${targetProject.name}...');
      await ref
          .read(currentProjectIdProvider.notifier)
          .select(targetProject.id);

      onStatus?.call('Waiting for project sync...');
      await Future.delayed(const Duration(milliseconds: 200));
      await waitForProjectSync();
    } finally {
      _tunnelConnectInProgress = false;
    }
  }

  /// Forces a global sync reconnect.
  ///
  /// When [connectionInfo] is provided (e.g. `{'type': 'tunnel', 'tunnelId': '...'}`),
  /// it is used directly for the connection — no saved mapping is required.
  /// This is the bootstrap path used by the connect dialog before any
  /// mappings exist. The `mapIncomingChangeset` callback will auto-save
  /// mappings for discovered projects after sync.
  Future<void> reconnectGlobal({Map<String, dynamic>? connectionInfo}) async {
    _disconnectGlobal();
    _closeProjectConnection();
    final db = ref.read(globalDatabaseProvider);
    final project = ref.read(currentProjectProvider);
    await _connectGlobal(
      db,
      project?.serverUrl,
      rethrowErrors: true,
      bootstrapConnectionInfo: connectionInfo,
    );
  }

  Future<void> _connectGlobal(
    GlobalDatabase db,
    String? serverUrl, {
    bool rethrowErrors = false,
    Map<String, dynamic>? bootstrapConnectionInfo,
  }) async {
    final _ResolvedConnection resolved;
    if (bootstrapConnectionInfo != null) {
      // Bootstrap mode: use provided connection info directly (no saved
      // mapping needed). Used by the connect dialog for first-time setup.
      _log.info('Using bootstrap connection info: $bootstrapConnectionInfo');
      resolved = _resolvedConnectionFromInfo(bootstrapConnectionInfo);
    } else {
      final project = ref.read(currentProjectProvider);
      if (project == null) {
        _log.info(
          'No current project, skipping connection resolution and global sync.',
        );
        return;
      }
      final currentProjectId = project.id;
      resolved = await _resolveConnectionSettings(
        projectId: currentProjectId,
        serverUrlFallback: serverUrl,
      );
    }

    // Build dedup key from resolved connection details.
    final connectionKey = resolved.tunnelId != null
        ? 'tunnel:${resolved.tunnelId}'
        : 'url:${resolved.directUrl}';

    if (connectionKey == _currentGlobalConnectionKey && _globalSync != null) {
      _log.fine(
        'Global sync already connected with key $connectionKey, skipping.',
      );
      return;
    }

    _disconnectGlobal();
    _currentGlobalConnectionKey = connectionKey;
    _currentGlobalConnectionInfo = resolved.connectionInfo;

    if (resolved.tunnelId == null && resolved.directUrl == null) {
      _log.warning('No connection details for global sync.');
      return;
    }

    try {
      // Ensure DB is open so that crdt instance is available
      await db.customSelect('SELECT 1;').get();

      final crdt = db.crdt;
      _globalAdapter = CrdtFlowAdapter(crdt);

      _log.info(
        'Connecting to global sync via ${resolved.tunnelId != null ? "tunnel:${resolved.tunnelId}" : resolved.directUrl}',
      );
      final WebSocketChannel channel;
      Map<String, String> responseHeaders = {};
      if (resolved.tunnelId != null) {
        final (wsChannel, tunnel, headers) = await _connectViaTunnel(
          tunnelId: resolved.tunnelId!,
          wsPath: '/sync/global',
          timeout: defaultConnectionTimeout,
          ensureServer: true,
        );
        channel = wsChannel;
        responseHeaders = headers;
        _globalSshTunnel = tunnel;
      } else {
        final uri = Uri.parse('${resolved.directUrl}/sync/global');
        final (wsChannel, headers) = await _connectWebSocketWithHeaders(
          uri,
          timeout: defaultConnectionTimeout,
        );
        channel = wsChannel;
        responseHeaders = headers;
      }

      // Read the server's CRDT node ID from the upgrade response header.
      // Headers are stored lowercased for case-insensitive lookup.
      final headerNodeId = responseHeaders[kNodeIdHeader.toLowerCase()];
      if (headerNodeId == null) {
        throw Exception(
          'Server did not send $kNodeIdHeader header on WebSocket upgrade',
        );
      }
      if (!isValidNodeId(headerNodeId)) {
        throw Exception(
          'Server returned invalid $kNodeIdHeader: $headerNodeId',
        );
      }
      _currentServerNodeId = headerNodeId;
      _globalReconnectAttempts = 0;
      _log.info('Discovered server node ID: $headerNodeId');
      _appEventBus.emit(GlobalSyncConnected(headerNodeId));

      _globalChannel = MultiplexedWebSocketChannel(
        channel,
        awaitSync: () => _globalAdapter!.onIdle,
      );
      _globalSubscription = _globalChannel!.onCustomMessage.listen((msg) {
        _log.fine('Global sync received custom message: $msg');
      });

      // Capture for closure — the connection details at connection time.
      final serverNodeId = _currentServerNodeId;
      final connInfo = _currentGlobalConnectionInfo;
      final mappingStorage = ref.read(connectionMappingStorageProvider);

      _globalSync = CrdtSync.client(
        _globalAdapter!,
        _globalChannel!,
        verbose: true,
        validateRecord: (table, record) {
          if (table == 'projects') {
            final remoteNodeId = record['server_node_id'] as String?;
            if (remoteNodeId != null) {
              // Reject if invalid format or belongs to a different server.
              final valid =
                  isValidNodeId(remoteNodeId) && remoteNodeId == serverNodeId;
              if (!valid) {
                _log.fine(
                  'validateRecord: rejecting project record — '
                  'server_node_id $remoteNodeId != expected $serverNodeId.',
                );
              }
              return valid;
            }
            // Transitional fallback: accept records with a server_url
            // if server_node_id is not yet set (pre-migration server).
            final remoteUrl = record['server_url'] as String?;
            if (remoteUrl != null && remoteUrl.isNotEmpty) {
              _log.fine(
                'validateRecord: accepting project record via transitional server_url fallback ($remoteUrl).',
              );
              return true;
            }
            _log.fine(
              'validateRecord: rejecting project record — no server_node_id or server_url.',
            );
            return false;
          }
          return true;
        },
        mapIncomingChangeset: (table, record) {
          // Auto-map: when we receive a project belonging to our server,
          // ensure a connection mapping exists. Fire-and-forget, idempotent.
          if (table == 'projects' && connInfo != null) {
            final remoteNodeId = record['server_node_id'] as String?;
            if (remoteNodeId == serverNodeId) {
              final projectId = record['id'] as String?;
              if (projectId != null) {
                _log.fine(
                  'mapIncomingChangeset: auto-saving connection mapping for project $projectId.',
                );
                mappingStorage.save(projectId, connInfo);
              } else {
                _log.fine(
                  'mapIncomingChangeset: project record for $serverNodeId has no id, skipping auto-map.',
                );
              }
            } else {
              _log.fine(
                'mapIncomingChangeset: project record server_node_id ($remoteNodeId) does not match server ($serverNodeId), skipping auto-map.',
              );
            }
          }
          return record;
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
                  // Primary filter: match by server_node_id
                  if (serverNodeId != null) {
                    final recordNodeId = record['server_node_id'] as String?;
                    if (recordNodeId == serverNodeId) return true;
                  }
                  // Transitional fallback: match by server_url
                  final recordUrl = record['server_url'] as String?;
                  return recordUrl != null && recordUrl == serverUrl;
                }).toList();

                if (filteredRecords.isEmpty) {
                  _log.fine(
                    'changesetBuilder: filtered out all ${records.length} project record(s) — none match server $serverNodeId.',
                  );
                  changeset.remove('projects');
                } else {
                  _log.fine(
                    'changesetBuilder: keeping ${filteredRecords.length}/${records.length} project record(s) for server $serverNodeId.',
                  );
                  changeset['projects'] = filteredRecords;
                }
              }
              return changeset;
            },
      );

      // Global sync connected — now connect project sync.
      _connectProjectIfReady();

      // After initial changeset exchange completes, emit idle event and
      // check whether any projects exist for this server.
      _globalAdapter!.onIdle.then((_) {
        final nodeId = _currentServerNodeId;
        if (nodeId != null) {
          _appEventBus.emit(GlobalSyncIdle(nodeId));
          _checkProjectsForServer();
        }
      });
    } catch (e, stackTrace) {
      _log.warning('Global DB sync connection error: $e, $stackTrace');
      if (rethrowErrors) rethrow;
      _scheduleGlobalReconnect();
    }
  }

  /// Connects project sync if global sync is up and a project DB is available.
  void _connectProjectIfReady() {
    if (_globalSync == null) return;
    final projectDb = ref.read(projectDatabaseProvider);
    final projectId = ref.read(currentProjectIdProvider);
    if (projectDb != null && projectId != null) {
      _connectProject(projectDb, projectId);
    }
  }

  /// Checks whether any projects exist for the current server after global
  /// sync reaches idle. If none exist, emits [NoProjectsForServer] so the UI
  /// can prompt the user to create one.
  Future<void> _checkProjectsForServer() async {
    final serverNodeId = _currentServerNodeId;
    if (serverNodeId == null) return;

    // Skip when connectViaTunnel is running — it has its own polling logic.
    if (_tunnelConnectInProgress) {
      _log.fine(
        '_checkProjectsForServer: skipping, tunnel connect in progress.',
      );
      return;
    }

    // Skip if the user already has a project selected.
    final currentProject = ref.read(currentProjectProvider);
    if (currentProject != null) {
      _log.fine(
        '_checkProjectsForServer: project ${currentProject.id} already selected, skipping.',
      );
      return;
    }

    final globalDb = ref.read(globalDatabaseProvider);

    // Poll briefly — the CRDT changeset with project data may not have been
    // merged yet when onIdle fires. Give sync up to 5 seconds.
    // HACK - Ideally onIdly really should work for us.
    List<ProjectEntity> projects = [];
    for (int i = 0; i < 10; i++) {
      projects = await globalDb.projectDao.getProjectsByServerNodeId(
        serverNodeId,
      );
      if (projects.isNotEmpty) {
        _log.fine(
          '_checkProjectsForServer: found ${projects.length} project(s) '
          'for server $serverNodeId after ${i + 1} poll(s).',
        );
        return;
      }
      // Re-check that we're still relevant before sleeping.
      if (_currentServerNodeId != serverNodeId) return;
      _log.fine('_checkProjectsForServer: no projects yet, poll ${i + 1}/10…');
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Still empty after polling — emit event so the UI can prompt.
    if (projects.isEmpty) {
      _log.info(
        '_checkProjectsForServer: no projects for server $serverNodeId '
        'after polling, emitting event.',
      );
      _appEventBus.emit(
        NoProjectsForServer(
          serverNodeId,
          connectionInfo: _currentGlobalConnectionInfo,
        ),
      );
    }
  }

  /// Resolves connection details for a project: checks the connection mapping
  /// first, then falls back to [serverUrlFallback] as a direct URL.
  Future<_ResolvedConnection> _resolveConnectionSettings({
    required String? projectId,
    required String? serverUrlFallback,
  }) async {
    if (projectId != null) {
      final mappingStorage = ref.read(connectionMappingStorageProvider);
      final mapping = await mappingStorage.get(projectId);
      if (mapping != null) {
        _log.fine(
          '_resolveConnectionSettings: found saved mapping for project $projectId: $mapping',
        );
        return _resolvedConnectionFromInfo(mapping);
      } else {
        _log.fine(
          '_resolveConnectionSettings: no saved mapping for project $projectId.',
        );
      }
    } else {
      _log.fine(
        '_resolveConnectionSettings: no projectId, skipping mapping lookup.',
      );
    }

    if (serverUrlFallback != null) {
      final cleanUrl = serverUrlFallback.endsWith('/')
          ? serverUrlFallback.substring(0, serverUrlFallback.length - 1)
          : serverUrlFallback;
      _log.fine(
        '_resolveConnectionSettings: using serverUrl fallback: $cleanUrl',
      );
      return _ResolvedConnection(
        directUrl: cleanUrl,
        connectionInfo: {'type': 'url', 'url': cleanUrl},
      );
    }

    _log.fine('_resolveConnectionSettings: no connection details resolved.');
    return const _ResolvedConnection();
  }

  /// Converts a connection info map (e.g. `{'type': 'tunnel', 'tunnelId': '...'}`)
  /// to a [_ResolvedConnection].
  _ResolvedConnection _resolvedConnectionFromInfo(Map<String, dynamic> info) {
    if (info['type'] == 'tunnel') {
      _log.fine('_resolvedConnectionFromInfo: tunnel id=${info['tunnelId']}');
      return _ResolvedConnection(
        tunnelId: info['tunnelId'] as String?,
        connectionInfo: info,
      );
    } else if (info['type'] == 'url') {
      _log.fine('_resolvedConnectionFromInfo: direct url=${info['url']}');
      return _ResolvedConnection(
        directUrl: info['url'] as String?,
        connectionInfo: info,
      );
    }
    _log.warning(
      '_resolvedConnectionFromInfo: unrecognised connection type "${info['type']}", returning empty resolution.',
    );
    return _ResolvedConnection(connectionInfo: info);
  }

  Future<void> _connectProject(ProjectDatabase db, String projectId) async {
    // Project sync requires global sync to be connected first.
    if (_globalSync == null) {
      _log.info(
        'Skipping project sync for $projectId — global sync not connected.',
      );
      return;
    }

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

      final resolved = await _resolveConnectionSettings(
        projectId: projectId,
        serverUrlFallback: null,
      );

      // For project sync, also try serverUrl from the project record.
      String? tunnelId = resolved.tunnelId;
      String? directUrl = resolved.directUrl;
      if (tunnelId == null && directUrl == null) {
        final project = await ref
            .read(databaseProvider)
            .projectDao
            .getProject(projectId);

        if (token.isCancelled) {
          _log.fine(
            '_connectProject: cancelled after project lookup for $projectId.',
          );
          return;
        }

        final serverUrl = project?.serverUrl;
        if (serverUrl != null) {
          directUrl = serverUrl.endsWith('/')
              ? serverUrl.substring(0, serverUrl.length - 1)
              : serverUrl;
          _log.fine('_connectProject: using serverUrl fallback: $directUrl');
        } else {
          _log.fine(
            '_connectProject: no serverUrl on project record for $projectId.',
          );
        }
      }

      if (tunnelId == null && directUrl == null) {
        _log.info(
          'No connection details for project $projectId. Skipping sync.',
        );
        return;
      }

      final crdt = db.crdt;
      _projectAdapter = CrdtFlowAdapter(crdt);

      _log.info(
        'Connecting to project sync for $projectId via '
        '${tunnelId != null ? "tunnel:$tunnelId" : directUrl}',
      );
      _updateConnectionState(SyncConnectionState.connecting);

      final WebSocketChannel wsChannel;
      if (tunnelId != null) {
        if (token.isCancelled) {
          _log.fine(
            '_connectProject: cancelled before tunnel connect for $projectId.',
          );
          return;
        }
        _log.info(
          '_connectProject: connecting via SSH tunnel $tunnelId for $projectId.',
        );
        final (ch, tunnel, _) = await _connectViaTunnel(
          tunnelId: tunnelId,
          wsPath: '/sync/project/$projectId',
          ensureServer: false,
        );
        wsChannel = ch;
        _projectSshTunnel = tunnel;
      } else {
        _log.info(
          '_connectProject: connecting via direct WebSocket to $directUrl for $projectId.',
        );
        final uri = Uri.parse('$directUrl/sync/project/$projectId');
        wsChannel = _connectWebSocket(uri);
      }
      final monitoredChannel = _ActivityMonitorWebSocketChannel(
        wsChannel,
        onActivity: _handleSyncActivity,
        onDisconnect: () {
          // If this connection attempt was cancelled/superseded, ignore disconnect
          if (token.isCancelled) {
            _log.info(
              'Ignoring disconnect for cancelled connection attempt for $projectId',
            );
            return;
          }
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
          _log.fine(
            '_connectProject: cancelled after channel ready for $projectId, closing.',
          );
          monitoredChannel.sink.close();
          return;
        }
        _updateConnectionState(SyncConnectionState.connected);
        // Reset reconnect attempts only after a stable connection duration (5s)
        // to prevent rapid reconnect loops if connection is flapping.
        Future.delayed(const Duration(seconds: 5), () {
          if (!token.isCancelled &&
              _currentProjectId == projectId &&
              _currentConnectionState == SyncConnectionState.connected) {
            _log.fine(
              '_connectProject: connection stable for 5s, resetting reconnect attempts.',
            );
            _reconnectAttempts = 0;
          } else {
            _log.fine(
              '_connectProject: stability check skipped '
              '(cancelled=${token.isCancelled}, '
              'currentProject=$_currentProjectId, '
              'state=$_currentConnectionState).',
            );
          }
        });
      } catch (e) {
        if (token.isCancelled) {
          _log.fine(
            '_connectProject: cancelled after connection failure for $projectId.',
          );
          return;
        }
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
        verbose: false,
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
    } catch (e, stackTrace) {
      if (token.isCancelled) return;
      _log.severe('Project DB sync connection error: $e', stackTrace);
      _scheduleReconnect();
    }
  }

  void _disconnectGlobal() {
    final wasConnected = _currentServerNodeId != null;
    _globalReconnectTimer?.cancel();
    _globalReconnectTimer = null;
    _globalSync?.close();
    _globalSync = null;
    _globalChannel = null;
    _globalSubscription?.cancel();
    _globalSubscription = null;
    _currentGlobalConnectionKey = null;
    _currentGlobalConnectionInfo = null;
    _currentServerNodeId = null;
    _globalSshTunnel?.close();
    _globalSshTunnel = null;
    if (wasConnected) {
      _appEventBus.emit(const GlobalSyncDisconnected());
    }
  }

  void _scheduleGlobalReconnect() {
    if (_globalReconnectTimer?.isActive ?? false) {
      _log.fine('_scheduleGlobalReconnect: timer already active, skipping.');
      return;
    }

    final delaySeconds = _getFibonacciDelay(_globalReconnectAttempts);
    _log.info(
      'Scheduling global reconnect in $delaySeconds seconds '
      '(attempt $_globalReconnectAttempts)...',
    );

    _globalReconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _globalReconnectAttempts++;
      final project = ref.read(currentProjectProvider);
      _connectGlobal(ref.read(globalDatabaseProvider), project?.serverUrl);
    });
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) {
      _log.fine('_scheduleReconnect: timer already active, skipping.');
      return;
    }
    if (_currentProjectId == null || _currentProjectDb == null) {
      _log.fine('_scheduleReconnect: no active project, skipping.');
      return;
    }

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
    _projectSshTunnel?.close();
    _projectSshTunnel = null;
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

  /// Handle app lifecycle state changes.
  /// On macOS, connections stay alive through inactive/hidden states.
  /// Only reconnect when transitioning from paused->resumed (mobile scenario).
  /// For system sleep/wake, rely on pingInterval timeout to detect dead connections.
  void _handleLifecycleStateChange(AppLifecycleState state) {
    _log.info('App lifecycle state: $_lastLifecycleState -> $state');

    // On macOS: resumed, inactive, and hidden all keep connections alive
    // Only paused (mobile-only) indicates actual suspension
    if (state == AppLifecycleState.resumed &&
        _lastLifecycleState == AppLifecycleState.paused) {
      _log.info('App resumed from paused state, reconnecting');
      _reconnectAll();
    } else {
      _log.fine(
        'App lifecycle transition $state does not require reconnect '
        '(previous: $_lastLifecycleState).',
      );
    }

    _lastLifecycleState = state;
  }

  void _reconnectAll() {
    // Force reconnect global sync — project sync follows automatically
    // via _connectProjectIfReady() at the end of a successful _connectGlobal.
    if (_currentGlobalConnectionKey != null) {
      _log.info(
        '_reconnectAll: forcing reconnect for key $_currentGlobalConnectionKey.',
      );
      _disconnectGlobal();
      _closeProjectConnection();
      _reconnectAttempts = 0;
      _globalReconnectAttempts = 0;
      final project = ref.read(currentProjectProvider);
      _connectGlobal(ref.read(globalDatabaseProvider), project?.serverUrl);
    } else {
      _log.fine(
        '_reconnectAll: no active global connection key, nothing to reconnect.',
      );
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

  /// Looks up a tunnel config from [SshTunnelStorage] and connects via SSH.
  /// Connects a WebSocket tunneled through SSH, returning the channel,
  /// tunnel handle, and the HTTP upgrade response headers.
  Future<(WebSocketChannel, _SshTunnel, Map<String, String>)>
  _connectViaTunnel({
    required String tunnelId,
    required String wsPath,
    Duration? timeout,
    bool ensureServer = true,
  }) async {
    final storage = ref.read(sshTunnelStorageProvider);
    final settings = await storage.get(tunnelId);
    if (settings == null) {
      throw Exception('Tunnel config not found for id: $tunnelId');
    }
    final password = await storage.getPassword(tunnelId);
    final privateKey = await storage.getPrivateKey(tunnelId);
    final passphrase = await storage.getPassphrase(tunnelId);

    return _connectSshWebSocket(
      sshHost: settings.host,
      sshPort: settings.port,
      sshUsername: settings.username,
      sshPassword: password,
      sshPrivateKey: privateKey,
      sshPassphrase: passphrase,
      wsPath: wsPath,
      timeout: timeout,
      ensureServer: ensureServer,
    );
  }

  /// Create a WebSocket channel tunneled through SSH to a remote Unix socket.
  ///
  /// 1. Connect SSH to [sshHost] as [sshUsername]
  /// 2. Discover remote home directory via `echo \$HOME`
  /// 3. Open a `direct-streamlocal` channel to `$HOME/.fewshell/agent.sock`
  /// 4. Bind a local TCP proxy that pipes to the SSH forward
  /// 5. Connect a WebSocket through the local proxy
  ///
  /// The [wsPath] (e.g. `/sync/global`) is appended to the WebSocket URL.
  Future<(WebSocketChannel, _SshTunnel, Map<String, String>)>
  _connectSshWebSocket({
    required String sshHost,
    required int sshPort,
    required String sshUsername,
    String? sshPassword,
    String? sshPrivateKey,
    String? sshPassphrase,
    required String wsPath,
    Duration? timeout,
    bool ensureServer = true,
  }) async {
    _log.info('SSH tunnel: connecting to $sshUsername@$sshHost:$sshPort');

    final sshSocket = await SSHSocket.connect(
      sshHost,
      sshPort,
      timeout: const Duration(seconds: 30),
    );

    List<SSHKeyPair>? identities;
    if (sshPrivateKey != null && sshPrivateKey.isNotEmpty) {
      _log.fine('SSH tunnel: loading private key for authentication.');
      identities = SSHKeyPair.fromPem(sshPrivateKey, sshPassphrase);
    } else {
      _log.fine(
        'SSH tunnel: no private key provided, relying on password/agent auth.',
      );
    }

    final client = SSHClient(
      sshSocket,
      username: sshUsername,
      identities: identities,
      onPasswordRequest: sshPassword != null && sshPassword.isNotEmpty
          ? () => sshPassword
          : null,
    );

    await client.authenticated;
    _log.info('SSH tunnel: authenticated');

    // Ensure the fewshell server is installed and running (global only).
    if (ensureServer) {
      final installer = RemoteInstaller(client);
      try {
        await installer.ensureServerRunning();
      } finally {
        installer.dispose();
      }
    }

    // Discover remote home directory
    final homeSession = await client.execute('echo \$HOME');
    final homeOutput = StringBuffer();
    await for (final data in homeSession.stdout) {
      homeOutput.write(utf8.decode(data));
    }
    await homeSession.done;
    final remoteHome = homeOutput.toString().trim();
    if (remoteHome.isEmpty) {
      client.close();
      throw Exception('SSH tunnel: failed to discover remote home directory');
    }
    final socketPath = '$remoteHome/.fewshell/agent.sock';
    _log.info('SSH tunnel: forwarding to $socketPath');

    // Bind local TCP proxy
    final serverSocket = await ServerSocket.bind('localhost', 0);
    final localPort = serverSocket.port;

    serverSocket.listen((tcpSocket) async {
      _log.fine(
        'SSH tunnel: new TCP proxy connection from ${tcpSocket.remoteAddress.address}:${tcpSocket.remotePort}.',
      );
      try {
        final forward = await client.forwardLocalUnix(socketPath);
        forward.stream.cast<List<int>>().pipe(tcpSocket);
        tcpSocket.cast<List<int>>().pipe(forward.sink);
      } catch (e) {
        _log.warning('SSH tunnel: proxy connection failed: $e');
        tcpSocket.destroy();
      }
    });

    _log.info('SSH tunnel: local proxy on localhost:$localPort');

    // Connect WebSocket through the proxy — use manual upgrade to capture
    // response headers (e.g. X-Fewshell-Server-Node-Id).
    final wsUri = Uri.parse('ws://localhost:$localPort$wsPath');
    final (wsChannel, headers) = await _connectWebSocketWithHeaders(
      wsUri,
      timeout: timeout,
      useMtls: false,
    );

    final tunnel = _SshTunnel(client, serverSocket);
    return (wsChannel, tunnel, headers);
  }

  /// Creates an [HttpClient] configured with mTLS using embedded certificates.
  HttpClient _createMtlsClient() {
    final context = SecurityContext(withTrustedRoots: false)
      ..useCertificateChainBytes(utf8.encode(clientCert))
      ..usePrivateKeyBytes(utf8.encode(clientKey))
      ..setTrustedCertificatesBytes(utf8.encode(caCert));

    if (kDebugMode) {
      HttpClient.enableTimelineLogging = true;
    }

    final client = HttpClient(context: context);
    client.badCertificateCallback = _verifyCertificate;
    return client;
  }

  /// Certificate verification callback for mTLS connections.
  ///
  /// SecurityContext validates the chain; this callback logs details and
  /// pins by subject/issuer + DER comparison.
  bool _verifyCertificate(X509Certificate cert, String host, int port) {
    _log.warning('Certificate verification failed for $host:$port');
    _log.warning('Subject: ${cert.subject}');
    _log.warning('Issuer: ${cert.issuer}');

    final isServerCert =
        cert.subject.contains('localhost') && cert.issuer.contains('Decamp CA');

    final isCaCert =
        cert.subject.contains('Decamp CA') && cert.issuer.contains('Decamp CA');

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
        final endMarker = '-----END CERTIFICATE-----';
        final endIndex = serverCert.indexOf(endMarker);
        if (endIndex == -1) {
          throw FormatException('Invalid serverCert format');
        }
        pemToCompare = serverCert.substring(0, endIndex + endMarker.length);
      } else {
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
  }

  WebSocketChannel _connectWebSocket(Uri uri, {Duration? timeout}) {
    _log.info('_connectWebSocket called for $uri with timeout: $timeout');

    try {
      _log.info('Configuring mTLS with embedded certificates');
      final client = _createMtlsClient();

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

  /// Connects a WebSocket with a manual HTTP upgrade, returning both the
  /// channel and the server's response headers.
  ///
  /// Used for global sync connections where we need to read the
  /// `X-Fewshell-Server-Node-Id` header from the upgrade response.
  /// When [useMtls] is false (e.g. tunnel connections through a local proxy),
  /// a plain [HttpClient] is used instead.
  Future<(WebSocketChannel, Map<String, String>)> _connectWebSocketWithHeaders(
    Uri uri, {
    Duration? timeout,
    bool useMtls = true,
  }) async {
    _log.info(
      '_connectWebSocketWithHeaders called for $uri '
      '(mTLS: $useMtls, timeout: $timeout)',
    );

    final httpClient = useMtls ? _createMtlsClient() : HttpClient();
    if (timeout != null) {
      httpClient.connectionTimeout = timeout;
    }

    try {
      // Convert ws/wss scheme to http/https for the upgrade request.
      final httpUri = uri.replace(
        scheme: uri.scheme == 'wss' ? 'https' : 'http',
      );

      final request = await httpClient.openUrl('GET', httpUri);

      // Standard WebSocket upgrade headers (RFC 6455 §4.1).
      final nonce = base64.encode(
        List<int>.generate(16, (_) => Random.secure().nextInt(256)),
      );
      request.headers
        ..set('Connection', 'Upgrade')
        ..set('Upgrade', 'websocket')
        ..set('Sec-WebSocket-Version', '13')
        ..set('Sec-WebSocket-Key', nonce);

      final response = await request.close();

      if (response.statusCode != HttpStatus.switchingProtocols) {
        // Drain the response body to free resources.
        await response.drain<void>();
        throw WebSocketException(
          'WebSocket upgrade failed with status ${response.statusCode}',
        );
      }

      // Collect response headers (lowercased keys for case-insensitive lookup).
      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        responseHeaders[name.toLowerCase()] = values.join(', ');
      });

      // Detach the raw socket and wrap it as a WebSocket.
      final socket = await response.detachSocket();
      final ws = WebSocket.fromUpgradedSocket(socket, serverSide: false);
      ws.pingInterval = const Duration(seconds: 10);
      final channel = IOWebSocketChannel(ws);

      _log.info(
        'WebSocket connected with headers: '
        '${responseHeaders.keys.join(', ')}',
      );

      return (channel as WebSocketChannel, responseHeaders);
    } catch (e, st) {
      httpClient.close();
      _log.severe('Error in _connectWebSocketWithHeaders', e, st);
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
          _log.warning(
            'ActivityMonitor: Stream error detected',
            error,
            stackTrace,
          );
          onDisconnect();
          sink.addError(error, stackTrace);
        },
        handleDone: (sink) {
          _log.info('ActivityMonitor: Stream done (closed by remote or local)');
          if (_inner.closeCode != null) {
            _log.info(
              'Close Code: ${_inner.closeCode}, Reason: ${_inner.closeReason}',
            );
          }
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

/// Result of [SyncService._resolveConnectionSettings].
class _ResolvedConnection {
  final String? tunnelId;
  final String? directUrl;
  final Map<String, dynamic>? connectionInfo;

  const _ResolvedConnection({
    this.tunnelId,
    this.directUrl,
    this.connectionInfo,
  });
}

/// Holds the resources for an SSH tunnel so they can be cleaned up together.
class _SshTunnel {
  final SSHClient client;
  final ServerSocket serverSocket;

  _SshTunnel(this.client, this.serverSocket);

  void close() {
    serverSocket.close();
    client.close();
  }
}
