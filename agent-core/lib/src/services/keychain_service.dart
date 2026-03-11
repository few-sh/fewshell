import 'dart:async';
import 'package:agent_core/src/secrets_storage/secrets_storage.dart';
import 'package:agent_core/src/models/secret.dart';

/// Service for securely storing and retrieving secrets using platform keychain.
/// Uses iOS Keychain on iOS and Android Keystore on Android.
class KeychainService {
  final SecretsStorage _storage;
  final Stream<void>? _changeStream;

  /// Expose the change stream for external listeners
  Stream<void> get onChange => _changeStream ?? const Stream.empty();

  KeychainService(this._storage, {Stream<void>? changeStream})
      : _changeStream = changeStream;

  /// Save a secret value with the given key.
  /// Overwrites existing value if key already exists.
  Future<void> saveSecret(String key, String value) async {
    await _storage.write(key: key, value: Secret(value: value));
  }

  /// Save a secret object with the given key.
  Future<void> saveSecretObject(String key, Secret secret) async {
    await _storage.write(key: key, value: secret);
  }

  /// Retrieve a secret value by key.
  /// Returns null if key doesn't exist.
  Future<String?> getSecret(String key) async {
    final secret = await _storage.read(key: key);
    return secret?.value;
  }

  /// Retrieve a secret object by key.
  Future<Secret?> getSecretObject(String key) async {
    return await _storage.read(key: key);
  }

  /// Delete a secret by key.
  /// No-op if key doesn't exist.
  Future<void> deleteSecret(String key) async {
    await _storage.delete(key: key);
  }

  /// List all secret keys stored.
  /// Returns empty map if no secrets exist.
  Future<Map<String, Secret>> listAllSecrets() async {
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

  /// Save a project-scoped secret object.
  Future<void> saveProjectSecret(
    String projectId,
    String secretName,
    Secret secret,
  ) async {
    final key = _buildProjectSecretKey(projectId, secretName);
    await saveSecretObject(key, secret);
  }

  /// Retrieve a project-scoped secret.
  Future<String?> getProjectSecret(String projectId, String secretName) async {
    final key = _buildProjectSecretKey(projectId, secretName);
    return await getSecret(key);
  }

  /// Retrieve multiple project-scoped secrets by name.
  /// Returns a map of secret name to value for secrets that exist.
  Future<Map<String, String>> getProjectSecrets(
    String projectId,
    List<String> secretNames,
  ) async {
    final results = <String, String>{};
    for (final name in secretNames) {
      final value = await getProjectSecret(projectId, name);
      if (value != null) {
        results[name] = value;
      }
    }
    return results;
  }

  /// Retrieve a project-scoped secret object.
  Future<Secret?> getProjectSecretObject(
      String projectId, String secretName) async {
    final key = _buildProjectSecretKey(projectId, secretName);
    return await getSecretObject(key);
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
        projectSecrets[secretName] = entry.value.value;
      }
    }

    return projectSecrets;
  }

  /// List all secret objects for a specific project.
  Future<Map<String, Secret>> listProjectSecretObjects(String projectId) async {
    final allSecrets = await listAllSecrets();
    final projectPrefix = 'project:$projectId:';

    final projectSecrets = <String, Secret>{};
    for (final entry in allSecrets.entries) {
      if (entry.key.startsWith(projectPrefix)) {
        // Extract secret name from key
        final secretName = entry.key.substring(projectPrefix.length);
        projectSecrets[secretName] = entry.value;
      }
    }

    return projectSecrets;
  }

  /// Watch secrets for a specific project.
  /// Yields the list of secrets whenever a change occurs.
  Stream<Map<String, String>> watchProjectSecrets(String projectId) async* {
    // Yield initial value
    yield await listProjectSecrets(projectId);

    if (_changeStream != null) {
      await for (final _ in _changeStream) {
        yield await listProjectSecrets(projectId);
      }
    }
  }

  /// Watch secret objects for a specific project.
  Stream<Map<String, Secret>> watchProjectSecretObjects(
      String projectId) async* {
    // Yield initial value
    yield await listProjectSecretObjects(projectId);

    if (_changeStream != null) {
      await for (final _ in _changeStream) {
        yield await listProjectSecretObjects(projectId);
      }
    }
  }

  /// Delete all secrets for a specific project.
  Future<void> deleteAllProjectSecrets(String projectId) async {
    final projectSecrets = await listProjectSecrets(projectId);
    for (final secretName in projectSecrets.keys) {
      await deleteProjectSecret(projectId, secretName);
    }
  }

  /// Save a global (non-project-specific) secret object.
  Future<void> saveGlobalSecret(String secretName, Secret secret) async {
    final key = _buildGlobalSecretKey(secretName);
    await saveSecretObject(key, secret);
  }

  /// Retrieve a global secret.
  Future<String?> getGlobalSecret(String secretName) async {
    final key = _buildGlobalSecretKey(secretName);
    return await getSecret(key);
  }

  /// Retrieve a global secret object.
  Future<Secret?> getGlobalSecretObject(String secretName) async {
    final key = _buildGlobalSecretKey(secretName);
    return await getSecretObject(key);
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
        globalSecrets[secretName] = entry.value.value;
      }
    }

    return globalSecrets;
  }

  /// List all global secret objects.
  Future<Map<String, Secret>> listGlobalSecretObjects() async {
    final allSecrets = await listAllSecrets();
    const globalPrefix = 'global:';

    final globalSecrets = <String, Secret>{};
    for (final entry in allSecrets.entries) {
      if (entry.key.startsWith(globalPrefix)) {
        // Extract secret name from key
        final secretName = entry.key.substring(globalPrefix.length);
        globalSecrets[secretName] = entry.value;
      }
    }

    return globalSecrets;
  }

  /// Watch for changes and return a list of secret keys that are visible to LLM.
  /// Includes global secrets and project-specific secrets if projectId is provided.
  Stream<List<String>> watchVisibleSecretKeys({String? projectId}) async* {
    // Initial yield
    yield await _getVisibleKeys(projectId);

    if (_changeStream != null) {
      await for (final _ in _changeStream) {
        yield await _getVisibleKeys(projectId);
      }
    }
  }

  Future<List<String>> _getVisibleKeys(String? projectId) async {
    final allSecrets = await listAllSecrets();
    final visibleKeys = <String>{};
    final projectPrefix = projectId != null ? 'project:$projectId:' : null;
    const globalPrefix = 'global:';

    for (final entry in allSecrets.entries) {
      final key = entry.key;
      final secret = entry.value;

      if (!secret.isVisibleToLlm) continue;

      if (projectPrefix != null && key.startsWith(projectPrefix)) {
        visibleKeys.add(key.substring(projectPrefix.length));
      } else if (key.startsWith(globalPrefix)) {
        visibleKeys.add(key.substring(globalPrefix.length));
      }
    }

    return visibleKeys.toList()..sort();
  }

  // Private helper methods

  String _buildProjectSecretKey(String projectId, String secretName) {
    return 'project:$projectId:$secretName';
  }

  String _buildGlobalSecretKey(String secretName) {
    return 'global:$secretName';
  }
}
