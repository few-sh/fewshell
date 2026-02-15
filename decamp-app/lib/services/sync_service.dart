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
import 'package:decamp/providers/providers.dart';
import 'package:decamp/providers/ssh_tunnel_provider.dart';

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
  String? _currentGlobalUrl;

  _SshTunnel? _globalSshTunnel;
  _SshTunnel? _projectSshTunnel;

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
  String? _currentProjectId;
  ProjectDatabase? _currentProjectDb;
  _CancellationToken? _connectionToken;
  int _reconnectAttempts = 0;
  AppLifecycleListener? _lifecycleListener;
  AppLifecycleState? _lastLifecycleState;

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

      _log.info('Connecting to global sync at $cleanUrl');
      final tunnelId = parseTunnelId(cleanUrl);
      final WebSocketChannel channel;
      Map<String, String> responseHeaders = {};
      if (tunnelId != null) {
        final (wsChannel, tunnel, headers) = await _connectViaTunnel(
          tunnelId: tunnelId,
          wsPath: '/sync/global',
          timeout: defaultConnectionTimeout,
        );
        channel = wsChannel;
        responseHeaders = headers;
        _globalSshTunnel = tunnel;
      } else {
        final uri = Uri.parse('$cleanUrl/sync/global');
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
      _log.info('Discovered server node ID: $headerNodeId');

      _globalChannel = MultiplexedWebSocketChannel(
        channel,
        awaitSync: () => _globalAdapter!.onIdle,
      );
      _globalSubscription = _globalChannel!.onCustomMessage.listen((msg) {
        _log.fine('Global sync received custom message: $msg');
      });

      // Capture for closure — the server node ID at connection time.
      final serverNodeId = _currentServerNodeId;

      _globalSync = CrdtSync.client(
        _globalAdapter!,
        _globalChannel!,
        verbose: true,
        validateRecord: (table, record) {
          if (table == 'projects') {
            final remoteNodeId = record['server_node_id'] as String?;
            // Primary check: valid server_node_id
            if (remoteNodeId != null) {
              return isValidNodeId(remoteNodeId);
            }
            // Transitional fallback: accept records with a server_url
            // if server_node_id is not yet set (pre-migration server).
            final remoteUrl = record['server_url'] as String?;
            if (remoteUrl != null && remoteUrl.isNotEmpty) return true;
            return false;
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
                  changeset.remove('projects');
                } else {
                  changeset['projects'] = filteredRecords;
                }
              }
              return changeset;
            },
      );
    } catch (e, stackTrace) {
      _log.warning('Global DB sync connection error: $e, $stackTrace');
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

      _log.info('Connecting to project sync for $projectId');
      _updateConnectionState(SyncConnectionState.connecting);

      final WebSocketChannel wsChannel;
      final tunnelId = parseTunnelId(serverUrl);
      if (tunnelId != null) {
        if (token.isCancelled) return;
        final (ch, tunnel, _) = await _connectViaTunnel(
          tunnelId: tunnelId,
          wsPath: '/sync/project/$projectId',
        );
        wsChannel = ch;
        _projectSshTunnel = tunnel;
      } else {
        final uri = Uri.parse('$serverUrl/sync/project/$projectId');
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
            _reconnectAttempts = 0;
          }
        });
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
    } catch (e, stackTrace) {
      if (token.isCancelled) return;
      _log.severe('Project DB sync connection error: $e', stackTrace);
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
    _currentServerNodeId = null;
    _globalSshTunnel?.close();
    _globalSshTunnel = null;
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
    }

    _lastLifecycleState = state;
  }

  void _reconnectAll() {
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

  /// Looks up a tunnel config from [SshTunnelStorage] and connects via SSH.
  /// Connects a WebSocket tunneled through SSH, returning the channel,
  /// tunnel handle, and the HTTP upgrade response headers.
  Future<(WebSocketChannel, _SshTunnel, Map<String, String>)>
  _connectViaTunnel({
    required String tunnelId,
    required String wsPath,
    Duration? timeout,
  }) async {
    final storage = ref.read(sshTunnelStorageProvider);
    final settings = await storage.get(tunnelId);
    if (settings == null) {
      throw Exception('Tunnel config not found for id: $tunnelId');
    }
    final privateKey = await storage.getPrivateKey(tunnelId);
    final passphrase = await storage.getPassphrase(tunnelId);

    return _connectSshWebSocket(
      sshHost: settings.host,
      sshPort: settings.port,
      sshUsername: settings.username,
      sshPrivateKey: privateKey,
      sshPassphrase: passphrase,
      wsPath: wsPath,
      timeout: timeout,
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
    String? sshPrivateKey,
    String? sshPassphrase,
    required String wsPath,
    Duration? timeout,
  }) async {
    _log.info('SSH tunnel: connecting to $sshUsername@$sshHost:$sshPort');

    final sshSocket = await SSHSocket.connect(
      sshHost,
      sshPort,
      timeout: const Duration(seconds: 30),
    );

    List<SSHKeyPair>? identities;
    if (sshPrivateKey != null && sshPrivateKey.isNotEmpty) {
      identities = SSHKeyPair.fromPem(sshPrivateKey, sshPassphrase);
    }

    final client = SSHClient(
      sshSocket,
      username: sshUsername,
      identities: identities,
    );

    await client.authenticated;
    _log.info('SSH tunnel: authenticated');

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
