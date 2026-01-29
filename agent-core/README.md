# Agent Core

Shared agent loop implementation for Decamp client and server.

## Overview

This package contains the core agent loop that:
1. Sends conversation to LLM
2. Checks for tool calls in response
3. Requests user approval for tools
4. Executes approved tools
5. Repeats until no more tool calls

## Usage

```dart
import 'package:agent_core/agent_core.dart';

await runAgentLoop(
  llmStream: (conversation, tools) => llmService.streamChat(conversation, tools: tools),
  tools: myTools,
  conversation: messages,
  requestApproval: (toolCalls) async {
    // Show approval UI, return approved subset or null to cancel
    return showApprovalDialog(toolCalls);
  },
  executeToolCall: (toolCalls) async {
    // Execute the tools and return list of result strings
    final results = <String>[];
    for (final toolCall in toolCalls) {
      results.add(await executeShell(toolCall));
    }
    return results;
  },
  onTextDelta: (delta) {
    // Handle streaming text
    setState(() => streamingText += delta);
  },
  onAssistantMessage: (message) async {
    // Save assistant message to database
    await db.insertMessage(message);
  },
  onToolResultMessage: (message) async {
    // Save tool result message to database
    await db.insertMessage(message);
  },
);
```
