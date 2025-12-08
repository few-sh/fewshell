import 'package:jinja/jinja.dart';

/// Simple template processor for agent instructions.
///
/// Uses Jinja2 for template rendering.
class TemplateProcessor {
  /// Available template variables that can be used in agent instructions
  static const Map<String, String> availableVariables = {
    'SECRETS_LIST': 'Comma-separated list of all available secret names',
  };

  /// Process template variables in the given text.
  ///
  /// Replaces {{SECRETS_LIST}} with the provided list of secret names.
  ///
  /// Example:
  /// ```dart
  /// final result = TemplateProcessor.process(
  ///   'Available secrets: {{SECRETS_LIST}}',
  ///   secretNames: ['API_KEY', 'DB_PASSWORD'],
  /// );
  /// // Result: 'Available secrets: API_KEY, DB_PASSWORD'
  /// ```
  static String process(String text, {required List<String> secretNames}) {
    if (text.isEmpty) return text;

    final environment = Environment();
    final template = environment.fromString(text);

    return template.render({
      'SECRETS_LIST': secretNames.join(', '),
    });
  }

  /// Check if the text contains any template variables
  static bool hasTemplateVariables(String text) {
    if (text.isEmpty) return false;
    // Simple check for Jinja variable syntax
    return text.contains('{{') && text.contains('}}');
  }
}
