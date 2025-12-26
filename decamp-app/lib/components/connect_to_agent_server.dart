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
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ShadButton(
          child: const Text('Connect'),
          onPressed: () {
            final url = _controller.text.trim();
            if (url.isNotEmpty) {
              ref.read(syncServiceProvider).connectGlobal(url);
            }
            Navigator.of(context).pop();
          },
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
        ],
      ),
    );
  }
}
