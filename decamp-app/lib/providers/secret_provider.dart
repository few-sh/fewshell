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

/// Provider to check if a specific secret exists (global or project)
final secretExistsProvider = FutureProvider.family<bool, SecretLookup>((
  ref,
  lookup,
) async {
  final keychain = ref.watch(keychainServiceProvider);
  if (lookup.projectId != null) {
    final value = await keychain.getProjectSecret(
      lookup.projectId!,
      lookup.secretName,
    );
    return value != null;
  } else {
    final value = await keychain.getGlobalSecret(lookup.secretName);
    return value != null;
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
