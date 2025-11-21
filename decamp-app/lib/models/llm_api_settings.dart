import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:llm_dart/core/provider_defaults.dart';

part 'llm_api_settings.freezed.dart';
part 'llm_api_settings.g.dart';

/// Supported LLM API types with configuration using Enhanced Enums
enum LlmApiType {
  openai(
    displayName: 'OpenAI',
    defaultBaseUrl: ProviderDefaults.openaiBaseUrl,
    defaultModelId: ProviderDefaults.openaiDefaultModel,
    aliases: ['oai'],
  ),
  anthropic(
    displayName: 'Anthropic (Claude)',
    defaultBaseUrl: ProviderDefaults.anthropicBaseUrl,
    defaultModelId: ProviderDefaults.anthropicDefaultModel,
    aliases: ['ant'],
  ),
  google(
    displayName: 'Google (Gemini)',
    defaultBaseUrl: ProviderDefaults.googleBaseUrl,
    defaultModelId: ProviderDefaults.googleDefaultModel,
    aliases: ['gem', 'gemini'],
  ),
  deepseek(
    displayName: 'DeepSeek',
    defaultBaseUrl: ProviderDefaults.deepseekBaseUrl,
    defaultModelId: ProviderDefaults.deepseekDefaultModel,
  ),
  groq(
    displayName: 'Groq',
    defaultBaseUrl: ProviderDefaults.groqBaseUrl,
    defaultModelId: ProviderDefaults.groqDefaultModel,
  ),
  ollama(
    displayName: 'Ollama (Local)',
    defaultBaseUrl: ProviderDefaults.ollamaBaseUrl,
    defaultModelId: ProviderDefaults.ollamaDefaultModel,
  ),
  xai(
    displayName: 'xAI (Grok)',
    defaultBaseUrl: ProviderDefaults.xaiBaseUrl,
    defaultModelId: ProviderDefaults.xaiDefaultModel,
  ),
  openaiCompatible(
    displayName: 'OpenAI Compatible',
    defaultBaseUrl: '',
    defaultModelId: 'model-identifier',
  );

  const LlmApiType({
    required this.displayName,
    required this.defaultBaseUrl,
    required this.defaultModelId,
    this.aliases = const [],
  });

  final String displayName;
  final String defaultBaseUrl;
  final String defaultModelId;
  final List<String> aliases;

  /// Helper to parse string code to LlmApiType
  static LlmApiType? fromCode(String code) {
    final normalized = code.toLowerCase();
    try {
      return LlmApiType.values.firstWhere(
        (e) => e.name == normalized || e.aliases.contains(normalized),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Configuration for an LLM API endpoint.
/// API keys are NOT stored in this model - they are stored separately in the keychain.
/// This keeps sensitive data separate from regular configuration.
@freezed
class LlmApiSettings with _$LlmApiSettings {
  const factory LlmApiSettings({
    /// Unique identifier for this LLM configuration (e.g., "gpt-4-turbo", "claude-3-5-sonnet")
    required String identifier,

    /// Type of API (OpenAI, Anthropic, etc.)
    required LlmApiType apiType,

    /// Base URL for the API endpoint
    required String baseUrl,

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
