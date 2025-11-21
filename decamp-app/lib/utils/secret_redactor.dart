import '../services/keychain_service.dart';

/// Utility class to redact secrets from text content before storing in database.
///
/// Scans text for any secret values (global and project-specific) and replaces
/// them with [REDACTED] to prevent sensitive data from being persisted.
class SecretRedactor {
  final KeychainService _keychain;
  final String? _projectId;

  SecretRedactor(this._keychain, this._projectId);

  /// Redacts all known secrets from the given text.
  ///
  /// Fetches both global and project-specific secrets (if projectId is set),
  /// then replaces any occurrences of secret values with [REDACTED].
  ///
  /// Returns the redacted text.
  Future<String> redact(String text) async {
    if (text.isEmpty) return text;

    // Fetch all relevant secrets
    final secrets = await _getAllSecrets();

    // If no secrets to redact, return original text
    if (secrets.isEmpty) return text;

    // Sort secrets by length descending and replace them.
    final secretValues = secrets.values.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    return secretValues.fold(
      text,
      (currentText, secret) =>
          secret.isEmpty ? currentText : currentText.replaceAll(secret, '[REDACTED]'),
    );
  }

  /// Fetches all secrets (global + project-specific if applicable).
  Future<Map<String, String>> _getAllSecrets() async {
    final globalSecrets = await _keychain.listGlobalSecrets();

    if (_projectId != null) {
      final projectSecrets = await _keychain.listProjectSecrets(_projectId);
      // Merge with project secrets taking precedence
      return {...globalSecrets, ...projectSecrets};
    }

    return globalSecrets;
  }
}
