import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llm_dart/llm_dart.dart';
import '../models/llm_api_settings.dart';
import '../models/llm_event.dart' as llm_event;
import '../providers/llm_settings_provider.dart';
import '../providers/project_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/secret_provider.dart';
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
///
/// This service is a stateless wrapper around the llm_dart library.
/// It provides a simple streaming interface for chat interactions.
/// Conversation state management is handled by the ChatController.
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
    String? defaultIdentifier;

    // Try project-specific settings first if we have a project
    if (currentProjectId != null) {
      settings = ref.read(projectLlmSettingsProvider(currentProjectId!));
      projectId = currentProjectId;
      defaultIdentifier = ref
          .read(projectSettingsProvider(currentProjectId!))
          ?.defaultLlmIdentifier;
    } else {
      settings = [];
    }

    // Fall back to global settings if no project settings
    if (settings.isEmpty) {
      settings = ref.read(globalLlmSettingsProvider);
      projectId = null;
      defaultIdentifier = ref.read(globalSettingsProvider).defaultLlmIdentifier;
    }

    // Try to use the default model if set and enabled
    LlmApiSettings? config;
    if (defaultIdentifier != null) {
      config = settings
          .where((s) => s.identifier == defaultIdentifier && s.enabled)
          .firstOrNull;
    }

    // Fall back to first enabled configuration if default is not available
    config ??= settings.where((s) => s.enabled).firstOrNull;

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

  /// Get the final agent instruction based on settings hierarchy
  /// Returns the appropriate instruction considering:
  /// 1. Project-specific model override (if project exists and override defined)
  /// 2. Project-specific default instruction (if project exists and defined)
  /// 3. User-level model override (if override defined)
  /// 4. User-level default instruction (if defined)
  /// 5. null (if no instructions configured)
  ///
  /// If project settings have includeUserInstructions=true, user instructions
  /// are prepended to project instructions.
  String? getAgentInstruction(String modelIdentifier) {
    final userSettings = ref.read(globalSettingsProvider);
    final userInstruction = userSettings.agentInstruction;

    String? projectInstructionText;
    bool includeUserInstructions = false;

    // Get project-specific instructions if we have a project
    if (currentProjectId != null) {
      final projectSettings = ref.read(
        projectSettingsProvider(currentProjectId!),
      );
      final projectInstruction = projectSettings?.agentInstruction;
      includeUserInstructions =
          projectSettings?.includeUserInstructions ?? false;

      if (projectInstruction != null) {
        // Check for model-specific override first
        if (projectInstruction.modelOverrides.containsKey(modelIdentifier)) {
          projectInstructionText =
              projectInstruction.modelOverrides[modelIdentifier];
        } else if (projectInstruction.defaultInstruction.isNotEmpty) {
          // Use project default instruction
          projectInstructionText = projectInstruction.defaultInstruction;
        }
      }
    }

    // Get user-level instructions
    String? userInstructionText;
    if (userInstruction != null) {
      // Check for model-specific override first
      if (userInstruction.modelOverrides.containsKey(modelIdentifier)) {
        userInstructionText = userInstruction.modelOverrides[modelIdentifier];
      } else if (userInstruction.defaultInstruction.isNotEmpty) {
        // Use user default instruction
        userInstructionText = userInstruction.defaultInstruction;
      }
    }

    // Combine instructions based on settings
    if (projectInstructionText != null && projectInstructionText.isNotEmpty) {
      if (includeUserInstructions &&
          userInstructionText != null &&
          userInstructionText.isNotEmpty) {
        // Prepend user instructions to project instructions
        return '$userInstructionText\n\n$projectInstructionText';
      }
      return projectInstructionText;
    }

    // Fall back to user instructions if no project instructions
    return userInstructionText;
  }

  /// Create an LLM provider based on the API type
  Future<ChatCapability> _createProvider(
    LlmApiSettings config,
    String apiKey, {
    String? systemInstruction,
  }) async {
    final temperature = config.temperature ?? 0.7;
    final maxTokens = config.maxTokens;

    switch (config.apiType) {
      case LlmApiType.openai:
        final builder = ai()
            .openai()
            .apiKey(apiKey)
            .baseUrl(config.baseUrl)
            .model(config.identifier)
            .temperature(temperature);
        if (maxTokens != null) builder.maxTokens(maxTokens);
        if (systemInstruction != null) builder.systemPrompt(systemInstruction);
        return await builder.build();

      case LlmApiType.anthropic:
        final builder = ai()
            .anthropic()
            .apiKey(apiKey)
            .baseUrl(config.baseUrl)
            .model(config.identifier)
            .temperature(temperature);
        if (maxTokens != null) builder.maxTokens(maxTokens);
        if (systemInstruction != null) builder.systemPrompt(systemInstruction);
        return await builder.build();

      case LlmApiType.google:
        final builder = ai()
            .google()
            .apiKey(apiKey)
            .baseUrl(config.baseUrl)
            .model(config.identifier)
            .temperature(temperature);
        if (maxTokens != null) builder.maxTokens(maxTokens);
        // Google Gemini requires system instruction in config, not in messages
        if (systemInstruction != null) builder.systemPrompt(systemInstruction);
        return await builder.build();

      case LlmApiType.ollama:
        return await ai()
            .ollama()
            .baseUrl(config.baseUrl)
            .model(config.identifier)
            .temperature(temperature)
            .build();

      case LlmApiType.groq:
        final builder = ai()
            .groq()
            .apiKey(apiKey)
            .baseUrl(config.baseUrl)
            .model(config.identifier)
            .temperature(temperature);
        if (maxTokens != null) builder.maxTokens(maxTokens);
        return await builder.build();

      case LlmApiType.deepseek:
        final builder = ai()
            .deepseek()
            .apiKey(apiKey)
            .baseUrl(config.baseUrl)
            .model(config.identifier)
            .temperature(temperature);
        if (maxTokens != null) builder.maxTokens(maxTokens);
        return await builder.build();

      case LlmApiType.xai:
        final builder = ai()
            .xai()
            .apiKey(apiKey)
            .baseUrl(config.baseUrl)
            .model(config.identifier)
            .temperature(temperature);
        if (maxTokens != null) builder.maxTokens(maxTokens);
        return await builder.build();

      case LlmApiType.openaiCompatible:
        final builder = ai()
            .openai()
            .apiKey(apiKey)
            .baseUrl(config.baseUrl)
            .model(config.identifier)
            .temperature(temperature);
        if (maxTokens != null) builder.maxTokens(maxTokens);
        return await builder.build();
    }
  }

  /// Stream chat events from the LLM
  ///
  /// Takes a complete conversation and streams back events.
  /// The caller is responsible for building the conversation state.
  Stream<llm_event.LlmEvent> streamChat(
    List<ChatMessage> conversation, {
    List<Tool>? tools,
  }) async* {
    final activeConfig = await _getActiveConfig();

    if (activeConfig == null) {
      yield llm_event.ErrorEvent(
        'No LLM configuration found. Please configure an LLM in Settings.',
      );
      return;
    }

    try {
      final agentInstruction = getAgentInstruction(
        activeConfig.config.identifier,
      );
      final provider = await _createProvider(
        activeConfig.config,
        activeConfig.apiKey,
        systemInstruction: agentInstruction,
      );

      final stream = provider.chatStream(conversation, tools: tools);

      await for (final event in stream) {
        switch (event) {
          case TextDeltaEvent(delta: final delta):
            yield llm_event.TextChunk(delta);

          case ToolCallDeltaEvent(toolCall: final toolCall):
            yield llm_event.ToolCallEvent(toolCall);

          case CompletionEvent():
            yield llm_event.CompletionEvent();

          case ErrorEvent(error: final error):
            yield llm_event.ErrorEvent(error.toString());

          case ThinkingDeltaEvent():
            yield llm_event.ThinkingEvent();
        }
      }
    } catch (e) {
      yield llm_event.ErrorEvent(e.toString());
    }
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

  /// Get the current agent instruction that would be used for the active model
  /// Useful for debugging or displaying in UI
  Future<String?> getCurrentAgentInstruction() async {
    final identifier = await getCurrentIdentifier();
    if (identifier == null) return null;
    return getAgentInstruction(identifier);
  }

  /// Test API connection with the provided settings
  /// Returns null if successful, or an error message if failed
  Future<String?> testConnection({
    required LlmApiSettings config,
    required String apiKey,
  }) async {
    try {
      final provider = await _createProvider(config, apiKey);
      final messages = [ChatMessage.user('Hi')];
      final stream = provider.chatStream(messages);
      bool receivedResponse = false;

      await for (final event in stream.timeout(
        const Duration(seconds: 30),
        onTimeout: (sink) {
          sink.addError(Exception('Connection timeout after 30 seconds'));
          sink.close();
        },
      )) {
        if (event is TextDeltaEvent) {
          receivedResponse = true;
          break;
        } else if (event is ErrorEvent) {
          return 'API Error: ${event.error}';
        }
      }

      if (!receivedResponse) {
        return 'No response received from API';
      }

      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
