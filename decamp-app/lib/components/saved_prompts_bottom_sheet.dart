import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'providers/providers.dart';
import '../components/empty_placeholder.dart';
import '../components/saved_prompt_card.dart';

/// Bottom sheet for selecting a saved prompt to send
class SavedPromptsBottomSheet extends ConsumerStatefulWidget {
  final Function(String) onSend;

  const SavedPromptsBottomSheet({super.key, required this.onSend});

  @override
  ConsumerState<SavedPromptsBottomSheet> createState() =>
      _SavedPromptsBottomSheetState();
}

class _SavedPromptsBottomSheetState
    extends ConsumerState<SavedPromptsBottomSheet>
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

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: theme.colorScheme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.muted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          //   child: Text('Saved Prompts', style: theme.textTheme.h4),
          // ),
          // Tabs
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
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildUserPrompts(), _buildProjectPrompts()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserPrompts() {
    final promptsAsync = ref.watch(globalSavedPromptsProvider);

    return promptsAsync.when(
      data: (prompts) => _buildPromptsList(
        prompts,
        isGlobal: true,
        scrollController: _userPromptsScrollController,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text('Error loading prompts: $error')),
    );
  }

  Widget _buildProjectPrompts() {
    final currentProjectId = ref.watch(currentProjectIdProvider);

    if (currentProjectId == null) {
      return const Center(
        child: EmptyPlaceholder(
          icon: LucideIcons.info,
          title: 'No Project Selected',
          subtitle: 'Select a project to view project-specific prompts.',
        ),
      );
    }

    final promptsAsync = ref.watch(
      projectSavedPromptsProvider(currentProjectId),
    );

    return promptsAsync.when(
      data: (prompts) => _buildPromptsList(
        prompts,
        isGlobal: false,
        scrollController: _projectPromptsScrollController,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text('Error loading prompts: $error')),
    );
  }

  Widget _buildPromptsList(
    List<SavedPromptEntity> prompts, {
    required bool isGlobal,
    required ScrollController scrollController,
  }) {
    if (prompts.isEmpty) {
      return const Center(
        child: EmptyPlaceholder(
          icon: LucideIcons.messageSquare,
          title: 'No Saved Prompts',
          subtitle: 'You haven\'t saved any prompts yet.',
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: prompts.length,
      itemBuilder: (context, index) {
        final prompt = prompts[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ShadCard(
            padding: EdgeInsets.zero,
            child: SavedPromptCard(
              prompt: prompt,
              isGlobal: isGlobal,
              showContextMenu: false,
              onSend: () {
                widget.onSend(prompt.content);
                // Mark as used
                ref.read(savedPromptControllerProvider).markAsUsed(prompt.id);
                Navigator.pop(context);
              },
            ),
          ),
        );
      },
    );
  }
}
