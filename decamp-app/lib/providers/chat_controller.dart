import 'dart:convert';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llm_dart/llm_dart.dart';
import 'package:drift/drift.dart';
import '../extensions/chat_message_extensions.dart';
import '../models/chat_state.dart';
import '../models/ssh_settings.dart';
import '../services/llm_service.dart';
import '../services/shell_service.dart';
import '../services/shell_tools_provider.dart'
    show shellTools, kExecuteShellCommand, kFetch;
import '../providers/database_provider.dart';
import '../providers/project_provider.dart';
import '../providers/ssh_settings_provider.dart';
import '../providers/secret_provider.dart';
import '../database/daos/message_dao.dart';
import '../database/daos/session_dao.dart';
import '../database/database.dart';
import '../components/multi_command_approval_overlay.dart';
import '../utils/secret_redactor.dart';
import '../utils/constants.dart';

// Constants for message user IDs
const String _kUserUserId = 'user';
const String _kUserUserName = 'You';
const String _kAiUserId = 'ai';
const String _kAiUserName = 'Ops Agent';

/// Controller for chat session state management
/// Handles all business logic for chat interactions, tool execution, and message syncing
/// Directly calls DAOs and services without unnecessary repository layer
class ChatController extends StateNotifier<ChatState> {
  final MessageDao _messageDao;
  final SessionDao _sessionDao;
  final LlmService _llmService;
  final ShellService _shellService;
  final SecretRedactor _secretRedactor;
  final SshSettings? _sshSettings;
  final String? sessionId;

  ChatController({
    required MessageDao messageDao,
    required SessionDao sessionDao,
    required LlmService llmService,
    required ShellService shellService,
    required SecretRedactor secretRedactor,
    SshSettings? sshSettings,
    this.sessionId,
  }) : _messageDao = messageDao,
       _sessionDao = sessionDao,
       _llmService = llmService,
       _shellService = shellService,
       _secretRedactor = secretRedactor,
       _sshSettings = sshSettings,
       super(const ChatState());

  /// Reset state when session changes (called by provider when session changes)
  void resetForNewSession() {
    state = const ChatState();
  }

  /// Build conversation history from database messages
  /// Reconstructs proper ChatMessage objects including tool use and tool results
  List<ChatMessage> _buildConversationHistory(List<dynamic> dbMessages) {
    final conversation = <ChatMessage>[];

    developer.log(
      '🔄 Building conversation history from ${dbMessages.length} messages',
      name: 'ChatController',
    );

    for (final msg in dbMessages) {
      // Cast to MessageEntity for type-safe access
      final messageEntity = msg as MessageEntity;

      // Use the extension method to convert to ChatMessage
      final chatMessage = messageEntity.toChatMessage();

      developer.log(
        '✅ Reconstructed ${chatMessage.role.name} message with kind: ${messageEntity.messageKind.name}',
        name: 'ChatController',
      );

      // Log tool calls and results for debugging
      if (chatMessage.messageType is ToolUseMessage) {
        final toolUse = chatMessage.messageType as ToolUseMessage;
        developer.log(
          '  🔧 Tool calls: ${toolUse.toolCalls.map((tc) => tc.function.name).join(", ")}',
          name: 'ChatController',
        );
      } else if (chatMessage.messageType is ToolResultMessage) {
        final toolResult = chatMessage.messageType as ToolResultMessage;
        developer.log(
          '  📊 Tool results: ${toolResult.results.length} result(s)',
          name: 'ChatController',
        );
      }

      conversation.add(chatMessage);
    }

    developer.log(
      '✅ Built conversation with ${conversation.length} messages',
      name: 'ChatController',
    );

    return conversation;
  }

