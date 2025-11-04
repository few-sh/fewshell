import 'package:freezed_annotation/freezed_annotation.dart';

part 'snippet.freezed.dart';
part 'snippet.g.dart';

/// Represents a code or command snippet that can be reused.
/// Snippets can be global or project-specific.
@freezed
class Snippet with _$Snippet {
  const factory Snippet({
    required String id,
    String? projectId, // null for global snippets
    required String name,
    required String content,
    String? description,
    @Default([]) List<String> tags,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Snippet;

  factory Snippet.fromJson(Map<String, dynamic> json) =>
      _$SnippetFromJson(json);
}
