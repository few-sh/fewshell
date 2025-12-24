import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:decamp/components/empty_placeholder.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum SelectableViewMode { active, archived }

/// A unified list view for displaying listable entities (Projects, Sessions).
///
/// Uses convention-over-configuration: pass a DAO and data, and the component
/// handles all standard behaviors (star, archive, unarchive, delete, rename).
class SelectableListView<T> extends ConsumerStatefulWidget {
  /// Page title (e.g., "Projects" or "Sessions").
  final String title;

  /// The DAO for performing CRUD operations.
  final ListableEntityDao<T> dao;

  /// Active (non-archived) items stream.
  final AsyncValue<List<T>> activeData;

  /// Archived items stream.
  final AsyncValue<List<T>> archivedData;

  /// Extracts the ID from an item.
  final String Function(T) getId;

  /// Extracts the display name from an item.
  final String Function(T) getName;

  /// Extracts the creation date for display.
  final DateTime Function(T) getCreatedAt;

  /// Extracts the update date for display.
  final DateTime Function(T) getUpdatedAt;

  /// Called when an item is selected (tapped).
  final void Function(T)? onSelect;

  /// Whether the item is currently selected.
  final bool Function(T)? isSelected;

  /// Optional hook called before archiving (e.g., for session switching).
  final Future<void> Function(T)? beforeArchive;

  /// Optional hook called before deleting (e.g., for session switching).
  final Future<void> Function(T)? beforeDelete;

  /// Optional: Additional cleanup when deleting (e.g., delete messages).
  final Future<void> Function(T)? cleanupOnDelete;

  /// Optional: Custom leading widget builder.
  final Widget Function(T, SelectableViewMode)? leadingBuilder;

  /// Floating action button (only shown in active mode).
  final Widget? floatingActionButton;

  const SelectableListView({
    super.key,
    required this.title,
    required this.dao,
    required this.activeData,
    required this.archivedData,
    required this.getId,
    required this.getName,
    required this.getCreatedAt,
    required this.getUpdatedAt,
    this.onSelect,
    this.isSelected,
    this.beforeArchive,
    this.beforeDelete,
    this.cleanupOnDelete,
    this.leadingBuilder,
    this.floatingActionButton,
  });

  @override
  ConsumerState<SelectableListView<T>> createState() =>
      _SelectableListViewState<T>();
}

class _SelectableListViewState<T> extends ConsumerState<SelectableListView<T>> {
  SelectableViewMode _viewMode = SelectableViewMode.active;
  final _viewMenuController = ShadPopoverController();

