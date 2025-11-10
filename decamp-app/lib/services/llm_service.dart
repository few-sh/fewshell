import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llm_dart/llm_dart.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart'
    as chat_ui
    show AiAction, ActionParameterType;
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
///
/// This service provides integration between llm_dart and flutter_gen_ai_chat_ui,
/// including native tool calling support through llm_dart's built-in Tool system.
///
/// Tool Calling Example:
/// ```dart
/// // 1. Get AI actions from the AiActionProvider
/// final aiActions = [...]; // Your AiAction definitions
///
/// // 2. Convert to llm_dart Tools
/// final tools = llmService.convertActionsToTools(aiActions);
///
/// // 3. Send message with tools
/// await for (final chunk in llmService.sendMessageWithTools(
///   'Check disk space on the server',
///   tools: tools,
/// )) {
///   print(chunk);
/// }
/// ```
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

  /// Send a chat message and get a streaming response
  /// Returns a stream of text chunks
  Stream<String> sendMessage(
    String message, {
    List<Map<String, String>>? history,
  }) async* {
    developer.log('🚀 sendMessage called', name: 'LlmService');
    developer.log('Message: $message', name: 'LlmService');
    developer.log(
      'History length: ${history?.length ?? 0}',
      name: 'LlmService',
    );

    final activeConfig = await _getActiveConfig();

    if (activeConfig == null) {
      developer.log('❌ No active config found', name: 'LlmService');
      yield 'Error: No LLM configuration found. Please configure an LLM in Settings.';
      return;
    }

    developer.log(
      '✅ Active config: ${activeConfig.config.identifier}',
      name: 'LlmService',
    );
    developer.log(
      'API Type: ${activeConfig.config.apiType}',
      name: 'LlmService',
    );

    try {
      // Get agent instruction if configured
      final agentInstruction = getAgentInstruction(
        activeConfig.config.identifier,
      );

      if (agentInstruction != null) {
        developer.log(
          '📝 Agent instruction: ${agentInstruction.substring(0, agentInstruction.length > 100 ? 100 : agentInstruction.length)}...',
          name: 'LlmService',
        );
      }

      // Create provider with system instruction in config
      developer.log('🔧 Creating provider...', name: 'LlmService');
      final provider = await _createProvider(
        activeConfig.config,
        activeConfig.apiKey,
        systemInstruction: agentInstruction,
      );
      developer.log('✅ Provider created', name: 'LlmService');

      // Build messages array
      final messages = <ChatMessage>[];

      // For Google Gemini, DO NOT add system message to messages array
      // It's handled via systemPrompt in the config
      // For other providers (OpenAI, Anthropic), the systemPrompt in config
      // will be properly handled by the llm_dart library

      // Add history if provided
      if (history != null) {
        developer.log(
          '📚 Adding ${history.length} history messages',
          name: 'LlmService',
        );
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
      developer.log(
        '📤 Total messages to send: ${messages.length}',
        name: 'LlmService',
      );

      // Stream the response
      developer.log('🌊 Starting stream...', name: 'LlmService');
      final stream = provider.chatStream(messages);

      var chunkCount = 0;
      await for (final event in stream) {
        chunkCount++;
        developer.log(
          '📨 Event #$chunkCount: ${event.runtimeType}',
          name: 'LlmService',
        );

        if (event is TextDeltaEvent) {
          developer.log('💬 Text chunk: "${event.delta}"', name: 'LlmService');
          yield event.delta;
        } else if (event is ErrorEvent) {
          developer.log('❌ Error event: ${event.error}', name: 'LlmService');
          yield 'Error: ${event.error}';
          break;
        } else {
          developer.log(
            'ℹ️ Other event type: ${event.runtimeType}',
            name: 'LlmService',
          );
        }
      }

      developer.log(
        '✅ Stream completed. Total chunks: $chunkCount',
        name: 'LlmService',
      );
    } catch (e) {
      developer.log('❌ Exception in sendMessage: $e', name: 'LlmService');
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

  /// Send a chat message with tool support
  ///
  /// When a tool call is detected, yields a Map with tool call information
  /// instead of executing it directly. The UI layer should handle execution
  /// through AiActionHook.executeAction() to show confirmation dialogs.
  ///
  /// Yields either:
  /// - String: text chunks from the LLM
  /// - Map: {'type': 'tool_call', 'name': '...', 'params': {...}}
  Stream<dynamic> sendMessageWithTools(
    String message, {
    List<Map<String, String>>? history,
    List<Tool>? tools,
  }) async* {
    final activeConfig = await _getActiveConfig();

    if (activeConfig == null) {
      yield 'Error: No LLM configuration found. Please configure an LLM in Settings.';
      return;
    }

    try {
      // Get agent instruction if configured
      final agentInstruction = getAgentInstruction(
        activeConfig.config.identifier,
      );

      // Create provider with system instruction
      // Note: Tools are passed to the chat methods, not the provider
      final provider = await _createProvider(
        activeConfig.config,
        activeConfig.apiKey,
        systemInstruction: agentInstruction,
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

      developer.log(
        '📤 Calling provider.chatStream with ${messages.length} messages and ${tools?.length ?? 0} tools',
        name: 'LlmService',
      );

      // Stream the response with tools
      final stream = provider.chatStream(messages, tools: tools);

      await for (final event in stream) {
        developer.log(
          '📥 Received event: ${event.runtimeType}',
          name: 'LlmService',
        );

        if (event is TextDeltaEvent) {
          developer.log('💬 Text delta: "${event.delta}"', name: 'LlmService');
          yield event.delta;
        } else if (event is ToolCallDeltaEvent) {
          developer.log(
            '🔧 Tool call detected: ${event.toolCall.function.name}',
            name: 'LlmService',
          );
          developer.log(
            '🔧 Tool arguments: ${event.toolCall.function.arguments}',
            name: 'LlmService',
          );

          // Parse tool call parameters
          final toolName = event.toolCall.function.name;
          final argumentsJson = event.toolCall.function.arguments;

          // Parse arguments
          final params = argumentsJson.isNotEmpty
              ? Map<String, dynamic>.from(json.decode(argumentsJson))
              : <String, dynamic>{};

          developer.log(
            '🔧 Yielding tool call to UI layer: $toolName',
            name: 'LlmService',
          );

          // Yield tool call information to the UI layer
          // The UI will handle execution through AiActionHook
          yield {'type': 'tool_call', 'name': toolName, 'params': params};
        } else if (event is ErrorEvent) {
          developer.log('❌ Error event: ${event.error}', name: 'LlmService');
          yield 'Error: ${event.error}';
          break;
        }
      }

      developer.log('✅ Stream completed', name: 'LlmService');
    } catch (e) {
      developer.log(
        '❌ Exception in sendMessageWithTools: $e',
        name: 'LlmService',
      );
      yield 'Error: ${e.toString()}';
    }
  }

  /// Continue conversation after tool execution
  /// Sends the tool result back to the LLM and streams its response
  Stream<String> continueWithToolResult(
    String toolName,
    Map<String, dynamic> toolParams,
    String toolResult, {
    required List<Map<String, String>> history,
    List<Tool>? tools,
  }) async* {
    final activeConfig = await _getActiveConfig();

    if (activeConfig == null) {
      yield 'Error: No LLM configuration found. Please configure an LLM in Settings.';
      return;
    }

    try {
      // Get agent instruction if configured
      final agentInstruction = getAgentInstruction(
        activeConfig.config.identifier,
      );

      // Create provider with system instruction
      final provider = await _createProvider(
        activeConfig.config,
        activeConfig.apiKey,
        systemInstruction: agentInstruction,
      );

      // Build messages array from history
      final messages = <ChatMessage>[];

      // Add history (everything up to and including the tool call request)
      if (history.isNotEmpty) {
        for (final msg in history) {
          if (msg['role'] == 'user') {
            messages.add(ChatMessage.user(msg['content'] ?? ''));
          } else {
            messages.add(ChatMessage.assistant(msg['content'] ?? ''));
          }
        }
      }

      // Add the tool call result as a message
      // The LLM will see this as context for its next response
      messages.add(
        ChatMessage.user('Tool execution result for $toolName:\n$toolResult'),
      );

      developer.log(
        '📤 Continuing conversation with tool result. Messages: ${messages.length}',
        name: 'LlmService',
      );

      // Stream the LLM's response
      final stream = provider.chatStream(messages, tools: tools);

      await for (final event in stream) {
        if (event is TextDeltaEvent) {
          yield event.delta;
        } else if (event is ErrorEvent) {
          developer.log('❌ Error event: ${event.error}', name: 'LlmService');
          yield 'Error: ${event.error}';
          break;
        }
        // Note: We could handle additional tool calls here if needed
      }

      developer.log('✅ Tool result stream completed', name: 'LlmService');
    } catch (e) {
      developer.log(
        '❌ Exception in continueWithToolResult: $e',
        name: 'LlmService',
      );
      yield 'Error: ${e.toString()}';
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

  /// Convert AiActions to llm_dart Tool objects
  /// This uses llm_dart's native tool support instead of manual conversion
  List<Tool> convertActionsToTools(List<chat_ui.AiAction> actions) {
    return actions.map((action) {
      // Build parameters schema
      final properties = <String, ParameterProperty>{};
      final required = <String>[];

      for (final param in action.parameters) {
        properties[param.name] = ParameterProperty(
          propertyType: _mapParameterTypeToString(param.type),
          description: param.description,
          enumList: param.enumValues,
        );

        if (param.required) {
          required.add(param.name);
        }
      }

      return Tool.function(
        name: action.name,
        description: action.description,
        parameters: ParametersSchema(
          schemaType: 'object',
          properties: properties,
          required: required,
        ),
      );
    }).toList();
  }

  /// Map ActionParameterType to string type for llm_dart
  String _mapParameterTypeToString(chat_ui.ActionParameterType type) {
    switch (type) {
      case chat_ui.ActionParameterType.string:
        return 'string';
      case chat_ui.ActionParameterType.number:
        return 'number';
      case chat_ui.ActionParameterType.boolean:
        return 'boolean';
      case chat_ui.ActionParameterType.object:
        return 'object';
      case chat_ui.ActionParameterType.array:
        return 'array';
      case chat_ui.ActionParameterType.objectArray:
        return 'array';
    }
  }

  /// Test API connection with the provided settings
  /// Returns null if successful, or an error message if failed
  Future<String?> testConnection({
    required LlmApiSettings config,
    required String apiKey,
  }) async {
    try {
      developer.log(
        '🧪 Testing connection for ${config.identifier}',
        name: 'LlmService',
      );

      // Create provider without system instruction for testing
      final provider = await _createProvider(config, apiKey);

      // Send a minimal test message
      final messages = [ChatMessage.user('Hi')];

      developer.log('📤 Sending test message...', name: 'LlmService');

      // Try to get a response with a short timeout
      final stream = provider.chatStream(messages);
      bool receivedResponse = false;

      await for (final event in stream.timeout(
        const Duration(seconds: 30),
        onTimeout: (sink) {
          sink.addError(Exception('Connection timeout after 30 seconds'));
          sink.close();
        },
      )) {
        developer.log(
          '📨 Test event: ${event.runtimeType}',
          name: 'LlmService',
        );

        if (event is TextDeltaEvent) {
          developer.log('✅ Received text response', name: 'LlmService');
          receivedResponse = true;
          break; // Got a response, test successful
        } else if (event is ErrorEvent) {
          developer.log('❌ Error event: ${event.error}', name: 'LlmService');
          return 'API Error: ${event.error}';
        }
      }

      if (!receivedResponse) {
        return 'No response received from API';
      }

      developer.log('✅ Connection test successful', name: 'LlmService');
      return null; // Success
    } catch (e, stackTrace) {
      developer.log(
        '❌ Connection test failed: $e',
        name: 'LlmService',
        error: e,
        stackTrace: stackTrace,
      );

      // Return the actual error message
      return e.toString();
    }
  }
}
