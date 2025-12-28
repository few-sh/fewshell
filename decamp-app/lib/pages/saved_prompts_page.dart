import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../providers/saved_prompt_provider.dart';
import '../providers/project_provider.dart';
import '../components/project_title_bar.dart';
import '../components/empty_placeholder.dart';
import '../components/saved_prompt_dialog.dart';
import '../components/confirmation_dialog.dart';

/// Saved Prompts page with User and Project prompts tabs
class SavedPromptsPage extends ConsumerStatefulWidget {
  const SavedPromptsPage({super.key});

  @override
  ConsumerState<SavedPromptsPage> createState() => _SavedPromptsPageState();
}

class _SavedPromptsPageState extends ConsumerState<SavedPromptsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _userPromptsScrollController = ScrollController();
  final ScrollController _projectPromptsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userPromptsScrollController.dispose();
    _projectPromptsScrollController.dispose();
    super.dispose();
  }

  void _addNewPrompt() {
    final isGlobal = _tabController.index == 0;
    showSavedPromptDialog(
      context,
      isGlobal: isGlobal,
      title: isGlobal ? 'Add User Prompt' : 'Add Project Prompt',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const ProjectTitleBar(title: 'Saved Prompts'),
          leading: ShadButton.ghost(
            onPressed: () => Navigator.of(context).pop(),
            child: const Icon(LucideIcons.arrowLeft),
          ),
          actions: [
            ShadButton.ghost(
              onPressed: _addNewPrompt,
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
                  bottom: BorderSide(color: theme.colorScheme.border, width: 1),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'User Prompts'),
                  Tab(text: 'Project Prompts'),
                ],
                onTap: (index) {
                  setState(() {});
                },
              ),
            ),
            // Scrollable content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildUserPrompts(), _buildProjectPrompts()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserPrompts() {
    final promptsAsync = ref.watch(globalSavedPromptsProvider);

    return Column(
      children: [
        Expanded(
          child: promptsAsync.when(
            data: (prompts) => _buildPromptsList(
              prompts,
              isGlobal: true,
              scrollController: _userPromptsScrollController,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) =>
                Center(child: Text('Error loading prompts: $error')),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _buildAddButton(
              label: 'Add User Prompt',
              onPressed: _addNewPrompt,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectPrompts() {
    final currentProjectId = ref.watch(currentProjectIdProvider);

    if (currentProjectId == null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: const EmptyPlaceholder(
            icon: LucideIcons.info,
            title: 'No Project Selected',
            subtitle: 'Select a project to manage project-specific prompts.',
          ),
        ),
      );
    }

    final promptsAsync = ref.watch(
      projectSavedPromptsProvider(currentProjectId),
    );

    return Column(
      children: [
        Expanded(
          child: promptsAsync.when(
            data: (prompts) => _buildPromptsList(
              prompts,
              isGlobal: false,
              scrollController: _projectPromptsScrollController,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) =>
                Center(child: Text('Error loading prompts: $error')),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _buildAddButton(
              label: 'Add Project Prompt',
              onPressed: _addNewPrompt,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPromptsList(
    List<SavedPromptEntity> prompts, {
    required bool isGlobal,
    required ScrollController scrollController,
  }) {
    if (prompts.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: const EmptyPlaceholder(
            icon: LucideIcons.messageSquare,
            title: 'No Saved Prompts Yet',
            subtitle: 'Add your first saved prompt using the + button below.',
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: prompts.length,
      itemBuilder: (context, index) {
        final prompt = prompts[index];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _buildPromptCard(
              index: index,
              prompt: prompt,
              isGlobal: isGlobal,
              onDelete: () => _deletePrompt(prompt),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deletePrompt(SavedPromptEntity prompt) async {
    await ref.read(savedPromptControllerProvider).deleteSavedPrompt(prompt.id);
  }

  Widget _buildPromptCard({
    required int index,
    required SavedPromptEntity prompt,
    required bool isGlobal,
    required VoidCallback onDelete,
  }) {
    final theme = ShadTheme.of(context);

    return Dismissible(
      key: ValueKey(prompt.id),
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
        final confirmed = await showConfirmationDialog(
          context: context,
          title: 'Delete Saved Prompt',
          content: 'Are you sure you want to delete this saved prompt?',
          confirmLabel: 'Delete',
        );
        if (confirmed == true) {
          onDelete();
          return true;
        }
        return false;
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ShadCard(
          padding: EdgeInsets.zero,
          child: _PromptCardContent(prompt: prompt, isGlobal: isGlobal),
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

class _PromptCardContent extends ConsumerStatefulWidget {
  final SavedPromptEntity prompt;
  final bool isGlobal;

  const _PromptCardContent({required this.prompt, required this.isGlobal});

  @override
  ConsumerState<_PromptCardContent> createState() => _PromptCardContentState();
}

class _PromptCardContentState extends ConsumerState<_PromptCardContent> {
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
          // Header with Context Menu
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
