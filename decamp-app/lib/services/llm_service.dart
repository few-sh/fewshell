import 'dart:convert';
import 'dart:developer' as developer;
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
///
/// This service provides integration with various LLM providers,
/// including native tool calling support through llm_dart's built-in Tool system.
///
/// Tool Calling Example:
/// ```dart
/// // 1. Define tools using llm_dart Tool
/// final tools = [Tool.function(name: 'my_tool', ...)];
///
/// // 2. Build conversation with ChatMessage objects
/// final conversation = [ChatMessage.user('Check disk space on the server')];
///
/// // 3. Send message with conversation and tools
/// await for (final chunk in llmService.sendMessageWithConversation(
///   conversation,
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

  /// Send a chat message with tool support using ChatMessage conversation
  ///
  /// This is the recommended method that preserves complete conversation context
  /// including tool use and tool results.
  ///
  /// Yields either:
  /// - String: text chunks from the LLM
  /// - Map: {'type': 'tool_call', 'name': '...', 'params': {...}, 'toolCall': ToolCall}
  Stream<dynamic> sendMessageWithConversation(
    List<ChatMessage> conversation,
    String newMessage, {
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

      // Build conversation with the new message
      final fullConversation = List<ChatMessage>.from(conversation);
      fullConversation.add(ChatMessage.user(newMessage));

      developer.log(
        '📤 Calling provider.chatStream with ${fullConversation.length} messages and ${tools?.length ?? 0} tools',
        name: 'LlmService',
      );

      // Debug: Log the conversation structure
      for (var i = 0; i < fullConversation.length; i++) {
        final msg = fullConversation[i];
        developer.log(
          '  [$i] ${msg.role.name} - ${msg.messageType.runtimeType}: ${msg.content.length} chars',
          name: 'LlmService',
        );
      }

      // Collect tool calls as they arrive
      final toolCallsCollected = <ToolCall>[];
      final textBuffer = StringBuffer();

      // Stream the response with tools
      final stream = provider.chatStream(fullConversation, tools: tools);

      await for (final event in stream) {
        developer.log(
          '📥 Received event: ${event.runtimeType}',
          name: 'LlmService',
        );

        switch (event) {
          case TextDeltaEvent(delta: final delta):
            developer.log('💬 Text delta: "$delta"', name: 'LlmService');
            textBuffer.write(delta);
            yield delta;

          case ToolCallDeltaEvent(toolCall: final toolCall):
            developer.log(
              '🔧 Tool call detected: ${toolCall.function.name}',
              name: 'LlmService',
            );
            developer.log(
              '🔧 Tool arguments: ${toolCall.function.arguments}',
              name: 'LlmService',
            );

            toolCallsCollected.add(toolCall);

            // Parse tool call parameters
            final toolName = toolCall.function.name;
            final argumentsJson = toolCall.function.arguments;

            // Parse arguments
            final params = argumentsJson.isNotEmpty
                ? Map<String, dynamic>.from(json.decode(argumentsJson))
                : <String, dynamic>{};

            developer.log(
              '🔧 Yielding tool call to UI layer: $toolName',
              name: 'LlmService',
            );

            // Yield tool call information to the UI layer
            yield {
              'type': 'tool_call',
              'name': toolName,
              'params': params,
              'toolCall': toolCall,
            };

          case CompletionEvent():
            developer.log('🏁 Stream completed', name: 'LlmService');

            // If tool calls were collected, yield completion info
            if (toolCallsCollected.isNotEmpty) {
              developer.log(
                '📦 Collected ${toolCallsCollected.length} tool calls',
                name: 'LlmService',
              );

              // Yield completion event with conversation and tool calls
              yield {
                'type': 'completion',
                'toolCalls': toolCallsCollected,
                'text': textBuffer.toString(),
                'conversation': fullConversation,
              };
            }

          case ErrorEvent(error: final error):
            developer.log('❌ Error event: $error', name: 'LlmService');
            yield 'Error: $error';
            break;

          case ThinkingDeltaEvent():
            developer.log('💭 Thinking event', name: 'LlmService');
        }
      }

      developer.log('✅ Stream completed', name: 'LlmService');
    } catch (e, stackTrace) {
      developer.log(
        '❌ Exception in sendMessageWithConversation: $e',
        name: 'LlmService',
        error: e,
        stackTrace: stackTrace,
      );
      yield 'Error: ${e.toString()}';
    }
  }

  /// Continue conversation after tool execution (following official pattern)
  ///
  /// Takes the conversation state, tool calls, and results, then continues
  /// the conversation with the LLM to get the final response.
  ///
  /// Parameters:
  /// - conversation: The conversation up to the point of tool calls
  /// - toolCalls: The ToolCall objects collected from the stream
  /// - toolResults: Map of tool call ID to result content
  /// - tools: Available tools for potential follow-up calls
  ///
  /// Yields:
  /// - String: Text delta for streaming response
  /// - Map: Tool call or completion events (same format as sendMessageWithTools)
  Stream<dynamic> continueWithToolResults(
    List<ChatMessage> conversation,
    List<ToolCall> toolCalls,
    Map<String, String> toolResults, {
    List<Tool>? tools,
  }) async* {
    final activeConfig = await _getActiveConfig();

    if (activeConfig == null) {
      yield 'Error: No LLM configuration found. Please configure an LLM in Settings.';
      return;
    }

    try {
      developer.log(
        '🔄 Continuing with ${toolCalls.length} tool results',
        name: 'LlmService',
      );

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

      // Build the continuation conversation
      // NOTE: The conversation should already include the assistant's tool use message
      // since we're receiving the updated conversation from the repository
      final updatedConversation = List<ChatMessage>.from(conversation);

      developer.log(
        '📋 Conversation before adding tool results: ${updatedConversation.length} messages',
        name: 'LlmService',
      );

      // Log the last few messages to verify structure
      for (
        var i = updatedConversation.length - 3;
        i < updatedConversation.length && i >= 0;
        i++
      ) {
        final msg = updatedConversation[i];
        developer.log(
          '  [$i] ${msg.role}: ${msg.messageType.runtimeType}',
          name: 'LlmService',
        );
      }

      // Add tool results
      for (final toolCall in toolCalls) {
        final result = toolResults[toolCall.id] ?? 'No result provided';
        developer.log(
          '📄 Adding result for ${toolCall.function.name}: ${result.length} chars',
          name: 'LlmService',
        );

        updatedConversation.add(
          ChatMessage.toolResult(results: [toolCall], content: result),
        );
      }

      developer.log(
        '📤 Getting final response with ${updatedConversation.length} messages',
        name: 'LlmService',
      );

      // Get final response
      final stream = provider.chatStream(updatedConversation, tools: tools);

      // Collect follow-up tool calls
      final followUpToolCalls = <ToolCall>[];
      final followUpTextBuffer = StringBuffer();

      await for (final event in stream) {
        switch (event) {
          case TextDeltaEvent(delta: final delta):
            followUpTextBuffer.write(delta);
            yield delta;

          case ToolCallDeltaEvent(toolCall: final toolCall):
            // Handle follow-up tool calls
            developer.log(
              '🔧 Follow-up tool call detected: ${toolCall.function.name}',
              name: 'LlmService',
            );

            followUpToolCalls.add(toolCall);

            // Parse and yield tool call info to UI
            final toolName = toolCall.function.name;
            final argumentsJson = toolCall.function.arguments;
            final params = argumentsJson.isNotEmpty
                ? Map<String, dynamic>.from(json.decode(argumentsJson))
                : <String, dynamic>{};

            developer.log(
              '🔧 Yielding follow-up tool call: $toolName',
              name: 'LlmService',
            );

            yield {
              'type': 'tool_call',
              'name': toolName,
              'params': params,
              'toolCall': toolCall,
            };

          case ErrorEvent(error: final error):
            developer.log('❌ Error event: $error', name: 'LlmService');
            yield 'Error: $error';
            break;

          case CompletionEvent():
            developer.log('🏁 Final response completed', name: 'LlmService');

            // If follow-up tool calls were collected, yield completion info
            if (followUpToolCalls.isNotEmpty) {
              developer.log(
                '📦 Collected ${followUpToolCalls.length} follow-up tool calls',
                name: 'LlmService',
              );

              yield {
                'type': 'completion',
                'toolCalls': followUpToolCalls,
                'text': followUpTextBuffer.toString(),
                'conversation': updatedConversation,
              };
            }

          case ThinkingDeltaEvent():
            developer.log('💭 Thinking event', name: 'LlmService');
        }
      }

      developer.log('✅ Continuation completed', name: 'LlmService');
    } catch (e, stackTrace) {
      developer.log(
        '❌ Exception in continueWithToolResults: $e',
        name: 'LlmService',
        error: e,
        stackTrace: stackTrace,
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
