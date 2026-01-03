import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:agent_core/agent_core.dart';
import '../providers/snippet_provider.dart';
import '../providers/project_provider.dart';
import '../themes/terminal_theme.dart';

class SnippetDraft {
  final String content;
  final String description;

  const SnippetDraft({required this.content, required this.description});
}

/// Shows a modal dialog to create or edit a snippet
Future<void> showNewSnippetDialog(
  BuildContext context, {
  String? initialDescription,
  String? initialContent,
  List<SnippetDraft>? drafts,
  bool? isGlobal,
  String? title,
  String? snippetId,
  bool? initialIsVisibleToLlm,
}) {
  return showDialog(
    context: context,
    builder: (context) => ShadDialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: drafts != null && drafts.isNotEmpty
            ? SnippetCarousel(
                drafts: drafts,
                isGlobal: isGlobal,
                initialIsVisibleToLlm: initialIsVisibleToLlm,
                title: title,
              )
            : NewSnippetCard(
                isGlobal: isGlobal,
                initialDescription: initialDescription,
                initialContent: initialContent,
                title: title,
                snippetId: snippetId,
                initialIsVisibleToLlm: initialIsVisibleToLlm,
                onCancel: () => Navigator.of(context).pop(),
                onSuccess: () => Navigator.of(context).pop(),
              ),
      ),
    ),
  );
}

class SnippetCarousel extends StatefulWidget {
  final List<SnippetDraft> drafts;
  final bool? isGlobal;
  final bool? initialIsVisibleToLlm;
  final String? title;

  const SnippetCarousel({
    super.key,
    required this.drafts,
    this.isGlobal,
    this.initialIsVisibleToLlm,
    this.title,
  });

  @override
  State<SnippetCarousel> createState() => _SnippetCarouselState();
}

class _SnippetCarouselState extends State<SnippetCarousel> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final draft = widget.drafts[_currentIndex];
    final theme = ShadTheme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.drafts.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShadButton.ghost(
                  enabled: _currentIndex > 0,
                  onPressed: () => setState(() => _currentIndex--),
                  child: const Icon(LucideIcons.chevronLeft),
                ),
                Text(
                  'Snippet ${_currentIndex + 1} of ${widget.drafts.length}',
                  style: theme.textTheme.small,
                ),
                ShadButton.ghost(
                  enabled: _currentIndex < widget.drafts.length - 1,
                  onPressed: () => setState(() => _currentIndex++),
                  child: const Icon(LucideIcons.chevronRight),
                ),
              ],
            ),
          ),
        NewSnippetCard(
          key: ValueKey(_currentIndex),
          initialDescription: draft.description,
          initialContent: draft.content,
          isGlobal: widget.isGlobal,
          initialIsVisibleToLlm: widget.initialIsVisibleToLlm,
          title:
              widget.title ?? (widget.drafts.length > 1 ? 'Add Snippet' : null),
          onCancel: () => Navigator.of(context).pop(),
          onSuccess: () {
            ShadToaster.of(context).show(
              const ShadToast(
                description: Text('Snippet saved successfully'),
                duration: Duration(seconds: 2),
              ),
            );
            if (_currentIndex < widget.drafts.length - 1) {
              setState(() => _currentIndex++);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ],
    );
  }
}

/// Widget for creating or editing a snippet inline
class NewSnippetCard extends ConsumerStatefulWidget {
  final bool? isGlobal;
  final String? initialDescription;
  final String? initialContent;
  final String? title;
  final String? snippetId;
  final bool? initialIsVisibleToLlm;
  final VoidCallback onCancel;
  final VoidCallback onSuccess;

