import 'dart:async';

import 'package:llm_dart/llm_dart.dart';
import 'package:test/test.dart';
import 'package:agent_core/agent_core.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

/// Minimal mock for MessageDao.
///
/// Only the methods used by ConversationSummarizer are implemented:
///   - getMessagesBySession
///   - insertMessage
///   - insertMessageWithId
///   - updateMessage
///   - deleteMessage
class MockMessageDao implements MessageDao {
  List<MessageEntity> storedMessages = [];
  final List<MessageEntityCompanion> insertedCompanions = [];
  final List<MessageEntityCompanion> updatedCompanions = [];
  final List<String> deletedIds = [];
  int _insertCounter = 0;

  @override
  Future<List<MessageEntity>> getMessagesBySession(String sessionId) async {
    return storedMessages.where((m) => m.sessionId == sessionId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<int> insertMessage(MessageEntityCompanion message) async {
    insertedCompanions.add(message);
    // Persist into storedMessages so subsequent reads see the insert.
    storedMessages.add(MessageEntity(
      id: message.id.value,
      sessionId: message.sessionId.value,
      userId: message.userId.value,
      userName: message.userName.value,
      content: message.content.value,
      timestamp: message.timestamp.value,
      createdAt: message.createdAt.value,
      editedAt: message.editedAt.present ? message.editedAt.value : null,
      isStreaming: message.isStreaming.value,
      isVisibleToLlm: message.isVisibleToLlm.value,
      messageKind: message.messageKind.value,
      imageUrl: message.imageUrl.present ? message.imageUrl.value : null,
      toolCallsJson:
          message.toolCallsJson.present ? message.toolCallsJson.value : null,
      toolResultsJson: message.toolResultsJson.present
          ? message.toolResultsJson.value
          : null,
      summary: message.summary.present ? message.summary.value : null,
    ));
    return 1;
  }

  @override
  Future<String> insertMessageWithId({
    String? id,
    required String sessionId,
    required String userId,
    required String userName,
    required String content,
    String? imageUrl,
    MessageKind? messageKind,
    bool isStreaming = false,
    bool isVisibleToLlm = true,
  }) async {
    _insertCounter++;
    return id ?? 'progress-$_insertCounter';
  }

  @override
  Future<int> deleteMessage(String id) async {
    deletedIds.add(id);
    return 1;
  }

  @override
  Future<bool> updateMessage(MessageEntityCompanion message) async {
    updatedCompanions.add(message);
    // Apply update to storedMessages so subsequent reads see it.
    final idx = storedMessages.indexWhere((m) => m.id == message.id.value);
    if (idx >= 0) {
      final old = storedMessages[idx];
      storedMessages[idx] = MessageEntity(
        id: old.id,
        sessionId:
            message.sessionId.present ? message.sessionId.value : old.sessionId,
        userId: message.userId.present ? message.userId.value : old.userId,
        userName:
            message.userName.present ? message.userName.value : old.userName,
        content: message.content.present ? message.content.value : old.content,
        timestamp:
            message.timestamp.present ? message.timestamp.value : old.timestamp,
        createdAt:
            message.createdAt.present ? message.createdAt.value : old.createdAt,
        editedAt:
            message.editedAt.present ? message.editedAt.value : old.editedAt,
        isStreaming: message.isStreaming.present
            ? message.isStreaming.value
            : old.isStreaming,
        isVisibleToLlm: message.isVisibleToLlm.present
            ? message.isVisibleToLlm.value
            : old.isVisibleToLlm,
        messageKind: message.messageKind.present
            ? message.messageKind.value
            : old.messageKind,
        imageUrl:
            message.imageUrl.present ? message.imageUrl.value : old.imageUrl,
        toolCallsJson: message.toolCallsJson.present
            ? message.toolCallsJson.value
            : old.toolCallsJson,
        toolResultsJson: message.toolResultsJson.present
            ? message.toolResultsJson.value
            : old.toolResultsJson,
        summary: message.summary.present ? message.summary.value : old.summary,
      );
    }
    return true;
  }

  // -- Unused stubs below (required by the interface) --

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not mocked');
}

/// Helper that produces a mock [LlmStreamFunction] for testing.
class MockLlmStream {
  String summaryToReturn = 'This is a test summary.';
  bool shouldError = false;
  String errorMessage = 'mock error';

  /// Tracks conversations passed to the stream function for assertions.
  final List<List<ChatMessage>> calls = [];

  /// The [SummarizationStreamFunction] to pass to [ConversationSummarizer].
  Stream<ChatStreamEvent> call(
    List<ChatMessage> conversation, {
    CancelToken? cancelToken,
  }) async* {
    calls.add(conversation);
    if (shouldError) {
      yield ErrorEvent(ProviderError(errorMessage));
      return;
    }
    // Emit the summary as text deltas (one chunk for simplicity)
    yield TextDeltaEvent(summaryToReturn);
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _testSessionId = 'session-1';

MessageEntity _makeMessage({
  required String id,
  String sessionId = _testSessionId,
  String userId = 'user',
  String userName = 'You',
  String content = 'hello',
  MessageKind messageKind = MessageKind.text,
  bool isVisibleToLlm = true,
  bool isStreaming = false,
  DateTime? createdAt,
}) {
  final ts =
      createdAt ?? DateTime(2025, 1, 1).add(Duration(minutes: int.parse(id)));
  return MessageEntity(
    id: id,
    sessionId: sessionId,
    userId: userId,
    userName: userName,
    content: content,
    timestamp: ts,
    createdAt: ts,
    messageKind: messageKind,
    isVisibleToLlm: isVisibleToLlm,
    isStreaming: isStreaming,
  );
}

List<MessageEntity> _makeMessages(int count,
    {String sessionId = _testSessionId}) {
  return List.generate(count, (i) {
    final id = i.toString();
    return _makeMessage(
      id: id,
      sessionId: sessionId,
      userId: i.isEven ? 'user' : 'ai',
      userName: i.isEven ? 'You' : 'Ops Agent',
      content: 'Message number $i',
    );
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockMessageDao mockDao;
  late MockLlmStream mockLlm;

  setUp(() {
    mockDao = MockMessageDao();
    mockLlm = MockLlmStream();
  });

  group('ConversationSummarizer - threshold logic', () {
    test('skips when message count is below threshold', () async {
      mockDao.storedMessages = _makeMessages(10);

      final summarizer = ConversationSummarizer(
        messageDao: mockDao,
        llmStream: mockLlm.call,
        config: const ConversationSummarizerConfig(
          messageCountThreshold: 20,
          tokenThreshold: 999999, // high so only count matters
          recentMessageCount: 5,
        ),
      );

      final result = await summarizer.summarizeIfNeeded(_testSessionId);

      expect(result, isFalse);
      expect(mockDao.insertedCompanions, isEmpty);
      expect(mockDao.updatedCompanions, isEmpty);
      expect(mockLlm.calls, isEmpty);
    });

    test('skips when all messages are streaming', () async {
      mockDao.storedMessages = List.generate(
        50,
        (i) => _makeMessage(id: i.toString(), isStreaming: true),
      );

      final summarizer = ConversationSummarizer(
        messageDao: mockDao,
        llmStream: mockLlm.call,
        config: const ConversationSummarizerConfig(
          messageCountThreshold: 20,
          recentMessageCount: 5,
        ),
      );

      final result = await summarizer.summarizeIfNeeded(_testSessionId);
      expect(result, isFalse);
    });

    test('skips when all messages are already hidden from LLM', () async {
      mockDao.storedMessages = List.generate(
        50,
        (i) => _makeMessage(id: i.toString(), isVisibleToLlm: false),
      );

      final summarizer = ConversationSummarizer(
        messageDao: mockDao,
        llmStream: mockLlm.call,
        config: const ConversationSummarizerConfig(
          messageCountThreshold: 20,
          recentMessageCount: 5,
        ),
      );

      final result = await summarizer.summarizeIfNeeded(_testSessionId);
      expect(result, isFalse);
    });

    test('triggers when message count reaches threshold', () async {
      mockDao.storedMessages = _makeMessages(25);

      final summarizer = ConversationSummarizer(
        messageDao: mockDao,
        llmStream: mockLlm.call,
        config: const ConversationSummarizerConfig(
          messageCountThreshold: 20,
          tokenThreshold: 999999,
          recentMessageCount: 5,
        ),
      );

      final result = await summarizer.summarizeIfNeeded(_testSessionId);
      expect(result, isTrue);
    });

    test('triggers when token estimate exceeds threshold', () async {
      // Each message content is ~16 chars ("Message number X").
      // 15 messages × 16 chars / 4 bytes-per-token ≈ 60 tokens.
      // Set token threshold very low to trigger.
      mockDao.storedMessages = _makeMessages(15);

      final summarizer = ConversationSummarizer(
        messageDao: mockDao,
        llmStream: mockLlm.call,
        config: const ConversationSummarizerConfig(
          messageCountThreshold: 999, // high so only tokens matter
          tokenThreshold: 10,
          bytesPerToken: 4,
          recentMessageCount: 5,
        ),
      );

      final result = await summarizer.summarizeIfNeeded(_testSessionId);
      expect(result, isTrue);
    });

    test('does not trigger when only one message exists', () async {
      mockDao.storedMessages = _makeMessages(1);

      final summarizer = ConversationSummarizer(
        messageDao: mockDao,
        llmStream: mockLlm.call,
        config: const ConversationSummarizerConfig(
          messageCountThreshold: 1,
          tokenThreshold: 1,
          recentMessageCount: 5,
        ),
      );

      final result = await summarizer.summarizeIfNeeded(_testSessionId);
      expect(result, isFalse);
    });

    test(
        'triggers over token limit even with fewer messages than recentMessageCount',
        () async {
      // 5 messages, recentMessageCount is 10, but token threshold is very low.
      // Should still summarize (keep 4, summarize 1) instead of being stuck.
      mockDao.storedMessages = _makeMessages(5);
      mockLlm.summaryToReturn = 'emergency summary';

      final summarizer = ConversationSummarizer(
        messageDao: mockDao,
        llmStream: mockLlm.call,
        config: const ConversationSummarizerConfig(
          messageCountThreshold: 999,
          tokenThreshold: 1, // very low — always over limit
          recentMessageCount: 10,
        ),
      );

      final result = await summarizer.summarizeIfNeeded(_testSessionId);
      expect(result, isTrue);
      // Should keep 4 (min(10, 5-1)) and summarize 1
      expect(mockDao.updatedCompanions, hasLength(1));
    });
  });

  group('ConversationSummarizer - summarization flow', () {
    test('inserts summary message and hides old messages', () async {
      const total = 20;
      const keep = 5;
      mockDao.storedMessages = _makeMessages(total);
      mockLlm.summaryToReturn = 'Summary of first 15 messages';

      final summarizer = ConversationSummarizer(
        messageDao: mockDao,
        llmStream: mockLlm.call,
        config: const ConversationSummarizerConfig(
          messageCountThreshold: 15,
          tokenThreshold: 999999,
          recentMessageCount: keep,
        ),
      );

      final result = await summarizer.summarizeIfNeeded(_testSessionId);
      expect(result, isTrue);

      // Should have called LLM once
      expect(mockLlm.calls, hasLength(1));

      // Should have inserted exactly 1 summary message
      expect(mockDao.insertedCompanions, hasLength(1));
      final inserted = mockDao.insertedCompanions.first;
      expect(inserted.messageKind.value, MessageKind.conversationSummary);
      expect(inserted.isVisibleToLlm.value, isTrue);
      expect(inserted.isStreaming.value, isFalse);
      expect(inserted.userId.value, 'system');
      // summary field should have the raw summary
      expect(inserted.summary.value, 'Summary of first 15 messages');
      // content should have prefix + summary
      expect(inserted.content.value, contains('Summary of first 15 messages'));
      expect(
        inserted.content.value,
        startsWith('Another language model'),
      );

      // Should have hidden total - keep = 15 messages
      expect(mockDao.updatedCompanions, hasLength(total - keep));
      for (final companion in mockDao.updatedCompanions) {
        expect(companion.isVisibleToLlm.value, isFalse);
      }
    });

    test('sends transcript of old messages to LLM', () async {
      mockDao.storedMessages = _makeMessages(20);
      mockLlm.summaryToReturn = 'ok';

      final summarizer = ConversationSummarizer(
        messageDao: mockDao,
        llmStream: mockLlm.call,
        config: const ConversationSummarizerConfig(
          messageCountThreshold: 15,
          tokenThreshold: 999999,
          recentMessageCount: 5,
        ),
      );

      await summarizer.summarizeIfNeeded(_testSessionId);

      // The LLM should have received two user messages:
      //   [0] transcript, [1] summarization prompt
      final conversation = mockLlm.calls.first;
      expect(conversation, hasLength(2));
      expect(conversation[0].role, ChatRole.user);
      expect(conversation[1].role, ChatRole.user);

      // First message: the transcript of old messages
      final transcript = conversation[0].content;
      expect(transcript, contains('Message number 0'));
      expect(transcript, contains('Message number 14'));
      // Should NOT contain the kept tail messages
      expect(transcript, isNot(contains('Message number 15')));

      // Last message: the default summarization prompt
      expect(
          conversation[1].content, contains('CONTEXT CHECKPOINT COMPACTION'));
    });

    test('uses custom summaryPrefix in inserted message content', () async {
      mockDao.storedMessages = _makeMessages(20);
      mockLlm.summaryToReturn = 'The actual summary text';

      const customPrefix = '[PRIOR CONTEXT]\n';
      final summarizer = ConversationSummarizer(
        messageDao: mockDao,
        llmStream: mockLlm.call,
        config: const ConversationSummarizerConfig(
          messageCountThreshold: 15,
          tokenThreshold: 999999,
          recentMessageCount: 5,
          summaryPrefix: customPrefix,
        ),
      );

      await summarizer.summarizeIfNeeded(_testSessionId);

      final inserted = mockDao.insertedCompanions.first;
      // content = prefix + raw summary
      expect(inserted.content.value, '${customPrefix}The actual summary text');
      // raw summary field is NOT prefixed
      expect(inserted.summary.value, 'The actual summary text');
    });

    test('passes custom summarizationPrompt as last LLM message', () async {
      mockDao.storedMessages = _makeMessages(20);
      mockLlm.summaryToReturn = 'ok';

      const customPrompt = 'Summarize in bullet points only.';
      final summarizer = ConversationSummarizer(
        messageDao: mockDao,
        llmStream: mockLlm.call,
        config: const ConversationSummarizerConfig(
          messageCountThreshold: 15,
          tokenThreshold: 999999,
          recentMessageCount: 5,
          summarizationPrompt: customPrompt,
        ),
      );

      await summarizer.summarizeIfNeeded(_testSessionId);

      final conversation = mockLlm.calls.first;
      expect(conversation.last.content, customPrompt);
    });

    test('fires onSummarized callback after completion', () async {
      mockDao.storedMessages = _makeMessages(20);
      mockLlm.summaryToReturn = 'done';

      String? callbackSessionId;
      final summarizer = ConversationSummarizer(
        messageDao: mockDao,
        llmStream: mockLlm.call,
        config: const ConversationSummarizerConfig(
          messageCountThreshold: 15,
          recentMessageCount: 5,
        ),
        onSummarized: (sessionId) async {
          callbackSessionId = sessionId;
        },
      );

      await summarizer.summarizeIfNeeded(_testSessionId);
      expect(callbackSessionId, _testSessionId);
    });

    test('does not fire onSummarized when summarization is skipped', () async {
      mockDao.storedMessages = _makeMessages(5);

      var callbackFired = false;
      final summarizer = ConversationSummarizer(
        messageDao: mockDao,
        llmStream: mockLlm.call,
        config: const ConversationSummarizerConfig(
          messageCountThreshold: 20,
          recentMessageCount: 3,
        ),
        onSummarized: (_) async {
          callbackFired = true;
        },
      );

      await summarizer.summarizeIfNeeded(_testSessionId);
      expect(callbackFired, isFalse);
    });
  });

  group('ConversationSummarizer - error handling', () {
    test('throws when LLM returns an error', () async {
      mockDao.storedMessages = _makeMessages(20);
      mockLlm.shouldError = true;
      mockLlm.errorMessage = 'rate limited';

      final summarizer = ConversationSummarizer(
        messageDao: mockDao,
        llmStream: mockLlm.call,
        config: const ConversationSummarizerConfig(
          messageCountThreshold: 15,
          recentMessageCount: 5,
        ),
      );

      expect(
        () => summarizer.summarizeIfNeeded(_testSessionId),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('rate limited'),
        )),
      );
    });

    test('throws when LLM returns empty summary', () async {
      mockDao.storedMessages = _makeMessages(20);
      mockLlm.summaryToReturn = '';

      final summarizer = ConversationSummarizer(
        messageDao: mockDao,
        llmStream: mockLlm.call,
        config: const ConversationSummarizerConfig(
          messageCountThreshold: 15,
          recentMessageCount: 5,
        ),
      );

      expect(
        () => summarizer.summarizeIfNeeded(_testSessionId),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('empty summary'),
        )),
      );
    });
  });

  group('ConversationSummarizer - stacking summaries', () {
    test('includes prior summary messages in the summarization input',
        () async {
      // Simulate a session that was already summarized once:
      // - Messages 0-9 are hidden (isVisibleToLlm = false)
      // - A conversationSummary message is visible
      // - Messages 10-29 are visible
      // Total visible = 1 summary + 20 messages = 21
      final hidden = List.generate(
        10,
        (i) => _makeMessage(id: i.toString(), isVisibleToLlm: false),
      );
      final previousSummary = _makeMessage(
        id: '100',
        userId: 'system',
        userName: 'System',
        content: 'Previous summary of messages 0-9',
        messageKind: MessageKind.conversationSummary,
        createdAt: DateTime(2025, 1, 1).add(const Duration(minutes: 10)),
      );
      final recent = List.generate(
        20,
        (i) => _makeMessage(
          id: (i + 10).toString(),
          createdAt: DateTime(2025, 1, 1).add(Duration(minutes: i + 11)),
        ),
      );

      mockDao.storedMessages = [...hidden, previousSummary, ...recent];
      mockLlm.summaryToReturn = 'Stacked summary';

      final summarizer = ConversationSummarizer(
        messageDao: mockDao,
        llmStream: mockLlm.call,
        config: const ConversationSummarizerConfig(
          messageCountThreshold: 15,
          tokenThreshold: 999999,
          recentMessageCount: 5,
        ),
      );

      await summarizer.summarizeIfNeeded(_testSessionId);

      // The transcript sent to LLM should include the previous summary
      final transcript = mockLlm.calls.first.first.content;
      expect(transcript, contains('Previous summary of messages 0-9'));

      // The previous summary message should now be hidden
      final hiddenIds =
          mockDao.updatedCompanions.map((c) => c.id.value).toSet();
      expect(hiddenIds, contains('100'));
    });
  });

  group('ConversationSummarizer - session isolation', () {
    test('only summarizes messages from the target session', () async {
      final sessionAMessages = _makeMessages(20, sessionId: 'session-a');
      final sessionBMessages = _makeMessages(20, sessionId: 'session-b');
      mockDao.storedMessages = [...sessionAMessages, ...sessionBMessages];
      mockLlm.summaryToReturn = 'Summary A';

      final summarizer = ConversationSummarizer(
        messageDao: mockDao,
        llmStream: mockLlm.call,
        config: const ConversationSummarizerConfig(
          messageCountThreshold: 15,
          recentMessageCount: 5,
        ),
      );

      await summarizer.summarizeIfNeeded('session-a');

      // All hidden messages should belong to session-a
      for (final companion in mockDao.updatedCompanions) {
        expect(companion.sessionId.value, 'session-a');
      }

      // Inserted summary should belong to session-a
      expect(mockDao.insertedCompanions.first.sessionId.value, 'session-a');
    });
  });

  group('ConversationSummarizer - forceSummarize', () {
    test('summarizes even when below threshold', () async {
      // 12 messages, threshold is 20 — summarizeIfNeeded would skip
      mockDao.storedMessages = _makeMessages(12);
      mockLlm.summaryToReturn = 'forced summary';

      final summarizer = ConversationSummarizer(
        messageDao: mockDao,
        llmStream: mockLlm.call,
        config: const ConversationSummarizerConfig(
          messageCountThreshold: 20,
          tokenThreshold: 999999,
          recentMessageCount: 5,
        ),
      );

      // summarizeIfNeeded should skip
      expect(await summarizer.summarizeIfNeeded(_testSessionId), isFalse);

      // forceSummarize should proceed
      final result = await summarizer.forceSummarize(_testSessionId);
      expect(result, isTrue);
      expect(mockDao.insertedCompanions, hasLength(1));
      expect(mockDao.updatedCompanions, hasLength(7)); // 12 - 5 kept
    });

    test('returns false when only one message exists', () async {
      mockDao.storedMessages = _makeMessages(1);

      final summarizer = ConversationSummarizer(
        messageDao: mockDao,
        llmStream: mockLlm.call,
        config: const ConversationSummarizerConfig(
          recentMessageCount: 5,
        ),
      );

      final result = await summarizer.forceSummarize(_testSessionId);
      expect(result, isFalse);
      expect(mockLlm.calls, isEmpty);
    });

    test(
        'summarizes with reduced tail when fewer messages than recentMessageCount',
        () async {
      // 3 messages, recentMessageCount=5 — should keep 2, summarize 1
      mockDao.storedMessages = _makeMessages(3);
      mockLlm.summaryToReturn = 'small session summary';

      final summarizer = ConversationSummarizer(
        messageDao: mockDao,
        llmStream: mockLlm.call,
        config: const ConversationSummarizerConfig(
          recentMessageCount: 5,
        ),
      );

      final result = await summarizer.forceSummarize(_testSessionId);
      expect(result, isTrue);
      expect(mockDao.updatedCompanions, hasLength(1)); // 3 - 2 kept = 1 hidden
      expect(mockDao.insertedCompanions, hasLength(1)); // 1 summary
    });
  });

  group('ConversationSummarizer - hideMessages flag', () {
    test('summarizeIfNeeded skips hiding when hideMessages is false', () async {
      mockDao.storedMessages = _makeMessages(25);
      mockLlm.summaryToReturn = 'summary without hiding';

      final summarizer = ConversationSummarizer(
        messageDao: mockDao,
        llmStream: mockLlm.call,
        config: const ConversationSummarizerConfig(
          messageCountThreshold: 20,
          recentMessageCount: 5,
        ),
      );

      final result = await summarizer.summarizeIfNeeded(
        _testSessionId,
        hideMessages: false,
      );
      expect(result, isTrue);

      // Summary should still be inserted
      expect(mockDao.insertedCompanions, hasLength(1));
      // But no messages should have been hidden
      expect(mockDao.updatedCompanions, isEmpty);
    });

    test('forceSummarize skips hiding when hideMessages is false', () async {
      mockDao.storedMessages = _makeMessages(12);
      mockLlm.summaryToReturn = 'debug summary';

      final summarizer = ConversationSummarizer(
        messageDao: mockDao,
        llmStream: mockLlm.call,
        config: const ConversationSummarizerConfig(
          recentMessageCount: 5,
        ),
      );

      final result = await summarizer.forceSummarize(
        _testSessionId,
        hideMessages: false,
      );
      expect(result, isTrue);
      expect(mockDao.insertedCompanions, hasLength(1));
      expect(mockDao.updatedCompanions, isEmpty);
    });
  });

  group('ConversationSummarizer - progress message', () {
    test('inserts and deletes a progress message during summarization',
        () async {
      mockDao.storedMessages = _makeMessages(20);
      mockLlm.summaryToReturn = 'progress test';

      final summarizer = ConversationSummarizer(
        messageDao: mockDao,
        llmStream: mockLlm.call,
        config: const ConversationSummarizerConfig(
          messageCountThreshold: 15,
          recentMessageCount: 5,
        ),
      );

      await summarizer.summarizeIfNeeded(_testSessionId);

      // Progress message should have been deleted after completion
      expect(mockDao.deletedIds, hasLength(1));
      expect(mockDao.deletedIds.first, startsWith('progress-'));
    });

    test('deletes progress message even when LLM errors', () async {
      mockDao.storedMessages = _makeMessages(20);
      mockLlm.shouldError = true;
      mockLlm.errorMessage = 'boom';

      final summarizer = ConversationSummarizer(
        messageDao: mockDao,
        llmStream: mockLlm.call,
        config: const ConversationSummarizerConfig(
          messageCountThreshold: 15,
          recentMessageCount: 5,
        ),
      );

      expect(
        () => summarizer.summarizeIfNeeded(_testSessionId),
        throwsA(isA<Exception>()),
      );

      // Give the finally block a chance to run
      await Future<void>.delayed(Duration.zero);
      expect(mockDao.deletedIds, hasLength(1));
    });
  });
}
