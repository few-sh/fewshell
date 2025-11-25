/// LLM API configuration settings.
///
/// API keys are stored separately (in keychain on client, in secrets file on server).
/// The [apiKeySecretId] references the secret, not the actual key value.
class LlmSettings {
  /// Unique identifier for this LLM configuration (e.g., "gpt-4-turbo")
  final String identifier;

  /// Type of API provider (openai, anthropic, google, etc.)
  final String provider;

  /// Model identifier (e.g., "gpt-4o", "claude-3-5-sonnet")
  final String model;

  /// Base URL for the API endpoint
  final String baseUrl;

  /// Secret ID that references the API key (not the actual key)
  final String? apiKeySecretId;

  /// Optional: Maximum tokens for this model
  final int? maxTokens;

  /// Optional: Default temperature setting
  final double? temperature;

  /// Whether this configuration is enabled
  final bool enabled;

  const LlmSettings({
    required this.identifier,
    required this.provider,
    required this.model,
    required this.baseUrl,
    this.apiKeySecretId,
    this.maxTokens,
    this.temperature,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'provider': provider,
        'model': model,
        'baseUrl': baseUrl,
        if (apiKeySecretId != null) 'apiKeySecretId': apiKeySecretId,
        if (maxTokens != null) 'maxTokens': maxTokens,
        if (temperature != null) 'temperature': temperature,
        'enabled': enabled,
      };

  factory LlmSettings.fromJson(Map<String, dynamic> json) => LlmSettings(
        identifier: json['identifier'] as String,
        provider: json['provider'] as String,
        model: json['model'] as String,
        baseUrl: json['baseUrl'] as String,
        apiKeySecretId: json['apiKeySecretId'] as String?,
        maxTokens: json['maxTokens'] as int?,
        temperature: (json['temperature'] as num?)?.toDouble(),
        enabled: json['enabled'] as bool? ?? true,
      );

  LlmSettings copyWith({
    String? identifier,
    String? provider,
    String? model,
    String? baseUrl,
    String? apiKeySecretId,
    int? maxTokens,
    double? temperature,
    bool? enabled,
  }) =>
      LlmSettings(
        identifier: identifier ?? this.identifier,
        provider: provider ?? this.provider,
        model: model ?? this.model,
        baseUrl: baseUrl ?? this.baseUrl,
        apiKeySecretId: apiKeySecretId ?? this.apiKeySecretId,
        maxTokens: maxTokens ?? this.maxTokens,
        temperature: temperature ?? this.temperature,
        enabled: enabled ?? this.enabled,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LlmSettings &&
          runtimeType == other.runtimeType &&
          identifier == other.identifier &&
          provider == other.provider &&
          model == other.model &&
          baseUrl == other.baseUrl &&
          apiKeySecretId == other.apiKeySecretId &&
          maxTokens == other.maxTokens &&
          temperature == other.temperature &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(
        identifier,
        provider,
        model,
        baseUrl,
        apiKeySecretId,
        maxTokens,
        temperature,
        enabled,
      );

  @override
  String toString() =>
      'LlmSettings(identifier: $identifier, provider: $provider, model: $model)';
}
