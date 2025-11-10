import 'package:flutter/services.dart';

/// Loads the default system prompt from the bundled asset file.
///
/// This function reads the default_sys_prompt.md file that is packaged
/// with the application and returns its contents as a string.
///
/// Returns the default system instruction text, or an empty string if
/// the asset cannot be loaded.
Future<String> loadDefaultSystemPrompt() async {
  try {
    final content = await rootBundle.loadString('assets/default_sys_prompt.md');
    return content.trim();
  } catch (e) {
    // If the asset fails to load, return empty string
    // This ensures graceful degradation
    return '';
  }
}
