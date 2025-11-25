import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:toml/toml.dart';

/// TOML-based storage for project data.
///
/// Stores data in:
/// ```
/// ~/.decamp/projects/{projectId}/
///   settings.toml
///   snippets.toml
///   secrets.toml
/// ```
class TomlProjectDataStore implements ProjectDataStore {
  final String _basePath;

  TomlProjectDataStore({String? basePath})
      : _basePath = basePath ?? _defaultBasePath();

  static String _defaultBasePath() {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return '$home/.decamp/projects';
  }

  String _projectDir(String projectId) => '$_basePath/$projectId';
  String _settingsPath(String projectId) =>
      '${_projectDir(projectId)}/settings.toml';
  String _snippetsPath(String projectId) =>
      '${_projectDir(projectId)}/snippets.toml';
  String _secretsPath(String projectId) =>
      '${_projectDir(projectId)}/secrets.toml';

  Future<void> _ensureProjectDir(String projectId) async {
    final dir = Directory(_projectDir(projectId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  // === Settings ===

  @override
  Future<ProjectSettings?> getSettings(String projectId) async {
    final file = File(_settingsPath(projectId));
    if (!await file.exists()) {
      return null;
    }

    try {
      final content = await file.readAsString();
      final doc = TomlDocument.parse(content);
      return _settingsFromToml(projectId, doc.toMap());
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> saveSettings(ProjectSettings settings) async {
    await _ensureProjectDir(settings.projectId);
    final file = File(_settingsPath(settings.projectId));
    final toml = _settingsToToml(settings);
    await file.writeAsString(toml);
  }

  ProjectSettings _settingsFromToml(
      String projectId, Map<String, dynamic> map) {
    final project = map['project'] as Map<String, dynamic>? ?? {};
    final llmList = map['llm'] as List<dynamic>? ?? [];
    final sshMap = map['ssh'] as Map<String, dynamic>?;

    return ProjectSettings(
      projectId: projectId,
      name: project['name'] as String? ?? 'Unnamed Project',
      systemPrompt: project['system_prompt'] as String?,
      defaultLlmIdentifier: project['default_llm'] as String?,
      llmSettings:
          llmList.map((e) => _llmFromToml(e as Map<String, dynamic>)).toList(),
      sshSettings: sshMap != null ? _sshFromToml(sshMap) : null,
    );
  }

  LlmSettings _llmFromToml(Map<String, dynamic> map) => LlmSettings(
        identifier: map['identifier'] as String? ?? '',
        provider: map['provider'] as String? ?? 'openai',
        model: map['model'] as String? ?? '',
        baseUrl: map['base_url'] as String? ?? '',
        apiKeySecretId: map['api_key_secret_id'] as String?,
        maxTokens: map['max_tokens'] as int?,
        temperature: (map['temperature'] as num?)?.toDouble(),
        enabled: map['enabled'] as bool? ?? true,
      );

  SshSettings _sshFromToml(Map<String, dynamic> map) => SshSettings(
        host: map['host'] as String? ?? '',
        port: map['port'] as int? ?? 22,
        username: map['username'] as String? ?? '',
        authMethod: SshAuthMethod.fromString(
            map['auth_method'] as String? ?? 'password'),
        passwordSecretId: map['password_secret_id'] as String?,
        privateKeySecretId: map['private_key_secret_id'] as String?,
        passphraseSecretId: map['passphrase_secret_id'] as String?,
        sudoPasswordSecretId: map['sudo_password_secret_id'] as String?,
        enabled: map['enabled'] as bool? ?? true,
      );

  String _settingsToToml(ProjectSettings settings) {
    final buffer = StringBuffer();

    // Project section
    buffer.writeln('[project]');
    buffer.writeln('name = ${_tomlString(settings.name)}');
    if (settings.systemPrompt != null) {
      buffer.writeln(
          'system_prompt = ${_tomlMultilineString(settings.systemPrompt!)}');
    }
    if (settings.defaultLlmIdentifier != null) {
      buffer.writeln(
          'default_llm = ${_tomlString(settings.defaultLlmIdentifier!)}');
    }
    buffer.writeln();

    // LLM settings
    for (final llm in settings.llmSettings) {
      buffer.writeln('[[llm]]');
      buffer.writeln('identifier = ${_tomlString(llm.identifier)}');
      buffer.writeln('provider = ${_tomlString(llm.provider)}');
      buffer.writeln('model = ${_tomlString(llm.model)}');
      buffer.writeln('base_url = ${_tomlString(llm.baseUrl)}');
      if (llm.apiKeySecretId != null) {
        buffer
            .writeln('api_key_secret_id = ${_tomlString(llm.apiKeySecretId!)}');
      }
      if (llm.maxTokens != null) {
        buffer.writeln('max_tokens = ${llm.maxTokens}');
      }
      if (llm.temperature != null) {
        buffer.writeln('temperature = ${llm.temperature}');
      }
      buffer.writeln('enabled = ${llm.enabled}');
      buffer.writeln();
    }

    // SSH settings
    if (settings.sshSettings != null) {
      final ssh = settings.sshSettings!;
      buffer.writeln('[ssh]');
      buffer.writeln('host = ${_tomlString(ssh.host)}');
      buffer.writeln('port = ${ssh.port}');
      buffer.writeln('username = ${_tomlString(ssh.username)}');
      buffer.writeln('auth_method = ${_tomlString(ssh.authMethod.name)}');
      if (ssh.passwordSecretId != null) {
        buffer.writeln(
            'password_secret_id = ${_tomlString(ssh.passwordSecretId!)}');
      }
      if (ssh.privateKeySecretId != null) {
        buffer.writeln(
            'private_key_secret_id = ${_tomlString(ssh.privateKeySecretId!)}');
      }
      if (ssh.passphraseSecretId != null) {
        buffer.writeln(
            'passphrase_secret_id = ${_tomlString(ssh.passphraseSecretId!)}');
      }
      if (ssh.sudoPasswordSecretId != null) {
        buffer.writeln(
            'sudo_password_secret_id = ${_tomlString(ssh.sudoPasswordSecretId!)}');
      }
      buffer.writeln('enabled = ${ssh.enabled}');
    }

    return buffer.toString();
  }

  // === Snippets ===

  @override
  Future<List<Snippet>> getSnippets(String projectId) async {
    final file = File(_snippetsPath(projectId));
    if (!await file.exists()) {
      return [];
    }

    try {
      final content = await file.readAsString();
      final doc = TomlDocument.parse(content);
      final map = doc.toMap();
      final snippetsList = map['snippet'] as List<dynamic>? ?? [];
      return snippetsList
          .map((e) => _snippetFromToml(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> saveSnippet(Snippet snippet) async {
    final projectId = snippet.projectId ?? 'global';
    await _ensureProjectDir(projectId);

    final snippets = await getSnippets(projectId);
    final index = snippets.indexWhere((s) => s.id == snippet.id);
    if (index >= 0) {
      snippets[index] = snippet;
    } else {
      snippets.add(snippet);
    }

    await _writeSnippets(projectId, snippets);
  }

  @override
  Future<void> deleteSnippet(String snippetId) async {
    // We need to find which project this snippet belongs to
    // For now, scan all projects (could be optimized with an index)
    final baseDir = Directory(_basePath);
    if (!await baseDir.exists()) return;

    await for (final entity in baseDir.list()) {
      if (entity is Directory) {
        final projectId = entity.path.split('/').last;
        final snippets = await getSnippets(projectId);
        final filtered = snippets.where((s) => s.id != snippetId).toList();
        if (filtered.length != snippets.length) {
          await _writeSnippets(projectId, filtered);
          return;
        }
      }
    }
  }

  Future<void> _writeSnippets(String projectId, List<Snippet> snippets) async {
    await _ensureProjectDir(projectId);
    final file = File(_snippetsPath(projectId));
    final buffer = StringBuffer();

    for (final snippet in snippets) {
      buffer.writeln('[[snippet]]');
      buffer.writeln('id = ${_tomlString(snippet.id)}');
      buffer.writeln('name = ${_tomlString(snippet.name)}');
      buffer.writeln('content = ${_tomlMultilineString(snippet.content)}');
      if (snippet.description != null) {
        buffer.writeln('description = ${_tomlString(snippet.description!)}');
      }
      if (snippet.tags.isNotEmpty) {
        buffer.writeln('tags = [${snippet.tags.map(_tomlString).join(', ')}]');
      }
      buffer.writeln('position = ${snippet.position}');
      buffer.writeln('created_at = ${snippet.createdAt.toIso8601String()}');
      buffer.writeln('updated_at = ${snippet.updatedAt.toIso8601String()}');
      buffer.writeln();
    }

    await file.writeAsString(buffer.toString());
  }

  Snippet _snippetFromToml(Map<String, dynamic> map) => Snippet(
        id: map['id'] as String,
        projectId: map['project_id'] as String?,
        name: map['name'] as String,
        content: map['content'] as String,
        description: map['description'] as String?,
        tags: (map['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        position: map['position'] as int? ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  // === Secrets ===

  @override
  Future<List<SecretMetadata>> getSecretMetadata(String projectId) async {
    final secrets = await _getSecrets(projectId);
    return secrets.map((s) => s.toMetadata()).toList();
  }

  @override
  Future<String?> getSecretValue(String secretId) async {
    // Scan all projects for this secret
    final baseDir = Directory(_basePath);
    if (!await baseDir.exists()) return null;

    await for (final entity in baseDir.list()) {
      if (entity is Directory) {
        final projectId = entity.path.split('/').last;
        final secrets = await _getSecrets(projectId);
        final secret = secrets.where((s) => s.id == secretId).firstOrNull;
        if (secret != null) {
          return secret.value;
        }
      }
    }
    return null;
  }

  @override
  Future<void> saveSecret(
      String projectId, String secretId, String name, String value) async {
    await _ensureProjectDir(projectId);

    final secrets = await _getSecrets(projectId);
    final now = DateTime.now();
    final index = secrets.indexWhere((s) => s.id == secretId);

    final secret = Secret(
      id: secretId,
      projectId: projectId,
      name: name,
      value: value,
      createdAt: index >= 0 ? secrets[index].createdAt : now,
      updatedAt: now,
    );

    if (index >= 0) {
      secrets[index] = secret;
    } else {
      secrets.add(secret);
    }

    await _writeSecrets(projectId, secrets);
  }

  @override
  Future<void> deleteSecret(String secretId) async {
    // Scan all projects for this secret
    final baseDir = Directory(_basePath);
    if (!await baseDir.exists()) return;

    await for (final entity in baseDir.list()) {
      if (entity is Directory) {
        final projectId = entity.path.split('/').last;
        final secrets = await _getSecrets(projectId);
        final filtered = secrets.where((s) => s.id != secretId).toList();
        if (filtered.length != secrets.length) {
          await _writeSecrets(projectId, filtered);
          return;
        }
      }
    }
  }

  Future<List<Secret>> _getSecrets(String projectId) async {
    final file = File(_secretsPath(projectId));
    if (!await file.exists()) {
      return [];
    }

    try {
      final content = await file.readAsString();
      final doc = TomlDocument.parse(content);
      final map = doc.toMap();
      final secretsList = map['secret'] as List<dynamic>? ?? [];
      return secretsList
          .map((e) => _secretFromToml(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _writeSecrets(String projectId, List<Secret> secrets) async {
    await _ensureProjectDir(projectId);
    final file = File(_secretsPath(projectId));

    // Set restrictive permissions on secrets file
    final buffer = StringBuffer();
    buffer.writeln('# SECRETS - Keep this file secure!');
    buffer.writeln();

    for (final secret in secrets) {
      buffer.writeln('[[secret]]');
      buffer.writeln('id = ${_tomlString(secret.id)}');
      buffer.writeln('name = ${_tomlString(secret.name)}');
      buffer.writeln('value = ${_tomlString(secret.value)}');
      if (secret.description != null) {
        buffer.writeln('description = ${_tomlString(secret.description!)}');
      }
      buffer.writeln('created_at = ${secret.createdAt.toIso8601String()}');
      buffer.writeln('updated_at = ${secret.updatedAt.toIso8601String()}');
      buffer.writeln();
    }

    await file.writeAsString(buffer.toString());

    // Try to set restrictive permissions (Unix only)
    try {
      await Process.run('chmod', ['600', file.path]);
    } catch (_) {
      // Ignore on non-Unix systems
    }
  }

  Secret _secretFromToml(Map<String, dynamic> map) => Secret(
        id: map['id'] as String,
        projectId: map['project_id'] as String?,
        name: map['name'] as String,
        value: map['value'] as String,
        description: map['description'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  // === TOML Helpers ===

  String _tomlString(String value) {
    // Escape special characters and wrap in quotes
    final escaped = value
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
    return '"$escaped"';
  }

  String _tomlMultilineString(String value) {
    // Use triple quotes for multiline strings
    if (value.contains('\n')) {
      return '"""\n$value"""';
    }
    return _tomlString(value);
  }
}
