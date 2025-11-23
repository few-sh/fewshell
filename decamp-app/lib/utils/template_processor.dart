/// Simple template processor for agent instructions.
///
/// Supports Jinja-like variable substitution with backslash escaping.
class TemplateProcessor {
  /// Available template variables that can be used in agent instructions
  static const Map<String, String> availableVariables = {
    'SECRETS_LIST': 'Comma-separated list of all available secret names',
  };

  /// Process template variables in the given text.
  ///
  /// Replaces {{SECRETS_LIST}} with the provided list of secret names.
  /// Use backslash to escape: \{{ will be rendered as {{
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

    // First, protect escaped braces by temporarily replacing them
    final escapedPlaceholder = '\u{FFFD}'; // Replacement character
    var result = text.replaceAll(r'\{{', '$escapedPlaceholder{{');
    result = result.replaceAll(r'\}}', '}}$escapedPlaceholder');

    // Replace {{SECRETS_LIST}} with actual secret names
    final secretsList = secretNames.join(', ');
    result = result.replaceAll('{{SECRETS_LIST}}', secretsList);

    // Restore escaped braces as literal braces
    result = result.replaceAll('$escapedPlaceholder{{', '{{');
    result = result.replaceAll('}}$escapedPlaceholder', '}}');

    return result;
  }

  /// Check if the text contains any template variables
  static bool hasTemplateVariables(String text) {
    if (text.isEmpty) return false;
    return text.contains('{{SECRETS_LIST}}');
  }
}
