import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:decamp/providers/project_provider.dart';
import 'package:decamp/providers/session_provider.dart';
import 'package:decamp/providers/database_provider.dart';
import 'package:decamp/components/selectable_list_view.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SessionsHistoryPage extends ConsumerWidget {
  const SessionsHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProject = ref.watch(currentProjectProvider);
    final currentSessionId = ref.watch(currentSessionIdProvider);
    final sessionDao = ref.read(databaseProvider).sessionDao;
    final messageDao = ref.read(databaseProvider).messageDao;

    // Helper: Switch to another session if the current one is being removed
    Future<void> switchFromSession(SessionEntity session) async {
      final currentId = ref.read(currentSessionIdProvider);
      if (currentId != session.id) return;

      final sessions = await sessionDao.getSessionsByProject(session.projectId);
      final otherSessions = sessions
          .where((s) => s.id != session.id && !s.isArchived)
          .toList();

      if (otherSessions.isNotEmpty) {
        ref
            .read(currentSessionIdProvider.notifier)
            .select(otherSessions.first.id);
      } else {
        final newSessionId = await sessionDao.createSessionWithId(
          projectId: session.projectId,
        );
        ref.read(currentSessionIdProvider.notifier).select(newSessionId);
      }
    }

    return SelectableListView<SessionEntity>(
      title: '${currentProject?.name ?? 'Project'} Sessions',
      activeData: ref.watch(currentProjectSessionsProvider),
      archivedData: ref.watch(archivedSessionsProvider),
      itemBuilder: (context, session, viewMode) {
        return _SessionListItem(
          session: session,
          viewMode: viewMode,
          isSelected: session.id == currentSessionId,
          dao: sessionDao,
          onSelect: (s) {
            ref.read(currentSessionIdProvider.notifier).select(s.id);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Switched to: ${s.description}')),
            );
          },
          beforeArchive: switchFromSession,
          beforeDelete: switchFromSession,
          cleanupOnDelete: (s) => messageDao.deleteMessagesBySession(s.id),
        );
      },
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final controller = ref.read(sessionControllerProvider);
          await controller.createNewSession();
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
        tooltip: 'New Session',
        child: const Icon(Icons.add_comment),
      ),
    );
  }
}

class _SessionListItem extends ConsumerStatefulWidget {
  final SessionEntity session;
  final SelectableViewMode viewMode;
  final bool isSelected;
  final SessionDao dao;
  final ValueChanged<SessionEntity> onSelect;
  final Future<void> Function(SessionEntity)? beforeArchive;
  final Future<void> Function(SessionEntity)? beforeDelete;
  final Future<void> Function(SessionEntity)? cleanupOnDelete;

  const _SessionListItem({
    required this.session,
    required this.viewMode,
    required this.isSelected,
    required this.dao,
    required this.onSelect,
    this.beforeArchive,
    this.beforeDelete,
    this.cleanupOnDelete,
  });

  @override
  ConsumerState<_SessionListItem> createState() => _SessionListItemState();
}

class _SessionListItemState extends ConsumerState<_SessionListItem> {
  final _menuController = ShadPopoverController();

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final id = widget.session.id;
    final name = widget.session.description;
    final isSelected = widget.isSelected;

