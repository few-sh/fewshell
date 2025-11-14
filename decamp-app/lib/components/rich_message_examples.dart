/// Example: Using Rich Message Features in Chat
///
/// This file shows practical examples of how to use the rich message features
/// in the decamp chat application.
library;

import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:decamp/utils/rich_message_utils.dart';

class RichMessageExamples {
  static final _aiUser = ChatUser(id: 'ai', firstName: 'Ops Agent');

  /// Example 1: Simple selectable message (default)
  /// All messages are selectable by default - no code needed!
  static ChatMessage simpleMessage() {
    return ChatMessage(
      text: 'This message has selectable text automatically!',
      user: _aiUser,
      createdAt: DateTime.now(),
    );
  }

  /// Example 2: Message with copy button
  /// Great for code snippets, error messages, or any text users might want to copy
  static ChatMessage messageWithCopyButton() {
    return ChatMessage(
      text: '''
Error: Connection timeout
Code: ERR_TIMEOUT_001
Please check your network settings.
''',
      user: _aiUser,
      createdAt: DateTime.now(),
    ).asCopyable();
  }

  /// Example 3: Collapsible content for long responses
  /// Perfect for logs, detailed output, or verbose responses
  static ChatMessage collapsibleLogs() {
    return ChatMessage(
      text: '''
[2024-11-13 10:23:45] Starting deployment...
[2024-11-13 10:23:47] Building Docker image...
[2024-11-13 10:24:12] Image built successfully
[2024-11-13 10:24:15] Pushing to registry...
[2024-11-13 10:24:58] Deployment complete!
''',
      user: _aiUser,
      createdAt: DateTime.now(),
    ).asCollapsible(title: 'Deployment Logs', initiallyExpanded: false);
  }

  /// Example 4: Interactive message with action buttons
  /// Use for commands that need approval, options, or follow-up actions
  static ChatMessage interactiveMessage({
    required VoidCallback onApprove,
    required VoidCallback onReject,
  }) {
    return ChatMessage(
      text: 'Command ready to execute: `docker build -t myapp:latest .`',
      user: _aiUser,
      createdAt: DateTime.now(),
    ).withActions([
      MessageActionData(
        label: 'Approve',
        icon: Icons.check_circle,
        onPressed: onApprove,
      ),
      MessageActionData(
        label: 'Reject',
        icon: Icons.cancel,
        onPressed: onReject,
      ),
      MessageActionData(
        label: 'Modify',
        icon: Icons.edit,
        onPressed: () {
          // Open editor
        },
      ),
    ]);
  }

  /// Example 5: Combined features - collapsible with copy
  /// Best for detailed technical information
  static ChatMessage detailedTechnicalInfo() {
    return ChatMessage(
      text: '''
## System Diagnostics

**CPU**: Intel i7-9750H @ 2.60GHz
**Memory**: 16GB DDR4
**Disk**: 512GB NVMe SSD

### Running Processes
- Docker: Running (4 containers)
- PostgreSQL: Running (port 5432)
- Redis: Running (port 6379)

### Network Status
- eth0: 192.168.1.100/24
- docker0: 172.17.0.1/16
- lo: 127.0.0.1/8
''',
      user: _aiUser,
      createdAt: DateTime.now(),
      customProperties: RichMessageUtils.combineProperties([
        RichMessageUtils.collapsibleMessage(
          title: 'System Information',
          initiallyExpanded: false,
        ),
        RichMessageUtils.copyableMessage(),
      ]),
    );
  }

  /// Example 6: Markdown with code highlighting
  /// Automatically gets syntax highlighting and copy functionality
  static ChatMessage codeExample() {
    return ChatMessage(
      text: '''
Here's how to fix the issue:

```dart
// Update the configuration
final config = AppConfig(
  apiUrl: 'https://api.example.com',
  timeout: Duration(seconds: 30),
);

await api.initialize(config);
```

The `timeout` parameter should be at least 30 seconds for this API.
''',
      user: _aiUser,
      createdAt: DateTime.now(),
      isMarkdown: true,
    );
  }

  /// Example 7: Tool execution result with actions
  /// Show results and offer follow-up options
  static ChatMessage toolExecutionResult({
    required String output,
    required VoidCallback onViewFull,
    required VoidCallback onRetry,
  }) {
    final truncatedOutput = output.length > 500
        ? '${output.substring(0, 500)}...\n\n(Output truncated)'
        : output;

    return ChatMessage(
      text:
          '''
**Command executed successfully!**

```
$truncatedOutput
```
''',
      user: _aiUser,
      createdAt: DateTime.now(),
      isMarkdown: true,
      customProperties: RichMessageUtils.interactiveMessage(
        actions: [
          MessageActionData(
            label: 'View Full Output',
            icon: Icons.open_in_full,
            onPressed: onViewFull,
          ),
          MessageActionData(
            label: 'Retry',
            icon: Icons.refresh,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }

  /// Example 8: Error message with troubleshooting steps
  /// Collapsible troubleshooting with copy button for error details
  static ChatMessage errorWithTroubleshooting(String errorMessage) {
    return ChatMessage(
      text:
          '''
❌ **Error Occurred**

```
$errorMessage
```

**Troubleshooting Steps:**

1. **Check Network Connection**
   - Verify internet connectivity
   - Check firewall settings

2. **Verify Credentials**
   - Ensure API key is valid
   - Check token expiration

3. **Review Logs**
   - Check application logs
   - Review system logs

If the issue persists, please copy this error and contact support.
''',
      user: _aiUser,
      createdAt: DateTime.now(),
      isMarkdown: true,
    ).asCopyable();
  }

  /// Example 9: Progress update with expandable details
  /// Show summary with detailed progress in collapsible section
  static ChatMessage progressUpdate({
    required String summary,
    required String details,
  }) {
    return ChatMessage(
      text: details,
      user: _aiUser,
      createdAt: DateTime.now(),
    ).asCollapsible(title: summary, initiallyExpanded: false);
  }

  /// Example 10: Multi-step process with actions
  /// Guide user through steps with interactive options
  static ChatMessage multiStepProcess({
    required int currentStep,
    required int totalSteps,
    required VoidCallback onNext,
    required VoidCallback onSkip,
  }) {
    return ChatMessage(
      text:
          '''
**Step $currentStep of $totalSteps: Configure Database**

Please provide the database connection details:
- Host: localhost
- Port: 5432
- Database: myapp_dev
''',
      user: _aiUser,
      createdAt: DateTime.now(),
      isMarkdown: true,
    ).withActions([
      MessageActionData(
        label: 'Next',
        icon: Icons.arrow_forward,
        onPressed: onNext,
      ),
      MessageActionData(
        label: 'Skip',
        icon: Icons.skip_next,
        onPressed: onSkip,
      ),
    ]);
  }
}