  /// Validate and prepare for sending a message
  Future<bool> _validateAndPrepare({
    required String sessionId,
    required String content,
  }) async {
    // Redact and save user's message
    final redactedContent = await _secretRedactor.redact(content);
    await _messageDao.insertMessageWithId(
      sessionId: sessionId,
      userId: _kUserUserId,
      userName: _kUserUserName,
      content: redactedContent,
    );

    // Update session description if it's empty or default (first message)
    final session = await _sessionDao.getSession(sessionId);
    final currentDescription = session?.description ?? '';
    if (currentDescription.isEmpty ||
        currentDescription == kDefaultSessionDescription) {
      final description = content.length > 495
          ? '${content.substring(0, 495)}...'
          : content;
      await _sessionDao.updateSession(
        SessionEntityCompanion(
          id: Value(sessionId),
          description: Value(description),
        ),
      );
    }

    // Check if LLM is configured
    final isConfigured = await _llmService.isConfigured();
    if (!isConfigured) {
      const configMessage =
          "⚠️ No LLM configured. Please go to Settings → AI Models to configure an LLM provider.";
      await _messageDao.insertMessageWithId(
        sessionId: sessionId,
        userId: _kAiUserId,
        userName: _kAiUserName,
        content: configMessage,
      );
      return false;
    }

    return true;
  }

  /// Convert tool calls to command actions for approval
  List<CommandAction> _toolCallsToActions(List<ToolCall> toolCalls) {
    return toolCalls.map((tc) {
      final argumentsJson = tc.function.arguments;
      final params = argumentsJson.isNotEmpty
          ? Map<String, dynamic>.from(jsonDecode(argumentsJson))
          : <String, dynamic>{};
      return CommandAction(
        id: tc.id,
        actionName: tc.function.name,
        params: params,
      );
    }).toList();
  }

