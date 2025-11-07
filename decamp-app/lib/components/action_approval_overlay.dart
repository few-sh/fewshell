import 'package:flutter/material.dart';

/// Overlay widget that shows action approval UI inline in the chat
class ActionApprovalOverlay extends StatefulWidget {
  final String actionName;
  final Map<String, dynamic> params;
  final Future<void> Function(String actionName, Map<String, dynamic> params)
  onExecute;
  final VoidCallback onDismiss;

  const ActionApprovalOverlay({
    super.key,
    required this.actionName,
    required this.params,
    required this.onExecute,
    required this.onDismiss,
  });

  @override
  State<ActionApprovalOverlay> createState() => _ActionApprovalOverlayState();
}

class _ActionApprovalOverlayState extends State<ActionApprovalOverlay>
    with SingleTickerProviderStateMixin {
  late TextEditingController _commandController;
  late TextEditingController _explanationController;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  bool _isExecuting = false;

  @override
  void initState() {
    super.initState();
    _commandController = TextEditingController(
      text: widget.params['command']?.toString() ?? '',
    );
    _explanationController = TextEditingController(
      text: widget.params['explanation']?.toString() ?? '',
    );

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
    _commandController.dispose();
    _explanationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleExecute() async {
    setState(() => _isExecuting = true);

    try {
      final updatedParams = {
        ...widget.params,
        'command': _commandController.text,
        'explanation': _explanationController.text,
      };

      await widget.onExecute(widget.actionName, updatedParams);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(_slideAnimation),
      child: Container(
        padding: const EdgeInsets.all(16),
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
              Row(
                children: [
                  Icon(Icons.terminal, color: colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Shell Command Request',
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
              const SizedBox(height: 16),

              // Explanation field
              TextField(
                controller: _explanationController,
                enabled: !_isExecuting,
                decoration: InputDecoration(
                  labelText: 'What this command does',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              // Command field (editable)
              TextField(
                controller: _commandController,
                enabled: !_isExecuting,
                decoration: InputDecoration(
                  labelText: 'Shell Command',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  prefixText: '\$ ',
                  prefixStyle: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
                maxLines: 3,
                autofocus: true,
              ),
              const SizedBox(height: 16),

              // Action buttons
              Row(
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
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.play_arrow, size: 24),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      child: Text(
                        _isExecuting ? 'Executing...' : 'Run Command',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
