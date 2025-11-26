import 'package:agent_core/agent_core.dart';

/// Service for securely storing and retrieving secrets using platform keychain.
/// Uses iOS Keychain on iOS and Android Keystore on Android.
class KeychainService {
  final SecureStorage _storage;

  KeychainService(this._storage);

  /// Save a secret value with the given key.
  /// Overwrites existing value if key already exists.
  Future<void> saveSecret(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Retrieve a secret value by key.
  /// Returns null if key doesn't exist.
  Future<String?> getSecret(String key) async {
    return await _storage.read(key: key);
  }

  /// Delete a secret by key.
  /// No-op if key doesn't exist.
  Future<void> deleteSecret(String key) async {
    await _storage.delete(key: key);
  }

  /// List all secret keys stored.
  /// Returns empty map if no secrets exist.
  Future<Map<String, String>> listAllSecrets() async {
    return await _storage.readAll();
  }

  /// Delete all secrets.
  /// Use with caution - this cannot be undone.
  Future<void> deleteAllSecrets() async {
    await _storage.deleteAll();
  }

  /// Check if a secret exists for the given key.
  Future<bool> hasSecret(String key) async {
    final value = await getSecret(key);
    return value != null;
  }

  /// Save a project-scoped secret.
  /// Key format: "project:{projectId}:{secretName}"
  Future<void> saveProjectSecret(
    String projectId,
    String secretName,
    String value,
  ) async {
    final key = _buildProjectSecretKey(projectId, secretName);
    await saveSecret(key, value);
  }

  /// Retrieve a project-scoped secret.
  Future<String?> getProjectSecret(String projectId, String secretName) async {
    final key = _buildProjectSecretKey(projectId, secretName);
    return await getSecret(key);
  }

  /// Delete a project-scoped secret.
  Future<void> deleteProjectSecret(String projectId, String secretName) async {
    final key = _buildProjectSecretKey(projectId, secretName);
    await deleteSecret(key);
  }

  /// List all secrets for a specific project.
  /// Returns map of secret names to values.
  Future<Map<String, String>> listProjectSecrets(String projectId) async {
    final allSecrets = await listAllSecrets();
    final projectPrefix = 'project:$projectId:';

    final projectSecrets = <String, String>{};
    for (final entry in allSecrets.entries) {
      if (entry.key.startsWith(projectPrefix)) {
        // Extract secret name from key
        final secretName = entry.key.substring(projectPrefix.length);
        projectSecrets[secretName] = entry.value;
      }
    }

    return projectSecrets;
  }

  /// Delete all secrets for a specific project.
  Future<void> deleteAllProjectSecrets(String projectId) async {
    final projectSecrets = await listProjectSecrets(projectId);
    for (final secretName in projectSecrets.keys) {
      await deleteProjectSecret(projectId, secretName);
    }
  }

  /// Save a global (non-project-specific) secret.
  /// Key format: "global:{secretName}"
  Future<void> saveGlobalSecret(String secretName, String value) async {
    final key = _buildGlobalSecretKey(secretName);
    await saveSecret(key, value);
  }

  /// Retrieve a global secret.
  Future<String?> getGlobalSecret(String secretName) async {
    final key = _buildGlobalSecretKey(secretName);
    return await getSecret(key);
  }

  /// Delete a global secret.
  Future<void> deleteGlobalSecret(String secretName) async {
    final key = _buildGlobalSecretKey(secretName);
    await deleteSecret(key);
  }

  /// List all global secrets.
  Future<Map<String, String>> listGlobalSecrets() async {
    final allSecrets = await listAllSecrets();
    const globalPrefix = 'global:';

    final globalSecrets = <String, String>{};
    for (final entry in allSecrets.entries) {
      if (entry.key.startsWith(globalPrefix)) {
        // Extract secret name from key
        final secretName = entry.key.substring(globalPrefix.length);
        globalSecrets[secretName] = entry.value;
      }
    }

    return globalSecrets;
  }

  // Private helper methods

  String _buildProjectSecretKey(String projectId, String secretName) {
    return 'project:$projectId:$secretName';
  }

  String _buildGlobalSecretKey(String secretName) {
    return 'global:$secretName';
  }
}
