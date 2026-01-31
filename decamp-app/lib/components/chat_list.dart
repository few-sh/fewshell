import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:decamp/components/rich_message_content.dart';
import 'package:decamp/utils/search_utils.dart';
import 'package:decamp/providers/providers.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Simple chat message list widget
/// Displays messages from database with streaming support and search highlighting
class ChatList extends StatefulWidget {
  final List<MessageEntity> messages;
  final bool isLoading;
  final Stream<MessageEntity?>? streamingMessageStream;
  final List<SearchMatch>? searchMatches;
  final int? currentMatchIndex; // Index of currently active match
  final double
  searchNavigatorHeight; // Height of search navigator overlay for bottom padding
  final List<MessageSubscriberEntity>?
  messageSubscribers; // Message subscriptions for rebuilding

  const ChatList({
    super.key,
    required this.messages,
    this.isLoading = false,
    this.streamingMessageStream,
    this.searchMatches,
    this.currentMatchIndex,
    this.searchNavigatorHeight = 0,
    this.messageSubscribers,
  });

  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _messageKeys = {};
  bool _isScrollingToMatch = false; // Flag to prevent scroll conflicts
  final Map<String, int> _scrollRetryCount = {}; // Track retries per message
  final Map<String, List<HighlightRange>> _highlightsByMessage =
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

    // Update highlights cache when search matches or current index changes
    if (widget.searchMatches != oldWidget.searchMatches ||
        widget.currentMatchIndex != oldWidget.currentMatchIndex) {
      _updateHighlightsCache();
      // Also update keys since they depend on search matches now
      _updateMessageKeys();
    } else if (widget.messages != oldWidget.messages) {
      // Update message keys when message list changes (to clean up old keys)
      _updateMessageKeys();
    }

    // Scroll when messages change or streaming updates (but not during match navigation)
    if (!_isScrollingToMatch &&
        (widget.messages.length != oldWidget.messages.length)) {
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
  /// Optimization: Only maintain GlobalKeys for messages that are search matches
  void _updateMessageKeys() {
    // If no search matches, clear all keys to free memory
    if (widget.searchMatches == null || widget.searchMatches!.isEmpty) {
      _messageKeys.clear();
      return;
    }

    // Identify which messages need GlobalKeys (only those with search matches)
    final messagesWithMatches = widget.searchMatches!
        .map((m) => m.messageId)
        .toSet();

    // Remove keys for messages that no longer need them
    _messageKeys.removeWhere(
      (messageId, _) => !messagesWithMatches.contains(messageId),
    );

    // Add keys for new matches
    for (final messageId in messagesWithMatches) {
      _messageKeys.putIfAbsent(
        messageId,
        () => GlobalKey(debugLabel: 'message_$messageId'),
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
    // TODO: When we copy the content, it should be a nicely formatted Markdown (if possible)
    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      reverse: true,
      cacheExtent: 1000, // Pre-render area to smooth out scrolling
      slivers: [
        // Padding for search navigator
        if (widget.searchNavigatorHeight > 0)
          SliverPadding(
            padding: EdgeInsets.only(bottom: widget.searchNavigatorHeight),
          ),

        // Streaming Message (if any)
        if (widget.streamingMessageStream != null)
          SliverToBoxAdapter(
            child: SelectionContainer.disabled(
              child: StreamBuilder<MessageEntity?>(
                stream: widget.streamingMessageStream,
                builder: (context, snapshot) {
                  final message = snapshot.data;
                  if (message != null) {
                    return _MessageItem(
                      key: _messageKeys[message.id],
                      message: message,
                      isStreaming: true,
                      showDivider: false,
                      highlights: _highlightsByMessage[message.id],
                      currentMatchIndex: widget.currentMatchIndex,
                      messageSubscribers: widget.messageSubscribers,
                    );
                  } else if (widget.isLoading) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: ShadTheme.of(context).colorScheme.primary,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),

        // Loading Indicator (if loading and no stream provided)
        if (widget.isLoading && widget.streamingMessageStream == null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(
                  color: ShadTheme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),

        // Completed Messages
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            // Calculate index for reversed list without creating a new list
            // widget.messages is [oldest, ..., newest]
            // We want index 0 to be newest (last element)
            final messageIndex = widget.messages.length - 1 - index;
            final message = widget.messages[messageIndex];

            // Show divider if this is not the first item in the list (index 0)
            return _MessageItem(
              // Use GlobalKey if available (for search scrolling), otherwise ValueKey (for diffing)
              key: _messageKeys[message.id] ?? ValueKey(message.id),
              message: message,
              isStreaming: false,
              showDivider: index > 0,
              highlights: _highlightsByMessage[message.id],
              currentMatchIndex: widget.currentMatchIndex,
              messageSubscribers: widget.messageSubscribers,
            );
          }, childCount: widget.messages.length),
        ),
      ],
    );
  }
}

class _MessageItem extends ConsumerWidget {
  final MessageEntity message;
  final bool isStreaming;
  final bool showDivider;
  final List<HighlightRange>? highlights;
  final int? currentMatchIndex;
  final List<MessageSubscriberEntity>? messageSubscribers;

  const _MessageItem({
    super.key,
    required this.message,
    required this.isStreaming,
    this.showDivider = true,
    this.highlights,
    this.currentMatchIndex,
    this.messageSubscribers,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.userId == 'user';

    // Check if this message is subscribed
    final isSubscribed =
        messageSubscribers?.any(
          (subscriber) => subscriber.messageId == message.id,
        ) ??
        false;

    // Handle subscription toggle
    Future<void> handleSubscribeToggle() async {
      final projectDb = ref.read(projectDatabaseProvider);
      if (projectDb == null) return;

      final currentProject = ref.read(currentProjectProvider);
      if (currentProject == null) return;

      final notificationService = ref.read(notificationServiceProvider);

      try {
        if (isSubscribed) {
          // Unsubscribe
          await notificationService.unsubscribeFromMessage(
            messageId: message.id,
            projectDb: projectDb,
          );
        } else {
          // Subscribe
          await notificationService.subscribeToMessage(
            messageId: message.id,
            sessionId: message.sessionId,
            projectId: currentProject.id,
            projectDb: projectDb,
          );
          ShadToaster.maybeOf(context)?.show(
            ShadToast(
              title: const Text('Subscribed'),
              description: const Text(
                'You will receive a notification when this finishes running.',
              ),
              showCloseIconOnlyWhenHovered: false,
            ),
          );
        }
      } catch (e) {
        // Handle error (could show a snackbar to the user)
        if (!context.mounted) {
          return;
        }
        ShadToaster.maybeOf(context)?.show(
          ShadToast.destructive(
            title: const Text('Subscription Failed'),
            description: Text(e.toString()),
          ),
        );
      }
    }

    return Column(
      children: [
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ShadSeparator.horizontal(
              color: ShadTheme.of(context).colorScheme.border,
              thickness: 0.5,
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.0),
          child: Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: RichMessageContent(
                // Force rebuild for streaming messages to ensure updates are shown
                // This handles cases where the message object instance might be reused
                // or when deep updates aren't detected automatically
                key: isStreaming
                    ? ValueKey('streaming_${message.content.length}')
                    : null,
                message: message,
                messageStream: null, // Handled by StreamBuilder
                isUser: isUser,
                highlights: highlights,
                currentMatchIndex: currentMatchIndex,
                isSubscribed: isSubscribed,
                onSubscribeToggle: isStreaming ? handleSubscribeToggle : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
