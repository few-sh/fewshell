import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings.freezed.dart';
part 'settings.g.dart';

/// Global application settings.
/// Currently minimal - will be expanded with AI model configs and agent instructions.
@freezed
class AppSettings with _$AppSettings {
  const factory AppSettings({DateTime? createdAt, DateTime? updatedAt}) =
      _AppSettings;

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);
}

/// Project-specific settings that can override global settings.
/// Currently minimal - will be expanded with project-specific AI model and instruction overrides.
@freezed
class ProjectSettings with _$ProjectSettings {
  const factory ProjectSettings({
    required String projectId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _ProjectSettings;

  factory ProjectSettings.fromJson(Map<String, dynamic> json) =>
      _$ProjectSettingsFromJson(json);
}
