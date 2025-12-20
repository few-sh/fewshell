import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(16),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding snippet: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'New Snippet',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isSaving)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onCancel,
                    tooltip: 'Cancel',
                    iconSize: 20,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              focusNode: _descriptionFocus,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                hintText: 'Description (e.g., List all pods)',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              minLines: 1,
              maxLines: null,
              style: theme.textTheme.bodyMedium,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                hintText: 'Command (e.g., kubectl get pods)',
                hintStyle: TextStyle(
                  color:
                      theme.extension<TerminalTheme>()?.hintColor ??
                      Colors.grey.shade600,
                ),
                isDense: true,
                filled: true,
                fillColor:
                    theme.extension<TerminalTheme>()?.backgroundColor ??
                    Colors.black,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color:
                        theme.extension<TerminalTheme>()?.borderColor ??
                        Colors.grey.shade800,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color:
                        theme.extension<TerminalTheme>()?.borderColor ??
                        Colors.grey.shade800,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              minLines: 2,
              maxLines: null,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color:
                    theme.extension<TerminalTheme>()?.textColor ??
                    Colors.greenAccent.shade400,
                height: 1.5,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Visible to AI'),
              subtitle: const Text(
                'Include this snippet in the AI context',
                style: TextStyle(fontSize: 12),
              ),
              value: _isVisibleToLlm,
              onChanged: (value) {
                setState(() {
                  _isVisibleToLlm = value;
                });
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            if (widget.isGlobal == null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Scope:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('Project'),
                    selected: !_isGlobalSelection,
                    onSelected: (selected) {
                      if (selected) setState(() => _isGlobalSelection = false);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('User (Global)'),
                    selected: _isGlobalSelection,
                    onSelected: (selected) {
                      if (selected) setState(() => _isGlobalSelection = true);
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: const Icon(Icons.check),
                label: const Text('Save Snippet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
