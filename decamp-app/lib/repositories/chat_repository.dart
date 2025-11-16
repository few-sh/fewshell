import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llm_dart/llm_dart.dart' as llm;
import '../extensions/chat_message_extensions.dart';
import '../services/llm_service.dart';
import '../services/ai_actions_config.dart';
import '../providers/message_provider.dart';
import '../providers/session_provider.dart';
import '../providers/project_provider.dart';

/// Result of sending a message to the AI
class MessageResult {
  final String? textResponse;
  final List<ToolCallRequest>? toolCalls;
  final List<llm.ChatMessage>? conversationState;
  final String? error;

  const MessageResult({
    this.textResponse,
    this.toolCalls,
    this.conversationState,
    this.error,
  });

  bool get hasError => error != null;
  bool get hasToolCalls => toolCalls != null && toolCalls!.isNotEmpty;
  bool get hasTextResponse => textResponse != null && textResponse!.isNotEmpty;
}

/// A tool call request from the AI
class ToolCallRequest {
  final String id;
  final String name;
  final Map<String, dynamic> params;
  final llm.ToolCall toolCall;

  const ToolCallRequest({
    required this.id,
    required this.name,
    required this.params,
    required this.toolCall,
  });

  /// Get the command from params (if applicable)
  String get command => params['command'] as String? ?? 'unknown';

  /// Get the explanation from params (if applicable)
  String get explanation => params['explanation'] as String? ?? '';
}

/// Result of executing tool calls
class ToolExecutionResult {
  final Map<String, String> toolResults;
  final List<String> chatMessages;
  final List<ToolCallRequest>
  toolCalls; // Add this to track which tool calls were made
  final MessageResult? followUpResult;
  final String? error;

  const ToolExecutionResult({
    required this.toolResults,
    required this.chatMessages,
    required this.toolCalls, // Add required parameter
    this.followUpResult,
    this.error,
  });

  bool get hasError => error != null;
  bool get hasFollowUp =>
      followUpResult != null && followUpResult!.hasToolCalls;
}

/// Repository for chat-related business logic
/// Handles message sending, AI responses, and tool execution coordination
class ChatRepository {
  final MessageActions _messageActions;
  final SessionActions _sessionActions;
  final LlmService _llmService;
  final Ref _ref;

  ChatRepository({
    required MessageActions messageActions,
    required SessionActions sessionActions,
    required LlmService llmService,
    required Ref ref,
  }) : _messageActions = messageActions,
       _sessionActions = sessionActions,
       _llmService = llmService,
       _ref = ref;

  /// Check if LLM is configured and ready
  Future<bool> isConfigured() async {
    return await _llmService.isConfigured();
  }

  /// Get the current model identifier
  Future<String?> getCurrentModelIdentifier() async {
    return await _llmService.getCurrentIdentifier();
  }

  /// Generate a unique message ID
  String generateMessageId() {
    return _messageActions.generateMessageId();
  }

  /// Save a user message to the database
  /// Returns the message ID
  Future<String> saveUserMessage({
    required String sessionId,
    required String content,
  }) async {
    return await _messageActions.insertMessage(
      sessionId: sessionId,
      userId: 'user',
      userName: 'You',
      content: content,
    );
  }

  /// Save an AI message to the database
  /// Returns the message ID
  Future<String> saveAiMessage({
    String? id, // Optional pre-generated ID
    required String sessionId,
    required String content,
  }) async {
    return await _messageActions.insertMessage(
      id: id,
      sessionId: sessionId,
      userId: 'ai',
      userName: 'Ops Agent',
      content: content,
    );
  }

  /// Save an assistant message with tool calls to the database
  /// Stores the complete ChatMessage structure in metadata for proper conversation reconstruction
  Future<String> saveAssistantMessageWithToolCalls({
    String? id,
    required String sessionId,
    required List<llm.ToolCall> toolCalls,
    String? textContent,
  }) async {
    // Create the ChatMessage with tool calls
    final chatMessage = llm.ChatMessage.toolUse(
      toolCalls: toolCalls,
      content: textContent ?? '',
    );

    // Use text content for display, full structure in metadata
    final displayContent = textContent ?? '[Tool calls: ${toolCalls.length}]';

    return await _messageActions.insertMessage(
      id: id,
      sessionId: sessionId,
      userId: 'ai',
      userName: 'Ops Agent',
      content: displayContent,
      metadata: jsonEncode(chatMessage.toStorageJson()),
    );
  }

