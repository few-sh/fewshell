import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:agent_core/agent_core.dart';
import '../providers/saved_prompt_provider.dart';
import '../providers/project_provider.dart';
import '../themes/terminal_theme.dart';

/// Shows a modal dialog to create or edit a saved prompt
Future<void> showSavedPromptDialog(
  BuildContext context, {
  String? initialDescription,
  String? initialContent,
  bool? isGlobal,
  String? title,
  String? savedPromptId,
}) {
  return showDialog(
    context: context,
    builder: (context) => ShadDialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SavedPromptDialog(
          isGlobal: isGlobal,
          initialDescription: initialDescription,
          initialContent: initialContent,
          title: title,
          savedPromptId: savedPromptId,
          onCancel: () => Navigator.of(context).pop(),
          onSuccess: () => Navigator.of(context).pop(),
        ),
      ),
    ),
  );
}

/// Widget for creating or editing a saved prompt
class SavedPromptDialog extends ConsumerStatefulWidget {
  final bool? isGlobal;
  final String? initialDescription;
  final String? initialContent;
  final String? title;
  final String? savedPromptId;
  final VoidCallback onCancel;
  final VoidCallback onSuccess;

  const SavedPromptDialog({
    super.key,
    this.isGlobal,
    this.initialDescription,
    this.initialContent,
    this.title,
    this.savedPromptId,
    required this.onCancel,
    required this.onSuccess,
  });

  @override
  ConsumerState<SavedPromptDialog> createState() => _SavedPromptDialogState();
}

class _SavedPromptDialogState extends ConsumerState<SavedPromptDialog> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _contentController;
  final _contentFocus = FocusNode();
  bool _isSaving = false;
  late bool _isGlobalSelection;
  String? _duplicateWarning;
  String? _duplicateId;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
    _contentController = TextEditingController(text: widget.initialContent);
    _isGlobalSelection = widget.isGlobal ?? false;

    // Auto-focus on content field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentFocus.requestFocus();
    });

    _contentController.addListener(_checkForDuplicates);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _contentController.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  Future<void> _checkForDuplicates() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      setState(() => _duplicateWarning = null);
      return;
    }

    // Check prompts based on selection
    final globalPrompts = await ref.read(globalSavedPromptsProvider.future);
    final currentProjectId = ref.read(currentProjectIdProvider);
    final projectPrompts = currentProjectId != null
        ? await ref.read(projectSavedPromptsProvider(currentProjectId).future)
        : <SavedPromptEntity>[];

    // Only check against the selected scope
    final promptsToCheck = _isGlobalSelection ? globalPrompts : projectPrompts;

    // Exclude current prompt if editing
    final duplicatePrompt = promptsToCheck
        .where((p) => p.content == content && p.id != widget.savedPromptId)
        .firstOrNull;

    if (duplicatePrompt != null && mounted) {
      setState(() {
        _duplicateWarning = 'A saved prompt with this content already exists.';
        _duplicateId = duplicatePrompt.id;
      });
    } else if (mounted) {
      setState(() {
        _duplicateWarning = null;
        _duplicateId = null;
      });
    }
  }

  Future<void> _overwrite() async {
    if (_duplicateId == null) return;

    setState(() => _isSaving = true);
    try {
      await ref
          .read(savedPromptControllerProvider)
          .updateSavedPrompt(
            id: _duplicateId!,
            content: _contentController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
          );
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast(
            description: Text('Error overwriting prompt: $e'),
            action: ShadButton.destructive(
              child: const Text('Dismiss'),
              onPressed: () => ShadToaster.of(context).hide(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _save() async {
    if (_contentController.text.trim().isEmpty) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final controller = ref.read(savedPromptControllerProvider);
      final currentProjectId = ref.read(currentProjectIdProvider);

      if (widget.savedPromptId != null) {
        // Update existing
        await controller.updateSavedPrompt(
          id: widget.savedPromptId!,
          content: _contentController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        );
      } else {
        // Create new
        await controller.addSavedPrompt(
          content: _contentController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          projectId: _isGlobalSelection ? null : currentProjectId,
        );
      }

      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast(
            description: Text('Error saving prompt: $e'),
            action: ShadButton.destructive(
              child: const Text('Dismiss'),
              onPressed: () => ShadToaster.of(context).hide(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final terminalTheme = Theme.of(context).extension<TerminalTheme>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title ??
              (widget.savedPromptId != null
                  ? 'Edit Saved Prompt'
                  : 'New Saved Prompt'),
          style: theme.textTheme.h4,
        ),
        const SizedBox(height: 24),

        // Scope selection (only for new prompts and if not forced)
        if (widget.savedPromptId == null && widget.isGlobal == null) ...[
          Row(
            children: [
              Text('Save to:', style: theme.textTheme.small),
              const SizedBox(width: 16),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.muted,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSegmentButton(
                      label: 'Project',
                      isSelected: !_isGlobalSelection,
                      onTap: () {
                        setState(() => _isGlobalSelection = false);
                        _checkForDuplicates();
                      },
                    ),
                    _buildSegmentButton(
                      label: 'User',
                      isSelected: _isGlobalSelection,
                      onTap: () {
                        setState(() => _isGlobalSelection = true);
                        _checkForDuplicates();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Content Field
        ShadInput(
          controller: _contentController,
          focusNode: _contentFocus,
          placeholder: const Text('Prompt Content'),
          maxLines: 5,
          minLines: 3,
          style: TextStyle(
            fontFamily: 'monospace',
            color: terminalTheme?.textColor,
          ),
        ),
        if (_duplicateWarning != null) ...[
          const SizedBox(height: 8),
          Text(
            _duplicateWarning!,
            style: theme.textTheme.small.copyWith(
              color: theme.colorScheme.destructive,
            ),
          ),
        ],
        const SizedBox(height: 16),

        // Description Field
        ShadInput(
          controller: _descriptionController,
          placeholder: const Text('Description (Optional)'),
        ),
        const SizedBox(height: 24),

        // Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ShadButton.ghost(
              onPressed: widget.onCancel,
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            ShadButton(
              onPressed: _isSaving
                  ? null
                  : (_duplicateId != null ? _overwrite : _save),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _duplicateId != null
                          ? 'Update Existing'
                          : (widget.savedPromptId != null
                                ? 'Save Changes'
                                : 'Create Prompt'),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = ShadTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.background : null,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: theme.textTheme.small.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? theme.colorScheme.foreground
                : theme.colorScheme.mutedForeground,
          ),
        ),
      ),
    );
  }
}
