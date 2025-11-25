import 'package:freezed_annotation/freezed_annotation.dart';

part 'llm_settings.freezed.dart';
part 'llm_settings.g.dart';

/// LLM API configuration settings.
///
/// API keys are stored separately (in keychain on client, in secrets file on server).
/// The [apiKeySecretId] references the secret, not the actual key value.
@freezed
class LlmSettings with _$LlmSettings {
  const factory LlmSettings({
    /// Unique identifier for this LLM configuration (e.g., "gpt-4-turbo")
    required String identifier,

    /// Type of API provider (openai, anthropic, google, etc.)
    required String provider,

    /// Model identifier (e.g., "gpt-4o", "claude-3-5-sonnet")
    required String model,

    /// Base URL for the API endpoint
    required String baseUrl,

    /// Secret ID that references the API key (not the actual key)
    String? apiKeySecretId,

    /// Optional: Maximum tokens for this model
    int? maxTokens,

    /// Optional: Default temperature setting
    double? temperature,

    /// Whether this configuration is enabled
    @Default(true) bool enabled,
  }) = _LlmSettings;

  factory LlmSettings.fromJson(Map<String, dynamic> json) =>
      _$LlmSettingsFromJson(json);
}
