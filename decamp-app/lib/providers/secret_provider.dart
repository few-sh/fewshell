import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/keychain_service.dart';

/// Provider for KeychainService singleton
final keychainServiceProvider = Provider<KeychainService>((ref) {
  return KeychainService();
});

/// Provider for global secrets actions
final globalSecretsProvider = Provider<GlobalSecretsActions>((ref) {
  final keychain = ref.watch(keychainServiceProvider);
  return GlobalSecretsActions(keychain);
});

/// Provider for project secrets actions (family provider)
final projectSecretsProvider = Provider.family<ProjectSecretsActions, String>((
  ref,
  projectId,
) {
  final keychain = ref.watch(keychainServiceProvider);
  return ProjectSecretsActions(keychain, projectId);
});

/// Actions for managing global secrets
class GlobalSecretsActions {
  final KeychainService _keychain;

  GlobalSecretsActions(this._keychain);

  /// Save a global secret
  Future<void> saveSecret(String secretName, String value) async {
    await _keychain.saveGlobalSecret(secretName, value);
  }

  /// Get a global secret
  Future<String?> getSecret(String secretName) async {
    return await _keychain.getGlobalSecret(secretName);
  }

  /// Delete a global secret
  Future<void> deleteSecret(String secretName) async {
    await _keychain.deleteGlobalSecret(secretName);
  }

  /// List all global secrets
  Future<Map<String, String>> listSecrets() async {
    return await _keychain.listGlobalSecrets();
  }

  /// Check if a global secret exists
  Future<bool> hasSecret(String secretName) async {
    final value = await getSecret(secretName);
    return value != null;
  }

  /// Update or create multiple global secrets at once
  Future<void> saveMultipleSecrets(Map<String, String> secrets) async {
    for (final entry in secrets.entries) {
      await saveSecret(entry.key, entry.value);
    }
  }

  /// Delete multiple global secrets at once
  Future<void> deleteMultipleSecrets(List<String> secretNames) async {
    for (final name in secretNames) {
      await deleteSecret(name);
    }
  }
}

/// Actions for managing project-scoped secrets
class ProjectSecretsActions {
  final KeychainService _keychain;
  final String _projectId;

  ProjectSecretsActions(this._keychain, this._projectId);

  /// Save a project secret
  Future<void> saveSecret(String secretName, String value) async {
    await _keychain.saveProjectSecret(_projectId, secretName, value);
  }

  /// Get a project secret
  Future<String?> getSecret(String secretName) async {
    return await _keychain.getProjectSecret(_projectId, secretName);
  }

  /// Delete a project secret
  Future<void> deleteSecret(String secretName) async {
    await _keychain.deleteProjectSecret(_projectId, secretName);
  }

  /// List all secrets for this project
  Future<Map<String, String>> listSecrets() async {
    return await _keychain.listProjectSecrets(_projectId);
  }

  /// Check if a project secret exists
  Future<bool> hasSecret(String secretName) async {
    final value = await getSecret(secretName);
    return value != null;
  }

  /// Update or create multiple project secrets at once
  Future<void> saveMultipleSecrets(Map<String, String> secrets) async {
    for (final entry in secrets.entries) {
      await saveSecret(entry.key, entry.value);
    }
  }

  /// Delete multiple project secrets at once
  Future<void> deleteMultipleSecrets(List<String> secretNames) async {
    for (final name in secretNames) {
      await deleteSecret(name);
    }
  }

  /// Delete all secrets for this project
  Future<void> deleteAllSecrets() async {
    await _keychain.deleteAllProjectSecrets(_projectId);
  }

  /// Copy secrets from another project
  Future<void> copyFromProject(String sourceProjectId) async {
    final sourceSecrets = await _keychain.listProjectSecrets(sourceProjectId);
    await saveMultipleSecrets(sourceSecrets);
  }
}

/// Provider for merged secrets (global + project overrides)
final effectiveSecretsProvider =
    FutureProvider.family<Map<String, String>, String>((ref, projectId) async {
      final keychain = ref.watch(keychainServiceProvider);

      // Get both global and project secrets
      final globalSecrets = await keychain.listGlobalSecrets();
      final projectSecrets = await keychain.listProjectSecrets(projectId);

      // Merge with project secrets taking precedence
      final merged = <String, String>{...globalSecrets};
      merged.addAll(projectSecrets);

      return merged;
    });

/// Provider to check if a specific secret exists (global or project)
final secretExistsProvider = FutureProvider.family<bool, SecretLookup>((
  ref,
  lookup,
) async {
  if (lookup.projectId != null) {
    final projectSecrets = ref.watch(projectSecretsProvider(lookup.projectId!));
    return await projectSecrets.hasSecret(lookup.secretName);
  } else {
    final globalSecrets = ref.watch(globalSecretsProvider);
    return await globalSecrets.hasSecret(lookup.secretName);
  }
});

/// Helper class for secret lookup parameters
class SecretLookup {
  final String secretName;
  final String? projectId;

  const SecretLookup({required this.secretName, this.projectId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecretLookup &&
          runtimeType == other.runtimeType &&
          secretName == other.secretName &&
          projectId == other.projectId;

  @override
  int get hashCode => secretName.hashCode ^ projectId.hashCode;
}
