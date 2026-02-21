import 'package:decamp/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'connection_progress_dialog.dart';
import 'ssh_settings_dialog.dart';

/// Dialog that opens the SSH tunnel configuration, then connects
/// to the remote agent and sets up the session.
class ConnectToAgentServerDialog extends ConsumerStatefulWidget {
  const ConnectToAgentServerDialog({super.key});

  static void show(BuildContext context) {
    showShadDialog(
      context: context,
      builder: (context) => const ConnectToAgentServerDialog(),
    );
  }

  /// Opens the SSH tunnel dialog first, then on save triggers the
  /// connection flow in a progress dialog.
  static void showWithTunnel(BuildContext context, WidgetRef ref) {
    SshSettingsDialog.showTunnel(
      context,
      ref,
      onSaved: (tunnelId) {
        if (!context.mounted) return;
        ConnectionProgressDialog.show(
          context,
          initialStatus: 'Connecting via SSH tunnel...',
          connect: (onStatus) async {
            final syncService = ref.read(syncServiceProvider);
            await syncService.connectViaTunnel(tunnelId, onStatus: onStatus);
          },
        );
      },
    );
  }

  @override
  ConsumerState<ConnectToAgentServerDialog> createState() =>
      _ConnectToAgentServerDialogState();
}

class _ConnectToAgentServerDialogState
    extends ConsumerState<ConnectToAgentServerDialog> {
  @override
  void initState() {
    super.initState();
    // Immediately open the tunnel dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close this empty dialog
      ConnectToAgentServerDialog.showWithTunnel(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Placeholder — immediately replaced by showWithTunnel
    return const SizedBox.shrink();
  }
}
