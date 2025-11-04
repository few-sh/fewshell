import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:hello_world/components/session_list.dart';
import 'package:hello_world/components/project_list.dart';

class ChatSession extends StatefulWidget {
  final Function(ThemeMode)? onThemeChanged;

  const ChatSession({super.key, this.onThemeChanged});

  @override
  State<ChatSession> createState() => _ChatSessionState();
}

class _ChatSessionState extends State<ChatSession> {
  // Controller for managing chat messages
  final _controller = ChatMessagesController();

  // Define users
  final _currentUser = ChatUser(id: 'user', firstName: 'You');
  final _aiUser = ChatUser(id: 'ai', firstName: 'Ops Agent');

  // Loading state
  bool _isLoading = false;

  // Sample chat sessions (replace with actual data later)
  late final List<ChatSessionItem> _chatSessions;

  // Sample projects (replace with actual data later)
  late List<Project> _projects;
  late String _currentProjectId;

  @override
  void initState() {
    super.initState();

    // Initialize sample projects
    _projects = [
      Project(
        id: '1',
        name: 'few-sh',
        description: 'Production environment for Fewshot',
        lastSessionDate: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Project(
        id: '2',
        name: 'autographiq',
        description: 'Sandbox environment for Gulliver',
        lastSessionDate: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Project(
        id: '3',
        name: 'RL environment',
        description: null,
        lastSessionDate: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Project(
        id: '4',
        name: 'API services',
        description: 'API services for iOS and Android apps',
        lastSessionDate: DateTime.now().subtract(const Duration(days: 30)),
      ),
    ];
    _currentProjectId = '1'; // Decamp is the current project

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

  void _showProjectSwitcher() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Switch Project'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          ),
          body: ProjectList(
            projects: _projects,
            onProjectTap: (project) {
              setState(() {
                _currentProjectId = project.id;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Switched to project: ${project.name}'),
                  duration: const Duration(seconds: 2),
                ),
              );
              // TODO: Load project data and sessions
            },
            onProjectDelete: (project) {
              setState(() {
                _projects.removeWhere((p) => p.id == project.id);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleted project: ${project.name}'),
                  duration: const Duration(seconds: 2),
                ),
              );
              // TODO: Delete project data from storage
            },
            onCreateProject: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Create project dialog coming soon!'),
                  duration: Duration(seconds: 2),
                ),
              );
              // TODO: Show create project dialog
            },
          ),
        ),
      ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.brightness_auto),
                title: const Text('System Default'),
                onTap: () {
                  if (widget.onThemeChanged != null) {
                    widget.onThemeChanged!(ThemeMode.system);
                  }
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.light_mode),
                title: const Text('Light'),
                onTap: () {
                  if (widget.onThemeChanged != null) {
                    widget.onThemeChanged!(ThemeMode.light);
                  }
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode),
                title: const Text('Dark (Neon)'),
                onTap: () {
                  if (widget.onThemeChanged != null) {
                    widget.onThemeChanged!(ThemeMode.dark);
                  }
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('fewshot production'),
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
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.inversePrimary,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PROJECT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _projects
                                    .firstWhere(
                                      (p) => p.id == _currentProjectId,
                                      orElse: () => _projects.first,
                                    )
                                    .name,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Current project',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.swap_horiz),
                          tooltip: 'Switch Project',
                          iconSize: 28,
                          onPressed: () {
                            Navigator.pop(context);
                            _showProjectSwitcher();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Snippets'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Snippets page coming soon!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.key),
                title: const Text('Secrets'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Secrets page coming soon!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Agent Instructions'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Customize instructions for the assistant.',
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.monitor_heart),
                title: const Text('Monitors (Premium)'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Monitoring page coming soon!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                  _showThemeDialog();
                },
              ),
            ],
          ),
        ),
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
    setState(() => _isLoading = true);

    try {
      // Simulate API call delay
      await Future.delayed(const Duration(seconds: 1));

      // Generate a response based on the user's message
      final response = _generateResponse(message.text);

      // Add AI response to chat
      _controller.addMessage(
        ChatMessage(text: response, user: _aiUser, createdAt: DateTime.now()),
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

  /// Generate a simple response (replace with actual AI integration)
  String _generateResponse(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();

    if (lowerMessage.contains('hello') || lowerMessage.contains('hi')) {
      return "Hello! 👋 How can I help you today?";
    } else if (lowerMessage.contains('help')) {
      return "I'm here to assist you! You can ask me questions, and I'll do my best to provide helpful answers. "
          "Feel free to explore the example questions or type your own query.";
    } else if (lowerMessage.contains('feature')) {
      return "This chat includes:\n\n"
          "• 🎨 Modern UI with dark/light themes\n"
          "• 💫 Streaming text animations\n"
          "• 📝 Markdown support\n"
          "• 🔄 Real-time message handling\n"
          "• 📱 Responsive design\n\n"
          "Try asking me anything!";
    } else if (lowerMessage.contains('how') && lowerMessage.contains('work')) {
      return "This chat works by:\n\n"
          "1. You type a message\n"
          "2. It gets sent to the AI system\n"
          "3. The AI processes your request\n"
          "4. You receive a response with smooth animations\n\n"
          "Currently, I'm using a simple demo backend. You can integrate this with real AI services like OpenAI, Claude, or Gemini!";
    } else {
      return "I received your message: \"$userMessage\"\n\n"
          "This is a demo response. In a real application, this would be connected to an AI service like:\n\n"
          "• OpenAI GPT\n"
          "• Anthropic Claude\n"
          "• Google Gemini\n"
          "• Or any custom AI backend\n\n"
          "Ask me about features or help!";
    }
  }
}
