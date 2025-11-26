import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:agent_core/agent_core.dart';
import 'package:decamp/components/rich_message_content.dart';
import 'package:decamp/utils/search_utils.dart';

/// Simple chat message list widget
/// Displays messages from database with streaming support and search highlighting
class ChatList extends StatefulWidget {
  final List<MessageEntity> messages;
  final bool isLoading;
  final String? streamingMessageId;
  final String streamingText;
  final Function(String messageId, String newContent)? onEditMessage;
  final Function(String messageId)? onResendMessage;
  final Function(String messageId)? onBranchSession;
  final List<SearchMatch>? searchMatches;
  final int? currentMatchIndex; // Index of currently active match
  final double
  searchNavigatorHeight; // Height of search navigator overlay for bottom padding

  const ChatList({
    super.key,
    required this.messages,
    this.isLoading = false,
    this.streamingMessageId,
    this.streamingText = '',
    this.onEditMessage,
    this.onResendMessage,
    this.onBranchSession,
    this.searchMatches,
    this.currentMatchIndex,
    this.searchNavigatorHeight = 0,
  });

  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _messageKeys = {};
  bool _isScrollingToMatch = false; // Flag to prevent scroll conflicts
  final Map<String, int> _scrollRetryCount = {}; // Track retries per message
  Map<String, List<HighlightRange>> _highlightsByMessage =
      {}; // O(1) lookup cache

  @override
  void initState() {
    super.initState();
    _updateMessageKeys();
    _updateHighlightsCache();
  }

