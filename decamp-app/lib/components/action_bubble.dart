import 'package:flutter/material.dart';

/// Custom chat bubble for action execution with inline editing and approval
class ActionBubble extends StatefulWidget {
  final String actionName;
  final Map<String, dynamic> params;
  final Function(String actionName, Map<String, dynamic> params) onExecute;
  final VoidCallback? onCancel;

  const ActionBubble({
    super.key,
    required this.actionName,
    required this.params,
    required this.onExecute,
    this.onCancel,
  });

  @override
  State<ActionBubble> createState() => _ActionBubbleState();
}

class _ActionBubbleState extends State<ActionBubble> {
  late TextEditingController _commandController;
  late TextEditingController _explanationController;
  bool _isExecuting = false;
  bool _isCompleted = false;
  String? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _commandController = TextEditingController(
      text: widget.params['command']?.toString() ?? '',
    );
    _explanationController = TextEditingController(
      text: widget.params['explanation']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _commandController.dispose();
    _explanationController.dispose();
    super.dispose();
  }

  Future<void> _handleExecute() async {
    setState(() {
      _isExecuting = true;
      _error = null;
    });

    try {
      // Get updated parameters
      final updatedParams = {
        ...widget.params,
        'command': _commandController.text,
        'explanation': _explanationController.text,
      };

      // Execute the action
      await widget.onExecute(widget.actionName, updatedParams);

      setState(() {
        _isCompleted = true;
        _isExecuting = false;
        _result = 'Command executed successfully';
      });
    } catch (e) {
      setState(() {
        _isExecuting = false;
        _error = e.toString();
      });
    }
  }

  void _handleCancel() {
    widget.onCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Show result if completed
    if (_isCompleted) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        color: colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Command Executed',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: SelectableText(
                  _commandController.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              if (_result != null) ...[
                const SizedBox(height: 8),
                Text(
                  _result!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Show error if failed
    if (_error != null) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        color: colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error, color: colorScheme.error),
                  const SizedBox(width: 8),
                  Text(
                    'Execution Failed',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SelectableText(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                  });
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    // Show editable form
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.terminal, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Shell Command',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_isExecuting)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(colorScheme.primary),
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
                labelText: 'Explanation',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: colorScheme.surface,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            // Command field (editable)
            TextField(
              controller: _commandController,
              enabled: !_isExecuting,
              decoration: InputDecoration(
                labelText: 'Command',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: colorScheme.surface,
                prefixText: '\$ ',
                prefixStyle: TextStyle(
                  fontFamily: 'monospace',
                  color: colorScheme.primary,
                ),
              ),
              style: const TextStyle(fontFamily: 'monospace'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isExecuting ? null : _handleCancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isExecuting ? null : _handleExecute,
                  icon: _isExecuting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(_isExecuting ? 'Running...' : 'Run'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
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
