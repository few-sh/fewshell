import 'dart:math';

import 'package:drift/drift.dart';
import 'package:llm_dart/llm_dart.dart';
import 'package:logging/logging.dart';

import '../database/database.dart';
import '../database/daos/message_dao.dart';
import '../database/tables/messages_table.dart';
import '../extensions/chat_message_extensions.dart';
import '../utils/id_generator.dart';

final _log = Logger('ConversationSummarizer');

const _defaultSummarizationPrompt =
    'You are performing a CONTEXT CHECKPOINT COMPACTION. Create a handoff '
    'summary for another LLM that will resume the task.\n\n'
    'Include:\n'
    '- Current progress and key decisions made\n'
    '- Important context, constraints, or user preferences\n'
    '- What remains to be done (clear next steps)\n'
    '- List of every tools/commands you used and whether they succeeded/failed\n'
    '- Any critical data, examples, or references needed to continue\n\n'
    'Be concise, structured, and focused on helping the next LLM seamlessly '
    'continue the work.';

const _defaultSummaryPrefix =
    'Another language model started to solve this problem and produced a '
    'summary of its thinking process. You also have access to the state of the '
    'tools that were used by that language model. Use this to build on the work '
    'that has already been done and avoid duplicating work. Here is the summary '
    'produced by the other language model, use the information in this summary '
    'to assist with your own analysis:\n\n';

/// Configuration for [ConversationSummarizer].
class ConversationSummarizerConfig {
  /// Minimum number of LLM-visible messages before summarization is triggered.
  ///
  /// When the count of visible messages in a session reaches this number,
  /// the summarizer will collapse older messages into a summary.
  final int messageCountThreshold;

  /// Estimated token budget above which summarization is triggered.
  ///
  /// Token count is approximated as `totalBytes / bytesPerToken`.
  /// Checked independently of [messageCountThreshold] — either condition
  /// being met will trigger summarization.
  final int tokenThreshold;

  /// Average number of bytes per token used for the token estimate.
  ///
  /// Defaults to 4, which is a reasonable approximation for English text
  /// with most tokenizers (GPT, Claude, etc.).
  final int bytesPerToken;

  /// Number of recent messages to keep unsummarized.
  ///
  /// When summarization fires, the most recent [recentMessageCount] messages
  /// are preserved as-is and only the older messages are collapsed.
  final int recentMessageCount;

  /// System prompt sent to the LLM when generating a conversation summary.
  ///
  /// Should instruct the model to produce a concise summary of the
  /// conversation history suitable for replacing the original messages
  /// in the context window.
  final String summarizationPrompt;

  /// Prefix prepended to the summary when it is injected back into the
  /// conversation as a [MessageKind.conversationSummary] message.
  ///
  /// Frames the summary as a handoff from a previous LLM, helping the
  /// receiving model understand the context.
  final String summaryPrefix;

  /// Maximum estimated token count for the messages sent to the LLM
  /// as input for the summarization call itself.
  ///
  /// Older messages are dropped (oldest first) if the input exceeds this
  /// budget so the summarization request doesn't blow the context window.
  final int summaryInputTokenBudget;

  const ConversationSummarizerConfig({
    this.messageCountThreshold = 40,
    this.tokenThreshold = 80000,
    this.bytesPerToken = 4,
    this.recentMessageCount = 1,
    this.summarizationPrompt = _defaultSummarizationPrompt,
    this.summaryPrefix = _defaultSummaryPrefix,
    this.summaryInputTokenBudget = 100000,
  });
}

/// Function that streams chat events from an LLM given a conversation.
///
/// Simpler than the agent loop's [LlmStreamFunction] — only takes a
/// conversation (no tools or cancel token) since summarization is a
/// single-shot call.
typedef SummarizationStreamFunction = Stream<ChatStreamEvent> Function(
  List<ChatMessage> conversation, {
  CancelToken? cancelToken,
});

/// Callback invoked after summarization completes, e.g. to show a warning
/// to the user about potential accuracy degradation in long threads.
typedef SummarizationCallback = Future<void> Function(String sessionId);

/// Summarizes older conversation messages to keep the context window manageable.
///
/// Invoked at the start of each agent loop iteration. Decides internally
/// whether summarization is needed based on message count and token thresholds.
///
/// When triggered, it:
/// 1. Reads all LLM-visible messages for the session
/// 2. Selects older messages that should be collapsed
/// 3. Calls the LLM to produce a summary
/// 4. Inserts a [MessageKind.conversationSummary] message with the summary
/// 5. Marks the original messages as not visible to the LLM
class ConversationSummarizer {
  final MessageDao _messageDao;
  final SummarizationStreamFunction _llmStream;
  final ConversationSummarizerConfig config;

  /// Optional callback fired after a successful summarization.
  /// Can be used to insert a user-facing warning about accuracy degradation.
  final SummarizationCallback? onSummarized;

