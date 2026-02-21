import 'package:decamp/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
        // After tunnel is saved, show the connection progress dialog
        if (!context.mounted) return;
        showShadDialog(
          context: context,
          builder: (context) =>
              _TunnelConnectProgressDialog(tunnelId: tunnelId),
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

/// Progress dialog shown after tunnel config is saved.
/// Connects via SSH tunnel, waits for sync, finds/switches to a project.
class _TunnelConnectProgressDialog extends ConsumerStatefulWidget {
  final String tunnelId;

  const _TunnelConnectProgressDialog({required this.tunnelId});

  @override
  ConsumerState<_TunnelConnectProgressDialog> createState() =>
      _TunnelConnectProgressDialogState();
}

class _TunnelConnectProgressDialogState
    extends ConsumerState<_TunnelConnectProgressDialog> {
  bool _isLoading = true;
  String? _errorMessage;
  String _statusMessage = 'Connecting via SSH tunnel...';

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      final syncService = ref.read(syncServiceProvider);
      await syncService.connectViaTunnel(
        widget.tunnelId,
        onStatus: (message) {
          if (mounted) setState(() => _statusMessage = message);
        },
      );

      if (!mounted) return;
      Navigator.of(context).pop();
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
      title: const Text('Connecting to Agent'),
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
                _statusMessage = 'Connecting via SSH tunnel...';
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
