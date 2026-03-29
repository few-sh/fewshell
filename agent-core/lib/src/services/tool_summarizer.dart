import 'dart:math';

import 'package:drift/drift.dart';
import 'package:llm_dart/llm_dart.dart';
import 'package:logging/logging.dart';

import '../database/database.dart';
import '../database/daos/message_dao.dart';
import '../database/tables/messages_table.dart';
import 'conversation_summarizer.dart' show SummarizationStreamFunction;

final _log = Logger('ToolSummarizer');

const _defaultToolSummarizationPrompt =
    'Summarize the following tool interaction concisely. Include:\n'
    '- What tool was called and with what arguments\n'
    '- The key results or output\n'
    '- Any errors or notable findings\n\n'
    'Be concise and structured. Preserve critical data such as file paths, '
    'numbers, error messages, and identifiers exactly as they appear.';

const _defaultRollingUpdatePrompt =
    'You have a previous summary of a tool interaction and a new chunk of '
    'content from the same interaction. Update and merge the summary to '
    'incorporate the new information.\n\n'
    'Previous summary:\n';

/// Configuration for [ToolSummarizer].
class ToolSummarizerConfig {
  /// Estimated token count above which a tool result message is summarized.
  ///
  /// Token count is approximated as `totalBytes / bytesPerToken`.
  final int tokenThreshold;

  /// Average number of bytes per token used for the token estimate.
  ///
  /// Defaults to 4, which is a reasonable approximation for English text
  /// with most tokenizers.
  final int bytesPerToken;

  /// Maximum estimated token count for the content sent to the LLM
  /// in a single summarization call.
  ///
  /// If the tool content exceeds this, it is split into batches and
  /// summarized via a rolling update strategy.
  final int maximumInputTokens;

  /// System prompt sent to the LLM when generating a tool output summary.
  final String summarizationPrompt;

  /// Prompt prefix used when performing a rolling summary update.
  ///
  /// The previous summary is appended after this prefix, followed by the
  /// new content batch.
  final String rollingUpdatePrompt;

  /// Maximum number of characters to scan for a newline when splitting
  /// content into batches. If no newline is found within this window
  /// before or after the split point, a hard split is performed.
  final int newlineScanWindow;

  const ToolSummarizerConfig({
    this.tokenThreshold = 2000,
    this.bytesPerToken = 4,
    this.maximumInputTokens = 80000,
    this.summarizationPrompt = _defaultToolSummarizationPrompt,
    this.rollingUpdatePrompt = _defaultRollingUpdatePrompt,
    this.newlineScanWindow = 200,
  });
}

/// Summarizes large tool result messages to keep the context window manageable.
///
/// Operates on individual [MessageKind.toolResult] messages. When a message's
/// canonical tool payload ([MessageEntity.toolCallsJson] +
/// [MessageEntity.toolResultsJson]) exceeds the configured
/// [ToolSummarizerConfig.tokenThreshold], the summarizer calls an LLM to
/// produce a concise summary and stores it in the message's `summary` field.
///
/// If the combined content exceeds [ToolSummarizerConfig.maximumInputTokens],
/// the content is split into batches and summarized via rolling updates:
/// batch 1 is summarized first, then each subsequent batch is merged with
/// the running summary.
class ToolSummarizer {
  final MessageDao _messageDao;
  final SummarizationStreamFunction _llmStream;
  final ToolSummarizerConfig config;

  ToolSummarizer({
    required MessageDao messageDao,
    required SummarizationStreamFunction llmStream,
    this.config = const ToolSummarizerConfig(),
  })  : _messageDao = messageDao,
        _llmStream = llmStream;

  /// Summarize a tool result message if its content exceeds the threshold.
  ///
  /// Returns `true` if summarization was performed, `false` if skipped
  /// (already summarized, below threshold, or wrong message kind).
  Future<bool> summarizeIfNeeded(
    MessageEntity message, {
    CancelToken? cancelToken,
  }) async {
    if (message.messageKind != MessageKind.toolResult) return false;
    if (message.summary != null) return false;

    final content = _buildContent(message);
    final estimatedTokens = content.length ~/ config.bytesPerToken;

    if (estimatedTokens < config.tokenThreshold) return false;

    return _summarize(message, content, cancelToken: cancelToken);
  }

  /// Force summarization of a tool result message regardless of threshold.
  ///
  /// Returns `true` if summarization was performed, `false` if the message
  /// is not a tool result.
  Future<bool> forceSummarize(
    MessageEntity message, {
    CancelToken? cancelToken,
  }) async {
    if (message.messageKind != MessageKind.toolResult) return false;

    final content = _buildContent(message);
    return _summarize(message, content, cancelToken: cancelToken);
  }

