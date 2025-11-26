import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:decamp/providers/database_provider.dart';
import 'package:decamp/providers/ssh_settings_provider.dart';
import 'package:decamp/providers/llm_settings_provider.dart';
import 'package:decamp/utils/project_utils.dart';

final projectImporterProvider = Provider<ProjectImporter>((ref) {
  return ProjectImporter(ref);
});

class ProjectImporter {
  final Ref _ref;

  ProjectImporter(this._ref);

  /// Imports project configuration from a JSON string (QR code content).
  ///
  /// If [targetProjectId] is provided, updates that project.
  /// Otherwise, creates a new project.
  ///
  /// Returns the project ID of the created/updated project.
  Future<String> importFromQrCode(
    String jsonString, {
    String? targetProjectId,
  }) async {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonString);
    } catch (e) {
      throw const FormatException('Invalid QR code format: Not a valid JSON');
    }

    String projectId;

    // 1. Resolve Project ID
    if (targetProjectId != null) {
      projectId = targetProjectId;
    } else {
      // Create new project
      // Check for name in keys 'n' or 'name'
      String? name = _getValue<String>(data, ['n', 'name']);

      if (name == null || name.isEmpty) {
        final projects = await _ref
            .read(databaseProvider)
            .projectDao
            .getAllProjects();
        final existingNames = projects.map((p) => p.name).toList();
        name = generateUniqueProjectName(existingNames);
      }

      final description = _getValue<String>(data, ['d', 'description']);

      projectId = await _ref
          .read(databaseProvider)
          .projectDao
          .createProjectWithId(name: name, description: description);
    }

    // 2. Import Settings
    await _importSshSettings(projectId, data);
    await _importLlmSettings(projectId, data);

    return projectId;
  }

  T? _getValue<T>(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      if (data.containsKey(key) && data[key] is T) {
        return data[key] as T;
      }
    }
    return null;
  }

  Future<void> _importSshSettings(
    String projectId,
    Map<String, dynamic> data,
  ) async {
    String? host;
    String? username;
    int port = 22;
    String? privateKey;
    String? password;
    String? passphrase;

    // 1. Try 'i' (identity) format from MainSettingsPage: user@host
    final identity = _getValue<String>(data, ['i']);
    if (identity != null && identity.contains('@')) {
      final parts = identity.split('@');
      username = parts[0];
      host = parts[1];
    }

    // 2. Fallback/Override with specific fields
    host = _getValue<String>(data, ['h', 'host']) ?? host;
    username = _getValue<String>(data, ['u', 'user', 'username']) ?? username;

    // Port
    final portVal = _getValue<dynamic>(data, ['p', 'port']);
    if (portVal is int) {
      port = portVal;
    } else if (portVal is String) {
      port = int.tryParse(portVal) ?? 22;
    }

    // Secrets
    // 's' is from MainSettingsPage for private key
    privateKey = _getValue<String>(data, ['s', 'k', 'key', 'private_key']);
    password = _getValue<String>(data, ['pw', 'password']);
    passphrase = _getValue<String>(data, ['pp', 'passphrase']);

    if (host == null || username == null) return;

    // Key formatting (from MainSettingsPage)
    if (privateKey != null && !privateKey.contains('-----BEGIN')) {
      privateKey =
          '-----BEGIN OPENSSH PRIVATE KEY-----\n$privateKey\n-----END OPENSSH PRIVATE KEY-----';
    }

    final notifier = _ref.read(projectSshSettingsProvider(projectId).notifier);
    final currentSettings = _ref.read(projectSshSettingsProvider(projectId));

    SshAuthMethod authMethod = SshAuthMethod.password;
    if (privateKey != null && privateKey.isNotEmpty) {
      authMethod = SshAuthMethod.privateKey;
    }

    if (currentSettings == null) {
      await notifier.createSshSettings(
        host: host,
        port: port,
        username: username,
        authMethod: authMethod,
        privateKey: privateKey,
        passphrase: passphrase,
        password: password,
      );
    } else {
      await notifier.updateSshSettings(
        host: host,
        port: port,
        username: username,
        authMethod: authMethod,
        privateKey: privateKey,
        passphrase: passphrase,
        password: password,
      );
    }
  }

  Future<void> _importLlmSettings(
    String projectId,
    Map<String, dynamic> data,
  ) async {
    // Check for nested object 'llm' or 'ai'
    final nested = _getValue<Map<String, dynamic>>(data, ['llm', 'ai']);
    // If nested exists, use it. If not, use data (root) which might contain 'l' and 'k'.
    final source = nested ?? data;

    // 'l' is from MainSettingsPage
    final providerCode = _getValue<String>(source, ['l', 'p', 'provider']);
    // 'k' is from MainSettingsPage
    final apiKey = _getValue<String>(source, ['k', 'key', 'api_key']);
    final baseUrl = _getValue<String>(source, ['url', 'base_url']);

    if (providerCode == null || apiKey == null) {
      return;
    }

    final apiType = LlmApiType.fromCode(providerCode);

    if (apiType == null) {
      throw Exception('Unknown provider code: $providerCode');
    }

    final modelId = apiType.defaultModelId;
    final url = baseUrl ?? apiType.defaultBaseUrl;

    final llmNotifier = _ref.read(
      projectLlmSettingsProvider(projectId).notifier,
    );
    final currentModels = _ref.read(projectLlmSettingsProvider(projectId));

    // Check if model exists by identifier (using default model ID for the type)
    final exists = currentModels.any((m) => m.identifier == modelId);

    if (exists) {
      await llmNotifier.updateLlmSettings(
        identifier: modelId,
        baseUrl: url,
        apiKey: apiKey,
      );
    } else {
      await llmNotifier.addLlmSettings(
        identifier: modelId,
        apiType: apiType,
        baseUrl: url,
        apiKey: apiKey,
      );
    }
  }
}
