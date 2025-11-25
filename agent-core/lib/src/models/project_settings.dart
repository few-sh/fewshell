import 'package:freezed_annotation/freezed_annotation.dart';

import 'llm_settings.dart';
import 'ssh_settings.dart';

part 'project_settings.freezed.dart';
part 'project_settings.g.dart';

/// Project-level settings for agent execution.
///
/// Contains all configuration needed to run an agent loop:
/// - LLM configuration (which model to use)
/// - SSH configuration (how to connect to remote shell)
/// - System prompt (agent instructions)
@freezed
class ProjectSettings with _$ProjectSettings {
  const ProjectSettings._();

  const factory ProjectSettings({
    /// Project identifier
    required String projectId,

    /// Human-readable project name
    required String name,

    /// List of configured LLM endpoints for this project
    @Default([]) List<LlmSettings> llmSettings,

    /// Default LLM identifier to use
    String? defaultLlmIdentifier,

    /// SSH/Remote shell configuration
    SshSettings? sshSettings,

    /// System prompt / agent instructions
    String? systemPrompt,

    /// Creation timestamp
    DateTime? createdAt,

    /// Last updated timestamp
    DateTime? updatedAt,
  }) = _ProjectSettings;

  /// Get the default LLM settings, or first enabled one
  LlmSettings? get defaultLlm {
    if (llmSettings.isEmpty) return null;
    if (defaultLlmIdentifier != null) {
      final found = llmSettings
          .where((s) => s.identifier == defaultLlmIdentifier && s.enabled)
          .firstOrNull;
      if (found != null) return found;
    }
    return llmSettings.where((s) => s.enabled).firstOrNull;
  }

  factory ProjectSettings.fromJson(Map<String, dynamic> json) =>
      _$ProjectSettingsFromJson(json);
}
