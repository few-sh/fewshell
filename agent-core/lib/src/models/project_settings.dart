import 'llm_settings.dart';
import 'ssh_settings.dart';

/// Project-level settings for agent execution.
///
/// Contains all configuration needed to run an agent loop:
/// - LLM configuration (which model to use)
/// - SSH configuration (how to connect to remote shell)
/// - System prompt (agent instructions)
class ProjectSettings {
  /// Project identifier
  final String projectId;

  /// Human-readable project name
  final String name;

  /// List of configured LLM endpoints for this project
  final List<LlmSettings> llmSettings;

  /// Default LLM identifier to use
  final String? defaultLlmIdentifier;

  /// SSH/Remote shell configuration
  final SshSettings? sshSettings;

  /// System prompt / agent instructions
  final String? systemPrompt;

  /// Creation timestamp
  final DateTime? createdAt;

  /// Last updated timestamp
  final DateTime? updatedAt;

  const ProjectSettings({
    required this.projectId,
    required this.name,
    this.llmSettings = const [],
    this.defaultLlmIdentifier,
    this.sshSettings,
    this.systemPrompt,
    this.createdAt,
    this.updatedAt,
  });

  /// Get the default LLM settings, or first enabled one
  LlmSettings? get defaultLlm {
    if (llmSettings.isEmpty) return null;
    if (defaultLlmIdentifier != null) {
      final found = llmSettings
          .where(
            (s) => s.identifier == defaultLlmIdentifier && s.enabled,
          )
          .firstOrNull;
      if (found != null) return found;
    }
    return llmSettings.where((s) => s.enabled).firstOrNull;
  }

  Map<String, dynamic> toJson() => {
        'projectId': projectId,
        'name': name,
        'llmSettings': llmSettings.map((s) => s.toJson()).toList(),
        if (defaultLlmIdentifier != null)
          'defaultLlmIdentifier': defaultLlmIdentifier,
        if (sshSettings != null) 'sshSettings': sshSettings!.toJson(),
        if (systemPrompt != null) 'systemPrompt': systemPrompt,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory ProjectSettings.fromJson(Map<String, dynamic> json) =>
      ProjectSettings(
        projectId: json['projectId'] as String,
        name: json['name'] as String,
        llmSettings: (json['llmSettings'] as List<dynamic>?)
                ?.map((e) => LlmSettings.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        defaultLlmIdentifier: json['defaultLlmIdentifier'] as String?,
        sshSettings: json['sshSettings'] != null
            ? SshSettings.fromJson(json['sshSettings'] as Map<String, dynamic>)
            : null,
        systemPrompt: json['systemPrompt'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
      );

  ProjectSettings copyWith({
    String? projectId,
    String? name,
    List<LlmSettings>? llmSettings,
    String? defaultLlmIdentifier,
    SshSettings? sshSettings,
    String? systemPrompt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      ProjectSettings(
        projectId: projectId ?? this.projectId,
        name: name ?? this.name,
        llmSettings: llmSettings ?? this.llmSettings,
        defaultLlmIdentifier: defaultLlmIdentifier ?? this.defaultLlmIdentifier,
        sshSettings: sshSettings ?? this.sshSettings,
        systemPrompt: systemPrompt ?? this.systemPrompt,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectSettings &&
          runtimeType == other.runtimeType &&
          projectId == other.projectId &&
          name == other.name;

  @override
  int get hashCode => Object.hash(projectId, name);

  @override
  String toString() => 'ProjectSettings(projectId: $projectId, name: $name)';
}
