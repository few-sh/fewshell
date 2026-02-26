import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Generic progress dialog for connection operations.
/// Shows a spinner with status text, and retry/cancel buttons on error.
class ConnectionProgressDialog extends StatefulWidget {
  final String title;
  final String initialStatus;
  final Future<void> Function(void Function(String) onStatus) connect;

  const ConnectionProgressDialog({
    super.key,
    this.title = 'Connecting to Agent',
    this.initialStatus = 'Connecting...',
    required this.connect,
  });

  /// Shows the dialog and runs the connect function.
  static Future<bool?> show(
    BuildContext context, {
    String title = 'Connecting to Agent',
    String initialStatus = 'Connecting...',
    required Future<void> Function(void Function(String) onStatus) connect,
  }) {
    return showShadDialog<bool>(
      context: context,
      builder: (context) => ConnectionProgressDialog(
        title: title,
        initialStatus: initialStatus,
        connect: connect,
      ),
    );
  }

  @override
  State<ConnectionProgressDialog> createState() =>
      _ConnectionProgressDialogState();
}

class _ConnectionProgressDialogState extends State<ConnectionProgressDialog> {
  bool _isLoading = true;
  String? _errorMessage;
  late String _statusMessage;

  @override
  void initState() {
    super.initState();
    _statusMessage = widget.initialStatus;
    _connect();
  }

  Future<void> _connect() async {
    try {
      await widget.connect((message) {
        if (mounted) setState(() => _statusMessage = message);
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Connection Failed: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return ShadDialog(
      title: Text(widget.title),
      actions: [
        if (_errorMessage != null) ...[
          ShadButton.outline(
            child: const Text('Close'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ShadButton(
            child: const Text('Retry'),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
                _statusMessage = widget.initialStatus;
              });
              _connect();
            },
          ),
        ] else
          ShadButton.outline(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoading)
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      color: theme.colorScheme.mutedForeground,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: theme.colorScheme.destructive,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
