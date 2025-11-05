import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llm_dart/llm_dart.dart';
import '../models/llm_api_settings.dart';
import '../providers/llm_settings_provider.dart';
import '../providers/project_provider.dart';
import '../services/keychain_service.dart';

/// Provider for the LLM service
final llmServiceProvider = Provider<LlmService>((ref) {
  final keychainService = ref.watch(keychainServiceProvider);
  final currentProject = ref.watch(currentProjectProvider);

  return LlmService(
    ref: ref,
    keychainService: keychainService,
    currentProjectId: currentProject?.id,
  );
});

/// Service for interacting with LLM APIs using llm_dart
class LlmService {
  final Ref ref;
  final KeychainService keychainService;
  final String? currentProjectId;

  LlmService({
    required this.ref,
    required this.keychainService,
    this.currentProjectId,
  });

  /// Get the active LLM configuration (project-specific or global)
  Future<({LlmApiSettings config, String apiKey})?> _getActiveConfig() async {
    List<LlmApiSettings> settings;
    String? projectId;

    // Try project-specific settings first if we have a project
    if (currentProjectId != null) {
      settings = ref.read(projectLlmSettingsProvider(currentProjectId!));
      projectId = currentProjectId;
    } else {
      settings = [];
    }

    // Fall back to global settings if no project settings
    if (settings.isEmpty) {
      settings = ref.read(globalLlmSettingsProvider);
      projectId = null;
    }

    // Find first enabled configuration
    final config = settings.where((s) => s.enabled).firstOrNull;
    if (config == null) {
      return null;
    }

    // Get API key from keychain
    final keychainKey = projectId != null
        ? LlmApiKeychainKeys.buildProjectKey(projectId, config.identifier)
        : LlmApiKeychainKeys.buildGlobalKey(config.identifier);

    final apiKey = await keychainService.getGlobalSecret(keychainKey);
    if (apiKey == null) {
      throw Exception('API key not found for ${config.identifier}');
    }

    return (config: config, apiKey: apiKey);
  }

  /// Create an LLM provider based on the identifier and baseUrl
  Future<ChatCapability> _createProvider(
    String identifier,
    String baseUrl,
    String apiKey, {
    double? temperature,
    int? maxTokens,
  }) async {
    final lowerIdentifier = identifier.toLowerCase();

    // OpenAI or OpenAI-compatible
    if (lowerIdentifier.contains('gpt') ||
        lowerIdentifier.contains('openai') ||
        baseUrl.contains('openai.com')) {
      final builder = ai()
          .openai()
          .apiKey(apiKey)
          .baseUrl(baseUrl)
          .model(identifier)
          .temperature(temperature ?? 0.7);
      if (maxTokens != null) builder.maxTokens(maxTokens);
      return await builder.build();
    }

    // Anthropic Claude
    if (lowerIdentifier.contains('claude') ||
        lowerIdentifier.contains('anthropic') ||
        baseUrl.contains('anthropic.com')) {
      final builder = ai()
          .anthropic()
          .apiKey(apiKey)
          .baseUrl(baseUrl)
          .model(identifier)
          .temperature(temperature ?? 0.7);
      if (maxTokens != null) builder.maxTokens(maxTokens);
      return await builder.build();
    }

    // Google Gemini
    if (lowerIdentifier.contains('gemini') ||
        lowerIdentifier.contains('google') ||
        baseUrl.contains('generativelanguage.googleapis.com')) {
      final builder = ai()
          .google()
          .apiKey(apiKey)
          .baseUrl(baseUrl)
          .model(identifier)
          .temperature(temperature ?? 0.7);
      if (maxTokens != null) builder.maxTokens(maxTokens);
      return await builder.build();
    }

    // Ollama (local)
    if (lowerIdentifier.contains('ollama') || baseUrl.contains('localhost')) {
      return await ai()
          .ollama()
          .baseUrl(baseUrl)
          .model(identifier)
          .temperature(temperature ?? 0.7)
          .build();
    }

    // Groq
    if (lowerIdentifier.contains('groq') || baseUrl.contains('groq.com')) {
      final builder = ai()
          .groq()
          .apiKey(apiKey)
          .baseUrl(baseUrl)
          .model(identifier)
          .temperature(temperature ?? 0.7);
      if (maxTokens != null) builder.maxTokens(maxTokens);
      return await builder.build();
    }

    // DeepSeek
    if (lowerIdentifier.contains('deepseek') ||
        baseUrl.contains('deepseek.com')) {
      final builder = ai()
          .deepseek()
          .apiKey(apiKey)
          .baseUrl(baseUrl)
          .model(identifier)
          .temperature(temperature ?? 0.7);
      if (maxTokens != null) builder.maxTokens(maxTokens);
      return await builder.build();
    }

    // xAI (Grok)
    if (lowerIdentifier.contains('grok') ||
        lowerIdentifier.contains('xai') ||
        baseUrl.contains('x.ai')) {
      final builder = ai()
          .xai()
          .apiKey(apiKey)
          .baseUrl(baseUrl)
          .model(identifier)
          .temperature(temperature ?? 0.7);
      if (maxTokens != null) builder.maxTokens(maxTokens);
      return await builder.build();
    }

    // Default to OpenAI-compatible API
    final builder = ai()
        .openai()
        .apiKey(apiKey)
        .baseUrl(baseUrl)
        .model(identifier)
        .temperature(temperature ?? 0.7);
    if (maxTokens != null) builder.maxTokens(maxTokens);
    return await builder.build();
  }

  /// Send a chat message and get a streaming response
  /// Returns a stream of text chunks
  Stream<String> sendMessage(
    String message, {
    List<Map<String, String>>? history,
  }) async* {
    final activeConfig = await _getActiveConfig();

    if (activeConfig == null) {
      yield 'Error: No LLM configuration found. Please configure an LLM in Settings.';
      return;
    }

    try {
      final provider = await _createProvider(
        activeConfig.config.identifier,
        activeConfig.config.baseUrl,
        activeConfig.apiKey,
        temperature: activeConfig.config.temperature,
        maxTokens: activeConfig.config.maxTokens,
      );

      // Build messages array
      final messages = <ChatMessage>[];

      // Add history if provided
      if (history != null) {
        for (final msg in history) {
          if (msg['role'] == 'user') {
            messages.add(ChatMessage.user(msg['content'] ?? ''));
          } else {
            messages.add(ChatMessage.assistant(msg['content'] ?? ''));
          }
        }
      }

      // Add current message
      messages.add(ChatMessage.user(message));

      // Stream the response
      final stream = provider.chatStream(messages);

      await for (final event in stream) {
        if (event is TextDeltaEvent) {
          yield event.delta;
        } else if (event is ErrorEvent) {
          yield 'Error: ${event.error}';
          break;
        }
      }
    } catch (e) {
      yield 'Error: ${e.toString()}';
    }
  }

  /// Send a message and get a complete response (non-streaming)
  Future<String> sendMessageSync(
    String message, {
    List<Map<String, String>>? history,
  }) async {
    final buffer = StringBuffer();

    await for (final chunk in sendMessage(message, history: history)) {
      buffer.write(chunk);
    }

    return buffer.toString();
  }

  /// Check if LLM is configured and ready
  Future<bool> isConfigured() async {
    final config = await _getActiveConfig();
    return config != null;
  }

  /// Get the current LLM identifier
  Future<String?> getCurrentIdentifier() async {
    final config = await _getActiveConfig();
    return config?.config.identifier;
  }
}
