import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings.freezed.dart';
part 'settings.g.dart';

/// Global application settings.
@freezed
class AppSettings with _$AppSettings {
  const factory AppSettings({
    @Default(false) bool darkMode,
    @Default('') String defaultAgentsMd,
    Map<String, dynamic>? globalSecrets,
  }) = _AppSettings;

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);
}

/// Project-specific settings that can override global settings.
@freezed
class ProjectSettings with _$ProjectSettings {
  const factory ProjectSettings({
    required String projectId,
    String? agentsMd,
    String? githubRepo,
    String? githubBranch,
    Map<String, String>? secrets,
    @Default(true) bool enableGithubSync,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _ProjectSettings;

  factory ProjectSettings.fromJson(Map<String, dynamic> json) =>
      _$ProjectSettingsFromJson(json);
}
