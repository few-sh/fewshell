import 'package:freezed_annotation/freezed_annotation.dart';
import 'llm_api_settings.dart';

part 'settings.freezed.dart';
part 'settings.g.dart';

/// Global application settings.
/// Includes LLM model configurations and other user-level settings.
@freezed
class AppSettings with _$AppSettings {
  const factory AppSettings({
    /// List of configured LLM API endpoints at the global level
    @Default([]) List<LlmApiSettings> llmSettings,

    /// Default LLM identifier to use when not overridden by project
    String? defaultLlmIdentifier,

    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _AppSettings;

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);
}

/// Project-specific settings that can override global settings.
/// Allows per-project LLM configuration and other project-specific settings.
@freezed
class ProjectSettings with _$ProjectSettings {
  const factory ProjectSettings({
    required String projectId,

    /// List of configured LLM API endpoints for this project
    /// If empty, falls back to global settings
    @Default([]) List<LlmApiSettings> llmSettings,

    /// Default LLM identifier for this project
    /// If null, falls back to global default
    String? defaultLlmIdentifier,

    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _ProjectSettings;

  factory ProjectSettings.fromJson(Map<String, dynamic> json) =>
      _$ProjectSettingsFromJson(json);
}
