import 'package:decamp/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection_progress_dialog.dart';
import 'ssh_settings_dialog.dart';

/// Helper class that opens the SSH tunnel configuration, then connects
/// to the remote agent and sets up the session.
class ConnectToAgentServerDialog {
  /// Opens the SSH tunnel dialog first, then on save triggers the
  /// connection flow in a progress dialog.
  static void show(BuildContext context, WidgetRef ref) {
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
}
