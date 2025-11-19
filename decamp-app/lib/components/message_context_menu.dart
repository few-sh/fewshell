import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Context menu for message actions
/// Shows Copy, Edit, Re-send, and Branch Session options
class MessageContextMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onResend;
  final VoidCallback onBranch;
  final String messageContent;
  final bool showResend;

  const MessageContextMenu({
    super.key,
    required this.onEdit,
    required this.onResend,
    required this.onBranch,
    required this.messageContent,
    this.showResend = true,
  });

  void _showMenu(BuildContext context) async {
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
        if (showResend)
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
      ],
    );

    if (result != null && context.mounted) {
      switch (result) {
        case 'copy':
          Clipboard.setData(ClipboardData(text: messageContent));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message copied to clipboard'),
              duration: Duration(seconds: 1),
            ),
          );
          break;
        case 'edit':
          onEdit();
          break;
        case 'resend':
          onResend();
          break;
        case 'branch':
          onBranch();
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
      onPressed: () => _showMenu(context),
      visualDensity: VisualDensity.compact,
    );
  }
}
