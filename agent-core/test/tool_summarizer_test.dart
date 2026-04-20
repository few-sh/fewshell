import 'dart:async';
import 'dart:convert';

import 'package:agent_core/agent_core.dart';
import 'package:llm_dart/llm_dart.dart';
import 'package:test/test.dart';

class MockMessageDao implements MessageDao {
  final List<MessageEntityCompanion> updatedCompanions = [];
  final Map<String, MessageEntity> storedMessages = {};

  @override
  Future<bool> updateMessage(MessageEntityCompanion message) async {
    updatedCompanions.add(message);

    final existing = storedMessages[message.id.value];
    if (existing != null) {
      storedMessages[message.id.value] = MessageEntity(
        id: existing.id,
        sessionId: message.sessionId.present
            ? message.sessionId.value
            : existing.sessionId,
        userId: message.userId.present ? message.userId.value : existing.userId,
        userName: message.userName.present
            ? message.userName.value
            : existing.userName,
        content:
            message.content.present ? message.content.value : existing.content,
        timestamp: message.timestamp.present
            ? message.timestamp.value
            : existing.timestamp,
        createdAt: message.createdAt.present
            ? message.createdAt.value
            : existing.createdAt,
        editedAt: message.editedAt.present
            ? message.editedAt.value
            : existing.editedAt,
        isStreaming: message.isStreaming.present
            ? message.isStreaming.value
            : existing.isStreaming,
        isVisibleToLlm: message.isVisibleToLlm.present
            ? message.isVisibleToLlm.value
            : existing.isVisibleToLlm,
        messageKind: message.messageKind.present
            ? message.messageKind.value
            : existing.messageKind,
        imageUrl: message.imageUrl.present
            ? message.imageUrl.value
            : existing.imageUrl,
        toolCallsJson: message.toolCallsJson.present
            ? message.toolCallsJson.value
            : existing.toolCallsJson,
        toolResultsJson: message.toolResultsJson.present
            ? message.toolResultsJson.value
            : existing.toolResultsJson,
        summary:
            message.summary.present ? message.summary.value : existing.summary,
      );
    }

    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not mocked');
}

class MockLlmStream {
  String summaryToReturn = 'summarized output';
  final List<List<ChatMessage>> calls = [];

