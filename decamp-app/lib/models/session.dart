import 'package:freezed_annotation/freezed_annotation.dart';

part 'session.freezed.dart';
part 'session.g.dart';

/// Represents a chat session within a project.
/// Each session contains a history of messages and belongs to a project.
@freezed
class Session with _$Session {
  const factory Session({
    required String id,
    required String projectId,
    required String description,
    required DateTime timestamp,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(false) bool isArchived,
  }) = _Session;

  factory Session.fromJson(Map<String, dynamic> json) =>
      _$SessionFromJson(json);
}
