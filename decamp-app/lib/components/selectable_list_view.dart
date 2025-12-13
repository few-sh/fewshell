import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:decamp/components/empty_placeholder.dart';
import 'package:decamp/components/confirmation_dialog.dart';
import 'package:decamp/components/input_dialog.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        backgroundColor: theme.colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'toggle_view') {
                setState(() {
                  _viewMode = _viewMode == SelectableViewMode.active
                      ? SelectableViewMode.archived
                      : SelectableViewMode.active;
                });
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle_view',
                child: Row(
                  children: [
                    Icon(
                      _viewMode == SelectableViewMode.active
                          ? Icons.archive_outlined
                          : Icons.list,
                      color: theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _viewMode == SelectableViewMode.active
                          ? 'Show archived'
                          : 'Show active',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: data.when(
        data: (items) {
          if (items.isEmpty) {
            return EmptyPlaceholder(
              icon: _viewMode == SelectableViewMode.active
                  ? Icons.inbox
                  : Icons.archive_outlined,
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
            itemCount: sortedItems.length,
            itemBuilder: (context, index) {
              final item = sortedItems[index];
              return _buildCard(context, item);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text(
            'Error: $error',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      ),
      floatingActionButton: _viewMode == SelectableViewMode.active
          ? widget.floatingActionButton
          : null,
    );
  }

  Widget _buildCard(BuildContext context, T item) {
    final theme = Theme.of(context);
    final id = widget.getId(item);
    final name = widget.getName(item);
    final isSelected = widget.isSelected?.call(item) ?? false;

    // Date display
    final dateDisplay = DateFormatter.formatSessionDateRange(
      widget.getCreatedAt(item),
      widget.getUpdatedAt(item),
    );
    final relativeTime = DateFormatter.formatRelativeTime(
      widget.getUpdatedAt(item),
    );

    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        if (_viewMode == SelectableViewMode.active) {
          await widget.beforeArchive?.call(item);
          await widget.dao.archiveItem(id);
        } else {
          await widget.dao.unarchiveItem(id);
        }
        return true;
      },
      background: _buildDismissBackground(context),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: isSelected ? theme.colorScheme.primaryContainer : null,
        child: ListTile(
          leading: widget.leadingBuilder?.call(item, _viewMode),
          title: Text(
            name,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurface,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateDisplay,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected
                        ? theme.colorScheme.onPrimaryContainer.withValues(
                            alpha: 0.7,
                          )
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  relativeTime,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.primary,
                  ),
                ),
                if (isSelected) _buildActiveIndicator(context),
              ],
            ),
          ),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(value, item),
            itemBuilder: (context) => _buildMenuItems(),
          ),
          onTap: () {
            if (_viewMode == SelectableViewMode.archived) return;
            widget.onSelect?.call(item);
          },
        ),
      ),
    );
  }

  // --- Inlined helpers ---

  Widget _buildDismissBackground(BuildContext context) {
    final theme = Theme.of(context);
    final color = _viewMode == SelectableViewMode.active
        ? theme.colorScheme.secondary
        : theme.colorScheme.primary;

    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      color: color,
      child: Icon(
        _viewMode == SelectableViewMode.active
            ? Icons.archive
            : Icons.unarchive,
        color: Colors.white,
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems() {
    return [
      const PopupMenuItem(
        value: 'rename',
        child: Row(
          children: [
            Icon(Icons.edit, size: 18),
            SizedBox(width: 12),
            Text('Rename'),
          ],
        ),
      ),
      if (_viewMode == SelectableViewMode.active)
        const PopupMenuItem(
          value: 'archive',
          child: Row(
            children: [
              Icon(Icons.archive_outlined, size: 18),
              SizedBox(width: 12),
              Text('Archive'),
            ],
          ),
        )
      else
        const PopupMenuItem(
          value: 'unarchive',
          child: Row(
            children: [
              Icon(Icons.unarchive_outlined, size: 18),
              SizedBox(width: 12),
              Text('Unarchive'),
            ],
          ),
        ),
      const PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete_outline, size: 18, color: Colors.red),
            SizedBox(width: 12),
            Text('Delete', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ];
  }

  Widget _buildActiveIndicator(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 14,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 4),
          Text(
            'Active',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenuAction(String action, T item) async {
    final id = widget.getId(item);
    final name = widget.getName(item);

    switch (action) {
      case 'rename':
        final newName = await showInputDialog(
          context: context,
          title: 'Rename',
          label: 'Name',
          initialValue: name,
          confirmLabel: 'Rename',
        );
        if (newName != null && newName.isNotEmpty && newName != name) {
          await widget.dao.renameItem(id, newName);
        }
        break;

      case 'archive':
        await widget.beforeArchive?.call(item);
        await widget.dao.archiveItem(id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Archived: $name'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => widget.dao.unarchiveItem(id),
            ),
          ),
        );
        break;

      case 'unarchive':
        await widget.dao.unarchiveItem(id);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Restored: $name')));
        break;

      case 'delete':
        final confirmed = await showConfirmationDialog(
          context: context,
          title: 'Delete?',
          content:
              'Are you sure you want to delete "$name"? This cannot be undone.',
        );
        if (confirmed == true) {
          await widget.beforeDelete?.call(item);
          await widget.cleanupOnDelete?.call(item);
          await widget.dao.deleteItem(id);
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Deleted: $name')));
        }
        break;
    }
  }
}
