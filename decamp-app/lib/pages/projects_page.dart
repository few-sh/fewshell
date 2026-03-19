import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:decamp/providers/providers.dart';
import 'package:decamp/components/selectable_list_view.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../providers/ssh_tunnel_provider.dart';
import '../utils/ui_utils.dart';
import 'project_setup_page.dart';

class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProject = ref.watch(currentProjectProvider);
    final projectDao = ref.read(globalDatabaseProvider).projectDao;

    return SelectableListView<ProjectEntity>(
      title: 'Projects',
      activeData: ref.watch(activeProjectsProvider),
      archivedData: ref.watch(archivedProjectsProvider),
      itemBuilder: (context, project, viewMode) {
        return _ProjectListItem(
          project: project,
          viewMode: viewMode,
          isSelected: project.id == currentProject?.id,
          dao: projectDao,
          onSelect: (p) async {
            await ref.read(currentProjectIdProvider.notifier).select(p.id);
            if (context.mounted) {
              Navigator.pop(context);
              ShadToaster.of(context).show(
                ShadToast(
                  description: Text('Switched to: ${p.name}'),
                  showCloseIconOnlyWhenHovered: false,
                ),
              );
            }
          },
        );
      },
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProjectSetupPage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Project'),
      ),
    );
  }
}

class _ProjectListItem extends ConsumerStatefulWidget {
  final ProjectEntity project;
  final SelectableViewMode viewMode;
  final bool isSelected;
  final ProjectDao dao;
  final ValueChanged<ProjectEntity> onSelect;

  const _ProjectListItem({
    required this.project,
    required this.viewMode,
    required this.isSelected,
    required this.dao,
    required this.onSelect,
  });

  @override
  ConsumerState<_ProjectListItem> createState() => _ProjectListItemState();
}

class _ProjectListItemState extends ConsumerState<_ProjectListItem> {
  final _menuController = ShadPopoverController();

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final id = widget.project.id;
    final name = widget.project.name;
    final isSelected = widget.isSelected;

    final dateDisplay = DateFormatter.format(widget.project.lastSessionDate);
    final relativeTime = DateFormatter.formatRelative(
      widget.project.lastSessionDate,
    );

    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        if (widget.viewMode == SelectableViewMode.active) {
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
              widget.onSelect(widget.project);
            },
            child: Row(
              children: [
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
                      if (widget.project.serverNodeId != null) ...[
                        const SizedBox(height: 2),
                        _buildServerInfo(theme),
                      ],
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

  Widget _buildServerInfo(ShadThemeData theme) {
    final tunnelAsync = ref.watch(projectTunnelProvider(widget.project.id));
    final label =
        tunnelAsync.whenOrNull(
          data: (settings) {
            if (settings != null) {
              return '${settings.username}@${settings.host}:${settings.port}';
            }
            return null;
          },
        ) ??
        'Remote';

    return Row(
      children: [
        Icon(
          LucideIcons.cloud,
          size: 12,
          color: theme.colorScheme.mutedForeground,
        ),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.muted.copyWith(fontSize: 11)),
      ],
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
    final id = widget.project.id;
    final name = widget.project.name;
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
          contextMenuBuilder: adaptiveContextMenuBuilder,
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
    final id = widget.project.id;
    final name = widget.project.name;

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
    final id = widget.project.id;
    final name = widget.project.name;

    await widget.dao.unarchiveItem(id);
    if (!mounted) return;

    ShadToaster.of(
      context,
    ).show(ShadToast(description: Text('Restored: $name')));
  }

  Future<void> _handleDelete() async {
    final id = widget.project.id;
    final name = widget.project.name;

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
      await widget.dao.deleteItem(id);
      if (!mounted) return;

      ShadToaster.of(
        context,
      ).show(ShadToast(description: Text('Deleted: $name')));
    }
  }
}
