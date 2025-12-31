import 'package:flutter/material.dart';
import 'package:agent_core/agent_core.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Overlay widget that shows multiple tool action approvals in a scrollable list
/// Returns selected actions when approved, null when cancelled
class MultiCommandApprovalOverlay extends StatefulWidget {
  final List<ToolAction> actions;

  const MultiCommandApprovalOverlay({super.key, required this.actions});

  /// Show the overlay and await user selection
  static Future<List<ToolAction>?> show(
    BuildContext context,
    List<ToolAction> actions,
  ) async {
    return await showShadSheet<List<ToolAction>>(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (context) => MultiCommandApprovalOverlay(actions: actions),
    );
  }

  /// Test method to show the overlay with placeholder data
  static Future<void> showTest(BuildContext context) async {
    final actions = [
      ToolAction(
        id: '1',
        toolName: 'run_in_terminal',
        params: {
          'command': 'ls -la',
          'explanation': 'List all files in the current directory',
        },
        isSelected: true,
      ),
      ToolAction(
        id: '2',
        toolName: 'fetch_webpage',
        params: {
          'url': 'https://example.com',
          'method': 'GET',
          'explanation': 'Fetch the example.com homepage',
        },
        isSelected: true,
      ),
      ToolAction(
        id: '3',
        toolName: 'run_in_terminal',
        params: {
          'command': 'sudo rm -rf /',
          'explanation': 'Dangerous command requiring privileges',
          'sudo_required': true,
        },
        isSelected: false,
      ),
      ToolAction(
        id: '4',
        toolName: 'custom_tool',
        params: {'explanation': 'A custom tool action'},
        isSelected: true,
      ),
    ];

    final result = await show(context, actions);
    if (context.mounted) {
      if (result != null) {
        ShadToaster.of(context).show(
          ShadToast(
            title: const Text('Approved'),
            description: Text('Approved ${result.length} actions'),
          ),
        );
      } else {
        ShadToaster.of(context).show(
          const ShadToast(
            title: Text('Cancelled'),
            description: Text('Operation cancelled'),
          ),
        );
      }
    }
  }

  @override
  State<MultiCommandApprovalOverlay> createState() =>
      _MultiCommandApprovalOverlayState();
}

class _MultiCommandApprovalOverlayState
    extends State<MultiCommandApprovalOverlay> {
  void _handleApprove() {
    final selectedActions = widget.actions
        .where((action) => action.isSelected)
        .toList();

    if (selectedActions.isEmpty) {
      if (mounted) {
        ShadToaster.of(context).show(
          const ShadToast(
            title: Text('Error'),
            description: Text('Please select at least one action'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    Navigator.of(context).pop(selectedActions);
  }

  void _handleCancel() {
    Navigator.of(context).pop(null);
  }

  void _toggleSelectAll(bool value) {
    if (!mounted) return;
    setState(() {
      for (final action in widget.actions) {
        action.isSelected = value;
      }
    });
  }

  int get _selectedCount => widget.actions.where((a) => a.isSelected).length;
  int get _privilegedCount =>
      widget.actions.where((a) => a.requiresPrivileges).length;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final allSelected = widget.actions.every((a) => a.isSelected);

    return ShadSheet(
      title: Row(
        children: [
          Icon(LucideIcons.wrench, color: theme.colorScheme.primary, size: 24),
          const SizedBox(width: 12),
          const Text('Tool Execution Request'),
        ],
      ),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review and approve actions ($_selectedCount of ${widget.actions.length} selected)',
          ),
          if (_privilegedCount > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  LucideIcons.shieldAlert,
                  size: 16,
                  color: theme.colorScheme.destructive,
                ),
                const SizedBox(width: 4),
                Text(
                  '$_privilegedCount ${_privilegedCount == 1 ? 'action requires' : 'actions require'} elevated privileges',
                  style: TextStyle(
                    color: theme.colorScheme.destructive,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Select All checkbox
            Row(
              children: [
                ShadCheckbox(value: allSelected, onChanged: _toggleSelectAll),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _toggleSelectAll(!allSelected),
                  child: const Text(
                    'Select All',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Scrollable list of commands
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.actions.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final action = widget.actions[index];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        action.isSelected = !action.isSelected;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.border),
                        borderRadius: BorderRadius.circular(8),
                        color: action.requiresPrivileges
                            ? theme.colorScheme.destructive.withValues(
                                alpha: 0.05,
                              )
                            : theme.colorScheme.secondary.withValues(
                                alpha: 0.1,
                              ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShadCheckbox(
                            value: action.isSelected,
                            onChanged: (value) {
                              setState(() {
                                action.isSelected = value;
                              });
                            },
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (action.requiresPrivileges) ...[
                                      Icon(
                                        LucideIcons.shieldAlert,
                                        size: 16,
                                        color: theme.colorScheme.destructive,
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    if (action.params['command'] != null)
                                      Text(
                                        action.requiresPrivileges
                                            ? 'sudo \$ '
                                            : '\$ ',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 14,
                                          color: action.requiresPrivileges
                                              ? theme.colorScheme.destructive
                                              : theme.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        action.primaryDisplay,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (action.explanation.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    action.explanation,
                                    style: theme.textTheme.muted,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ShadButton.outline(
                  onPressed: _handleCancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ShadButton(
                  onPressed: _handleApprove,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.play, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Run ${_selectedCount > 1 ? '$_selectedCount Actions' : 'Action'}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