  ConversationSummarizer({
    required MessageDao messageDao,
    required SummarizationStreamFunction llmStream,
    this.config = const ConversationSummarizerConfig(),
    this.onSummarized,
  })  : _messageDao = messageDao,
        _llmStream = llmStream;

  /// Run summarization for [sessionId] if thresholds are exceeded.
  ///
  /// Set [hideMessages] to `false` to keep the original messages visible
  /// (useful for debugging).
  ///
  /// Returns `true` if summarization was performed, `false` if skipped.
  Future<bool> summarizeIfNeeded(
    String sessionId, {
    bool hideMessages = true,
    CancelToken? cancelToken,
  }) async {
    final messages = await _messageDao.getMessagesBySession(sessionId);

    final visible =
        messages.where((m) => m.isVisibleToLlm && !m.isStreaming).toList();

    if (!_shouldSummarize(visible)) {
      return false;
    }

    return _summarize(sessionId, visible,
        hideMessages: hideMessages, cancelToken: cancelToken);
  }

  /// Force summarization for [sessionId] regardless of thresholds.
  ///
  /// Set [hideMessages] to `false` to keep the original messages visible
  /// (useful for debugging).
  ///
  /// Returns `true` if summarization was performed, `false` if there were
  /// not enough messages to leave a recent tail.
  Future<bool> forceSummarize(
    String sessionId, {
    bool hideMessages = true,
    CancelToken? cancelToken,
  }) async {
    final messages = await _messageDao.getMessagesBySession(sessionId);

    final visible =
        messages.where((m) => m.isVisibleToLlm && !m.isStreaming).toList();

    return _summarize(sessionId, visible,
        hideMessages: hideMessages, cancelToken: cancelToken);
  }

  /// Shared summarization logic used by both [summarizeIfNeeded] and
  /// [forceSummarize].
  Future<bool> _summarize(
    String sessionId,
    List<MessageEntity> visible, {
    required bool hideMessages,
    CancelToken? cancelToken,
  }) async {
    // Need at least 2 messages: 1 to summarize + 1 to keep as tail
    if (visible.length < 2) {
      return false;
    }

    // Keep up to recentMessageCount, but shrink the tail if there aren't
    // enough messages (e.g. few huge messages exceeding the token limit).
    final tailCount = min(config.recentMessageCount, visible.length - 1);

    // Messages to summarize: everything except the most recent tail
    final toSummarize = visible.sublist(0, visible.length - tailCount);

    if (toSummarize.isEmpty) {
      return false;
    }

    _log.info(
      'Summarizing ${toSummarize.length} messages in session $sessionId',
    );

    // Show a streaming progress message while summarizing
    final progressId = await _messageDao.insertMessageWithId(
      sessionId: sessionId,
      userId: 'system',
      userName: 'System',
      content: 'Summarizing conversation\u2026',
      isStreaming: true,
      isVisibleToLlm: false,
    );

    try {
      final summary =
          await _generateSummary(toSummarize, cancelToken: cancelToken);

      // Insert a summary message just before the kept tail
      await _insertSummaryMessage(
        sessionId: sessionId,
        summary: summary,
        // Place it just before the first kept message
        timestamp: toSummarize.last.createdAt,
      );

      // Hide the original messages from the LLM
      if (hideMessages) {
        await hideMessagesBeforeSummary(sessionId);
      }

      _log.info('Summarization complete for session $sessionId');

      await onSummarized?.call(sessionId);

      return true;
    } finally {
      // Always remove the progress message
      await _messageDao.deleteMessage(progressId);
    }
  }

