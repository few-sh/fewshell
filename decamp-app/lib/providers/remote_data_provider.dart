import 'package:agent_core/agent_core.dart'
    hide SshSettings, RemoteSessionController;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../services/remote_session_controller.dart';
import 'project_provider.dart';

/// Provider for a shared RemoteSessionController for the current project.
///
/// Returns null if the current project is not remote (no serverUrl).
/// This controller is reused across the app for the same project.
final remoteControllerProvider = Provider<RemoteSessionController?>((ref) {
  final currentProject = ref.watch(currentProjectProvider);

  if (currentProject == null || currentProject.serverUrl == null) {
    return null;
  }

  return RemoteSessionController(
    serverUrl: currentProject.serverUrl!,
    projectId: currentProject.id,
  );
});

/// Whether the current project is remote
final isRemoteProjectProvider = Provider<bool>((ref) {
  final currentProject = ref.watch(currentProjectProvider);
  return currentProject?.serverUrl != null;
});

/// Provider for remote project settings.
///
/// Returns null if not a remote project or if fetching fails.
final remoteSettingsProvider = FutureProvider<ProjectSettings?>((ref) async {
  final controller = ref.watch(remoteControllerProvider);
  if (controller == null) return null;

  return controller.getSettings();
});

/// Provider for remote snippets.
///
/// Returns empty list if not a remote project.
final remoteSnippetsProvider = FutureProvider<List<Snippet>>((ref) async {
  final controller = ref.watch(remoteControllerProvider);
  if (controller == null) return [];

  return controller.getSnippets();
});

/// Provider for remote secret metadata.
///
/// Returns empty list if not a remote project.
final remoteSecretsProvider = FutureProvider<List<SecretMetadata>>((ref) async {
  final controller = ref.watch(remoteControllerProvider);
  if (controller == null) return [];

  return controller.getSecrets();
});

// ============================================================
// Conversion utilities between Snippet and SnippetEntity
// ============================================================

/// Convert agent_core Snippet to local SnippetEntity
SnippetEntity snippetToEntity(Snippet snippet) {
  return SnippetEntity(
    id: snippet.id,
    projectId: snippet.projectId,
    name: snippet.name,
    content: snippet.content,
    description: snippet.description,
    tags: snippet.tags.join(','),
    position: snippet.position,
    createdAt: snippet.createdAt,
    updatedAt: snippet.updatedAt,
  );
}

/// Convert local SnippetEntity to agent_core Snippet
Snippet entityToSnippet(SnippetEntity entity) {
  return Snippet(
    id: entity.id,
    projectId: entity.projectId,
    name: entity.name,
    content: entity.content,
    description: entity.description,
    tags: entity.tags.isEmpty ? [] : entity.tags.split(','),
    position: entity.position,
    createdAt: entity.createdAt,
    updatedAt: entity.updatedAt,
  );
}

// ============================================================
// Helper functions for remote operations
// ============================================================

/// Helper to save remote settings
Future<bool> saveRemoteSettings(WidgetRef ref, ProjectSettings settings) async {
  final controller = ref.read(remoteControllerProvider);
  if (controller == null) return false;

  return controller.saveSettings(settings);
}

/// Helper to save a remote snippet
Future<bool> saveRemoteSnippet(WidgetRef ref, Snippet snippet) async {
  final controller = ref.read(remoteControllerProvider);
  if (controller == null) return false;

  return controller.saveSnippet(snippet);
}

/// Helper to delete a remote snippet
Future<bool> deleteRemoteSnippet(WidgetRef ref, String snippetId) async {
  final controller = ref.read(remoteControllerProvider);
  if (controller == null) return false;

  return controller.deleteSnippet(snippetId);
}

/// Helper to save a remote secret
Future<bool> saveRemoteSecret(
  WidgetRef ref,
  String secretId,
  String name,
  String value,
) async {
  final controller = ref.read(remoteControllerProvider);
  if (controller == null) return false;

  return controller.saveSecret(secretId, name, value);
}

/// Helper to delete a remote secret
Future<bool> deleteRemoteSecret(WidgetRef ref, String secretId) async {
  final controller = ref.read(remoteControllerProvider);
  if (controller == null) return false;

  return controller.deleteSecret(secretId);
}