  /// Save a tool result message to the database
  /// Returns the message ID
  Future<String> saveToolMessage({
    required String sessionId,
    required String content,
  }) async {
    return await _messageActions.insertMessage(
      sessionId: sessionId,
      userId: 'tool',
      userName: 'Tool',
      content: content,
    );
  }

  /// Save tool results to the database with complete ChatMessage structure
  /// This preserves the ToolCall information needed for conversation reconstruction
  Future<String> saveToolResultMessage({
    String? id,
    required String sessionId,
    required List<llm.ToolCall> toolCalls,
    required String resultContent,
  }) async {
    // Create the ChatMessage with tool results
    final chatMessage = llm.ChatMessage.toolResult(
      results: toolCalls,
      content: resultContent,
    );

    return await _messageActions.insertMessage(
      id: id,
      sessionId: sessionId,
      userId: 'tool',
      userName: 'Tool',
      content: resultContent,
      metadata: jsonEncode(chatMessage.toStorageJson()),
    );
  }

  /// Build conversation history from database messages
  /// Reconstructs proper ChatMessage objects including tool use and tool results
  List<llm.ChatMessage> buildConversationHistory(List<dynamic> dbMessages) {
    final conversation = <llm.ChatMessage>[];

    for (final msg in dbMessages) {
      final userId = msg.userId as String;
      final content = msg.content as String;
      final metadata = msg.metadata as String?;

      // Try to reconstruct from metadata first if it exists
      if (metadata != null && metadata.isNotEmpty) {
        try {
          final json = jsonDecode(metadata) as Map<String, dynamic>;
          final chatMessage = ChatMessageStorage.fromStorageJson(json);
          conversation.add(chatMessage);

          developer.log(
            '📦 Restored ${json['messageType']} message from metadata',
            name: 'ChatRepository',
          );
          continue;
        } catch (e) {
          developer.log(
            '⚠️ Failed to deserialize ChatMessage from metadata: $e',
            name: 'ChatRepository',
          );
          // Fall through to simple text conversion
        }
      }

      // Fallback: create simple text message based on userId
      if (userId == 'user') {
        conversation.add(llm.ChatMessage.user(content));
      } else if (userId == 'ai' || userId == 'assistant') {
        conversation.add(llm.ChatMessage.assistant(content));
      } else if (userId == 'tool') {
        // Tool messages without metadata - skip them as they can't be properly reconstructed
        developer.log(
          '⚠️ Tool message without metadata, skipping',
          name: 'ChatRepository',
        );
      }
    }

    developer.log(
      '✅ Built conversation with ${conversation.length} messages',
      name: 'ChatRepository',
    );

    return conversation;
  }

  /// Update session description if this is the first message
  Future<void> updateSessionDescriptionIfNeeded({
    required String sessionId,
    required String messageContent,
    required bool isFirstMessage,
  }) async {
    if (!isFirstMessage) return;

    final description = messageContent.length > 495
        ? '${messageContent.substring(0, 495)}...'
        : messageContent;

    await _sessionActions.updateSession(
      id: sessionId,
      description: description,
    );

    developer.log(
      'Updated session description: $description',
      name: 'ChatRepository',
    );
  }