  /// Core summarization logic.
  Future<bool> _summarize(
    MessageEntity message,
    String content, {
    CancelToken? cancelToken,
  }) async {
    final estimatedTokens = content.length ~/ config.bytesPerToken;

    _log.info(
      'Summarizing tool result ${message.id} '
      '(~$estimatedTokens tokens, ${content.length} bytes)',
    );

    String summary;
    if (estimatedTokens <= config.maximumInputTokens) {
      summary = await _generateSummary(content, cancelToken: cancelToken);
    } else {
      summary = await _generateRollingSummary(
        content,
        cancelToken: cancelToken,
      );
    }

    // Store the summary in the message's summary field.
    final companion = message.toCompanion(true).copyWith(
          summary: Value(summary),
        );
    await _messageDao.updateMessage(companion);

    _log.info(
      'Tool summary for ${message.id}: ${summary.length} chars '
      '(~${summary.length ~/ config.bytesPerToken} tokens)',
    );

    return true;
  }

  /// Build the summarizer input from the canonical tool call/result fields.
  String _buildContent(MessageEntity message) {
    final buffer = StringBuffer();

    if (message.toolCallsJson != null) {
      for (final tc in message.toolCallsJson!) {
        buffer.writeln('[Tool Call] ${tc.function.name}'
            '(${tc.function.arguments})');
      }
    }

    if (message.toolResultsJson != null) {
      for (final tr in message.toolResultsJson!) {
        buffer.writeln('[Tool Result] ${tr.function.name}: '
            '${tr.function.arguments}');
      }
    }

    return buffer.toString();
  }

  /// Single-shot summarization for content that fits within the input budget.
  Future<String> _generateSummary(
    String content, {
    CancelToken? cancelToken,
  }) async {
    final conversation = [
      ChatMessage.user(content),
      ChatMessage.user(config.summarizationPrompt),
    ];

    return _streamToString(conversation, cancelToken: cancelToken);
  }

  /// Rolling summarization for content that exceeds the input budget.
  ///
  /// Splits the content into batches, summarizes the first batch, then
  /// merges each subsequent batch with the running summary.
  Future<String> _generateRollingSummary(
    String content, {
    CancelToken? cancelToken,
  }) async {
    final maxBatchBytes = config.maximumInputTokens * config.bytesPerToken;
    final batches = _splitIntoBatches(content, maxBatchBytes);

    _log.info('Rolling summary: ${batches.length} batches');

    // Summarize the first batch.
    var summary = await _generateSummary(
      batches.first,
      cancelToken: cancelToken,
    );

    // Merge each subsequent batch with the running summary.
    for (var i = 1; i < batches.length; i++) {
      _log.fine('Rolling summary: processing batch ${i + 1}/${batches.length}');

      final conversation = [
        ChatMessage.user(
          '${config.rollingUpdatePrompt}$summary\n\n'
          'New content:\n${batches[i]}',
        ),
        ChatMessage.user(config.summarizationPrompt),
      ];

      summary = await _streamToString(conversation, cancelToken: cancelToken);
    }

    return summary;
  }

  /// Split [content] into chunks of at most [maxBytes], preferring to
  /// break at newline boundaries.
  List<String> _splitIntoBatches(String content, int maxBytes) {
    if (content.length <= maxBytes) return [content];

    final batches = <String>[];
    var offset = 0;

    while (offset < content.length) {
      final remaining = content.length - offset;
      if (remaining <= maxBytes) {
        batches.add(content.substring(offset));
        break;
      }

      // Try to find a newline near the max boundary.
      final splitPoint = _findSplitPoint(content, offset, maxBytes);
      batches.add(content.substring(offset, splitPoint));
      offset = splitPoint;
    }

    return batches;
  }

  /// Find the best split point near [offset + maxBytes] in [content].
  ///
  /// Searches backwards from the ideal split point for a newline within
  /// [ToolSummarizerConfig.newlineScanWindow] characters. Falls back to
  /// a hard split at [offset + maxBytes].
  int _findSplitPoint(String content, int offset, int maxBytes) {
    final ideal = offset + maxBytes;
    final scanStart = max(offset, ideal - config.newlineScanWindow);

    // Scan backwards from the ideal point for a newline.
    for (var i = ideal - 1; i >= scanStart; i--) {
      if (content.codeUnitAt(i) == 0x0A) {
        return i + 1; // split after the newline
      }
    }

    // No newline found in the scan window — hard split.
    return min(ideal, content.length);
  }

  /// Stream an LLM conversation and collect the result into a string.
  Future<String> _streamToString(
    List<ChatMessage> conversation, {
    CancelToken? cancelToken,
  }) async {
    final buffer = StringBuffer();

    await for (final event
        in _llmStream(conversation, cancelToken: cancelToken)) {
      switch (event) {
        case TextDeltaEvent(delta: final delta):
          buffer.write(delta);
        case ErrorEvent(error: final error):
          throw Exception('Tool summarization LLM call failed: '
              '${error.message}');
        default:
          break;
      }
    }

    final result = buffer.toString();
    if (result.isEmpty) {
      throw Exception('LLM returned empty tool summary');
    }

    return result;
  }
}