  @override
  void dispose() {
    _viewMenuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final data = _viewMode == SelectableViewMode.active
        ? widget.activeData
        : widget.archivedData;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _viewMode == SelectableViewMode.active
              ? widget.title
              : 'Archived ${widget.title}',
        ),
        actions: [
          ShadContextMenu(
            controller: _viewMenuController,
            items: [
              ShadContextMenuItem(
                leading: Icon(
                  _viewMode == SelectableViewMode.active
                      ? LucideIcons.archive
                      : LucideIcons.list,
                  size: 16,
                ),
                child: Text(
                  _viewMode == SelectableViewMode.active
                      ? 'Show archived'
                      : 'Show active',
                ),
                onPressed: () {
                  setState(() {
                    _viewMode = _viewMode == SelectableViewMode.active
                        ? SelectableViewMode.archived
                        : SelectableViewMode.active;
                  });
                  _viewMenuController.toggle();
                },
              ),
            ],
            child: ShadButton.ghost(
              width: 32,
              height: 32,
              padding: EdgeInsets.zero,
              decoration: const ShadDecoration(border: ShadBorder.none),
              onPressed: _viewMenuController.toggle,
              child: const Icon(LucideIcons.ellipsisVertical, size: 16),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: data.when(
        data: (items) {
          if (items.isEmpty) {
            return EmptyPlaceholder(
              icon: _viewMode == SelectableViewMode.active
                  ? LucideIcons.inbox
                  : LucideIcons.archive,
              title: _viewMode == SelectableViewMode.active
                  ? 'No ${widget.title.toLowerCase()}'
                  : 'No archived ${widget.title.toLowerCase()}',
              subtitle: _viewMode == SelectableViewMode.active
                  ? 'Create a new one to get started'
                  : 'Archived items will appear here',
            );
          }

          final sortedItems = List<T>.from(items);

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: sortedItems.length,
            itemBuilder: (context, index) {
              final item = sortedItems[index];
              return _SelectableListItem<T>(
                key: ValueKey(widget.getId(item)),
                item: item,
                viewMode: _viewMode,
                widget: widget,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text(
            'Error: $error',
            style: TextStyle(color: theme.colorScheme.destructive),
          ),
        ),
      ),
      floatingActionButton: _viewMode == SelectableViewMode.active
          ? widget.floatingActionButton
          : null,
    );
  }
}

class _SelectableListItem<T> extends ConsumerStatefulWidget {
  final T item;
  final SelectableViewMode viewMode;
  final SelectableListView<T> widget;

  const _SelectableListItem({
    super.key,
    required this.item,
    required this.viewMode,
    required this.widget,
  });

  @override
  ConsumerState<_SelectableListItem<T>> createState() =>
      _SelectableListItemState<T>();
}

class _SelectableListItemState<T>
    extends ConsumerState<_SelectableListItem<T>> {
  final _menuController = ShadPopoverController();

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final id = widget.widget.getId(widget.item);
    final name = widget.widget.getName(widget.item);
    final isSelected = widget.widget.isSelected?.call(widget.item) ?? false;

    // Date display
    final dateDisplay = DateFormatter.format(
      widget.widget.getUpdatedAt(widget.item),
    );
    final relativeTime = DateFormatter.formatRelative(
      widget.widget.getUpdatedAt(widget.item),
    );

    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        if (widget.viewMode == SelectableViewMode.active) {
          await widget.widget.beforeArchive?.call(widget.item);
          await widget.widget.dao.archiveItem(id);
        } else {
          await widget.widget.dao.unarchiveItem(id);
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
              widget.widget.onSelect?.call(widget.item);
            },
            child: Row(
              children: [
                if (widget.widget.leadingBuilder != null) ...[
                  widget.widget.leadingBuilder!(widget.item, widget.viewMode),
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
    final id = widget.widget.getId(widget.item);
    final name = widget.widget.getName(widget.item);
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
        ),
      ),
    );

    controller.dispose();

    if (newName != null && newName.isNotEmpty && newName != name) {
      await widget.widget.dao.renameItem(id, newName);
    }
  }

  Future<void> _handleArchive() async {
    final id = widget.widget.getId(widget.item);
    final name = widget.widget.getName(widget.item);

    await widget.widget.beforeArchive?.call(widget.item);
    await widget.widget.dao.archiveItem(id);
    if (!mounted) return;

    ShadToaster.of(context).show(
      ShadToast(
        description: Text('Archived: $name'),
        action: ShadButton.outline(
          child: const Text('Undo'),
          onPressed: () => widget.widget.dao.unarchiveItem(id),
        ),
      ),
    );
  }

  Future<void> _handleUnarchive() async {
    final id = widget.widget.getId(widget.item);
    final name = widget.widget.getName(widget.item);

    await widget.widget.dao.unarchiveItem(id);
    if (!mounted) return;

    ShadToaster.of(
      context,
    ).show(ShadToast(description: Text('Restored: $name')));
  }

  Future<void> _handleDelete() async {
    final id = widget.widget.getId(widget.item);
    final name = widget.widget.getName(widget.item);

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
      await widget.widget.beforeDelete?.call(widget.item);
      await widget.widget.cleanupOnDelete?.call(widget.item);
      await widget.widget.dao.deleteItem(id);
      if (!mounted) return;

      ShadToaster.of(
        context,
      ).show(ShadToast(description: Text('Deleted: $name')));
    }
  }
}
