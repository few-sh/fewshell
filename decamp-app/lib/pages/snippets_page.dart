import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../providers/snippet_provider.dart';
import '../providers/project_provider.dart';
import '../themes/terminal_theme.dart';
import '../components/project_title_bar.dart';
import '../components/empty_placeholder.dart';
import '../components/new_snippet_card.dart';

/// Snippets page with User and Project snippets tabs
class SnippetsPage extends ConsumerStatefulWidget {
  const SnippetsPage({super.key});

  @override
  ConsumerState<SnippetsPage> createState() => _SnippetsPageState();
}

class _SnippetsPageState extends ConsumerState<SnippetsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _userSnippetsScrollController = ScrollController();
  final ScrollController _projectSnippetsScrollController = ScrollController();
  bool _isAddingSnippet = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userSnippetsScrollController.dispose();
    _projectSnippetsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside text fields
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const ProjectTitleBar(title: 'Snippets'),
          leading: ShadButton.ghost(
            child: const Icon(LucideIcons.arrowLeft),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            ShadButton.ghost(
              onPressed: _addNewSnippet,
              child: const Icon(LucideIcons.plus),
            ),
          ],
        ),
        body: Column(
          children: [
            // Stationary tab bar
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: theme.colorScheme.border),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: theme.colorScheme.primary,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.mutedForeground,
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                tabs: const [
                  Tab(text: 'User Snippets'),
                  Tab(text: 'Project Snippets'),
                ],
              ),
            ),
            // Scrollable content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildUserSnippets(), _buildProjectSnippets()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addNewSnippet() {
    setState(() {
      _isAddingSnippet = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _tabController.index == 0
          ? _userSnippetsScrollController
          : _projectSnippetsScrollController;

      if (controller.hasClients) {
        controller.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildUserSnippets() {
    final snippetsAsync = ref.watch(globalSnippetsProvider);

    return snippetsAsync.when(
      data: (snippets) => _buildSnippetsList(
        snippets,
        isGlobal: true,
        scrollController: _userSnippetsScrollController,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text('Error loading snippets: $error')),
    );
  }

  Widget _buildProjectSnippets() {
    final currentProjectId = ref.watch(currentProjectIdProvider);

    if (currentProjectId == null) {
      return Center(
        child: EmptyPlaceholder(
          icon: LucideIcons.info,
          title: 'No Project Selected',
          subtitle: 'Select a project to manage project-specific snippets.',
        ),
      );
    }

    final snippetsAsync = ref.watch(projectSnippetsProvider(currentProjectId));

    return snippetsAsync.when(
      data: (snippets) => _buildSnippetsList(
        snippets,
        isGlobal: false,
        scrollController: _projectSnippetsScrollController,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text('Error loading snippets: $error')),
    );
  }

  Widget _buildSnippetsList(
    List<SnippetEntity> snippets, {
    required bool isGlobal,
    required ScrollController scrollController,
  }) {
    // Show empty state only if no snippets AND not adding a new one
    if (snippets.isEmpty && !_isAddingSnippet) {
      return Center(
        child: EmptyPlaceholder(
          icon: LucideIcons.code,
          title: 'No Snippets Yet',
          subtitle: 'Add your first snippet using the + button above.',
        ),
      );
    }

    // Build list items with new snippet card at top if needed
    final listItems = <Widget>[
      if (_isAddingSnippet)
        NewSnippetCard(
          key: const ValueKey('new_snippet'),
          isGlobal: isGlobal,
          onSuccess: () {
            setState(() {
              _isAddingSnippet = false;
            });
          },
          onCancel: () {
            setState(() {
              _isAddingSnippet = false;
            });
          },
        ),
      ...snippets.asMap().entries.map((entry) {
        final index = entry.key + (_isAddingSnippet ? 1 : 0);
        final snippet = entry.value;
        return _buildSnippetCard(
          key: ValueKey(snippet.id),
          index: index,
          snippet: snippet,
          isGlobal: isGlobal,
          onDelete: () async {
            await ref.read(snippetControllerProvider).deleteSnippet(snippet.id);
          },
        );
      }),
    ];

    return ReorderableListView(
      scrollController: scrollController,
      padding: const EdgeInsets.all(16),
      onReorder: (oldIndex, newIndex) async {
        // Skip reordering if trying to move the new snippet card
        if (_isAddingSnippet && (oldIndex == 0 || newIndex == 0)) {
          return;
        }

        // Adjust indices if new snippet card is present
        final adjustedOldIndex = _isAddingSnippet ? oldIndex - 1 : oldIndex;
        final adjustedNewIndex = _isAddingSnippet ? newIndex - 1 : newIndex;

        // Update the order in the database
        await ref
            .read(snippetControllerProvider)
            .reorderSnippets(snippets, adjustedOldIndex, adjustedNewIndex);
      },
      children: listItems,
    );
  }

  Widget _buildSnippetCard({
    required Key key,
    required int index,
    required SnippetEntity snippet,
    required bool isGlobal,
    required VoidCallback onDelete,
  }) {
    final theme = ShadTheme.of(context);

    return Dismissible(
      key: key,
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.destructive,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          LucideIcons.trash2,
          color: theme.colorScheme.destructiveForeground,
        ),
      ),
      confirmDismiss: (direction) async {
        onDelete();
        return true;
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ShadCard(
          padding: EdgeInsets.zero,
          child: _SnippetCardContent(
            index: index,
            snippet: snippet,
            isGlobal: isGlobal,
          ),
        ),
      ),
    );
  }
}