  Stream<ChatStreamEvent> call(
    List<ChatMessage> conversation, {
    CancelToken? cancelToken,
  }) async* {
    calls.add(conversation);
    yield TextDeltaEvent(summaryToReturn);
  }
}

void main() {
  group('ToolSummarizer', () {
    test('summarizes oversized tool results individually', () async {
      final mockDao = MockMessageDao();
      final mockLlm = MockLlmStream()
        ..summaryToReturn = 'trimmed command output';

      final message = _buildToolResultMessage(
        toolCalls: [
          _toolCall(
            id: 'call_1',
            name: 'execute_shell_command',
            arguments: '{"command":"ls -la"}',
          ),
          _toolCall(
            id: 'call_2',
            name: 'fetch',
            arguments: '{"url":"https://example.com"}',
          ),
        ],
        toolResults: [
          _toolCall(
            id: 'call_1',
            name: 'execute_shell_command',
            arguments: 'A' * 120,
          ),
          _toolCall(
            id: 'call_2',
            name: 'fetch',
            arguments: 'short result',
          ),
        ],
      );
      mockDao.storedMessages[message.id] = message;

      final summarizer = ToolSummarizer(
        messageDao: mockDao,
        llmStream: mockLlm.call,
        config: const ToolSummarizerConfig(
          tokenThreshold: 50,
          bytesPerToken: 1,
          maximumInputTokens: 1000,
        ),
      );

      final didSummarize = await summarizer.summarizeIfNeeded(message);

      expect(didSummarize, isTrue);
      expect(mockLlm.calls, hasLength(1));
      expect(mockDao.updatedCompanions, hasLength(1));

      // messageKind stays as toolResult; summary field holds the oversized entries.
      final updated = mockDao.updatedCompanions.single;
      expect(updated.messageKind.value, MessageKind.toolResult);

      // The stored summary is a JSON map keyed by tool call ID, only oversized results.
      final encodedSummary = updated.summary.value!;
      final parsed = Map<String, String>.from(
        jsonDecode(encodedSummary) as Map,
      );

      // Only the oversized result (call_1) should be in the map.
      expect(parsed, hasLength(1));
      expect(parsed['call_1'], 'trimmed command output');
      expect(parsed.containsKey('call_2'), isFalse);

      expect(
        mockLlm.calls.single.first.content,
        contains('Tool call ID: call_1'),
      );
      expect(
        mockLlm.calls.single.first.content,
        isNot(contains('short result')),
      );
    });
  });

  group('MessageEntityToChat', () {
    test('substitutes summarized content for oversized tool results', () {
      // Summary map only has call_1 summarized; call_2 stays original.
      final message = _buildToolResultMessage(
        toolCalls: [
          _toolCall(
            id: 'call_1',
            name: 'execute_shell_command',
            arguments: '{"command":"pwd"}',
          ),
          _toolCall(
            id: 'call_2',
            name: 'fetch',
            arguments: '{"url":"https://example.com"}',
          ),
        ],
        toolResults: [
          _toolCall(
            id: 'call_1',
            name: 'execute_shell_command',
            arguments: '/very/long/raw/output',
          ),
          _toolCall(
            id: 'call_2',
            name: 'fetch',
            arguments: 'short result',
          ),
        ],
        summary: jsonEncode({'call_1': '/srv/app'}),
      );

      final chatMessages = message.toChatMessage();

      expect(chatMessages, hasLength(2));
      expect(chatMessages.first.messageType, isA<ToolUseMessage>());
      expect(chatMessages.last.messageType, isA<ToolResultMessage>());

      final toolResultMessage =
          chatMessages.last.messageType as ToolResultMessage;
      expect(toolResultMessage.results, hasLength(2));

      // call_1 should use the summarized content.
      expect(toolResultMessage.results[0].id, 'call_1');
      expect(toolResultMessage.results[0].function.arguments, '/srv/app');

      // call_2 should keep the original content.
      expect(toolResultMessage.results[1].id, 'call_2');
      expect(toolResultMessage.results[1].function.arguments, 'short result');
    });

    test('uses original results when summary is absent', () {
      final message = _buildToolResultMessage(
        toolCalls: [
          _toolCall(
            id: 'call_1',
            name: 'execute_shell_command',
            arguments: '{"command":"pwd"}',
          ),
        ],
        toolResults: [
          _toolCall(
            id: 'call_1',
            name: 'execute_shell_command',
            arguments: 'original output',
          ),
        ],
      );

      final chatMessages = message.toChatMessage();

      final toolResultMessage =
          chatMessages.last.messageType as ToolResultMessage;
      expect(
        toolResultMessage.results.single.function.arguments,
        'original output',
      );
    });

    test('strips ANSI escapes from shell tool stdout/stderr', () {
      final raw = jsonEncode({
        'stdout': '\x1B[31mERR\x1B[0m\nplain',
        'stderr': '\x1B[1mwarn\x1B[22m',
        'exitCode': 1,
      });
      final message = _buildToolResultMessage(
        toolCalls: [
          _toolCall(
            id: 'call_1',
            name: 'execute_shell_command',
            arguments: '{"command":"ls --color"}',
          ),
        ],
        toolResults: [
          _toolCall(
            id: 'call_1',
            name: 'execute_shell_command',
            arguments: raw,
          ),
        ],
      );

      final chatMessages = message.toChatMessage();
      final toolResultMessage =
          chatMessages.last.messageType as ToolResultMessage;
      final cleaned = jsonDecode(
        toolResultMessage.results.single.function.arguments,
      ) as Map<String, dynamic>;

      expect(cleaned['stdout'], 'ERR\nplain');
      expect(cleaned['stderr'], 'warn');
      expect(cleaned['exitCode'], 1);
    });

    test('summary takes precedence over ANSI stripping', () {
      final raw = jsonEncode({
        'stdout': '\x1B[31mraw\x1B[0m',
        'stderr': '',
        'exitCode': 0,
      });
      final message = _buildToolResultMessage(
        toolCalls: [
          _toolCall(
            id: 'call_1',
            name: 'execute_shell_command',
            arguments: '{"command":"ls"}',
          ),
        ],
        toolResults: [
          _toolCall(
            id: 'call_1',
            name: 'execute_shell_command',
            arguments: raw,
          ),
        ],
        summary: jsonEncode({'call_1': 'summarized'}),
      );

      final chatMessages = message.toChatMessage();
      final toolResultMessage =
          chatMessages.last.messageType as ToolResultMessage;
      expect(
        toolResultMessage.results.single.function.arguments,
        'summarized',
      );
    });

    test('does not strip ANSI from non-shell tools', () {
      final raw = '{"data":"\\u001B[31mraw\\u001B[0m"}';
      final message = _buildToolResultMessage(
        toolCalls: [
          _toolCall(
            id: 'call_1',
            name: 'fetch',
            arguments: '{"url":"https://example.com"}',
          ),
        ],
        toolResults: [
          _toolCall(
            id: 'call_1',
            name: 'fetch',
            arguments: raw,
          ),
        ],
      );

      final chatMessages = message.toChatMessage();
      final toolResultMessage =
          chatMessages.last.messageType as ToolResultMessage;
      expect(
        toolResultMessage.results.single.function.arguments,
        raw,
      );
    });
  });
}

ToolCall _toolCall({
  required String id,
  required String name,
  required String arguments,
}) {
  return ToolCall(
    id: id,
    callType: 'function',
    function: FunctionCall(
      name: name,
      arguments: arguments,
    ),
  );
}

MessageEntity _buildToolResultMessage({
  MessageKind kind = MessageKind.toolResult,
  required List<ToolCall> toolCalls,
  required List<ToolCall> toolResults,
  String content = '',
  String? summary,
}) {
  final now = DateTime(2026, 4, 4);
  return MessageEntity(
    id: 'message-1',
    sessionId: 'session-1',
    userId: 'tool',
    userName: 'Tool',
    content: content,
    timestamp: now,
    createdAt: now,
    editedAt: null,
    isStreaming: false,
    isVisibleToLlm: true,
    messageKind: kind,
    imageUrl: null,
    toolCallsJson: toolCalls,
    toolResultsJson: toolResults,
    summary: summary,
  );
}
