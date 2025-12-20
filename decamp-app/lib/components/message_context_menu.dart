import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:agent_core/src/database/tables/messages_table.dart';
import 'package:decamp/providers/chat_controller_provider.dart';
import 'package:decamp/services/sync_service.dart';
import 'package:decamp/components/multi_command_approval_overlay.dart';
import 'package:decamp/components/new_snippet_card.dart';
import 'package:decamp/providers/session_provider.dart';
import 'package:decamp/utils/globals.dart';
import 'package:logging/logging.dart';

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text(
          'Are you sure you want to delete this message? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
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

  void _showMenu() async {
    final colorScheme = Theme.of(context).colorScheme;
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final isUser = widget.message.userId == 'user';
    final isToolCall = widget.message.messageKind == MessageKind.toolUse;
    bool isShellCommand = false;
    String? shellCommandContent;
    String? shellCommandExplanation;

    if (isToolCall && widget.message.toolCallsJson != null) {
      for (final toolCall in widget.message.toolCallsJson!) {
        if (toolCall.function.name == 'execute_shell_command') {
          isShellCommand = true;
          try {
            final args =
                jsonDecode(toolCall.function.arguments) as Map<String, dynamic>;
            if (args.containsKey('command')) {
              shellCommandContent = args['command'] as String?;
            }
            if (args.containsKey('explanation')) {
              shellCommandExplanation = args['explanation'] as String?;
            }
          } catch (e) {
            // Ignore parsing errors
          }
          break;
        }
      }
    }

    final result = await showMenu<String>(
      context: context,
      position: position,
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy, size: 18, color: colorScheme.onSurface),
              const SizedBox(width: 12),
              const Text('Copy content'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18, color: colorScheme.onSurface),
              const SizedBox(width: 12),
              const Text('Edit'),
            ],
          ),
        ),
        if (isShellCommand)
          PopupMenuItem<String>(
            value: 'add_snippet',
            child: Row(
              children: [
                Icon(Icons.code, size: 18, color: colorScheme.onSurface),
                const SizedBox(width: 12),
                const Text('Add to Snippets'),
              ],
            ),
          ),
        if (isUser)
          PopupMenuItem<String>(
            value: 'resend',
            child: Row(
              children: [
                Icon(Icons.send, size: 18, color: colorScheme.onSurface),
                const SizedBox(width: 12),
                const Text('Re-send'),
              ],
            ),
          ),
        PopupMenuItem<String>(
          value: 'branch',
          child: Row(
            children: [
              Icon(Icons.call_split, size: 18, color: colorScheme.onSurface),
              const SizedBox(width: 12),
              const Text('Branch Session'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 18, color: colorScheme.error),
              const SizedBox(width: 12),
              Text('Delete', style: TextStyle(color: colorScheme.error)),
            ],
          ),
        ),
      ],
    );

    if (result != null && mounted) {
      switch (result) {
        case 'copy':
          Clipboard.setData(ClipboardData(text: widget.message.content));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message copied to clipboard'),
              duration: Duration(seconds: 1),
            ),
          );
          break;
        case 'edit':
          widget.onEdit();
          break;
        case 'add_snippet':
          // FIXME: Support multiple snippets from one messsage (as we have tool calls)
          await showNewSnippetDialog(
            context,
            initialDescription: shellCommandExplanation ?? 'Test Description',
            initialContent: shellCommandContent ?? 'Test Content',
            isGlobal: null,
          );
          break;
        case 'resend':
          await _handleResend();
          break;
        case 'branch':
          await _handleBranch();
          break;
        case 'delete':
          if (mounted) {
            await _handleDelete();
          }
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      icon: Icon(
        Icons.more_vert,
        size: 18,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      tooltip: 'Message options',
      onPressed: _showMenu,
      visualDensity: VisualDensity.compact,
    );
  }
}
