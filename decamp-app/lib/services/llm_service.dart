import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llm_dart/llm_dart.dart';
import '../models/llm_api_settings.dart';
import '../providers/llm_settings_provider.dart';
import '../providers/project_provider.dart';
import '../providers/settings_provider.dart';
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
    String apiKey,
  ) async {
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
        return await builder.build();

      case LlmApiType.anthropic:
        final builder = ai()
            .anthropic()
            .apiKey(apiKey)
            .baseUrl(config.baseUrl)
            .model(config.identifier)
            .temperature(temperature);
        if (maxTokens != null) builder.maxTokens(maxTokens);
        return await builder.build();

      case LlmApiType.google:
        final builder = ai()
            .google()
            .apiKey(apiKey)
            .baseUrl(config.baseUrl)
            .model(config.identifier)
            .temperature(temperature);
        if (maxTokens != null) builder.maxTokens(maxTokens);
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
        activeConfig.config,
        activeConfig.apiKey,
      );

      // Build messages array
      final messages = <ChatMessage>[];

      // Add system message with agent instruction if configured
      final agentInstruction = getAgentInstruction(
        activeConfig.config.identifier,
      );
      if (agentInstruction != null && agentInstruction.isNotEmpty) {
        messages.add(ChatMessage.system(agentInstruction));
      }

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

  /// Get the current agent instruction that would be used for the active model
  /// Useful for debugging or displaying in UI
  Future<String?> getCurrentAgentInstruction() async {
    final identifier = await getCurrentIdentifier();
    if (identifier == null) return null;
    return getAgentInstruction(identifier);
  }
}
