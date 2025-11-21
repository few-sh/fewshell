import 'package:freezed_annotation/freezed_annotation.dart';

part 'llm_api_settings.freezed.dart';
part 'llm_api_settings.g.dart';

/// Supported LLM API types
enum LlmApiType {
  openai,
  anthropic,
  google,
  deepseek,
  groq,
  ollama,
  xai,
  openaiCompatible, // For any OpenAI-compatible API
}

/// Extension to provide display names for LLM API types
extension LlmApiTypeExtension on LlmApiType {
  String get displayName {
    switch (this) {
      case LlmApiType.openai:
        return 'OpenAI';
      case LlmApiType.anthropic:
        return 'Anthropic (Claude)';
      case LlmApiType.google:
        return 'Google (Gemini)';
      case LlmApiType.deepseek:
        return 'DeepSeek';
      case LlmApiType.groq:
        return 'Groq';
      case LlmApiType.ollama:
        return 'Ollama (Local)';
      case LlmApiType.xai:
        return 'xAI (Grok)';
      case LlmApiType.openaiCompatible:
        return 'OpenAI Compatible';
    }
  }

  String get defaultBaseUrl {
    switch (this) {
      case LlmApiType.openai:
        return 'https://api.openai.com/v1/';
      case LlmApiType.anthropic:
        return 'https://api.anthropic.com/v1/';
      case LlmApiType.google:
        return 'https://generativelanguage.googleapis.com/v1beta/';
      case LlmApiType.deepseek:
        return 'https://api.deepseek.com/';
      case LlmApiType.groq:
        return 'https://api.groq.com/openai/v1/';
      case LlmApiType.ollama:
        return 'http://localhost:11434';
      case LlmApiType.xai:
        return 'https://api.x.ai/v1/';
      case LlmApiType.openaiCompatible:
        return '';
    }
  }

  String get defaultModelId {
    switch (this) {
      case LlmApiType.openai:
        return 'gpt-5';
      case LlmApiType.anthropic:
        return 'claude-4-5-sonnet';
      case LlmApiType.google:
        return 'gemini-3-pro';
      case LlmApiType.deepseek:
        return 'deepseek-chat';
      case LlmApiType.groq:
        return 'llama3-70b-8192';
      case LlmApiType.ollama:
        return 'llama3';
      case LlmApiType.xai:
        return 'grok-beta';
      case LlmApiType.openaiCompatible:
        return 'model-identifier';
    }
  }

  /// Helper to parse string code to LlmApiType
  static LlmApiType? fromCode(String code) {
    final normalized = code.toLowerCase();
    switch (normalized) {
      case 'oai':
        return LlmApiType.openai;
      case 'ant':
        return LlmApiType.anthropic;
      case 'gem':
      case 'gemini':
        return LlmApiType.google;
      default:
        try {
          return LlmApiType.values.byName(normalized);
        } catch (_) {
          return null;
        }
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
