import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:hello_world/components/session_list.dart';
import 'package:hello_world/components/main_drawer.dart';
import 'package:hello_world/components/action_approval_overlay.dart';
import 'package:hello_world/providers/project_provider.dart';
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
    // Watch the current project from the provider
    final currentProject = ref.watch(currentProjectProvider);
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
      _controller.addMessage(
        ChatMessage(
          text: result.success
              ? '✅ Executed: `$command`\n\nResult: ${result.data}'
              : '❌ Failed to execute: `$command`\n\nError: ${result.error}',
          user: _aiUser,
          createdAt: DateTime.now(),
        ),
      );

      // Clear pending action
      setState(() {
        _pendingAction = null;
      });
    } catch (e) {
      developer.log('❌ Action execution error: $e', name: 'ChatSession');
      _controller.addMessage(
        ChatMessage(
          text: '❌ Error executing command: $e',
          user: _aiUser,
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  /// Handle sending messages
  Future<void> _handleSendMessage(ChatMessage message) async {
    developer.log('🎯 _handleSendMessage called', name: 'ChatSession');
    developer.log('User message: ${message.text}', name: 'ChatSession');

    // Add the user's message to the chat history first
    _controller.addMessage(message);
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
        _controller.addMessage(
          ChatMessage(
            text:
                "⚠️ No LLM configured. Please go to Settings → AI Models to configure an LLM provider.",
            user: _aiUser,
            createdAt: DateTime.now(),
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
          _controller.addMessage(
            ChatMessage(
              text: '🔧 Requesting to execute: `$command`\n$explanation',
              user: _aiUser,
              createdAt: DateTime.now(),
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
      _controller.addMessage(
        ChatMessage(
          text: buffer.toString(),
          user: _aiUser,
          createdAt: DateTime.now(),
        ),
      );
      developer.log('✅ AI response added to controller', name: 'ChatSession');
    } catch (e) {
      // Handle errors
      developer.log('❌ Error in _handleSendMessage: $e', name: 'ChatSession');
      _controller.addMessage(
        ChatMessage(
          text: "Sorry, I encountered an error: $e",
          user: _aiUser,
          createdAt: DateTime.now(),
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
