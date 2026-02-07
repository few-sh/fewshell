import 'package:logging/logging.dart';

import '../database/database.dart';
import '../database/daos/message_dao.dart';
import '../database/tables/messages_table.dart';
import 'llm_service.dart';

final _log = Logger('ConversationSummarizer');

const _defaultSummarizationPrompt =
    'You are a conversation summarizer. Condense the following conversation '
    'into a concise summary that preserves all important context, decisions, '
    'findings, and action items. The summary will replace the original messages '
    'in the context window, so it must retain enough detail for the assistant '
    'to continue the conversation without losing track of what happened.';

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

  const ConversationSummarizerConfig({
    this.messageCountThreshold = 40,
    this.tokenThreshold = 80000,
    this.bytesPerToken = 4,
    this.recentMessageCount = 10,
    this.summarizationPrompt = _defaultSummarizationPrompt,
  });
}

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
  final LlmService _llmService;
  final ConversationSummarizerConfig config;

  ConversationSummarizer({
    required MessageDao messageDao,
    required LlmService llmService,
    this.config = const ConversationSummarizerConfig(),
  })  : _messageDao = messageDao,
        _llmService = llmService;

  /// Run summarization for [sessionId] if needed.
  ///
  /// Returns `true` if summarization was performed, `false` if skipped.
  Future<bool> summarizeIfNeeded(String sessionId) async {
    final messages = await _messageDao.getMessagesBySession(sessionId);

    final visible =
        messages.where((m) => m.isVisibleToLlm && !m.isStreaming).toList();

    if (!_shouldSummarize(visible)) {
      return false;
    }

    // Messages to summarize: everything except the most recent tail
    final toSummarize =
        visible.sublist(0, visible.length - config.recentMessageCount);

    if (toSummarize.isEmpty) {
      return false;
    }

    _log.info(
      'Summarizing ${toSummarize.length} messages in session $sessionId',
    );

    final summary = await _generateSummary(toSummarize);

    // Insert a summary message just before the kept tail
    await _insertSummaryMessage(
      sessionId: sessionId,
      summary: summary,
      // Place it just before the first kept message
      timestamp: toSummarize.last.createdAt,
    );

    // Hide the original messages from the LLM
    await _hideMessages(toSummarize);

    _log.info('Summarization complete for session $sessionId');
    return true;
  }

  /// Call the LLM to produce a summary of the given messages.
  Future<String> _generateSummary(List<MessageEntity> messages) async {
    // TODO: Build a prompt from messages and call _llmService
    // For now, return a placeholder.
    throw UnimplementedError('_generateSummary not yet implemented');
  }

  /// Insert a [MessageKind.conversationSummary] message into the database.
  Future<void> _insertSummaryMessage({
    required String sessionId,
    required String summary,
    required DateTime timestamp,
  }) async {
    // TODO: insert via _messageDao
    throw UnimplementedError('_insertSummaryMessage not yet implemented');
  }

  /// Set `isVisibleToLlm = false` on each summarized message.
  Future<void> _hideMessages(List<MessageEntity> messages) async {
    // TODO: batch update via _messageDao
    throw UnimplementedError('_hideMessages not yet implemented');
  }

  /// Check whether summarization should be triggered.
  ///
  /// Returns `true` if either the message count or estimated token count
  /// exceeds the configured thresholds, and there are enough messages
  /// to leave a tail of [ConversationSummarizerConfig.recentMessageCount].
  bool _shouldSummarize(List<MessageEntity> visible) {
    if (visible.length <= config.recentMessageCount) return false;

    final overMessageLimit = visible.length >= config.messageCountThreshold;
    final estimatedTokens = _estimateTokens(visible);
    final overTokenLimit = estimatedTokens >= config.tokenThreshold;

    return overMessageLimit || overTokenLimit;
  }

  /// Rough token estimate: sum of content byte lengths / bytesPerToken.
  int _estimateTokens(List<MessageEntity> messages) {
    var totalBytes = 0;
    for (final m in messages) {
      totalBytes += m.content.length;
    }
    return totalBytes ~/ config.bytesPerToken;
  }
}
