import '../services/keychain_service.dart';

/// Utility class to redact secrets from text content before storing in database.
///
/// Scans text for any secret values (global and project-specific) and replaces
/// them with [REDACTED] to prevent sensitive data from being persisted.
class SecretRedactor {
  final KeychainService _keychain;
  final String? _projectId;

  /// Cached secret values sorted by length descending, populated by [load].
  List<String>? _cachedSecretValues;

  SecretRedactor(this._keychain, this._projectId);

  /// Pre-fetches all secrets so that [redactSync] can be used without await.
  /// Must be called (and awaited) before using [redactSync].
  Future<void> load() async {
    final secrets = await _getAllSecrets();
    _cachedSecretValues = secrets.values.where((s) => s.isNotEmpty).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
  }

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

    String redactedText = text;
    for (final secret in secretValues) {
      if (secret.isNotEmpty) {
        redactedText = redactedText.replaceAll(secret, '[REDACTED]');
      }
    }
    return redactedText;
  }

  /// Synchronous variant of [redact] that uses cached secrets from [load].
  ///
  /// Returns the original text if [load] has not been called yet.
  String redactSync(String text) {
    if (text.isEmpty) return text;
    final values = _cachedSecretValues;
    if (values == null || values.isEmpty) return text;

    String redactedText = text;
    for (final secret in values) {
      redactedText = redactedText.replaceAll(secret, '[REDACTED]');
    }
    return redactedText;
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
