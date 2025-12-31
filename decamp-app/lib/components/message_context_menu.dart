import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:decamp/providers/chat_controller_provider.dart';
import 'package:decamp/services/sync_service.dart';
import 'package:decamp/components/multi_command_approval_overlay.dart';
import 'package:decamp/components/new_snippet_card.dart';
import 'package:decamp/components/saved_prompt_dialog.dart';
import 'package:decamp/providers/session_provider.dart';
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

    await controller.resendMessage(
      messageId: widget.message.id,
      sessionId: widget.message.sessionId,
      requestApproval: (actions) {
        final overlayContext = navigatorKey.currentContext;
        if (overlayContext == null) return Future.value(null);
        return MultiCommandApprovalOverlay.show(overlayContext, actions);
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
    final isToolCall = widget.message.messageKind == MessageKind.toolUse;
    final List<SnippetDraft> shellCommands = [];

    if (isToolCall && widget.message.toolCallsJson != null) {
      for (final toolCall in widget.message.toolCallsJson!) {
        if (toolCall.function.name == 'execute_shell_command') {
          try {
            final args =
                jsonDecode(toolCall.function.arguments) as Map<String, dynamic>;
            if (args.containsKey('command')) {
              shellCommands.add(SnippetDraft(
                content: args['command'] as String,
                description: args['explanation'] as String? ?? 'Shell Command',
              ));
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
            child: const Text('Add to Saved Prompts'),
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
            Clipboard.setData(ClipboardData(text: widget.message.content));
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
            child: Text(shellCommands.length > 1
                ? 'Add ${shellCommands.length} Snippets'
                : 'Add to Snippets'),
            onPressed: () async {
              await showNewSnippetDialog(
                context,
                drafts: shellCommands,
                isGlobal: null,
              );
            },
          ),
        if (isUser)
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
