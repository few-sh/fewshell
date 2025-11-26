import 'package:flutter/material.dart';

/// Represents a single tool action with its parameters
class ToolAction {
  final String id;
  final String toolName;
  final Map<String, dynamic> params;
  bool isSelected;

  ToolAction({
    required this.id,
    required this.toolName,
    required this.params,
    this.isSelected = false, // Deselected by default
  });

  /// Primary display text - works for any tool type
  String get primaryDisplay {
    // For shell commands, show the command
    if (params['command'] != null) return params['command'].toString();
    // For fetch, show method + URL
    if (params['url'] != null) {
      final method = params['method']?.toString().toUpperCase() ?? 'GET';
      return '$method ${params['url']}';
    }
    // Fallback: show tool name
    return toolName;
  }

  String get explanation => params['explanation']?.toString() ?? '';
  bool get requiresPrivileges => params['sudo_required'] as bool? ?? false;
}

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
    return await showModalBottomSheet<List<ToolAction>>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => MultiCommandApprovalOverlay(actions: actions),
    );
  }

  @override
  State<MultiCommandApprovalOverlay> createState() =>
      _MultiCommandApprovalOverlayState();
}

class _MultiCommandApprovalOverlayState
    extends State<MultiCommandApprovalOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleApprove() {
    final selectedActions = widget.actions
        .where((action) => action.isSelected)
        .toList();

    if (selectedActions.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one action')),
        );
      }
      return;
    }

    Navigator.of(context).pop(selectedActions);
  }

  void _handleCancel() {
    Navigator.of(context).pop(null);
  }

  void _toggleSelectAll(bool? value) {
    if (!mounted) return;
    setState(() {
      for (final action in widget.actions) {
        action.isSelected = value ?? false;
      }
    });
  }

  int get _selectedCount => widget.actions.where((a) => a.isSelected).length;
  int get _privilegedCount =>
      widget.actions.where((a) => a.requiresPrivileges).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allSelected = widget.actions.every((a) => a.isSelected);
    final noneSelected = widget.actions.every((a) => !a.isSelected);

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(_slideAnimation),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.build, color: colorScheme.primary, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tool Execution Request',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Review and approve actions ($_selectedCount of ${widget.actions.length} selected)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    if (_privilegedCount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.security,
                            size: 16,
                            color: colorScheme.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_privilegedCount ${_privilegedCount == 1 ? 'action requires' : 'actions require'} elevated privileges',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Select All checkbox
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CheckboxListTile(
                  value: allSelected,
                  tristate: !allSelected && !noneSelected,
                  onChanged: _toggleSelectAll,
                  title: Text(
                    allSelected ? 'Deselect All' : 'Select All',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
              ),

              const Divider(height: 1),

              // Scrollable list of commands
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: widget.actions.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final action = widget.actions[index];
                    return CheckboxListTile(
                      value: action.isSelected,
                      onChanged: (value) {
                        setState(() {
                          action.isSelected = value ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: action.requiresPrivileges
                              ? colorScheme.error.withValues(alpha: 0.05)
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: action.requiresPrivileges
                              ? Border.all(
                                  color: colorScheme.error.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 1.5,
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            if (action.requiresPrivileges) ...[
                              Icon(
                                Icons.security,
                                size: 16,
                                color: colorScheme.error,
                              ),
                              const SizedBox(width: 4),
                            ],
                            if (action.params['command'] != null)
                              Text(
                                action.requiresPrivileges ? 'sudo \$ ' : '\$ ',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                  color: action.requiresPrivileges
                                      ? colorScheme.error
                                      : colorScheme.primary,
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
                      ),
                      subtitle: action.explanation.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8, left: 12),
                              child: Text(
                                action.explanation,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                            )
                          : null,
                    );
                  },
                ),
              ),

              const Divider(height: 1),

              // Action buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _handleCancel,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _handleApprove,
                      icon: const Icon(Icons.play_arrow, size: 24),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: Text(
                          'Run ${_selectedCount > 1 ? '$_selectedCount Actions' : 'Action'}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