/// Widget for displaying and editing a snippet inline
class _SnippetCardContent extends ConsumerStatefulWidget {
  final int index;
  final SnippetEntity snippet;
  final bool isGlobal;

  const _SnippetCardContent({
    required this.index,
    required this.snippet,
    required this.isGlobal,
  });

  @override
  ConsumerState<_SnippetCardContent> createState() =>
      _SnippetCardContentState();
}

class _SnippetCardContentState extends ConsumerState<_SnippetCardContent> {
  late TextEditingController _contentController;
  late TextEditingController _descriptionController;
  late bool _isVisibleToLlm;
  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.snippet.content);
    _descriptionController = TextEditingController(
      text: widget.snippet.description ?? '',
    );
    _isVisibleToLlm = widget.snippet.isVisibleToLlm;

    // Listen for changes
    _contentController.addListener(_markChanged);
    _descriptionController.addListener(_markChanged);
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _autoSave() async {
    if (!_hasChanges) return;
    if (_descriptionController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ref
          .read(snippetControllerProvider)
          .updateSnippet(
            id: widget.snippet.id,
            name: _descriptionController.text.trim(),
            content: _contentController.text.trim(),
            description: _descriptionController.text.trim(),
            isVisibleToLlm: _isVisibleToLlm,
          );

      if (mounted) {
        setState(() {
          _hasChanges = false;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ShadToaster.of(context).show(
          ShadToast(
            description: Text('Error saving: $e'),
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

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle at top center
          Center(
            child: ReorderableDragStartListener(
              index: widget.index,
              child: Icon(
                LucideIcons.gripHorizontal,
                size: 20,
                color: theme.colorScheme.mutedForeground,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Description with status indicator
          Row(
            children: [
              if (_isSaving)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                )
              else if (_hasChanges)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    LucideIcons.circle,
                    size: 8,
                    color: theme.colorScheme.primary,
                  ),
                ),
              Expanded(
                child: ShadInput(
                  controller: _descriptionController,
                  placeholder: const Text('Description'),
                  onSubmitted: (_) => _autoSave(),
                  // onTapOutside: (_) => _autoSave(), // ShadInput doesn't have onTapOutside yet? Check errors.
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ShadInput(
            controller: _contentController,
            placeholder: const Text('Command'),
            minLines: 2,
            maxLines: null,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: terminalTheme?.textColor ?? Colors.greenAccent.shade400,
              height: 1.5,
            ),
            // Note: ShadInput doesn't support full decoration customization like TextField
            // We rely on default Shadcn styling which is clean.
            onSubmitted: (_) => _autoSave(),
          ),
          const SizedBox(height: 8),
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
                    _hasChanges = true;
                  });
                  _autoSave();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
