import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:hello_world/components/session_list.dart';
import 'package:hello_world/components/main_drawer.dart';
import 'package:hello_world/components/action_approval_overlay.dart';
import 'package:hello_world/providers/project_provider.dart';
import 'package:hello_world/providers/session_provider.dart';
import 'package:hello_world/providers/message_provider.dart';
import 'package:hello_world/pages/projects_page.dart';
import 'package:hello_world/services/llm_service.dart';
import 'package:hello_world/services/ai_actions_config.dart';
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

  // Sample chat sessions (replace with actual data later)
  late final List<ChatSessionItem> _chatSessions;

  @override
  void initState() {
    super.initState();

    // Load current model identifier
    _loadCurrentModel();

    // Note: Session initialization moved to didChangeDependencies
    // to ensure we have access to the project provider

    // Initialize sample sessions
    _chatSessions = [
      ChatSessionItem(
        id: '1',
        description: 'Troubleshooting site outage due to MySQL',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      ChatSessionItem(
        id: '2',
        description: 'Restart of redis server on production',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
      ),
      ChatSessionItem(
        id: '3',
        description: 'Help investigating elevated errors on the app server',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
      ),
      ChatSessionItem(
        id: '4',
        description: 'Out of memory errors in background jobs',
        timestamp: DateTime.now().subtract(const Duration(days: 7)),
      ),
      ChatSessionItem(
        id: '5',
        description: 'RL Cluster not responding',
        timestamp: DateTime.now().subtract(const Duration(days: 14)),
      ),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

  void _showSessionHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Session History'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          ),
          body: SessionList(
            sessions: _chatSessions,
            onSessionTap: (session) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Opening session: ${session.description}'),
                  duration: const Duration(seconds: 2),
                ),
              );
              // TODO: Load the selected session
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Activate the session manager (handles all business logic)
    ref.watch(sessionManagerProvider);

    // Watch current state
    final currentProject = ref.watch(currentProjectProvider);
    final messagesAsync = ref.watch(currentSessionMessagesProvider);

    // Sync messages from provider to controller
    messagesAsync.whenData((messages) {
      // Only sync if controller doesn't match provider
      if (_controller.messages.length != messages.length) {
        _controller.clearMessages();
        for (final msg in messages) {
          _controller.addMessage(
            ChatMessage(
              text: msg.content,
              user: msg.userId == 'user' ? _currentUser : _aiUser,
              createdAt: msg.createdAt,
              customProperties: {'id': msg.id},
            ),
          );
        }
      }
    });

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
                    enableAnimation: true,
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

      // Add result message to chat with the actual command details
      final command = params['command'] ?? 'unknown command';
      final resultMessage = result.success
          ? '✅ Executed: `$command`\n\nResult: ${result.data}'
          : '❌ Failed to execute: `$command`\n\nError: ${result.error}';

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
        ),
      );

      // Clear pending action
      setState(() {
        _pendingAction = null;
      });
    } catch (e) {
      developer.log('❌ Action execution error: $e', name: 'ChatSession');

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
        ),
      );
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
          .toList();

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
        '�🚀 Calling llmService.sendMessageWithTools...',
        name: 'ChatSession',
      );

      // Collect the response and handle tool calls
      final buffer = StringBuffer();
      var chunkCount = 0;

      await for (final chunk in llmService.sendMessageWithTools(
        message.text,
        history: history,
        tools: tools,
      )) {
        chunkCount++;
        developer.log('📦 Chunk #$chunkCount: $chunk', name: 'ChatSession');

        // Check if this is a tool call
        if (chunk is Map && chunk['type'] == 'tool_call') {
          developer.log(
            '🔧 Tool call received: ${chunk['name']}',
            name: 'ChatSession',
          );

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

          // Show the action approval overlay
          setState(() {
            _pendingAction = Map<String, dynamic>.from(chunk);
            _isLoading = false; // Stop loading while waiting for user approval
          });

          // Note: We return here and let the overlay handle execution
          // The buffer will be added to chat when action completes
          return;
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
