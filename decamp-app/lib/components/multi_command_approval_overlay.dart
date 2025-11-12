import 'package:flutter/material.dart';

/// Represents a single command action with its parameters
class CommandAction {
  final String id;
  final String actionName;
  final Map<String, dynamic> params;
  bool isSelected;

  CommandAction({
    required this.id,
    required this.actionName,
    required this.params,
    this.isSelected = true, // Selected by default
  });

  String get command => params['command']?.toString() ?? 'unknown';
  String get explanation => params['explanation']?.toString() ?? '';
}

/// Overlay widget that shows multiple command approvals in a scrollable list
class MultiCommandApprovalOverlay extends StatefulWidget {
  final List<CommandAction> actions;
  final Future<void> Function(List<CommandAction> selectedActions) onExecute;
  final VoidCallback onDismiss;

  const MultiCommandApprovalOverlay({
    super.key,
    required this.actions,
    required this.onExecute,
    required this.onDismiss,
  });

  @override
  State<MultiCommandApprovalOverlay> createState() =>
      _MultiCommandApprovalOverlayState();
}

class _MultiCommandApprovalOverlayState
    extends State<MultiCommandApprovalOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  bool _isExecuting = false;

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

  Future<void> _handleExecute() async {
    final selectedActions = widget.actions
        .where((action) => action.isSelected)
        .toList();

    if (selectedActions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one command')),
      );
      return;
    }

    setState(() => _isExecuting = true);

    try {
      await widget.onExecute(selectedActions);
      await _animationController.reverse();
      widget.onDismiss();
    } catch (e) {
      setState(() => _isExecuting = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _handleCancel() async {
    await _animationController.reverse();
    widget.onDismiss();
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      for (final action in widget.actions) {
        action.isSelected = value ?? false;
      }
    });
  }

  int get _selectedCount => widget.actions.where((a) => a.isSelected).length;

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
                        Icon(
                          Icons.terminal,
                          color: colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Shell Commands Request',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (_isExecuting)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Review and approve commands ($_selectedCount of ${widget.actions.length} selected)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),

              // Select All checkbox
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CheckboxListTile(
                  value: allSelected,
                  tristate: !allSelected && !noneSelected,
                  onChanged: _isExecuting ? null : _toggleSelectAll,
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
                      onChanged: _isExecuting
                          ? null
                          : (value) {
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
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '\$ ',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                action.command,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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
                      onPressed: _isExecuting ? null : _handleCancel,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _isExecuting ? null : _handleExecute,
                      icon: _isExecuting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.play_arrow, size: 24),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: Text(
                          _isExecuting
                              ? 'Executing...'
                              : 'Run ${_selectedCount > 1 ? '$_selectedCount Commands' : 'Command'}',
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
