import '../models/models.dart';

/// Abstract interface for project data storage.
///
/// Implementations:
/// - Client (local): SharedPreferences + Keychain
/// - Client (remote): HTTP/WebSocket to server
/// - Server: TOML files
abstract class ProjectDataStore {
  // === Settings ===

  /// Get project settings
  Future<ProjectSettings?> getSettings(String projectId);

  /// Save project settings
  Future<void> saveSettings(ProjectSettings settings);

  // === Snippets ===

  /// Get all snippets for a project
  Future<List<Snippet>> getSnippets(String projectId);

  /// Save a snippet (create or update)
  Future<void> saveSnippet(Snippet snippet);

  /// Delete a snippet
  Future<void> deleteSnippet(String snippetId);

  // === Secrets ===

  /// Get all secret metadata for a project (values NOT included)
  Future<List<SecretMetadata>> getSecretMetadata(String projectId);

  /// Get a secret value by ID (server-side only)
  /// Clients should use the keychain directly.
  Future<String?> getSecretValue(String secretId);

  /// Save a secret (create or update)
  Future<void> saveSecret(
      String projectId, String secretId, String name, String value);

  /// Delete a secret
  Future<void> deleteSecret(String secretId);
}
