import 'package:jinja/jinja.dart';
import '../database/entities/snippet_entity.dart';

/// Simple template processor for agent instructions.
///
/// Uses Jinja2 for template rendering.
class TemplateProcessor {
  /// Available template variables that can be used in agent instructions
  static const Map<String, String> availableVariables = {
    'SECRETS': 'List of all available secret names',
    'USER_SNIPPETS': 'List of user-defined snippets',
    'PROJECT_SNIPPETS': 'List of project-specific snippets',
  };

  /// Process template variables in the given text.
  ///
  /// Supports {{ SECRETS }} as a list variable.
  /// Supports {{ USER_SNIPPETS }} and {{ PROJECT_SNIPPETS }} as lists of snippets.
  ///
  /// Example:
  /// ```dart
  /// final result = TemplateProcessor.process(
  ///   'Available secrets: {{ SECRETS|join(", ") }}',
  ///   secretNames: ['API_KEY', 'DB_PASSWORD'],
  /// );
  /// // Result: 'Available secrets: API_KEY, DB_PASSWORD'
  /// ```
  static String process(
    String text, {
    required List<String> secretNames,
    List<SnippetEntity> userSnippets = const [],
    List<SnippetEntity> projectSnippets = const [],
  }) {
    if (text.isEmpty) return text;

    final environment = Environment();
    final template = environment.fromString(text);

    return template.render({
      'SECRETS': secretNames,
      'USER_SNIPPETS': userSnippets.map(_snippetToMap).toList(),
      'PROJECT_SNIPPETS': projectSnippets.map(_snippetToMap).toList(),
    });
  }

  static Map<String, dynamic> _snippetToMap(SnippetEntity snippet) {
    return {
      'name': snippet.name,
      'content': snippet.content,
      'description': snippet.description,
      'tags': snippet.tags,
      'position': snippet.position,
      'createdAt': snippet.createdAt.toIso8601String(),
      'updatedAt': snippet.updatedAt.toIso8601String(),
    };
  }

  /// Check if the text contains any template variables
  static bool hasTemplateVariables(String text) {
    if (text.isEmpty) return false;
    // Simple check for Jinja variable syntax
    return text.contains('{{') && text.contains('}}');
  }
}
