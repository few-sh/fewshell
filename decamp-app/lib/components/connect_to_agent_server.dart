import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:decamp/services/sync_service.dart';

class ConnectToAgentServerDialog extends ConsumerStatefulWidget {
  const ConnectToAgentServerDialog({super.key});

  static void show(BuildContext context) {
    showShadDialog(
      context: context,
      builder: (context) => const ConnectToAgentServerDialog(),
    );
  }

  @override
  ConsumerState<ConnectToAgentServerDialog> createState() =>
      _ConnectToAgentServerDialogState();
}

class _ConnectToAgentServerDialogState
    extends ConsumerState<ConnectToAgentServerDialog> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShadDialog(
      title: const Text('Connect to Agent Server'),
      actions: [
        ShadButton.outline(
          enabled: !_isLoading,
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ShadButton(
          enabled: !_isLoading,
          onPressed: _isLoading
              ? null
              : () async {
                  final url = _controller.text.trim();
                  if (url.isEmpty) return;

                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });

                  try {
                    await ref.read(syncServiceProvider).connectGlobal(url);
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  } catch (e) {
                    if (!context.mounted) return;
                    setState(() {
                      _errorMessage = 'Connection Failed: $e';
                    });
                  } finally {
                    if (mounted) {
                      setState(() => _isLoading = false);
                    }
                  }
                },
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Connect'),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter the remote URL for global sync:'),
          const SizedBox(height: 10),
          ShadInput(
            controller: _controller,
            placeholder: const Text('wss://...'),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: ShadTheme.of(context).colorScheme.destructive,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
