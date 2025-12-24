import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../providers/snippet_provider.dart';
import '../providers/project_provider.dart';
import '../themes/terminal_theme.dart';

/// Shows a modal dialog to create a new snippet
Future<void> showNewSnippetDialog(
  BuildContext context, {
  String? initialDescription,
  String? initialContent,
  bool? isGlobal,
}) {
  return showDialog(
    context: context,
    builder: (context) => ShadDialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: NewSnippetCard(
          isGlobal: isGlobal,
          initialDescription: initialDescription,
          initialContent: initialContent,
          onCancel: () => Navigator.of(context).pop(),
          onSuccess: () => Navigator.of(context).pop(),
        ),
      ),
    ),
  );
}

/// Widget for creating a new snippet inline
class NewSnippetCard extends ConsumerStatefulWidget {
  final bool? isGlobal;
  final String? initialDescription;
  final String? initialContent;
  final VoidCallback onCancel;
  final VoidCallback onSuccess;

  const NewSnippetCard({
    super.key,
    this.isGlobal,
    this.initialDescription,
    this.initialContent,
    required this.onCancel,
    required this.onSuccess,
  });

  @override
  ConsumerState<NewSnippetCard> createState() => _NewSnippetCardState();
}

class _NewSnippetCardState extends ConsumerState<NewSnippetCard> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _contentController;
  final _descriptionFocus = FocusNode();
  bool _isSaving = false;
  bool _isVisibleToLlm = true;
  late bool _isGlobalSelection;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
    _contentController = TextEditingController(text: widget.initialContent);
    _isGlobalSelection = widget.isGlobal ?? false;

    // Auto-focus on description field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _descriptionFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _contentController.dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_descriptionController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      return; // Don't save if required fields are empty
    }

    setState(() => _isSaving = true);

    try {
      final currentProjectId = ref.read(currentProjectIdProvider);
      final isGlobal = widget.isGlobal ?? _isGlobalSelection;

      await ref
          .read(snippetControllerProvider)
          .addSnippet(
            name: _descriptionController.text.trim(),
            content: _contentController.text.trim(),
            description: _descriptionController.text.trim(),
            projectId: isGlobal ? null : currentProjectId,
            isVisibleToLlm: _isVisibleToLlm,
          );

      if (mounted) {
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ShadToaster.of(context).show(
          ShadToast(
            description: Text('Error adding snippet: $e'),
            action: ShadButton.destructive(
              child: const Text('Dismiss'),
              onPressed: () => ShadToaster.of(context).hide(),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final terminalTheme = Theme.of(context).extension<TerminalTheme>();

    return ShadCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.circlePlus, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'New Snippet',
                style: theme.textTheme.h4.copyWith(fontSize: 18),
              ),
              const Spacer(),
              if (_isSaving)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                ShadButton.ghost(
                  child: const Icon(LucideIcons.x),
                  onPressed: widget.onCancel,
                ),
            ],
          ),
          const SizedBox(height: 12),
          ShadInput(
            controller: _descriptionController,
            focusNode: _descriptionFocus,
            placeholder: const Text('Description (e.g., List all pods)'),
            minLines: 1,
            maxLines: null,
          ),
          const SizedBox(height: 12),
          ShadInput(
            controller: _contentController,
            placeholder: const Text('Command (e.g., kubectl get pods)'),
            minLines: 2,
            maxLines: null,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: terminalTheme?.textColor ?? Colors.greenAccent.shade400,
              height: 1.5,
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Visible to AI', style: theme.textTheme.small),
                    Text(
                      'Include this snippet in the AI context',
                      style: theme.textTheme.muted,
                    ),
                  ],
                ),
              ),
              ShadSwitch(
                value: _isVisibleToLlm,
                onChanged: (value) {
                  setState(() {
                    _isVisibleToLlm = value;
                  });
                },
              ),
            ],
          ),
          if (widget.isGlobal == null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Scope:',
                  style: theme.textTheme.p.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: ShadButton(
                          onPressed: () {
                            setState(() => _isGlobalSelection = false);
                          },
                          backgroundColor: !_isGlobalSelection
                              ? theme.colorScheme.primary
                              : theme.colorScheme.secondary,
                          foregroundColor: !_isGlobalSelection
                              ? theme.colorScheme.primaryForeground
                              : theme.colorScheme.secondaryForeground,
                          child: const Text('Project'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ShadButton(
                          onPressed: () {
                            setState(() => _isGlobalSelection = true);
                          },
                          backgroundColor: _isGlobalSelection
                              ? theme.colorScheme.primary
                              : theme.colorScheme.secondary,
                          foregroundColor: _isGlobalSelection
                              ? theme.colorScheme.primaryForeground
                              : theme.colorScheme.secondaryForeground,
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('User'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ShadButton(
              onPressed: _isSaving ? null : _save,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(LucideIcons.check, size: 16),
                  SizedBox(width: 8),
                  Text('Save Snippet'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
