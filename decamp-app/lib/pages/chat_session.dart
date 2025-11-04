import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';

class ChatSession extends StatefulWidget {
  const ChatSession({super.key});

  @override
  State<ChatSession> createState() => _ChatSessionState();
}

class _ChatSessionState extends State<ChatSession> {
  // Controller for managing chat messages
  final _controller = ChatMessagesController();

  // Define users
  final _currentUser = ChatUser(id: 'user', firstName: 'You');
  final _aiUser = ChatUser(id: 'ai', firstName: 'AI Assistant');

  // Loading state
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Chat'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
        inputOptions: InputOptions.minimal(
          hintText: 'Ask me anything...',
          textColor: Colors.black,
          hintColor: Colors.grey,
          backgroundColor: Colors.white,
          borderRadius: 24.0,
          autofocus: true,
          sendOnEnter: true,
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
            userBubbleColor: Colors.blue.withOpacity(0.1),
            aiBubbleColor: Colors.grey.shade100,
            userNameColor: Colors.blue.shade700,
            aiNameColor: Colors.purple.shade700,
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
