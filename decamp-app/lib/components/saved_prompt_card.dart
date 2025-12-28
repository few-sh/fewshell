import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../providers/saved_prompt_provider.dart';
import '../components/saved_prompt_dialog.dart';
import '../components/confirmation_dialog.dart';

/// Reusable card widget for displaying a saved prompt
class SavedPromptCard extends ConsumerStatefulWidget {
  final SavedPromptEntity prompt;
  final bool isGlobal;
  final VoidCallback? onSend;
  final bool showContextMenu;

  const SavedPromptCard({
    super.key,
    required this.prompt,
    required this.isGlobal,
    this.onSend,
    this.showContextMenu = true,
  });

  @override
  ConsumerState<SavedPromptCard> createState() => _SavedPromptCardState();
}

class _SavedPromptCardState extends ConsumerState<SavedPromptCard> {
  final _menuController = ShadPopoverController();

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  Future<void> _editPrompt() async {
    await showSavedPromptDialog(
      context,
      savedPromptId: widget.prompt.id,
      initialContent: widget.prompt.content,
      initialDescription: widget.prompt.description,
      isGlobal: widget.isGlobal,
    );
  }

  Future<void> _deletePrompt() async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Delete Saved Prompt',
      content: 'Are you sure you want to delete this saved prompt?',
      confirmLabel: 'Delete',
    );

    if (confirmed == true) {
      await ref
          .read(savedPromptControllerProvider)
          .deleteSavedPrompt(widget.prompt.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Context Menu or Send Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.prompt.description ?? '',
                  style: theme.textTheme.p.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.onSend != null)
                ShadButton.outline(
                  width: 32,
                  height: 32,
                  padding: EdgeInsets.zero,
                  onPressed: widget.onSend,
                  child: const Icon(LucideIcons.send, size: 16),
                )
              else if (widget.showContextMenu)
                ShadContextMenu(
                  controller: _menuController,
                  items: [
                    ShadContextMenuItem(
                      leading: const Icon(LucideIcons.pencil),
                      onPressed: _editPrompt,
                      child: const Text('Edit'),
                    ),
                    ShadContextMenuItem(
                      leading: Icon(
                        LucideIcons.trash2,
                        color: theme.colorScheme.destructive,
                      ),
                      onPressed: _deletePrompt,
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
                    onPressed: _menuController.toggle,
                    child: Icon(
                      LucideIcons.ellipsisVertical,
                      size: 16,
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Content
          ShadInput(
            initialValue: widget.prompt.content,
            readOnly: true,
            maxLines: null,
            minLines: 1,
          ),
          if (widget.prompt.lastUsedAt != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Last Used: ${DateFormatter.format(widget.prompt.lastUsedAt!)}',
                  style: theme.textTheme.muted.copyWith(fontSize: 11),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormatter.formatRelative(widget.prompt.lastUsedAt!),
                  style: theme.textTheme.muted.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
