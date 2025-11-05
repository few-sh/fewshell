import 'package:freezed_annotation/freezed_annotation.dart';

part 'llm_api_settings.freezed.dart';
part 'llm_api_settings.g.dart';

/// Configuration for an LLM API endpoint.
/// API keys are NOT stored in this model - they are stored separately in the keychain.
/// This keeps sensitive data separate from regular configuration.
@freezed
class LlmApiSettings with _$LlmApiSettings {
  const factory LlmApiSettings({
    /// Unique identifier for this LLM configuration (e.g., "gpt-4-turbo", "claude-3-5-sonnet")
    required String identifier,

    /// Display name for the model (e.g., "GPT-4 Turbo", "Claude 3.5 Sonnet")
    required String displayName,

    /// Base URL for the API endpoint
    required String baseUrl,

    /// Optional: Model name to use in API requests (if different from identifier)
    String? modelName,

    /// Optional: Additional headers to include in requests (as JSON string)
    /// Format: {"Header-Name": "value", ...}
    String? customHeaders,

    /// Optional: Maximum tokens for this model
    int? maxTokens,

    /// Optional: Default temperature setting
    double? temperature,

    /// Whether this model is currently enabled
    @Default(true) bool enabled,

    /// Creation timestamp
    DateTime? createdAt,

    /// Last updated timestamp
    DateTime? updatedAt,
  }) = _LlmApiSettings;

  factory LlmApiSettings.fromJson(Map<String, dynamic> json) =>
      _$LlmApiSettingsFromJson(json);
}

/// Helper class to build keychain keys for LLM API keys
class LlmApiKeychainKeys {
  /// Build a keychain key for a global LLM API key
  static String buildGlobalKey(String identifier) {
    return 'llm_api_key:global:$identifier';
  }

  /// Build a keychain key for a project-scoped LLM API key
  static String buildProjectKey(String projectId, String identifier) {
    return 'llm_api_key:project:$projectId:$identifier';
  }
}
