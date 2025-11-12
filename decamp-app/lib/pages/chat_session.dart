import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:hello_world/components/main_drawer.dart';
import 'package:hello_world/components/action_approval_overlay.dart';
import 'package:hello_world/providers/project_provider.dart';
import 'package:hello_world/providers/session_provider.dart';
import 'package:hello_world/providers/message_provider.dart';
import 'package:hello_world/providers/llm_settings_provider.dart';
import 'package:hello_world/providers/settings_provider.dart';
import 'package:hello_world/pages/projects_page.dart';
import 'package:hello_world/pages/sessions_history.dart';
import 'package:hello_world/services/llm_service.dart';
import 'package:hello_world/services/ai_actions_config.dart';
import 'package:llm_dart/llm_dart.dart' as llm show ChatMessage, ToolCall;
import 'dart:developer' as developer;

class ChatSession extends ConsumerStatefulWidget {
  const ChatSession({super.key});

  @override
  ConsumerState<ChatSession> createState() => _ChatSessionState();
}

class _ChatSessionState extends ConsumerState<ChatSession> {
  // Controller for managing chat messages
  final _controller = ChatMessagesController();

  // Counter for generating unique message IDs
  int _messageIdCounter = 0;

  /// Generate a unique message ID
  String _generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}_${_messageIdCounter++}';
  }

  /// Save a message to the database
  Future<String> _saveMessageToDatabase({
    required String content,
    required String userId,
    required String userName,
  }) async {
    final currentSessionId = ref.read(currentSessionIdProvider);
    if (currentSessionId == null) {
      developer.log(
        'No session selected, cannot save message',
        name: 'ChatSession',
      );
      return _generateMessageId(); // Return temp ID for in-memory message
    }

    final messageActions = ref.read(messageActionsProvider);
    final messageId = await messageActions.sendMessage(
      sessionId: currentSessionId,
      userId: userId,
      userName: userName,
      content: content,
    );

    developer.log('Saved message to database: $messageId', name: 'ChatSession');
    return messageId;
  }

  // Define users
  final _currentUser = ChatUser(id: 'user', firstName: 'You');
  final _aiUser = ChatUser(id: 'ai', firstName: 'Ops Agent');

  // Loading state
  bool _isLoading = false;

  // Current model identifier
  String? _currentModelIdentifier;

  // Context for AiActionProvider (captured from Builder)
  BuildContext? _actionContext;

  // Pending action approval
  Map<String, dynamic>? _pendingAction;

  // Track conversation state for tool calls (following official pattern)
  List<llm.ChatMessage>? _conversationForToolCalls;
  List<llm.ToolCall>? _pendingToolCalls;
  // ignore: unused_field
  String? _assistantTextBeforeTools; // For potential future use

  // Track last synced session to avoid duplicate syncs
  String? _lastSyncedSessionId;

  // Track synced message IDs to avoid recreating existing messages
  final Set<String> _syncedMessageIds = {};

  @override
  void initState() {
    super.initState();

    // Load current model identifier
    _loadCurrentModel();

    // Initial message sync will happen in first build via listeners
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Sync messages from provider to controller
  /// Only called when messages actually change, not on every build
  Future<void> _syncMessagesFromProvider() async {
    final currentSessionId = ref.read(currentSessionIdProvider);
    if (currentSessionId == null) {
      _controller.clearMessages();
      _syncedMessageIds.clear();
      return;
    }

    try {
      final messages = await ref.read(currentSessionMessagesProvider.future);

      // Check if this is a new session - if so, use setMessages for bulk load
      if (_lastSyncedSessionId != currentSessionId) {
        _lastSyncedSessionId = currentSessionId;

        // Convert all messages to ChatMessage format
        final chatMessages = messages.map((msg) {
          return ChatMessage(
            text: msg.content,
            user: msg.userId == 'user' ? _currentUser : _aiUser,
            createdAt: msg.createdAt,
            customProperties: {'id': msg.id},
          );
        }).toList();

        // Use setMessages for bulk persistence loading (no animation per message)
        _controller.setMessages(chatMessages);

        // Update synced IDs
        _syncedMessageIds.clear();
        _syncedMessageIds.addAll(messages.map((m) => m.id));
      } else {
        // For incremental updates within same session, only add new messages
        final newMessages = <ChatMessage>[];
        for (final msg in messages) {
          if (!_syncedMessageIds.contains(msg.id)) {
            _syncedMessageIds.add(msg.id);
            newMessages.add(
              ChatMessage(
                text: msg.content,
                user: msg.userId == 'user' ? _currentUser : _aiUser,
                createdAt: msg.createdAt,
                customProperties: {'id': msg.id},
              ),
            );
          }
        }

        // Use addMessage for real-time new messages (with animation)
        for (final message in newMessages) {
          _controller.addMessage(message);
        }
      }
    } catch (e) {
      developer.log('Error syncing messages: $e', name: 'ChatSession');
    }
  }

  /// Load the current model identifier
  Future<void> _loadCurrentModel() async {
    final llmService = ref.read(llmServiceProvider);
    final identifier = await llmService.getCurrentIdentifier();
    if (mounted) {
      setState(() {
        _currentModelIdentifier = identifier;
      });
    }
  }

  Future<void> _createNewSession() async {
    final currentProject = ref.read(currentProjectProvider);
    if (currentProject == null) return;

    final sessionActions = ref.read(sessionActionsProvider);
    await sessionActions.createNewSessionAndSwitch(
      projectId: currentProject.id,
    );
  }

  void _showSessionHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SessionsHistoryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Activate the session manager (handles all business logic)
    ref.watch(sessionManagerProvider);

    // Watch current state
    final currentProject = ref.watch(currentProjectProvider);
    final currentSessionId = ref.watch(currentSessionIdProvider);

    // NOTE: ref.listen() in build() is the correct Riverpod pattern
    // It's automatically deduplicated and cleaned up by the framework
    // See: https://riverpod.dev/docs/concepts/reading#using-reflisten-to-react-to-a-provider-change

    // Listen to session changes and sync messages ONLY when session changes
    ref.listen(currentSessionIdProvider, (previous, next) {
      if (previous != next) {
        // Sync runs as side effect, not during build
        Future.microtask(() => _syncMessagesFromProvider());
      }
    });

    // Listen to messages changes and sync ONLY when messages actually change
    ref.listen(currentSessionMessagesProvider, (previous, next) {
      // Compare actual message lists to avoid unnecessary syncs
      final prevData = previous?.asData?.value ?? [];
      final nextData = next.asData?.value ?? [];

      // Only sync if message count changed or we have the current session
      if (prevData.length != nextData.length &&
          _lastSyncedSessionId == currentSessionId) {
        // Sync runs as side effect, not during build
        Future.microtask(() => _syncMessagesFromProvider());
      }
    });

    // Listen to global settings changes to update model identifier when default changes
    ref.listen(globalSettingsProvider.select((s) => s.defaultLlmIdentifier), (
      previous,
      next,
    ) {
      if (previous != next) {
        Future.microtask(() => _loadCurrentModel());
      }
    });

    // Listen to project settings changes to update model identifier when default changes
    if (currentProject?.id != null) {
      ref.listen(
        projectSettingsProvider(
          currentProject!.id,
        ).select((s) => s?.defaultLlmIdentifier),
        (previous, next) {
          if (previous != next) {
            Future.microtask(() => _loadCurrentModel());
          }
        },
      );
    }

    // Also listen to LLM settings in case models are added/removed/enabled/disabled
    ref.listen(globalLlmSettingsProvider, (previous, next) {
      Future.microtask(() => _loadCurrentModel());
    });

    if (currentProject?.id != null) {
      ref.listen(projectLlmSettingsProvider(currentProject!.id), (
        previous,
        next,
      ) {
        Future.microtask(() => _loadCurrentModel());
      });
    }

    final currentProjectName = currentProject?.name ?? 'No Project';
    final hasProject = currentProject != null;

    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            onTap: hasProject
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProjectsPage(),
                      ),
                    );
                  },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(currentProjectName),
                if (!hasProject) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.add_circle_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ],
              ],
            ),
          ),
          centerTitle: false,
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New Session',
              onPressed: hasProject ? _createNewSession : null,
            ),
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Session History',
              onPressed: _showSessionHistory,
            ),
          ],
        ),
        drawer: const MainDrawer(),
        body: Stack(
          children: [
            // Main chat widget
            AiActionProvider(
              key: ValueKey('actions_${currentProject?.id}'),
              config: ref.watch(aiActionsConfigProvider(currentProject?.id)),
              // Use a Builder to get the correct context inside AiActionProvider
              child: Builder(
                builder: (actionContext) {
                  // Capture the action context for use in callbacks
                  _actionContext = actionContext;

                  return AiChatWidget(
                    // Required parameters
                    currentUser: _currentUser,
                    aiUser: _aiUser,
                    controller: _controller,
                    onSendMessage: _handleSendMessage,

                    // Loading configuration
                    loadingConfig: LoadingConfig(
                      isLoading: _isLoading,
                      showCenteredIndicator: true,
                    ),

                    // Input field customization
                    inputOptions: InputOptions(
                      textStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: _currentModelIdentifier != null
                            ? 'Send to $_currentModelIdentifier...'
                            : 'Type your message...',
                        hintStyle: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24.0),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 10.0,
                        ),
                      ),
                      useOuterContainer: false,
                      autofocus: true,
                      sendOnEnter: true,
                      textInputAction: TextInputAction.send,
                      maxLines: 1,
                    ),

                    // Enable animations and streaming
                    enableAnimation:
                        false, // Disabled to prevent re-animation on scroll
                    enableMarkdownStreaming: true,
                    streamingWordByWord: true,
                    streamingDuration: const Duration(milliseconds: 30),

                    // Message options
                    messageOptions: MessageOptions(
                      showTime: true,
                      showUserName: true,
                      containerMargin: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 4,
                      ),
                      bubbleStyle: BubbleStyle(
                        userBubbleColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        aiBubbleColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        userNameColor: Theme.of(context).colorScheme.primary,
                        aiNameColor: Theme.of(context).colorScheme.secondary,
                        bottomLeftRadius: 22,
                        bottomRightRadius: 22,
                        enableShadow: true,
                      ),
                    ),

                    // Scroll behavior
                    scrollBehaviorConfig: ScrollBehaviorConfig(
                      autoScrollBehavior: AutoScrollBehavior.onUserMessageOnly,
                      scrollToFirstResponseMessage: true,
                    ),

                    // Layout options
                    maxWidth: 800,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  );
                },
              ),
            ),

            // Action approval overlay (shown when a tool call is pending)
            if (_pendingAction != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ActionApprovalOverlay(
                  actionName: _pendingAction!['name'] as String,
                  params: _pendingAction!['params'] as Map<String, dynamic>,
                  onExecute: _executeAction,
                  onDismiss: () {
                    setState(() {
                      _pendingAction = null;
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Execute an action with the given parameters
  /// Now follows the official llm_dart pattern for tool execution
  Future<void> _executeAction(
    String actionName,
    Map<String, dynamic> params,
  ) async {
    developer.log(
      '🚀 Executing action: $actionName with params: $params',
      name: 'ChatSession',
    );

    if (_actionContext == null) {
      developer.log('❌ Action context not available', name: 'ChatSession');
      return;
    }

    try {
      // Get the action hook to execute the action
      final actionHook = AiActionHook.of(_actionContext!);

      // Execute the action (this will call the handler)
      final result = await actionHook.executeAction(actionName, params);

      developer.log(
        '✅ Action completed: success=${result.success}',
        name: 'ChatSession',
      );

      // Add result message to chat UI with the actual command details
      final command = params['command'] ?? 'unknown command';

      String resultMessage;
      if (result.success) {
        final buffer = StringBuffer();
        buffer.writeln('✅ Executed: `$command`');
        buffer.writeln();

        // Print stdout if available
        final stdout = result.data?['stdout']?.toString().trim() ?? '';
        if (stdout.isNotEmpty) {
          buffer.writeln('Result:');
          buffer.writeln('```');
          buffer.writeln(stdout);
          buffer.writeln('```');
        }

        // Print stderr in red if available
        final stderr = result.data?['stderr']?.toString().trim() ?? '';
        if (stderr.isNotEmpty) {
          buffer.writeln();
          buffer.writeln('**⚠️ stderr:**');
          buffer.writeln('```');
          buffer.writeln(stderr);
          buffer.writeln('```');
        }

        // Print exit code only if non-zero
        final exitCode = result.data?['exitCode'] as int?;
        if (exitCode != null && exitCode != 0) {
          buffer.writeln();
          buffer.writeln('**Exit Code:** $exitCode');
        }

        resultMessage = buffer.toString().trim();
      } else {
        resultMessage =
            '❌ Failed to execute: `$command`\n\nError: ${result.error}';
      }

      // Save result message to database
      final resultMessageId = await _saveMessageToDatabase(
        content: resultMessage,
        userId: 'ai',
        userName: 'Ops Agent',
      );

      _controller.addMessage(
        ChatMessage(
          text: resultMessage,
          user: _aiUser,
          createdAt: DateTime.now(),
          customProperties: {'id': resultMessageId},
          isMarkdown: true,
        ),
      );

      // Clear pending action UI
      setState(() {
        _pendingAction = null;
        _isLoading = true; // Show loading while getting LLM response
      });

      developer.log(
        '🔄 Continuing conversation after tool execution',
        name: 'ChatSession',
      );

      // Get AI actions and convert to tools for potential follow-up calls
      final currentProject = ref.read(currentProjectProvider);
      final aiActionsConfig = ref.read(
        aiActionsConfigProvider(currentProject?.id),
      );
      final llmService = ref.read(llmServiceProvider);
      final tools = llmService.convertActionsToTools(aiActionsConfig.actions);

      // Check if we have the new conversation state (for providers with completion events)
      final llmResponseBuffer = StringBuffer();

      if (_conversationForToolCalls != null && _pendingToolCalls != null) {
        developer.log(
          '✅ Using new continueWithToolResults pattern',
          name: 'ChatSession',
        );

        // Build tool results map (tool call ID -> result content)
        final toolResults = <String, String>{};
        for (final toolCall in _pendingToolCalls!) {
          if (toolCall.function.name == actionName) {
            toolResults[toolCall.id] = result.success
                ? result.data?.toString() ?? 'Success'
                : 'Error: ${result.error}';
          }
        }

        // Use the new continueWithToolResults method (official pattern)
        await for (final chunk in llmService.continueWithToolResults(
          _conversationForToolCalls!,
          _pendingToolCalls!,
          toolResults,
          tools: tools,
        )) {
          llmResponseBuffer.write(chunk);
        }

        // Clear conversation state
        setState(() {
          _conversationForToolCalls = null;
          _pendingToolCalls = null;
          _assistantTextBeforeTools = null;
        });
      } else {
        developer.log(
          '⚠️ Falling back to legacy continueWithToolResult (no completion event)',
          name: 'ChatSession',
        );

        // Fall back to old pattern for providers that don't send completion events
        // Build current conversation history
        final history = _controller.messages
            .where((msg) => msg.text.isNotEmpty)
            .map(
              (msg) => {
                'role': msg.user.id == 'user' ? 'user' : 'assistant',
                'content': msg.text,
              },
            )
            .toList()
            .reversed
            .toList();

        // Use deprecated method as fallback
        // ignore: deprecated_member_use
        await for (final chunk in llmService.continueWithToolResult(
          actionName,
          params,
          resultMessage,
          history: history,
          tools: tools,
        )) {
          llmResponseBuffer.write(chunk);
        }
      }

      // Add LLM's response to chat if not empty
      final llmResponse = llmResponseBuffer.toString().trim();
      if (llmResponse.isNotEmpty) {
        final llmMessageId = await _saveMessageToDatabase(
          content: llmResponse,
          userId: 'ai',
          userName: 'Ops Agent',
        );

        _controller.addMessage(
          ChatMessage(
            text: llmResponse,
            user: _aiUser,
            createdAt: DateTime.now(),
            customProperties: {'id': llmMessageId},
            isMarkdown: true,
          ),
        );
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      developer.log(
        '❌ Action execution error: $e',
        name: 'ChatSession',
        error: e,
        stackTrace: stackTrace,
      );

      final errorMessage = '❌ Error executing command: $e';

      // Save error message to database
      final errorMessageId = await _saveMessageToDatabase(
        content: errorMessage,
        userId: 'ai',
        userName: 'Ops Agent',
      );

      _controller.addMessage(
        ChatMessage(
          text: errorMessage,
          user: _aiUser,
          createdAt: DateTime.now(),
          customProperties: {'id': errorMessageId},
          isMarkdown: true,
        ),
      );

      // Clear state on error
      setState(() {
        _conversationForToolCalls = null;
        _pendingToolCalls = null;
        _assistantTextBeforeTools = null;
        _isLoading = false;
      });
    }
  }

  /// Handle sending messages
  Future<void> _handleSendMessage(ChatMessage message) async {
    developer.log('🎯 _handleSendMessage called', name: 'ChatSession');
    developer.log('User message: ${message.text}', name: 'ChatSession');

    // Save user message to database
    final userMessageId = await _saveMessageToDatabase(
      content: message.text,
      userId: 'user',
      userName: 'You',
    );

    // Check if this is the first message to update session description
    final currentSessionId = ref.read(currentSessionIdProvider);
    if (currentSessionId != null && _controller.messages.isEmpty) {
      final sessionActions = ref.read(sessionActionsProvider);
      // Use first 50 characters of message as description
      final description = message.text.length > 50
          ? '${message.text.substring(0, 50)}...'
          : message.text;
      await sessionActions.updateSession(
        id: currentSessionId,
        description: description,
      );
      developer.log(
        'Updated session description: $description',
        name: 'ChatSession',
      );
    }

    // Add the user's message to the chat UI with the database ID
    final userChatMessage = ChatMessage(
      text: message.text,
      user: _currentUser,
      createdAt: DateTime.now(),
      customProperties: {'id': userMessageId},
    );
    _controller.addMessage(userChatMessage);
    developer.log('✅ User message added to controller', name: 'ChatSession');

    setState(() => _isLoading = true);
    developer.log('⏳ Loading state set to true', name: 'ChatSession');

    try {
      // Get the LLM service
      final llmService = ref.read(llmServiceProvider);
      developer.log('✅ LLM service obtained', name: 'ChatSession');

      // Update current model identifier
      final identifier = await llmService.getCurrentIdentifier();
      developer.log('Model identifier: $identifier', name: 'ChatSession');

      if (mounted) {
        setState(() {
          _currentModelIdentifier = identifier;
        });
      }

      // Check if LLM is configured
      final isConfigured = await llmService.isConfigured();
      developer.log('Is configured: $isConfigured', name: 'ChatSession');

      if (!isConfigured) {
        developer.log('❌ LLM not configured', name: 'ChatSession');

        final configMessage =
            "⚠️ No LLM configured. Please go to Settings → AI Models to configure an LLM provider.";

        // Save config warning to database
        final configMessageId = await _saveMessageToDatabase(
          content: configMessage,
          userId: 'ai',
          userName: 'Ops Agent',
        );

        _controller.addMessage(
          ChatMessage(
            text: configMessage,
            user: _aiUser,
            createdAt: DateTime.now(),
            customProperties: {'id': configMessageId},
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Build conversation history for context (excluding the current user message)
      developer.log(
        '📚 Building history from ${_controller.messages.length} messages',
        name: 'ChatSession',
      );

      final history = _controller.messages
          .where((msg) => msg.text.isNotEmpty) // Skip empty messages
          .map(
            (msg) => {
              'role': msg.user.id == 'user' ? 'user' : 'assistant',
              'content': msg.text,
            },
          )
          .toList()
          .reversed
          .toList(); // Reverse to chronological order for LLM

      developer.log(
        '📚 History built: ${history.length} messages',
        name: 'ChatSession',
      );

      // Get AI actions and convert to tools
      developer.log('🔧 Getting AI actions config...', name: 'ChatSession');
      final currentProject = ref.read(currentProjectProvider);
      final aiActionsConfig = ref.read(
        aiActionsConfigProvider(currentProject?.id),
      );
      final tools = llmService.convertActionsToTools(aiActionsConfig.actions);
      developer.log(
        '🔧 Converted ${tools.length} actions to tools',
        name: 'ChatSession',
      );

      developer.log(
        '🚀 Calling llmService.sendMessageWithTools...',
        name: 'ChatSession',
      );

      // Collect the response and handle tool calls (following official pattern)
      final buffer = StringBuffer();
      var chunkCount = 0;
      final collectedToolCalls = <llm.ToolCall>[];

      await for (final chunk in llmService.sendMessageWithTools(
        message.text,
        history: history,
        tools: tools,
      )) {
        chunkCount++;
        developer.log('📦 Chunk #$chunkCount: $chunk', name: 'ChatSession');

        if (chunk is Map) {
          final type = chunk['type'] as String?;

          if (type == 'tool_call') {
            developer.log(
              '🔧 Tool call received: ${chunk['name']}',
              name: 'ChatSession',
            );

            // Extract the ToolCall object
            final toolCall = chunk['toolCall'] as llm.ToolCall?;
            if (toolCall != null) {
              collectedToolCalls.add(toolCall);
            }

            // Add the tool call to chat history so the LLM remembers it
            final command = chunk['params']?['command'] ?? 'unknown';
            final explanation = chunk['params']?['explanation'] ?? '';
            final toolCallMessage =
                '🔧 Requesting to execute: `$command`\n$explanation';

            // Save tool call message to database
            final toolCallMessageId = await _saveMessageToDatabase(
              content: toolCallMessage,
              userId: 'ai',
              userName: 'Ops Agent',
            );

            _controller.addMessage(
              ChatMessage(
                text: toolCallMessage,
                user: _aiUser,
                createdAt: DateTime.now(),
                customProperties: {'id': toolCallMessageId},
              ),
            );

            // Don't return yet - collect all tool calls first
            // Store for approval overlay
            if (_pendingAction == null) {
              _pendingAction = Map<String, dynamic>.from(chunk);
            }
          } else if (type == 'completion') {
            developer.log(
              '🏁 Completion event received with ${collectedToolCalls.length} tool calls',
              name: 'ChatSession',
            );

            // Extract conversation state
            final conversation =
                chunk['conversation'] as List<llm.ChatMessage>?;

            if (collectedToolCalls.isNotEmpty && conversation != null) {
              // Save state for tool execution continuation
              _conversationForToolCalls = conversation;
              _pendingToolCalls = collectedToolCalls;
              _assistantTextBeforeTools = buffer.toString();

              developer.log(
                '📦 Saved conversation state with ${conversation.length} messages',
                name: 'ChatSession',
              );

              // Show the action approval overlay for the first tool call
              setState(() {
                _isLoading =
                    false; // Stop loading while waiting for user approval
              });

              // Return here and let the overlay handle execution
              return;
            }
          }
        } else if (chunk is String) {
          // Regular text chunk
          buffer.write(chunk);
        }
      }

      developer.log(
        '✅ Stream completed. Total chunks: $chunkCount',
        name: 'ChatSession',
      );
      developer.log(
        '📝 Complete response: "${buffer.toString()}"',
        name: 'ChatSession',
      );

      // Add the complete response
      developer.log('💬 Adding AI response to controller', name: 'ChatSession');

      // Save AI message to database
      final aiMessageId = await _saveMessageToDatabase(
        content: buffer.toString(),
        userId: 'ai',
        userName: 'Ops Agent',
      );

      _controller.addMessage(
        ChatMessage(
          text: buffer.toString(),
          user: _aiUser,
          createdAt: DateTime.now(),
          customProperties: {'id': aiMessageId},
        ),
      );
      developer.log('✅ AI response added to controller', name: 'ChatSession');
    } catch (e) {
      // Handle errors
      developer.log('❌ Error in _handleSendMessage: $e', name: 'ChatSession');

      final errorMessage = "Sorry, I encountered an error: $e";

      // Save error message to database
      final errorMessageId = await _saveMessageToDatabase(
        content: errorMessage,
        userId: 'ai',
        userName: 'Ops Agent',
      );

      _controller.addMessage(
        ChatMessage(
          text: errorMessage,
          user: _aiUser,
          createdAt: DateTime.now(),
          customProperties: {'id': errorMessageId},
        ),
      );
    } finally {
      developer.log(
        '🏁 Finally block - setting loading to false',
        name: 'ChatSession',
      );
      setState(() => _isLoading = false);
    }
  }
}