  /// Send a message to the AI and get response
  /// Handles streaming, tool calls, and conversation state
  Future<MessageResult> sendMessageToAI({
    required String messageContent,
    required List<dynamic>
    dbMessages, // Database messages to build conversation from
    required String
    messageId, // Pre-generated message ID to use for streaming and DB
    void Function(String messageId)? onStreamStart,
    void Function(String messageId, String currentText)? onStreamChunk,
    void Function(String streamingMessageId)? onStreamEnd,
  }) async {
    try {
      developer.log('🚀 Sending message to AI', name: 'ChatRepository');

      // Build conversation from database messages
      final conversation = buildConversationHistory(dbMessages);

      developer.log(
        '📚 Built conversation with ${conversation.length} messages',
        name: 'ChatRepository',
      );

      // Get current project and AI actions
      final currentProject = _ref.read(currentProjectProvider);
      final aiActionsConfig = _ref.read(
        aiActionsConfigProvider(currentProject?.id),
      );
      final tools = _llmService.convertActionsToTools(aiActionsConfig.actions);

      developer.log(
        '🔧 Converted ${tools.length} actions to tools',
        name: 'ChatRepository',
      );

      // Collect response
      final buffer = StringBuffer();
      final collectedToolCalls = <ToolCallRequest>[];
      List<llm.ChatMessage>? conversationState;

      var hasStartedStreaming = false;

      await for (final chunk in _llmService.sendMessageWithConversation(
        conversation,
        messageContent,
        tools: tools,
      )) {
        if (chunk is Map) {
          final type = chunk['type'] as String?;

          if (type == 'tool_call') {
            developer.log(
              '🔧 Tool call received: ${chunk['name']}',
              name: 'ChatRepository',
            );

            final toolCall = chunk['toolCall'] as llm.ToolCall?;
            if (toolCall != null) {
              collectedToolCalls.add(
                ToolCallRequest(
                  id: toolCall.id,
                  name: chunk['name'] as String,
                  params: chunk['params'] as Map<String, dynamic>,
                  toolCall: toolCall,
                ),
              );
            }
          } else if (type == 'completion') {
            developer.log(
              '🏁 Completion event received',
              name: 'ChatRepository',
            );

            conversationState = chunk['conversation'] as List<llm.ChatMessage>?;
          }
        } else if (chunk is String) {
          buffer.write(chunk);

          // Notify streaming callbacks with the pre-generated message ID
          if (!hasStartedStreaming && onStreamStart != null) {
            onStreamStart(messageId);
            hasStartedStreaming = true;
          }

          if (onStreamChunk != null) {
            onStreamChunk(messageId, buffer.toString());
          }
        }
      }

      // Stop streaming when complete
      if (hasStartedStreaming && onStreamEnd != null) {
        onStreamEnd(messageId);
      }

      developer.log('✅ AI response complete', name: 'ChatRepository');

      return MessageResult(
        textResponse: buffer.toString(),
        toolCalls: collectedToolCalls.isEmpty ? null : collectedToolCalls,
        conversationState: conversationState,
      );
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error sending message to AI: $e',
        name: 'ChatRepository',
        error: e,
        stackTrace: stackTrace,
      );

      return MessageResult(error: e.toString());
    }
  }

  /// Execute tool calls and handle follow-up responses
  Future<ToolExecutionResult> executeToolCalls({
    required List<ToolCallRequest> toolCalls,
    required List<llm.ChatMessage> conversationState,
    required Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
    executeAction,
  }) async {
    developer.log(
      '🚀 Executing ${toolCalls.length} tool calls',
      name: 'ChatRepository',
    );

    final toolResults = <String, String>{};
    final chatMessages = <String>[];

    try {
      // Execute each tool call
      for (var i = 0; i < toolCalls.length; i++) {
        final toolCall = toolCalls[i];

        developer.log(
          '🔄 Executing tool ${i + 1}/${toolCalls.length}: ${toolCall.name}',
          name: 'ChatRepository',
        );

        // Execute the action
        final result = await executeAction(toolCall.name, toolCall.params);

        // Build result message
        final resultMessage = _formatExecutionResult(
          toolCall.command,
          result['success'] as bool,
          result['data'],
          result['error'],
        );

        chatMessages.add(resultMessage);

        // Map result for LLM
        toolResults[toolCall.id] = result['success'] as bool
            ? result['data']?.toString() ?? 'Success'
            : 'Error: ${result['error']}';
      }

      developer.log(
        '🔄 Continuing conversation with ${toolResults.length} tool results',
        name: 'ChatRepository',
      );

      // Get tools for potential follow-up
      final currentProject = _ref.read(currentProjectProvider);
      final aiActionsConfig = _ref.read(
        aiActionsConfigProvider(currentProject?.id),
      );
      final tools = _llmService.convertActionsToTools(aiActionsConfig.actions);

      // Build updated conversation with tool use message already included
      final updatedConversation = List<llm.ChatMessage>.from(conversationState);

      // Add the assistant's tool use message
      updatedConversation.add(
        llm.ChatMessage.toolUse(
          toolCalls: toolCalls.map((tc) => tc.toolCall).toList(),
          content: '',
        ),
      );

      developer.log(
        '📋 Updated conversation has ${updatedConversation.length} messages (added tool use)',
        name: 'ChatRepository',
      );

      // Continue conversation with tool results
      final followUpResult = await _continueWithToolResults(
        conversationState: updatedConversation,
        toolCalls: toolCalls.map((tc) => tc.toolCall).toList(),
        toolResults: toolResults,
        tools: tools,
      );

      return ToolExecutionResult(
        toolResults: toolResults,
        chatMessages: chatMessages,
        toolCalls: toolCalls, // Add the tool calls
        followUpResult: followUpResult,
      );
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error executing tool calls: $e',
        name: 'ChatRepository',
        error: e,
        stackTrace: stackTrace,
      );

      return ToolExecutionResult(
        toolResults: toolResults,
        chatMessages: chatMessages,
        toolCalls: toolCalls, // Add the tool calls even on error
        error: e.toString(),
      );
    }
  }

  /// Continue conversation with tool results
  Future<MessageResult?> _continueWithToolResults({
    required List<llm.ChatMessage> conversationState,
    required List<llm.ToolCall> toolCalls,
    required Map<String, String> toolResults,
    required List<llm.Tool> tools,
  }) async {
    try {
      final buffer = StringBuffer();
      final followUpToolCalls = <ToolCallRequest>[];
      List<llm.ChatMessage>? newConversationState;

      await for (final chunk in _llmService.continueWithToolResults(
        conversationState,
        toolCalls,
        toolResults,
        tools: tools,
      )) {
        if (chunk is Map) {
          final type = chunk['type'] as String?;

          if (type == 'tool_call') {
            developer.log(
              '🔧 Follow-up tool call received: ${chunk['name']}',
              name: 'ChatRepository',
            );

            final toolCall = chunk['toolCall'] as llm.ToolCall?;
            if (toolCall != null) {
              followUpToolCalls.add(
                ToolCallRequest(
                  id: toolCall.id,
                  name: chunk['name'] as String,
                  params: chunk['params'] as Map<String, dynamic>,
                  toolCall: toolCall,
                ),
              );
            }
          } else if (type == 'completion') {
            developer.log(
              '🏁 Follow-up completion event',
              name: 'ChatRepository',
            );

            newConversationState =
                chunk['conversation'] as List<llm.ChatMessage>?;
          }
        } else if (chunk is String) {
          buffer.write(chunk);
        }
      }

      // Return result if we have follow-up tool calls or text
      if (followUpToolCalls.isNotEmpty || buffer.isNotEmpty) {
        return MessageResult(
          textResponse: buffer.toString(),
          toolCalls: followUpToolCalls.isEmpty ? null : followUpToolCalls,
          conversationState: newConversationState,
        );
      }

      return null;
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error continuing with tool results: $e',
        name: 'ChatRepository',
        error: e,
        stackTrace: stackTrace,
      );

      return MessageResult(error: e.toString());
    }
  }

  /// Format execution result as a chat message
  String _formatExecutionResult(
    String command,
    bool success,
    dynamic data,
    dynamic error,
  ) {
    final buffer = StringBuffer();

    if (success) {
      buffer.writeln('✅ **Executed:**');
      buffer.writeln('```');
      buffer.writeln(command);
      buffer.writeln('```');
      buffer.writeln();

      // Print stdout if available
      final stdout = data?['stdout']?.toString().trim() ?? '';
      if (stdout.isNotEmpty) {
        buffer.writeln('**Result:**');
        buffer.writeln('```');
        buffer.writeln(stdout);
        buffer.writeln('```');
        buffer.writeln();
      }

      // Print stderr if available
      final stderr = data?['stderr']?.toString().trim() ?? '';
      if (stderr.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('**⚠️ Warning (stderr):**');
        buffer.writeln('```');
        buffer.writeln(stderr);
        buffer.writeln('```');
      }

      // Print exit code only if non-zero
      final exitCode = data?['exitCode'] as int?;
      if (exitCode != null && exitCode != 0) {
        buffer.writeln();
        buffer.writeln('**Exit Code:** $exitCode');
      }
    } else {
      buffer.writeln('❌ **Failed:** `$command`');
      buffer.writeln();
      buffer.writeln('**Error:**');
      buffer.writeln('```');
      buffer.writeln(error?.toString() ?? 'Unknown error');
      buffer.writeln('```');
    }

    return buffer.toString().trim();
  }
}

/// Provider for ChatRepository
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    messageActions: ref.watch(messageActionsProvider),
    sessionActions: ref.watch(sessionActionsProvider),
    llmService: ref.watch(llmServiceProvider),
    ref: ref,
  );
});
