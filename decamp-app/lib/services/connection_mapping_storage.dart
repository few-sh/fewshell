import 'dart:convert';
import 'package:agent_core/agent_core.dart';

/// Client-only storage for project → connection mappings.
///
/// Maps each project to its connection method (SSH tunnel or direct URL).
/// Stored in [SecureStorage], bypassing CRDT replication — connection
/// details are local to each device.
///
/// Key scheme: `connectionMap:<projectId>` → JSON connection info.
///
/// Connection info shapes:
/// - Tunnel: `{ "type": "tunnel", "tunnelId": "<uuid>" }`
/// - Direct: `{ "type": "url", "url": "wss://..." }`
class ConnectionMappingStorage {
  final SecureStorage _storage;

  static const _prefix = 'connectionMap:';

  ConnectionMappingStorage(this._storage);

  /// Saves the connection mapping for [projectId].
  Future<void> save(
    String projectId,
    Map<String, dynamic> connectionInfo,
  ) async {
    await _storage.write(
      key: '$_prefix$projectId',
      value: jsonEncode(connectionInfo),
    );
  }

  /// Returns the connection mapping for [projectId], or null.
  Future<Map<String, dynamic>?> get(String projectId) async {
    final raw = await _storage.read(key: '$_prefix$projectId');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Deletes the connection mapping for [projectId].
  Future<void> delete(String projectId) async {
    await _storage.delete(key: '$_prefix$projectId');
  }

  /// Returns all connection mappings as projectId → connectionInfo.
  Future<Map<String, Map<String, dynamic>>> listAll() async {
    final all = await _storage.readAll();
    final result = <String, Map<String, dynamic>>{};
    for (final entry in all.entries) {
      if (!entry.key.startsWith(_prefix)) continue;
      final projectId = entry.key.substring(_prefix.length);
      try {
        final json = jsonDecode(entry.value) as Map<String, dynamic>;
        result[projectId] = json;
      } catch (_) {
        // Skip malformed entries
      }
    }
    return result;
  }
}