  @override
  void didUpdateWidget(ChatList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update message keys when message list changes
    if (widget.messages != oldWidget.messages) {
      _updateMessageKeys();
    }

    // Update highlights cache when search matches or current index changes
    if (widget.searchMatches != oldWidget.searchMatches ||
        widget.currentMatchIndex != oldWidget.currentMatchIndex) {
      _updateHighlightsCache();
    }

    // Scroll when messages change or streaming updates (but not during match navigation)
    if (!_isScrollingToMatch &&
        (widget.messages.length != oldWidget.messages.length ||
            widget.streamingText != oldWidget.streamingText)) {
      WidgetsBinding.instance.endOfFrame.then((_) {
        if (mounted && !_isScrollingToMatch) _scrollToBottom();
      });
    }

    // Scroll to current match when it changes
    if (widget.currentMatchIndex != null &&
        widget.currentMatchIndex != oldWidget.currentMatchIndex &&
        widget.searchMatches != null &&
        widget.currentMatchIndex! < widget.searchMatches!.length) {
      final currentMatch = widget.searchMatches![widget.currentMatchIndex!];

      // Clear retry counts when switching to a new match
      _scrollRetryCount.clear();

      setState(() {
        _isScrollingToMatch = true;
      });

      // Use multiple frame callbacks to ensure layout is stable
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) {
          setState(() {
            _isScrollingToMatch = false;
          });
          return;
        }
        // Add another frame delay to ensure rendering is complete
        await Future.delayed(const Duration(milliseconds: 50));
        if (mounted) {
          await _scrollToMatch(currentMatch.messageId);
          // Reset flag after scroll completes
          if (mounted) {
            setState(() {
              _isScrollingToMatch = false;
            });
          }
        }
      });
    }
  }

  /// Update message keys to stay in sync with current messages
  void _updateMessageKeys() {
    final currentMessageIds = widget.messages.map((m) => m.id).toSet();

    // Remove keys for messages that no longer exist
    _messageKeys.removeWhere(
      (messageId, _) => !currentMessageIds.contains(messageId),
    );

    // Add keys for new messages
    for (final message in widget.messages) {
      _messageKeys.putIfAbsent(
        message.id,
        () => GlobalKey(debugLabel: 'message_${message.id}'),
      );
    }
  }

  /// Pre-process search matches into a map for O(1) lookup performance
  /// This avoids iterating through all matches for every message in the list
  void _updateHighlightsCache() {
    _highlightsByMessage.clear();

    if (widget.searchMatches == null || widget.searchMatches!.isEmpty) {
      return;
    }

    // Group matches by message ID
    for (int i = 0; i < widget.searchMatches!.length; i++) {
      final match = widget.searchMatches![i];
      final highlight = HighlightRange(
        offset: match.matchOffset,
        length: match.matchLength,
        isActive: i == widget.currentMatchIndex,
        matchIndex: i,
      );

      _highlightsByMessage
          .putIfAbsent(match.messageId, () => [])
          .add(highlight);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;

    // In a reversed list, position 0 is the bottom
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _scrollToMatch(String messageId) async {
    final key = _messageKeys[messageId];
    if (key == null) {
      debugPrint('⚠️ No key found for message: $messageId');
      return;
    }

    final context = key.currentContext;
    if (context == null) {
      // Check retry count to prevent infinite loops
      final retryCount = _scrollRetryCount[messageId] ?? 0;
      if (retryCount >= 3) {
        debugPrint('⚠️ Max retries reached for message: $messageId');
        _scrollRetryCount.remove(messageId);
        return;
      }

      debugPrint('⚠️ No context for message: $messageId (retry $retryCount)');
      // Item not yet rendered - use scrollToIndex-like approach
      final messageIndex = widget.messages.indexWhere((m) => m.id == messageId);
      if (messageIndex != -1 && _scrollController.hasClients) {
        final position = _scrollController.position;

        // In a reversed list, index 0 is at the bottom (maxScrollExtent)
        // So we need to reverse the index calculation
        final reversedIndex = widget.messages.length - 1 - messageIndex;
        final ratio = reversedIndex / (widget.messages.length - 1);

        // Calculate estimated offset (0 = bottom, maxScrollExtent = top for reversed list)
        final estimatedOffset = position.maxScrollExtent * ratio;

        debugPrint(
          '📍 Message index: $messageIndex, reversed: $reversedIndex, ratio: $ratio',
        );
        debugPrint(
          '📍 Scrolling to estimated position: $estimatedOffset (max: ${position.maxScrollExtent})',
        );

        _scrollRetryCount[messageId] = retryCount + 1;

        await _scrollController.animateTo(
          estimatedOffset,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );

        // Retry after scroll completes and item is rendered
        await Future.delayed(const Duration(milliseconds: 150));
        if (mounted) {
          await _scrollToMatch(messageId);
        }
      }
      return;
    }

    // Reset retry count on successful context found
    _scrollRetryCount.remove(messageId);

    if (!_scrollController.hasClients) {
      debugPrint('⚠️ Scroll controller has no clients');
      return;
    }

    try {
      debugPrint('📍 Scrolling to message: $messageId');

      // Get the RenderObject to calculate position
      final renderObject = context.findRenderObject();
      if (renderObject == null || renderObject is! RenderBox) {
        debugPrint('⚠️ No valid RenderObject');
        return;
      }

      // Get the scroll position and viewport
      final scrollPosition = _scrollController.position;
      final viewport = RenderAbstractViewport.of(renderObject);

      // For reversed lists, getOffsetToReveal with alignment 0.0 gives us the offset
      // needed to put the item at the TOP of the viewport
      final revealTop = viewport.getOffsetToReveal(renderObject, 0.0);

      // And alignment 1.0 gives us the offset for BOTTOM of viewport
      final revealBottom = viewport.getOffsetToReveal(renderObject, 1.0);

      debugPrint('📊 Current offset: ${scrollPosition.pixels}');
      debugPrint('📊 Reveal at top (0.0): ${revealTop.offset}');
      debugPrint('📊 Reveal at bottom (1.0): ${revealBottom.offset}');

      // We want to position at 30% from top, so interpolate
      final targetOffset =
          revealTop.offset + (revealBottom.offset - revealTop.offset) * 0.3;

      debugPrint('📊 Target offset (30% from top): $targetOffset');
      debugPrint(
        '📊 Min: ${scrollPosition.minScrollExtent}, Max: ${scrollPosition.maxScrollExtent}',
      );

      // Clamp and animate
      final clampedTarget = targetOffset.clamp(
        scrollPosition.minScrollExtent,
        scrollPosition.maxScrollExtent,
      );

      debugPrint('📊 Clamped target: $clampedTarget');

      await _scrollController.animateTo(
        clampedTarget,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } catch (e, stack) {
      debugPrint('⚠️ Exception during scroll: $e');
      debugPrint('Stack: $stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reverse the list so newest messages are at index 0
    final reversedMessages = widget.messages.reversed.toList();

    return ListView.builder(
      controller: _scrollController,
      // Reverse the ListView so it naturally starts at the bottom
      reverse: true,
      padding: widget.searchNavigatorHeight > 0
          ? EdgeInsets.only(bottom: widget.searchNavigatorHeight)
          : EdgeInsets.zero,
      itemCount: reversedMessages.length + (widget.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (widget.isLoading && index == 0) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // Get message (adjust index if loading indicator is shown)
        final messageIndex = widget.isLoading ? index - 1 : index;
        final message = reversedMessages[messageIndex];

        // Check if this message is currently streaming
        final isStreaming = message.id == widget.streamingMessageId;
        // Only provide displayText when actually streaming
        final displayText = isStreaming ? widget.streamingText : null;
        final isUser = message.userId == 'user';

        return Column(
          key: _messageKeys[message.id],
          children: [
            if (messageIndex > 0)
              Divider(
                height: 8,
                thickness: 0.5,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.0),
              child: Align(
                alignment: isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: RichMessageContent(
                    message: message,
                    displayText: displayText,
                    isUser: isUser,
                    onEdit: widget.onEditMessage,
                    onResend: widget.onResendMessage,
                    onBranch: widget.onBranchSession,
                    highlights: _highlightsByMessage[message.id],
                    currentMatchIndex: widget.currentMatchIndex,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
