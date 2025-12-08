import 'package:llm_dart/llm_dart.dart';
import 'package:agent_core/agent_core.dart';
import '../database/database_facade.dart';

/// Service for interacting with LLM APIs using llm_dart
///
/// This service is a stateless wrapper around the llm_dart library.
/// It provides a simple streaming interface for chat interactions.
/// Conversation state management is handled by the ChatController.
class LlmService {
  final KeychainService keychainService;
  final SnippetDaoFacade? snippetDao;
  final String? currentProjectId;

  final List<LlmApiSettings> projectLlmSettings;
  final ProjectSettings? projectSettings;
  final List<LlmApiSettings> globalLlmSettings;
  final AppSettings globalSettings;

  LlmService({
    required this.keychainService,
    this.snippetDao,
    this.currentProjectId,
    required this.projectLlmSettings,
    required this.projectSettings,
    required this.globalLlmSettings,
    required this.globalSettings,
  });

  /// Get the active LLM configuration (project-specific or global)
  Future<({LlmApiSettings config, String apiKey})?> _getActiveConfig() async {
    List<LlmApiSettings> settings;
    String? projectId;
    String? defaultIdentifier;

    // Try project-specific settings first if we have a project
    if (currentProjectId != null) {
      settings = projectLlmSettings;
      projectId = currentProjectId;
      defaultIdentifier = projectSettings?.defaultLlmIdentifier;
    } else {
      settings = [];
    }

    // Fall back to global settings if no project settings
    if (settings.isEmpty) {
      settings = globalLlmSettings;
      projectId = null;
      defaultIdentifier = globalSettings.defaultLlmIdentifier;
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
    // Try project-specific key first, then fall back to global key
    String? apiKey;
    if (projectId != null) {
      apiKey = await keychainService.getProjectSecret(
        projectId,
        LlmApiKeychainKeys.buildProjectKey(projectId, config.identifier),
      );
      // Fall back to global key if project-specific key not found
      apiKey ??= await keychainService.getGlobalSecret(
        LlmApiKeychainKeys.buildGlobalKey(config.identifier),
      );
    } else {
      apiKey = await keychainService.getGlobalSecret(
        LlmApiKeychainKeys.buildGlobalKey(config.identifier),
      );
    }

    if (apiKey == null) {
      throw Exception('API key not found for ${config.identifier}');
    }

    return (config: config, apiKey: apiKey);
  }

  /// Get the final agent instruction for a model
  /// Simplified hierarchy: project override > project default > global override > global default
  /// Processes template variables like {{ SECRETS }}
  Future<String?> getAgentInstruction(String modelIdentifier) async {
    String? instruction;

    // Get project instruction if we have a project
    if (currentProjectId != null) {
      final projectInstruction = projectSettings?.agentInstruction;

      if (projectInstruction != null) {
        // Check model override first, then default
        instruction = projectInstruction.modelOverrides[modelIdentifier] ??
            (projectInstruction.defaultInstruction.isNotEmpty
                ? projectInstruction.defaultInstruction
                : null);

        if (instruction != null) {
          // Optionally prepend global instruction
          if (projectSettings?.includeUserInstructions ?? false) {
            final globalInstruction = await _getGlobalInstruction(
              modelIdentifier,
            );
            if (globalInstruction != null) {
              instruction = '$globalInstruction\n\n$instruction';
            }
          }
        }
      }
    }

    // Fall back to global instruction if not set
    instruction ??= await _getGlobalInstruction(modelIdentifier);

    // Process template variables if instruction exists
    if (instruction != null) {
      instruction = await _processTemplateVariables(instruction);
    }

    return instruction;
  }

  /// Get global instruction for a model
  Future<String?> _getGlobalInstruction(String modelIdentifier) async {
    final userInstruction = globalSettings.agentInstruction;
    if (userInstruction == null) return null;

    // Check model override first, then default
    return userInstruction.modelOverrides[modelIdentifier] ??
        (userInstruction.defaultInstruction.isNotEmpty
            ? userInstruction.defaultInstruction
            : null);
  }

  /// Process template variables in the instruction text
  Future<String> _processTemplateVariables(String instruction) async {
    // Quick check if there are any template variables
    if (!TemplateProcessor.hasTemplateVariables(instruction)) {
      return instruction;
    }

    // Fetch all secret names (global + project merged)
    final globalSecrets = await keychainService.listGlobalSecrets();
    final Map<String, String> secretsMap = {...globalSecrets};

    if (currentProjectId != null) {
      final projectSecrets = await keychainService.listProjectSecrets(
        currentProjectId!,
      );
      secretsMap.addAll(projectSecrets);
    }

    final secretNames = secretsMap.keys.toList()..sort();

    // Fetch snippets
    List<SnippetEntity> userSnippets = [];
    List<SnippetEntity> projectSnippets = [];

    if (snippetDao != null) {
      userSnippets = await snippetDao!.getGlobalSnippets();
      if (currentProjectId != null) {
        projectSnippets = await snippetDao!.getProjectSnippets(
          currentProjectId!,
        );
      }
    }

    // Process the template
    return TemplateProcessor.process(
      instruction,
      secretNames: secretNames,
      userSnippets: userSnippets,
      projectSnippets: projectSnippets,
    );
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
  Stream<ChatStreamEvent> streamChat(
    List<ChatMessage> conversation, {
    List<Tool>? tools,
  }) async* {
    final activeConfig = await _getActiveConfig();

    if (activeConfig == null) {
      yield ErrorEvent(
        ProviderError(
          'No LLM configuration found. Please configure an LLM in Settings.',
        ),
      );
      return;
    }

    try {
      final agentInstruction = await getAgentInstruction(
        activeConfig.config.identifier,
      );
      final provider = await _createProvider(
        activeConfig.config,
        activeConfig.apiKey,
        systemInstruction: agentInstruction,
      );

      final stream = provider.chatStream(conversation, tools: tools);
      yield* stream;
    } catch (e) {
      yield ErrorEvent(ProviderError(e.toString()));
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

  /// Get a snapshot of the active configuration for remote execution
  Future<Map<String, dynamic>?> getActiveConfigSnapshot() async {
    final activeConfig = await _getActiveConfig();
    if (activeConfig == null) return null;

    return {
      'apiKey': activeConfig.apiKey,
      'provider': activeConfig.config.apiType.name,
      'model': activeConfig.config.identifier,
      'baseUrl': activeConfig.config.baseUrl,
      'temperature': activeConfig.config.temperature,
      'maxTokens': activeConfig.config.maxTokens,
    };
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