  /// Send a message to the AI
  /// Handles saving to database, getting AI response, and managing tool calls
  ///
  /// If content is null, resends the last user message in the conversation.
  /// This is used for resend/edit operations.
  ///
  /// Streaming is managed internally through ChatState:
  /// - startStreaming: Sets streamingMessageId in state
  /// - updateStreamingText: Updates streamingText in state
  /// - stopStreaming: Clears streaming state
  Future<void> sendMessage({
    String? content,
    required String sessionId,
    required Future<List<CommandAction>?> Function(List<CommandAction>)
    requestApproval,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // If content is provided, validate and save the new user message
      if (content != null) {
        final isValid = await _validateAndPrepare(
          sessionId: sessionId,
          content: content,
        );
        if (!isValid) {
          state = state.copyWith(isLoading: false);
          return;
        }
      }

      var aiMessageId = _messageDao.generateMessageId();

      while (true) {
        // Rebuild conversation from database (single source of truth)
        final dbMessages = await _messageDao.getMessagesBySession(sessionId);
        final currentConversation = _buildConversationHistory(dbMessages);

        // Send message to AI
        final result = await _sendMessageToAI(
          conversation: currentConversation,
          messageId: aiMessageId,
        );

        // Check for error
        if (result.hasError) {
          final errorMessage = 'Sorry, I encountered an error: ${result.error}';
          final redactedError = await _secretRedactor.redact(errorMessage);
          await _messageDao.insertMessageWithId(
            sessionId: sessionId,
            userId: _kAiUserId,
            userName: _kAiUserName,
            content: redactedError,
          );
          state = state.copyWith(isLoading: false, error: result.error);
          return;
        }

        // If no tool calls, save text response and exit loop
        if (!result.hasToolCalls) {
          if (result.hasTextResponse) {
            final redactedResponse = await _secretRedactor.redact(
              result.textResponse!,
            );
            await _messageDao.insertMessageWithId(
              id: aiMessageId,
              sessionId: sessionId,
              userId: _kAiUserId,
              userName: _kAiUserName,
              content: redactedResponse,
            );
          }
          break;
        }

        // Has tool calls - request approval
        final actions = _toolCallsToActions(result.toolCalls!);
        final selectedActions = await requestApproval(actions);

        // User cancelled
        if (selectedActions == null) {
          developer.log(
            '🚨 User cancelled tool execution',
            name: 'ChatController',
          );
          break;
        }

        developer.log(
          '✅ User approved ${selectedActions.length} tool calls',
          name: 'ChatController',
        );

        // Get selected tool calls
        final selectedToolCalls = selectedActions
            .map(
              (action) =>
                  result.toolCalls!.firstWhere((tc) => tc.id == action.id),
            )
            .toList();

        // Execute tools and get results
        final toolExecutionResult = await _executeToolCalls(
          toolCalls: selectedToolCalls,
          sessionId: sessionId,
        );

        // Save assistant's tool use message
        final assistantMessage = ChatMessage.toolUse(
          toolCalls: selectedToolCalls,
          content: result.textResponse ?? '',
        );
        await _messageDao.insertMessage(
          assistantMessage.toMessageCompanion(
            sessionId: sessionId,
            id: aiMessageId,
          ),
        );

        // Save tool results message
        await _messageDao.insertMessage(
          toolExecutionResult.toolResultMessage.toMessageCompanion(
            sessionId: sessionId,
          ),
        );

        aiMessageId = _messageDao.generateMessageId();

        // Loop continues - next iteration will rebuild conversation from DB
      }

      state = state.copyWith(isLoading: false);
    } catch (e) {
      final errorMessage = 'Sorry, I encountered an error: $e';
      final redactedError = await _secretRedactor.redact(errorMessage);
      await _messageDao.insertMessageWithId(
        sessionId: sessionId,
        userId: _kAiUserId,
        userName: _kAiUserName,
        content: redactedError,
      );
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Send a message to the AI and get response
  /// Handles streaming, tool calls, and conversation state
  Future<_MessageResult> _sendMessageToAI({
    required List<ChatMessage> conversation,
    required String messageId,
  }) async {
    try {
      developer.log(
        '📤 Sending to LLM with ${conversation.length} messages in conversation',
        name: 'ChatController',
      );

      // Log conversation summary for debugging
      for (var i = 0; i < conversation.length; i++) {
        final msg = conversation[i];
        final messageType = msg.messageType;
        if (messageType is ToolUseMessage) {
          developer.log(
            '  [$i] ${msg.role.name}: Tool calls (${messageType.toolCalls.length})',
            name: 'ChatController',
          );
        } else if (messageType is ToolResultMessage) {
          developer.log(
            '  [$i] ${msg.role.name}: Tool results (${messageType.results.length})',
            name: 'ChatController',
          );
        } else {
          final preview = msg.content.length > 50
              ? '${msg.content.substring(0, 50)}...'
              : msg.content;
          developer.log(
            '  [$i] ${msg.role.name}: $preview',
            name: 'ChatController',
          );
        }
      }

      // Get shell tools
      final tools = shellTools;

      // Stream from service
      final buffer = StringBuffer();
      final collectedToolCalls = <ToolCall>[];
      var hasStartedStreaming = false;

      await for (final event in _llmService.streamChat(
        conversation,
        tools: tools,
      )) {
        switch (event) {
          case TextDeltaEvent(delta: final delta):
            buffer.write(delta);
            if (!hasStartedStreaming) {
              startStreaming(messageId);
              hasStartedStreaming = true;
            }
            updateStreamingText(buffer.toString());

          case ToolCallDeltaEvent(toolCall: final toolCall):
            collectedToolCalls.add(toolCall);

          case CompletionEvent():
            break;

          case ErrorEvent(error: final error):
            if (hasStartedStreaming) stopStreaming();
            return _MessageResult(error: error.message);

          case ThinkingDeltaEvent():
            break;
        }
      }

      if (hasStartedStreaming) stopStreaming();

      // Build result
      if (collectedToolCalls.isNotEmpty) {
        return _MessageResult(
          textResponse: buffer.toString(),
          toolCalls: collectedToolCalls,
        );
      }

      return _MessageResult(textResponse: buffer.toString());
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error sending message to AI: $e',
        name: 'ChatController',
        error: e,
        stackTrace: stackTrace,
      );

      return _MessageResult(error: e.toString());
    }
  }

  /// Execute tool calls and return results
  Future<_ToolExecutionResult> _executeToolCalls({
    required List<ToolCall> toolCalls,
    required String sessionId,
  }) async {
    final toolResults = <String, String>{};

    // Execute each tool call
    for (final toolCall in toolCalls) {
      final argumentsJson = toolCall.function.arguments;
      final params = argumentsJson.isNotEmpty
          ? Map<String, dynamic>.from(jsonDecode(argumentsJson))
          : <String, dynamic>{};

      // Execute the action
      final result = await _executeAction(toolCall.function.name, params);

      // Map result for LLM
      toolResults[toolCall.id] = jsonEncode(result['data']);
    }

    // Build consolidated tool result message
    final allResults = toolCalls.map((toolCall) {
      final result = toolResults[toolCall.id] ?? 'No result';
      return ToolCall(
        id: toolCall.id,
        callType: toolCall.callType,
        function: FunctionCall(name: toolCall.function.name, arguments: result),
      );
    }).toList();

    final combinedContent = toolCalls
        .map((toolCall) => toolResults[toolCall.id] ?? 'No result')
        .join('\n---\n');

    final toolResultMessage = ChatMessage.toolResult(
      results: allResults,
      content: combinedContent,
    );

    return _ToolExecutionResult(toolResultMessage: toolResultMessage);
  }

  /// Execute a single action (shell command)
  Future<Map<String, dynamic>> _executeAction(
    String actionName,
    Map<String, dynamic> params,
  ) async {
    if (actionName == kExecuteShellCommand) {
      final command = params['command'] as String;
      final sudoRequired = params['sudo_required'] as bool? ?? false;

      final Map<String, dynamic> result;

      if (sudoRequired) {
        result = await _shellService.executeWithSudo(
          command: command,
          sudoPasswordSecretId:
              _sshSettings?.sudoPasswordSecretId ??
              _sshSettings?.passwordSecretId,
        );
      } else {
        result = await _shellService.executeCommand(command);
      }

      return {
        'success': (result['exitCode'] as int? ?? -1) == 0,
        'data': result,
        'error': result['stderr'] as String?,
      };
    }

    if (actionName == kFetch) {
      final url = params['url'] as String;
      final method = (params['method'] as String?)?.toUpperCase() ?? 'GET';
      final headers = params['headers'] as Map<String, dynamic>?;
      final body = params['body'] as String?;
      final timeoutSeconds = params['timeout'] as int? ?? 30;

      try {
        final dio = Dio();
        final response = await dio
            .request(
              url,
              data: body,
              options: Options(
                method: method,
                headers: headers,
                responseType: ResponseType.plain,
                validateStatus: (status) => true, // Accept all status codes
              ),
            )
            .timeout(Duration(seconds: timeoutSeconds));

        final isSuccess =
            response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! < 300;

        return {
          'success': isSuccess,
          'data': {
            'statusCode': response.statusCode ?? 0,
            'headers': response.headers.map,
            'body': response.data?.toString() ?? '',
            'url': url,
            'method': method,
          },
          'error': isSuccess ? null : 'HTTP ${response.statusCode}',
        };
      } catch (e) {
        return {
          'success': false,
          'data': {
            'statusCode': 0,
            'headers': {},
            'body': '',
            'url': url,
            'method': method,
          },
          'error': e.toString(),
        };
      }
    }

    throw Exception('Unknown action: $actionName');
  }

  /// Edit a message and resend from that point
  /// Updates the message content, deletes all messages after it, then resends
  Future<void> editMessage({
    required String messageId,
    required String newContent,
    required String sessionId,
    required Future<List<CommandAction>?> Function(List<CommandAction>)
    requestApproval,
  }) async {
    developer.log('✏️ Editing message: $messageId', name: 'ChatController');

    // Get the message to find its timestamp
    final message = await _messageDao.getMessage(messageId);
    if (message == null) {
      developer.log('❌ Message not found: $messageId', name: 'ChatController');
      return;
    }

    // Update the message content
    await _messageDao.updateMessageContent(
      messageId: messageId,
      newContent: newContent,
    );

    developer.log('💾 Updated message content', name: 'ChatController');

    // Delete all messages AFTER this one (keep the edited message)
    final deletedCount = await _messageDao.deleteMessagesAfter(
      sessionId: sessionId,
      afterTimestamp: message.timestamp,
    );

    developer.log(
      '🗑️ Deleted $deletedCount messages after edit, now resending',
      name: 'ChatController',
    );

    // Resend from the edited message
    await sendMessage(
      content: null, // Use existing conversation (now with edited message)
      sessionId: sessionId,
      requestApproval: requestApproval,
    );
  }

  /// Resend a message: delete all messages after it, then resend from that point
  Future<void> resendMessage({
    required String messageId,
    required String sessionId,
    required Future<List<CommandAction>?> Function(List<CommandAction>)
    requestApproval,
  }) async {
    developer.log(
      '🔄 Resending from message: $messageId',
      name: 'ChatController',
    );

    // Get the message to find its timestamp
    final message = await _messageDao.getMessage(messageId);
    if (message == null) {
      developer.log('❌ Message not found: $messageId', name: 'ChatController');
      return;
    }

    // Delete all messages AFTER this one (keep the message itself)
    final deletedCount = await _messageDao.deleteMessagesAfter(
      sessionId: sessionId,
      afterTimestamp: message.timestamp,
    );

    developer.log(
      '🗑️ Deleted $deletedCount messages after target, now resending',
      name: 'ChatController',
    );

    // Resend - conversation will include the message we're resending from
    await sendMessage(
      content: null, // Use existing conversation
      sessionId: sessionId,
      requestApproval: requestApproval,
    );
  }

  /// Branch the session by creating a copy up to a specific message
  /// Returns the new session ID
  Future<String> branchSession({
    required String messageId,
    required String sessionId,
  }) async {
    developer.log(
      '🌿 Branching session at message: $messageId',
      name: 'ChatController',
    );

    final newSessionId = await _sessionDao.branchSession(
      sessionId: sessionId,
      upToMessageId: messageId,
    );

    developer.log(
      '✅ Created new session: $newSessionId',
      name: 'ChatController',
    );

    return newSessionId;
  }

  /// Start streaming for a message
  void startStreaming(String messageId) {
    state = state.copyWith(streamingMessageId: messageId, streamingText: '');
  }

  /// Update streaming text for a message
  void updateStreamingText(String text) {
    state = state.copyWith(streamingText: text);
  }

  /// Stop streaming
  void stopStreaming() {
    state = state.copyWith(streamingMessageId: null, streamingText: '');
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for ChatController
/// Uses family provider to scope controller to specific session
final chatControllerProvider =
    StateNotifierProvider.family<ChatController, ChatState, String?>((
      ref,
      sessionId,
    ) {
      // Get current project to access shell service and SSH settings
      final currentProject = ref.watch(currentProjectProvider);
      final projectId = currentProject?.id;

      final sshSettings = projectId != null
          ? ref.watch(projectSshSettingsProvider(projectId))
          : null;

      // Create secret redactor for this project
      final keychain = ref.watch(keychainServiceProvider);
      final secretRedactor = SecretRedactor(keychain, projectId);

      return ChatController(
        messageDao: ref.watch(databaseProvider).messageDao,
        sessionDao: ref.watch(databaseProvider).sessionDao,
        llmService: ref.watch(llmServiceProvider),
        shellService: ref.watch(shellServiceProvider(projectId)),
        secretRedactor: secretRedactor,
        sshSettings: sshSettings,
        sessionId: sessionId,
      );
    });

// Internal helper classes

/// Result of sending a message to the AI
class _MessageResult {
  final String? textResponse;
  final List<ToolCall>? toolCalls;
  final String? error;

  const _MessageResult({this.textResponse, this.toolCalls, this.error});

  bool get hasError => error != null;
  bool get hasToolCalls => toolCalls != null && toolCalls!.isNotEmpty;
  bool get hasTextResponse => textResponse != null && textResponse!.isNotEmpty;
}

/// Result of tool execution
class _ToolExecutionResult {
  final ChatMessage toolResultMessage;

  _ToolExecutionResult({required this.toolResultMessage});
}
