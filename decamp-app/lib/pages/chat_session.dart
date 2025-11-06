import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:hello_world/components/session_list.dart';
import 'package:hello_world/components/main_drawer.dart';
import 'package:hello_world/providers/project_provider.dart';
import 'package:hello_world/pages/projects_page.dart';
import 'package:hello_world/services/llm_service.dart';

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

  // Sample chat sessions (replace with actual data later)
  late final List<ChatSessionItem> _chatSessions;

  @override
  void initState() {
    super.initState();

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
        body: AiChatWidget(
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
              hintText: 'Ask me anything...',
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

          // Welcome message configuration
          welcomeMessageConfig: WelcomeMessageConfig(
            title: 'Welcome to AI Chat',
            questionsSectionTitle: 'Try asking me:',
          ),

          // Example questions for users
          exampleQuestions: [
            ExampleQuestion(question: "What can you help me with?"),
            ExampleQuestion(question: "Tell me about your features"),
            ExampleQuestion(question: "How does this chat work?"),
          ],

          // Enable animations and streaming
          enableAnimation: true,
          enableMarkdownStreaming: true,
          streamingWordByWord: true,
          streamingDuration: const Duration(milliseconds: 30),

          // Message options
          messageOptions: MessageOptions(
            showTime: true,
            showUserName: true,
            bubbleStyle: BubbleStyle(
              userBubbleColor: Theme.of(context).colorScheme.primaryContainer,
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
          padding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  /// Handle sending messages
  Future<void> _handleSendMessage(ChatMessage message) async {
    // Add the user's message to the chat history first
    _controller.addMessage(message);

    setState(() => _isLoading = true);

    try {
      // Get the LLM service
      final llmService = ref.read(llmServiceProvider);

      // Check if LLM is configured
      final isConfigured = await llmService.isConfigured();
      if (!isConfigured) {
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
      final history = _controller.messages
          .where((msg) => msg.text.isNotEmpty) // Skip empty messages
          .map(
            (msg) => {
              'role': msg.user.id == 'user' ? 'user' : 'assistant',
              'content': msg.text,
            },
          )
          .toList();

      // Collect the full response
      final buffer = StringBuffer();
      await for (final chunk in llmService.sendMessage(
        message.text,
        history: history,
      )) {
        buffer.write(chunk);
      }

      // Add the complete response
      _controller.addMessage(
        ChatMessage(
          text: buffer.toString(),
          user: _aiUser,
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      // Handle errors
      _controller.addMessage(
        ChatMessage(
          text: "Sorry, I encountered an error: $e",
          user: _aiUser,
          createdAt: DateTime.now(),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
