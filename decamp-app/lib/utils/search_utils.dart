import 'package:decamp/database/database.dart';
import 'package:decamp/utils/message_formatter.dart';

/// Highlight range for search matches
class HighlightRange {
  final int offset;
  final int length;
  final bool isActive;

  const HighlightRange({
    required this.offset,
    required this.length,
    this.isActive = false,
  });
}

/// Type of content where match was found
enum MatchType { messageContent, toolCall, toolResult }

/// Represents a single search match within a message
class SearchMatch {
  /// ID of the message containing this match
  final String messageId;

  /// Index of this match among all matches (0-based)
  final int matchIndex;

  /// Character offset within the searchable content
  final int matchOffset;

  /// Length of the matched text
  final int matchLength;

  /// Snippet of surrounding text for context
  final String matchContext;

  /// Type of content where match was found
  final MatchType matchType;

  const SearchMatch({
    required this.messageId,
    required this.matchIndex,
    required this.matchOffset,
    required this.matchLength,
    required this.matchContext,
    required this.matchType,
  });
}

/// Utility functions for searching through messages
class SearchUtils {
  /// Find all matches for a query in a list of messages
  /// Supports regex patterns and searches only visible message content
  static List<SearchMatch> findMatches(
    String query,
    List<MessageEntity> messages,
  ) {
    if (query.isEmpty) return [];

    final matches = <SearchMatch>[];

    // Try to compile as regex, fall back to literal string search
    RegExp? regex;

    try {
      regex = RegExp(query, caseSensitive: false);
    } catch (e) {
      // If regex compilation fails, escape special chars and use as literal
      regex = RegExp(RegExp.escape(query), caseSensitive: false);
    }

    for (final message in messages) {
      // Search in formatted message content (same as what's displayed)
      final formattedContent = MessageFormatter.formatMessageContent(message);
      _findMatchesInText(
        text: formattedContent,
        regex: regex,
        messageId: message.id,
        matchType: MatchType.messageContent,
        matches: matches,
      );
    }

    return matches;
  }

  /// Find matches in a specific text using regex
  static void _findMatchesInText({
    required String text,
    required RegExp regex,
    required String messageId,
    required MatchType matchType,
    required List<SearchMatch> matches,
  }) {
    final allMatches = regex.allMatches(text);

    for (final match in allMatches) {
      final matchOffset = match.start;
      final matchLength = match.end - match.start;
      final matchContext = _extractContext(text, matchOffset, matchLength);

      matches.add(
        SearchMatch(
          messageId: messageId,
          matchIndex: matches.length,
          matchOffset: matchOffset,
          matchLength: matchLength,
          matchContext: matchContext,
          matchType: matchType,
        ),
      );
    }
  }

  /// Extract context around a match (50 chars before and after)
  static String _extractContext(String text, int offset, int length) {
    const contextLength = 50;
    final start = (offset - contextLength).clamp(0, text.length);
    final end = (offset + length + contextLength).clamp(0, text.length);

    String context = text.substring(start, end);

    // Add ellipsis if we didn't capture the full text
    if (start > 0) context = '...$context';
    if (end < text.length) context = '$context...';

    return context;
  }
}
