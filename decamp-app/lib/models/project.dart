import 'package:freezed_annotation/freezed_annotation.dart';

part 'project.freezed.dart';
part 'project.g.dart';

/// Represents a project in the Decamp app.
/// Each project contains multiple sessions and has its own settings.
@freezed
class Project with _$Project {
  const factory Project({
    required String id,
    required String name,
    String? description,
    required DateTime lastSessionDate,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Project;

  factory Project.fromJson(Map<String, dynamic> json) =>
      _$ProjectFromJson(json);
}