  const NewSnippetCard({
    super.key,
    this.isGlobal,
    this.initialDescription,
    this.initialContent,
    this.title,
    this.snippetId,
    this.initialIsVisibleToLlm,
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
  SnippetEntity? _existingSnippet;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
    _contentController = TextEditingController(text: widget.initialContent);
    _isGlobalSelection = widget.isGlobal ?? false;
    _isVisibleToLlm = widget.initialIsVisibleToLlm ?? true;

    _contentController.addListener(_checkForDuplicate);

    // Auto-focus on description field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _descriptionFocus.requestFocus();
      _checkForDuplicate();
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _contentController.dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  void _checkForDuplicate() {
    if (widget.snippetId != null) return;

    final content = _contentController.text.trim();
    if (content.isEmpty) {
      if (_existingSnippet != null) {
        setState(() => _existingSnippet = null);
      }
      return;
    }

    final globalSnippets = ref.read(globalSnippetsProvider).valueOrNull ?? [];
    final projectId = ref.read(currentProjectIdProvider);
    final projectSnippets = projectId != null
        ? (ref.read(projectSnippetsProvider(projectId)).valueOrNull ?? [])
        : <SnippetEntity>[];

    SnippetEntity? match;
    try {
      match = [
        ...projectSnippets,
        ...globalSnippets,
      ].firstWhere((s) => s.content.trim() == content);
    } catch (_) {
      match = null;
    }

    if (match != _existingSnippet) {
      setState(() {
        _existingSnippet = match;
        if (match != null) {
          _descriptionController.text = match.name;
          _isVisibleToLlm = match.isVisibleToLlm;
          _isGlobalSelection = match.projectId == null;
        }
      });
    }
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
      final idToUpdate = widget.snippetId ?? _existingSnippet?.id;

      if (idToUpdate != null) {
        await ref
            .read(snippetControllerProvider)
            .updateSnippet(
              id: idToUpdate,
              content: _contentController.text.trim(),
              description: _descriptionController.text.trim(),
              isVisibleToLlm: _isVisibleToLlm,
            );
      } else {
        await ref
            .read(snippetControllerProvider)
            .addSnippet(
              content: _contentController.text.trim(),
              description: _descriptionController.text.trim(),
              projectId: isGlobal ? null : currentProjectId,
              isVisibleToLlm: _isVisibleToLlm,
            );
      }

      if (mounted) {
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ShadToaster.of(context).show(
          ShadToast(
            description: Text('Error saving snippet: $e'),
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

    // Watch providers to ensure we have data for duplicate checking
    ref.watch(globalSnippetsProvider);
    final projectId = ref.watch(currentProjectIdProvider);
    if (projectId != null) {
      ref.watch(projectSnippetsProvider(projectId));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.title ?? 'New Snippet',
              style: theme.textTheme.h4.copyWith(fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ShadInput(
          controller: _descriptionController,
          focusNode: _descriptionFocus,
          placeholder: const Text('Description (e.g., List all pods)'),
          autocorrect: false,
          minLines: 1,
          maxLines: null,
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: terminalTheme?.backgroundColor ?? Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: terminalTheme?.borderColor ?? Colors.grey,
              width: 1,
            ),
          ),
          child: ShadInput(
            controller: _contentController,
            placeholder: const Text('Command (e.g., kubectl get pods)'),
            autocorrect: false,
            minLines: 2,
            maxLines: null,
            decoration: const ShadDecoration(border: ShadBorder.none),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: terminalTheme?.textColor ?? Colors.greenAccent.shade400,
              height: 1.5,
            ),
            onSubmitted: (_) => _save(),
          ),
        ),
        if (_existingSnippet != null) ...[
          const SizedBox(height: 8),
          Text(
            'Snippet already exists. Saving will overwrite it.',
            style: theme.textTheme.small.copyWith(
              color: theme.colorScheme.destructive,
            ),
          ),
        ],
        const SizedBox(height: 12),
        ShadSwitch(
          value: _isVisibleToLlm,
          onChanged: (value) {
            setState(() {
              _isVisibleToLlm = value;
            });
          },
          label: const Text('Visible to AI'),
          sublabel: const Text('Include this snippet in the AI context'),
        ),
        if (widget.isGlobal == null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Scope:',
                style: theme.textTheme.p.copyWith(fontWeight: FontWeight.bold),
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
              children: [
                const Icon(LucideIcons.check, size: 16),
                const SizedBox(width: 8),
                Text(
                  _existingSnippet != null || widget.snippetId != null
                      ? 'Update Snippet'
                      : 'Save Snippet',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
