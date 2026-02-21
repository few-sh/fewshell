import 'package:decamp/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:agent_core/agent_core.dart';
import 'package:decamp/services/sync_service.dart';

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
      // TODO: Most of this function should probably live in the SyncService
      if (!mounted) return;
      setState(() => _statusMessage = 'Establishing SSH tunnel...');

      // Bootstrap: pass connection info directly so _connectGlobal can use it
      // without a saved mapping. The mapIncomingChangeset callback will
      // auto-save mappings for all discovered projects after sync.
      final syncService = ref.read(syncServiceProvider);
      await syncService.reconnectGlobal(
        connectionInfo: {'type': 'tunnel', 'tunnelId': widget.tunnelId},
      );

      if (!mounted) return;
      setState(() => _statusMessage = 'Waiting for global sync...');
      await syncService.waitForGlobalSync();

      if (!mounted) return;
      setState(() => _statusMessage = 'Checking projects...');

      // The server node ID is now known from the WebSocket upgrade header.
      final serverNodeId = syncService.currentServerNodeId;
      if (serverNodeId == null) {
        throw Exception('Server did not provide a node ID.');
      }

      final globalDb = ref.read(globalDatabaseProvider);
      List<ProjectEntity> matchingProjects = [];
      // Poll for projects for up to 10 seconds
      for (int i = 0; i < 20; i++) {
        if (!mounted) return;

        matchingProjects = await globalDb.projectDao.getProjectsByServerNodeId(
          serverNodeId,
        );

        if (matchingProjects.isNotEmpty) break;

        setState(
          () =>
              _statusMessage = 'Waiting for projects to sync... (${i + 1}/20)',
        );
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (matchingProjects.isEmpty) {
        throw Exception(
          'No projects found for this tunnel. '
          'Make sure the remote agent has a project configured.',
        );
      }

      // Switch to the matching project
      final targetProject = matchingProjects.first;
      if (!mounted) return;
      setState(
        () => _statusMessage = 'Switching to project ${targetProject.name}...',
      );
      await ref
          .read(currentProjectIdProvider.notifier)
          .select(targetProject.id);

      if (!mounted) return;
      setState(() => _statusMessage = 'Waiting for project sync...');
      await Future.delayed(const Duration(milliseconds: 200));
      await syncService.waitForProjectSync();

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
