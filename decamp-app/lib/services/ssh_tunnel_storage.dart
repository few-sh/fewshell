import 'dart:convert';
import 'package:agent_core/agent_core.dart';

/// Client-only storage for SSH tunnel configurations.
///
/// Stores tunnel configs in [SecureStorage] (FlutterSecureStorage) directly,
/// bypassing CRDT replication. Tunnel data never leaves the device.
///
/// Key scheme:
/// - `tunnelId:{id}` → JSON-encoded [SshSettings] metadata
/// - `tunnelId:{id}:privateKey` → private key PEM string
/// - `tunnelId:{id}:passphrase` → optional passphrase
class SshTunnelStorage {
  final SecureStorage _storage;

  static const _prefix = 'tunnelId:';

  SshTunnelStorage(this._storage);

  /// Returns all stored tunnel configs as a map of id → [SshSettings].
  Future<Map<String, SshSettings>> listAll() async {
    final all = await _storage.readAll();
    final result = <String, SshSettings>{};
    for (final entry in all.entries) {
      if (!entry.key.startsWith(_prefix)) continue;
      final suffix = entry.key.substring(_prefix.length);
      // Skip sub-keys like tunnelId:{id}:privateKey
      if (suffix.contains(':')) continue;
      try {
        final json = jsonDecode(entry.value) as Map<String, dynamic>;
        result[suffix] = SshSettings.fromJson(json);
      } catch (_) {
        // Skip malformed entries
      }
    }
    return result;
  }

  /// Returns the [SshSettings] for the given tunnel [id], or null.
  Future<SshSettings?> get(String id) async {
    final raw = await _storage.read(key: '$_prefix$id');
    if (raw == null) return null;
    try {
      return SshSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Saves a tunnel config. [id] is the tunnel UUID.
  Future<void> save({
    required String id,
    required SshSettings settings,
    String? privateKey,
    String? passphrase,
  }) async {
    await _storage.write(
      key: '$_prefix$id',
      value: jsonEncode(settings.toJson()),
    );
    if (privateKey != null && privateKey.isNotEmpty) {
      await _storage.write(key: '$_prefix$id:privateKey', value: privateKey);
    }
    if (passphrase != null && passphrase.isNotEmpty) {
      await _storage.write(key: '$_prefix$id:passphrase', value: passphrase);
    }
  }

  /// Deletes a tunnel config and its credential sub-keys.
  Future<void> delete(String id) async {
    await _storage.delete(key: '$_prefix$id');
    await _storage.delete(key: '$_prefix$id:privateKey');
    await _storage.delete(key: '$_prefix$id:passphrase');
  }

  /// Returns the private key for the given tunnel [id], or null.
  Future<String?> getPrivateKey(String id) async {
    return _storage.read(key: '$_prefix$id:privateKey');
  }

  /// Returns the passphrase for the given tunnel [id], or null.
  Future<String?> getPassphrase(String id) async {
    return _storage.read(key: '$_prefix$id:passphrase');
  }

  /// Finds an existing tunnel config matching [username]@[host].
  /// Returns the tunnel ID or null if no match.
  Future<String?> findByHostAndUsername(String host, String username) async {
    final all = await listAll();
    for (final entry in all.entries) {
      if (entry.value.host == host && entry.value.username == username) {
        return entry.key;
      }
    }
    return null;
  }
}
