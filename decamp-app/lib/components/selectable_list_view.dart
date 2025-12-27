import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decamp/components/empty_placeholder.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum SelectableViewMode { active, archived }

/// A unified list view for displaying listable entities (Projects, Sessions).
class SelectableListView<T> extends ConsumerStatefulWidget {
  /// Page title (e.g., "Projects" or "Sessions").
  final String title;

  /// Active (non-archived) items stream.
  final AsyncValue<List<T>> activeData;

  /// Archived items stream.
  final AsyncValue<List<T>> archivedData;

  /// Builder for list items.
  final Widget Function(BuildContext context, T item, SelectableViewMode mode)
  itemBuilder;

  /// Floating action button (only shown in active mode).
  final Widget? floatingActionButton;

  const SelectableListView({
    super.key,
    required this.title,
    required this.activeData,
    required this.archivedData,
    required this.itemBuilder,
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
    final data =
        _viewMode == SelectableViewMode.active
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
                    _viewMode =
                        _viewMode == SelectableViewMode.active
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
              icon:
                  _viewMode == SelectableViewMode.active
                      ? LucideIcons.inbox
                      : LucideIcons.archive,
              title:
                  _viewMode == SelectableViewMode.active
                      ? 'No ${widget.title.toLowerCase()}'
                      : 'No archived ${widget.title.toLowerCase()}',
              subtitle:
                  _viewMode == SelectableViewMode.active
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
              return widget.itemBuilder(context, item, _viewMode);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stack) => Center(
              child: Text(
                'Error: $error',
                style: TextStyle(color: theme.colorScheme.destructive),
              ),
            ),
      ),
      floatingActionButton:
          _viewMode == SelectableViewMode.active
              ? widget.floatingActionButton
              : null,
    );
  }
}