  /// Build a conversation transcript from message entities and stream it
  /// to the LLM with the summarization prompt to produce a summary.
  Future<String> _generateSummary(
    List<MessageEntity> messages, {
    CancelToken? cancelToken,
  }) async {
    // Build a flat transcript of the messages for the summarizer
    final transcript = StringBuffer();
    for (final m in messages) {
      final role = switch (m.userId) {
        'user' => 'User',
        'ai' || 'assistant' => 'Assistant',
        'system' => 'System',
        _ => m.userName,
      };

      transcript.writeln('[$role]: ${m.content}');

      // A toolResult entity holds both toolCallsJson (the requests) and
      // toolResultsJson (the responses). Interleave each call with its
      // corresponding result so the summarizer sees them paired.
      // A toolUse entity (no results yet) only has toolCallsJson.
      if (m.messageKind == MessageKind.toolResult) {
        if (m.summary != null) {
          // Future tool-result summarization: prefer the pre-computed summary.
          transcript.writeln('  [Tool Result Summary] ${m.summary}');
        } else {
          final calls = m.toolCallsJson ?? [];
          final results = m.toolResultsJson ?? [];
          for (var i = 0; i < calls.length; i++) {
            transcript.writeln(
              '  [Tool Call] ${calls[i].function.name}'
              '(${calls[i].function.arguments})',
            );
            if (i < results.length) {
              transcript.writeln(
                '  [Tool Result] ${results[i].function.name}: '
                '${results[i].function.arguments}',
              );
            }
          }
        }
      } else if (m.messageKind == MessageKind.toolUse &&
          m.toolCallsJson != null) {
        for (final tc in m.toolCallsJson!) {
          transcript.writeln(
            '  [Tool Call Skipped] ${tc.function.name}(${tc.function.arguments})',
          );
        }
      }
    }

    // Call LLM via streaming (the only interface LlmService exposes).
    // Transcript first, summarization instruction last — matching the Codex
    // pattern so the LLM sees the full context before the task.
    final conversation = [
      ChatMessage.user(transcript.toString()),
      ChatMessage.user(config.summarizationPrompt),
    ];

    final buffer = StringBuffer();
    await for (final event
        in _llmStream(conversation, cancelToken: cancelToken)) {
      switch (event) {
        case TextDeltaEvent(delta: final delta):
          buffer.write(delta);
        case ErrorEvent(error: final error):
          throw Exception('Summarization LLM call failed: ${error.message}');
        default:
          break;
      }
    }

    final summary = buffer.toString();
    if (summary.isEmpty) {
      throw Exception('LLM returned empty summary');
    }

    _log.info(
      'Generated summary: ${summary.length} chars '
      '(~${summary.length ~/ config.bytesPerToken} tokens)',
    );

    return summary;
  }

  /// Insert a [MessageKind.conversationSummary] message into the database.
  ///
  /// The summary text is stored in the [MessageEntity.summary] field.
  /// The [MessageEntity.content] field contains the prefixed summary that
  /// will be seen by the LLM when the conversation is rebuilt.
  Future<void> _insertSummaryMessage({
    required String sessionId,
    required String summary,
    required DateTime timestamp,
  }) async {
    final prefixedContent = '${config.summaryPrefix}$summary';

    final companion = MessageEntityCompanion(
      id: Value(IdGenerator.messageId()),
      sessionId: Value(sessionId),
      userId: const Value('system'),
      userName: const Value('System'),
      content: Value(prefixedContent),
      summary: Value(summary),
      timestamp: Value(timestamp),
      createdAt: Value(timestamp),
      messageKind: const Value(MessageKind.conversationSummary),
      isVisibleToLlm: const Value(true),
      isStreaming: const Value(false),
    );

    await _messageDao.insertMessage(companion);
  }

  /// Set `isVisibleToLlm = false` on all messages before the last summary.
  ///
  /// Finds the last [MessageKind.conversationSummary] message in the session
  /// and hides every message that precedes it. Idempotent — safe to call
  /// multiple times; already-hidden messages are skipped.
  Future<void> hideMessagesBeforeSummary(String sessionId) async {
    final messages = await _messageDao.getMessagesBySession(sessionId);

    // Find the last summary message
    final lastSummaryIndex = messages.lastIndexWhere(
      (m) => m.messageKind == MessageKind.conversationSummary,
    );

    if (lastSummaryIndex < 0) return;

    for (var i = 0; i < lastSummaryIndex; i++) {
      final m = messages[i];
      if (!m.isVisibleToLlm) continue; // already hidden

      final companion = m.toCompanion(true).copyWith(
            isVisibleToLlm: const Value(false),
          );
      await _messageDao.updateMessage(companion);
    }
  }

  /// Check whether summarization should be triggered.
  ///
  /// Returns `true` if either the message count or estimated token count
  /// exceeds the configured thresholds, and there are enough messages
  /// to leave a tail of [ConversationSummarizerConfig.recentMessageCount].
  bool _shouldSummarize(List<MessageEntity> visible) {
    if (visible.length < 2) return false;

    final overMessageLimit = visible.length >= config.messageCountThreshold;
    final estimatedTokens = _estimateTokens(visible);
    final overTokenLimit = estimatedTokens >= config.tokenThreshold;

    return overMessageLimit || overTokenLimit;
  }

  /// Rough token estimate based on the serialized form of ChatMessages.
  ///
  /// Uses [MessageEntity.toChatMessage] to mirror what the LLM actually sees,
  /// then sums content + serialized tool call lengths.
  int _estimateTokens(List<MessageEntity> messages) {
    var totalBytes = 0;
    for (final m in messages) {
      for (final chatMsg in m.toChatMessage()) {
        totalBytes += chatMsg.content.length;
        switch (chatMsg.messageType) {
          case ToolUseMessage(:final toolCalls):
            for (final tc in toolCalls) {
              totalBytes += tc.toString().length;
            }
          case ToolResultMessage(:final results):
            for (final tr in results) {
              totalBytes += tr.toString().length;
            }
          default:
            break;
        }
      }
    }
    return totalBytes ~/ config.bytesPerToken;
  }
}