    final dateDisplay = DateFormatter.format(widget.session.updatedAt);
    final relativeTime = DateFormatter.formatRelative(widget.session.updatedAt);

    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        if (widget.viewMode == SelectableViewMode.active) {
          await widget.beforeArchive?.call(widget.session);
          await widget.dao.archiveItem(id);
        } else {
          await widget.dao.unarchiveItem(id);
        }
        return true;
      },
      background: _buildDismissBackground(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: ShadCard(
          padding: const EdgeInsets.all(12),
          backgroundColor: isSelected ? theme.colorScheme.muted : null,
          child: InkWell(
            onTap: () {
              if (widget.viewMode == SelectableViewMode.archived) return;
              widget.onSelect(widget.session);
            },
            child: Row(
              children: [
                if (widget.viewMode == SelectableViewMode.active) ...[
                  Icon(
                    Icons.arrow_back_ios,
                    size: 16,
                    color: theme.colorScheme.mutedForeground,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.p.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            dateDisplay,
                            style: theme.textTheme.muted.copyWith(fontSize: 11),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            relativeTime,
                            style: theme.textTheme.muted.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      if (isSelected) _buildActiveIndicator(context),
                    ],
                  ),
                ),
                ShadContextMenu(
                  controller: _menuController,
                  items: _buildMenuItems(context),
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
          ),
        ),
      ),
    );
  }

  Widget _buildDismissBackground(BuildContext context) {
    final theme = ShadTheme.of(context);
    final color = widget.viewMode == SelectableViewMode.active
        ? theme.colorScheme.secondary
        : theme.colorScheme.primary;

    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: color,
      child: Icon(
        widget.viewMode == SelectableViewMode.active
            ? LucideIcons.archive
            : LucideIcons.archiveRestore,
        color: theme.colorScheme.secondaryForeground,
      ),
    );
  }

  Widget _buildActiveIndicator(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            LucideIcons.circleCheck,
            size: 14,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            'Active',
            style: theme.textTheme.muted.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMenuItems(BuildContext context) {
    final theme = ShadTheme.of(context);
    return [
      ShadContextMenuItem(
        leading: const Icon(LucideIcons.pencil),
        child: const Text('Rename'),
        onPressed: () {
          _menuController.toggle();
          _handleRename();
        },
      ),
      if (widget.viewMode == SelectableViewMode.active)
        ShadContextMenuItem(
          leading: const Icon(LucideIcons.archive),
          child: const Text('Archive'),
          onPressed: () {
            _menuController.toggle();
            _handleArchive();
          },
        )
      else
        ShadContextMenuItem(
          leading: const Icon(LucideIcons.archiveRestore),
          child: const Text('Unarchive'),
          onPressed: () {
            _menuController.toggle();
            _handleUnarchive();
          },
        ),
      ShadContextMenuItem(
        leading: Icon(LucideIcons.trash2, color: theme.colorScheme.destructive),
        child: Text(
          'Delete',
          style: TextStyle(color: theme.colorScheme.destructive),
        ),
        onPressed: () {
          _menuController.toggle();
          _handleDelete();
        },
      ),
    ];
  }

  Future<void> _handleRename() async {
    final id = widget.session.id;
    final name = widget.session.description;
    final controller = TextEditingController(text: name);

    final newName = await showShadDialog<String>(
      context: context,
      builder: (context) => ShadDialog(
        title: const Text('Rename'),
        actions: [
          ShadButton.outline(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ShadButton(
            child: const Text('Rename'),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
          ),
        ],
        child: ShadInput(
          controller: controller,
          placeholder: const Text('Name'),
          autocorrect: false,
        ),
      ),
    );

    controller.dispose();

    if (newName != null && newName.isNotEmpty && newName != name) {
      await widget.dao.renameItem(id, newName);
    }
  }

  Future<void> _handleArchive() async {
    final id = widget.session.id;
    final name = widget.session.description;

    await widget.beforeArchive?.call(widget.session);
    await widget.dao.archiveItem(id);
    if (!mounted) return;

    ShadToaster.of(context).show(
      ShadToast(
        description: Text('Archived: $name'),
        action: ShadButton.outline(
          child: const Text('Undo'),
          onPressed: () => widget.dao.unarchiveItem(id),
        ),
      ),
    );
  }

  Future<void> _handleUnarchive() async {
    final id = widget.session.id;
    final name = widget.session.description;

    await widget.dao.unarchiveItem(id);
    if (!mounted) return;

    ShadToaster.of(
      context,
    ).show(ShadToast(description: Text('Restored: $name')));
  }

  Future<void> _handleDelete() async {
    final id = widget.session.id;
    final name = widget.session.description;

    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog.alert(
        title: const Text('Delete?'),
        description: Text(
          'Are you sure you want to delete "$name"? This cannot be undone.',
        ),
        actions: [
          ShadButton.outline(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          ShadButton.destructive(
            child: const Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.beforeDelete?.call(widget.session);
      await widget.cleanupOnDelete?.call(widget.session);
      await widget.dao.deleteItem(id);
      if (!mounted) return;

      ShadToaster.of(
        context,
      ).show(ShadToast(description: Text('Deleted: $name')));
    }
  }
}
