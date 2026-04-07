import 'dart:convert';
import 'package:decamp/providers/providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';

import 'package:decamp/services/sync_service.dart';
import 'package:decamp/components/multi_command_approval_overlay.dart';
import 'package:decamp/components/full_screen_raw_message_view.dart';
import 'package:decamp/components/new_snippet_card.dart';
import 'package:decamp/components/saved_prompt_dialog.dart';

import 'package:decamp/utils/globals.dart';
import 'package:logging/logging.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Context menu for message actions
/// Shows Copy, Edit, Re-send, and Branch Session options
class MessageContextMenu extends ConsumerStatefulWidget {
  final MessageEntity message;
  final VoidCallback onEdit;

  const MessageContextMenu({
    super.key,
    required this.message,
    required this.onEdit,
  });

  @override
  ConsumerState<MessageContextMenu> createState() => _MessageContextMenuState();
}

class _MessageContextMenuState extends ConsumerState<MessageContextMenu> {
  static final _log = Logger('MessageContextMenu');
  final _popoverController = ShadPopoverController();

  @override
  void dispose() {
    _popoverController.dispose();
    super.dispose();
  }

  Future<void> _handleResend() async {
    _log.info('🔄 Resending message: ${widget.message.id}');

    final controller = ref.read(
      chatControllerProvider(widget.message.sessionId).notifier,
    );

    // Get sync channel
    final syncChannel = ref.read(syncServiceProvider).projectChannel;
    final activeSessionId = ref.read(currentSessionIdProvider);

    await controller.resendMessage(
      messageId: widget.message.id,
      sessionId: widget.message.sessionId,
      requestApproval: (pendingCalls) {
        final overlayContext = navigatorKey.currentContext;
        if (overlayContext == null) return Future.value(null);

        // Check if we're still on the same session before showing approval UI.
        // If the user switched sessions while this approval was pending,
        // return null to signal we're not responding (not a cancellation).
        // Returning null prevents sending any approval_response to the server.
        if (activeSessionId != widget.message.sessionId) {
          _log.info(
            'Approval request for wrong session: was for ${widget.message.sessionId} but active is $activeSessionId. Not responding.',
          );
          return Future.value(null);
        }

        return MultiCommandApprovalOverlay.show(
          overlayContext,
          pendingCalls,
          sessionId: widget.message.sessionId,
          channel: syncChannel,
        );
      },
      syncChannel: syncChannel,
    );
  }

  Future<void> _handleBranch() async {
    _log.info('🌿 Branching session at message: ${widget.message.id}');

    final controller = ref.read(
      chatControllerProvider(widget.message.sessionId).notifier,
    );

    final newSessionId = await controller.branchSession(
      messageId: widget.message.id,
      sessionId: widget.message.sessionId,
    );

    // Switch to the new session
    ref.read(currentSessionIdProvider.notifier).select(newSessionId);

    _log.info('✅ Switched to new session: $newSessionId');
  }

  Future<void> _handleDelete() async {
    // Confirm deletion
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog.alert(
        title: const Text('Delete Message'),
        description: const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Are you sure you want to delete this message? This action cannot be undone.',
          ),
        ),
        actions: [
          ShadButton.outline(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ShadButton.destructive(
            child: const Text('Delete'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    _log.info('🗑️ Deleting message: ${widget.message.id}');

    final controller = ref.read(
      chatControllerProvider(widget.message.sessionId).notifier,
    );

    await controller.deleteMessage(widget.message.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    final isUser = widget.message.userId == 'user';
    final List<SnippetDraft> shellCommands = [];

    if (widget.message.toolCallsJson != null) {
      for (final toolCall in widget.message.toolCallsJson!) {
        if (toolCall.function.name == 'execute_shell_command') {
          try {
            final args =
                jsonDecode(toolCall.function.arguments) as Map<String, dynamic>;
            final command = args['command'];
            if (command is String) {
              shellCommands.add(
                SnippetDraft(
                  content: command,
                  description:
                      args['explanation'] as String? ?? 'Shell Command',
                ),
              );
            }
          } catch (e) {
            // Ignore parsing errors
          }
        }
      }
    }

    return ShadContextMenu(
      controller: _popoverController,
      items: [
        if (isUser)
          ShadContextMenuItem(
            leading: const Icon(LucideIcons.bookmark),
            child: const Text('Add to Quick Prompts'),
            onPressed: () async {
              await showSavedPromptDialog(
                context,
                initialContent: widget.message.content,
                isGlobal: null,
              );
            },
          ),
        ShadContextMenuItem(
          leading: const Icon(LucideIcons.copy),
          child: const Text('Copy content'),
          onPressed: () {
            final formatted = MessageFormatter.formatMessageContent(
              widget.message,
            );
            Clipboard.setData(ClipboardData(text: formatted));
            ShadToaster.of(context).show(
              const ShadToast(description: Text('Message copied to clipboard')),
            );
          },
        ),
        ShadContextMenuItem(
          leading: const Icon(LucideIcons.pencil),
          onPressed: widget.onEdit,
          child: const Text('Edit'),
        ),
        if (shellCommands.isNotEmpty)
          ShadContextMenuItem(
            leading: const Icon(LucideIcons.code),
            child: Text(
              shellCommands.length > 1
                  ? 'Add ${shellCommands.length} Snippets'
                  : 'Add to Snippets',
            ),
            onPressed: () async {
              await showNewSnippetDialog(
                context,
                drafts: shellCommands,
                isGlobal: null,
              );
            },
          ),
        if (isUser || shellCommands.isNotEmpty)
          ShadContextMenuItem(
            leading: const Icon(LucideIcons.send),
            onPressed: _handleResend,
            child: const Text('Re-send'),
          ),
        ShadContextMenuItem(
          leading: const Icon(LucideIcons.gitBranch),
          onPressed: _handleBranch,
          child: const Text('Branch Session'),
        ),
        if (kDebugMode)
          ShadContextMenuItem(
            leading: const Icon(LucideIcons.braces),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      FullScreenRawMessageView(message: widget.message),
                ),
              );
            },
            child: const Text('View Raw JSON'),
          ),
        ShadContextMenuItem(
          leading: Icon(
            LucideIcons.trash2,
            color: theme.colorScheme.destructive,
          ),
          onPressed: _handleDelete,
          child: Text(
            'Delete',
            style: TextStyle(color: theme.colorScheme.destructive),
          ),
        ),
      ],
      child: ShadButton.ghost(
        width: 24,
        height: 24,
        padding: EdgeInsets.zero,
        decoration: const ShadDecoration(border: ShadBorder.none),
        onPressed: _popoverController.toggle,
        child: Icon(
          LucideIcons.ellipsisVertical,
          size: 16,
          color: theme.colorScheme.mutedForeground,
        ),
      ),
    );
  }
}
