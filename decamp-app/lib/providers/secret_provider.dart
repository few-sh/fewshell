import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/keychain_service.dart';

/// Provider for KeychainService singleton
/// Access directly: ref.watch(keychainServiceProvider).saveProjectSecret(...)
final keychainServiceProvider = Provider<KeychainService>((ref) {
  return KeychainService();
});

/// Provider to get all secrets (global and project merged)
final allSecretsProvider = FutureProvider.family<Map<String, String>, String?>((
  ref,
  projectId,
) async {
  final keychain = ref.watch(keychainServiceProvider);

  if (projectId != null) {
    final projectSecrets = await keychain.listProjectSecrets(projectId);
    final globalSecrets = await keychain.listGlobalSecrets();

    // Merge with project secrets taking precedence
    final merged = <String, String>{...globalSecrets};
    merged.addAll(projectSecrets);

    return merged;
  } else {
    return await keychain.listGlobalSecrets();
  }
});

/// Provider to get a specific global secret
final globalSecretProvider = FutureProvider.family<String?, String>((
  ref,
  secretName,
) async {
  final keychain = ref.watch(keychainServiceProvider);
  return keychain.getGlobalSecret(secretName);
});

/// Provider to get a specific project secret
/// Parameter is a record with projectId and secretName
final projectSecretProvider =
    FutureProvider.family<String?, ({String projectId, String secretName})>((
      ref,
      params,
    ) async {
      final keychain = ref.watch(keychainServiceProvider);
      return keychain.getProjectSecret(params.projectId, params.secretName);
    });
