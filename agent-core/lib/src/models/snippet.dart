import 'package:freezed_annotation/freezed_annotation.dart';

part 'snippet.freezed.dart';
part 'snippet.g.dart';

/// A reusable text snippet (code, command, prompt fragment).
@freezed
class Snippet with _$Snippet {
  const factory Snippet({
    /// Unique identifier
    required String id,

    /// Project ID (null for global snippets)
    String? projectId,

    /// Snippet name/title
    required String name,

    /// Snippet content
    required String content,

    /// Optional description
    String? description,

    /// Tags for categorization
    @Default([]) List<String> tags,

    /// Position for ordering (lower = higher in list)
    @Default(0) int position,

    /// Creation timestamp
    required DateTime createdAt,

    /// Last updated timestamp
    required DateTime updatedAt,
  }) = _Snippet;

  factory Snippet.fromJson(Map<String, dynamic> json) =>
      _$SnippetFromJson(json);
}
