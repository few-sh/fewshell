import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../themes/shad_layout_theme.dart';
import 'package:decamp/providers/providers.dart';
import '../themes/terminal_theme.dart';
import '../components/project_title_bar.dart';
import '../components/empty_placeholder.dart';
import '../components/new_snippet_card.dart';
import '../components/confirmation_dialog.dart';

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

  void _addNewSnippet() {
    final isGlobal = _tabController.index == 0;
    showNewSnippetDialog(
      context,
      isGlobal: isGlobal,
      title: isGlobal ? 'Add User Snippet' : 'Add Project Snippet',
    );
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Icon(LucideIcons.arrowLeft),
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
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth:
                      Theme.of(
                        context,
                      ).extension<ShadLayoutTheme>()?.centeredContentMaxWidth ??
                      800,
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

  Widget _buildUserSnippets() {
    final snippetsAsync = ref.watch(globalSnippetsProvider);

    return Column(
      children: [
        Expanded(
          child: snippetsAsync.when(
            data: (snippets) => _buildSnippetsList(
              snippets,
              isGlobal: true,
              scrollController: _userSnippetsScrollController,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) =>
                Center(child: Text('Error loading snippets: $error')),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  Theme.of(
                    context,
                  ).extension<ShadLayoutTheme>()?.centeredContentMaxWidth ??
                  800,
            ),
            child: _buildAddButton(
              label: 'Add User Snippet',
              onPressed: () => showNewSnippetDialog(
                context,
                isGlobal: true,
                title: 'Add User Snippet',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectSnippets() {
    final currentProjectId = ref.watch(currentProjectIdProvider);

    if (currentProjectId == null) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth:
                Theme.of(
                  context,
                ).extension<ShadLayoutTheme>()?.centeredContentMaxWidth ??
                800,
          ),
          child: EmptyPlaceholder(
            icon: LucideIcons.info,
            title: 'No Project Selected',
            subtitle: 'Select a project to manage project-specific snippets.',
          ),
        ),
      );
    }

    final snippetsAsync = ref.watch(projectSnippetsProvider(currentProjectId));

    return Column(
      children: [
        Expanded(
          child: snippetsAsync.when(
            data: (snippets) => _buildSnippetsList(
              snippets,
              isGlobal: false,
              scrollController: _projectSnippetsScrollController,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) =>
                Center(child: Text('Error loading snippets: $error')),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  Theme.of(
                    context,
                  ).extension<ShadLayoutTheme>()?.centeredContentMaxWidth ??
                  800,
            ),
            child: _buildAddButton(
              label: 'Add Project Snippet',
              onPressed: () => showNewSnippetDialog(
                context,
                isGlobal: false,
                title: 'Add Project Snippet',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSnippetsList(
    List<SnippetEntity> snippets, {
    required bool isGlobal,
    required ScrollController scrollController,
  }) {
    // Show empty state only if no snippets
    if (snippets.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth:
                Theme.of(
                  context,
                ).extension<ShadLayoutTheme>()?.centeredContentMaxWidth ??
                800,
          ),
          child: EmptyPlaceholder(
            icon: LucideIcons.code,
            title: 'No Snippets Yet',
            subtitle: 'Add your first snippet using the + button below.',
          ),
        ),
      );
    }

    // Build list items
    final listItems = <Widget>[
      ...snippets.asMap().entries.map((entry) {
        final index = entry.key;
        final snippet = entry.value;
        return Center(
          key: ValueKey('snippet_wrapper_${snippet.id}'),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  Theme.of(
                    context,
                  ).extension<ShadLayoutTheme>()?.centeredContentMaxWidth ??
                  800,
            ),
            child: _buildSnippetCard(
              key: ValueKey(snippet.id),
              index: index,
              snippet: snippet,
              isGlobal: isGlobal,
              onDelete: () async {
                await ref
                    .read(snippetControllerProvider)
                    .deleteSnippet(snippet.id);
              },
            ),
          ),
        );
      }),
    ];

    return ReorderableListView(
      buildDefaultDragHandles: false,
      scrollController: scrollController,
      padding: const EdgeInsets.all(16),
      onReorder: (oldIndex, newIndex) async {
        // Update the order in the database
        await ref
            .read(snippetControllerProvider)
            .reorderSnippets(snippets, oldIndex, newIndex);
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

  Widget _buildAddButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      alignment: Alignment.centerRight,
      child: ShadButton(
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.plus, size: 16),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}

/// Widget for displaying a snippet with visibility toggle and context menu
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
  final _menuController = ShadPopoverController();

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  Future<void> _toggleVisibility(bool value) async {
    try {
      await ref
          .read(snippetControllerProvider)
          .updateSnippet(
            id: widget.snippet.id,
            content: widget.snippet.content,
            description: widget.snippet.description ?? '',
            isVisibleToLlm: value,
          );
    } catch (e) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast(
            description: Text('Error updating visibility: $e'),
            action: ShadButton.destructive(
              child: const Text('Dismiss'),
              onPressed: () => ShadToaster.of(context).hide(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteSnippet() async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Delete Snippet',
      content: 'Are you sure you want to delete this snippet?',
      confirmLabel: 'Delete',
    );

    if (confirmed == true) {
      await ref
          .read(snippetControllerProvider)
          .deleteSnippet(widget.snippet.id);
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
          // Header with Drag Handle and Context Menu
          Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: ReorderableDragStartListener(
                  index: widget.index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Icon(
                      LucideIcons.gripHorizontal,
                      size: 20,
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: -4,
                child: ShadContextMenu(
                  controller: _menuController,
                  items: [
                    ShadContextMenuItem(
                      leading: const Icon(LucideIcons.pencil),
                      child: const Text('Edit'),
                      onPressed: () {
                        _menuController.hide();
                        showNewSnippetDialog(
                          context,
                          title: 'Edit Snippet',
                          initialDescription: widget.snippet.description,
                          initialContent: widget.snippet.content,
                          isGlobal: widget.isGlobal,
                          snippetId: widget.snippet.id,
                          initialIsVisibleToLlm: widget.snippet.isVisibleToLlm,
                        );
                      },
                    ),
                    ShadContextMenuItem(
                      leading: const Icon(LucideIcons.pencil),
                      child: const Text('Duplicate'),
                      onPressed: () {
                        _menuController.hide();
                        showNewSnippetDialog(
                          context,
                          title: 'Duplicate Snippet',
                          initialDescription:
                              'Copy of ${widget.snippet.description}',
                          initialContent: widget.snippet.content,
                          isGlobal: widget.isGlobal,
                          initialIsVisibleToLlm: widget.snippet.isVisibleToLlm,
                        );
                      },
                    ),
                    ShadContextMenuItem(
                      leading: Icon(
                        LucideIcons.trash2,
                        color: theme.colorScheme.destructive,
                      ),
                      child: Text(
                        'Delete',
                        style: TextStyle(color: theme.colorScheme.destructive),
                      ),
                      onPressed: () {
                        _menuController.hide();
                        _deleteSnippet();
                      },
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
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Description
          SelectableText(
            widget.snippet.description ?? '',
            style: theme.textTheme.p.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          // Content
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: terminalTheme?.backgroundColor ?? Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: terminalTheme?.borderColor ?? Colors.grey,
                width: 1,
              ),
            ),
            child: SelectableText(
              widget.snippet.content,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: terminalTheme?.textColor ?? Colors.greenAccent.shade400,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ShadSwitch(
            value: widget.snippet.isVisibleToLlm,
            onChanged: _toggleVisibility,
            label: const Text('Visible to AI'),
            sublabel: const Text('Include this snippet in the AI context'),
          ),
        ],
      ),
    );
  }
}
