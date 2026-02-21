import 'dart:async';
import 'package:agent_core/agent_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../services/ssh_tunnel_storage.dart';
import '../services/storage/flutter_secure_storage_impl.dart';
import 'providers.dart';

/// Singleton provider for [SshTunnelStorage].
final sshTunnelStorageProvider = Provider<SshTunnelStorage>((ref) {
  return SshTunnelStorage(FlutterSecureStorageImpl());
});

/// Notifier that manages SSH tunnel configs in FlutterSecureStorage.
///
/// Exposes CRUD methods and holds the current map of id → [SshSettings].
final sshTunnelConfigsProvider =
    AsyncNotifierProvider<SshTunnelConfigsNotifier, Map<String, SshSettings>>(
      SshTunnelConfigsNotifier.new,
    );

class SshTunnelConfigsNotifier extends AsyncNotifier<Map<String, SshSettings>> {
  @override
  Future<Map<String, SshSettings>> build() async {
    final storage = ref.watch(sshTunnelStorageProvider);
    return storage.listAll();
  }

  /// Creates a new tunnel config. Returns the generated tunnel ID.
  ///
  /// If an existing config matches the same [host] and [username],
  /// updates it instead and returns the existing ID.
  Future<String> create({
    required String host,
    required int port,
    required String username,
    SshAuthMethod authMethod = SshAuthMethod.privateKey,
    String? privateKey,
    String? passphrase,
  }) async {
    final storage = ref.read(sshTunnelStorageProvider);

    // Check for existing config with same host+username
    final existingId = await storage.findByHostAndUsername(host, username);
    final id = existingId ?? const Uuid().v4();

    final settings = SshSettings(
      host: host,
      port: port,
      username: username,
      authMethod: authMethod,
      enabled: true,
      createdAt: existingId == null ? DateTime.now() : null,
      updatedAt: DateTime.now(),
    );

    await storage.save(
      id: id,
      settings: settings,
      privateKey: privateKey,
      passphrase: passphrase,
    );

    // Refresh state
    state = AsyncData(await storage.listAll());
    return id;
  }

  /// Updates an existing tunnel config.
  Future<void> updateTunnel({
    required String id,
    required String host,
    required int port,
    required String username,
    SshAuthMethod authMethod = SshAuthMethod.privateKey,
    String? privateKey,
    String? passphrase,
  }) async {
    final storage = ref.read(sshTunnelStorageProvider);

    final existing = await storage.get(id);
    final settings = SshSettings(
      host: host,
      port: port,
      username: username,
      authMethod: authMethod,
      enabled: true,
      createdAt: existing?.createdAt,
      updatedAt: DateTime.now(),
    );

    await storage.save(
      id: id,
      settings: settings,
      privateKey: privateKey,
      passphrase: passphrase,
    );

    state = AsyncData(await storage.listAll());
  }

  /// Deletes a tunnel config and its credentials.
  Future<void> delete(String id) async {
    final storage = ref.read(sshTunnelStorageProvider);
    await storage.delete(id);
    state = AsyncData(await storage.listAll());
  }
}

/// Derives the tunnel config assigned to a project from its connection mapping.
///
/// Returns null if the project has no connection mapping or the mapping
/// is not of type `tunnel`.
final projectTunnelProvider = FutureProvider.family<SshSettings?, String>((
  ref,
  projectId,
) async {
  final connInfo = await ref.watch(projectConnectionInfoProvider(projectId).future);
  if (connInfo == null || connInfo['type'] != 'tunnel') return null;

  final tunnelId = connInfo['tunnelId'] as String?;
  if (tunnelId == null) return null;

  final storage = ref.watch(sshTunnelStorageProvider);
  return storage.get(tunnelId);
});
