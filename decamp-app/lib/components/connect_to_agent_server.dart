import 'package:decamp/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:agent_core/agent_core.dart';
import 'package:decamp/services/sync_service.dart';

import '../utils/ui_utils.dart';

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
  String? _statusMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _connectAndSetupSession(String url) async {
    final syncService = ref.read(syncServiceProvider);
    await syncService.connectGlobal(url);

    if (!mounted) return;
    setState(() => _statusMessage = 'Waiting for global sync...');
    await syncService.waitForGlobalSync();

    if (!mounted) return;
    setState(() => _statusMessage = 'Checking projects...');
    final globalDb = ref.read(globalDatabaseProvider);

    // Filter projects by URL
    final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;

    List<ProjectEntity> matchingProjects = [];
    // Poll for projects for up to 10 seconds (20 attempts * 500ms)
    for (int i = 0; i < 20; i++) {
      if (!mounted) return;

      final projects = await globalDb.projectDao.getAllProjects();

      matchingProjects = projects.where((p) {
        final pUrl = p.serverUrl;
        if (pUrl == null) return false;
        final cleanPUrl = pUrl.endsWith('/')
            ? pUrl.substring(0, pUrl.length - 1)
            : pUrl;
        return cleanPUrl == cleanUrl;
      }).toList();

      if (matchingProjects.isNotEmpty) break;

      setState(
        () => _statusMessage = 'Waiting for projects to sync... (${i + 1}/20)',
      );
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (matchingProjects.isEmpty) {
      throw Exception('No projects found matching $url');
    }

    if (matchingProjects.isNotEmpty) {
      final currentProject = ref.read(currentProjectProvider);
      bool shouldSwitch = false;

      if (currentProject == null) {
        shouldSwitch = true;
      } else {
        final currentUrl = currentProject.serverUrl;
        if (currentUrl == null) {
          shouldSwitch = true;
        } else {
          final cleanCurrentUrl = currentUrl.endsWith('/')
              ? currentUrl.substring(0, currentUrl.length - 1)
              : currentUrl;
          if (cleanCurrentUrl != cleanUrl) {
            shouldSwitch = true;
          }
        }
      }

      if (shouldSwitch) {
        // Pick latest project (already ordered by lastSessionDate desc in getAllProjects)
        final targetProject = matchingProjects.first;
        if (!mounted) return;
        setState(
          () =>
              _statusMessage = 'Switching to project ${targetProject.name}...',
        );
        await ref
            .read(currentProjectIdProvider.notifier)
            .select(targetProject.id);

        // Wait for project sync
        if (!mounted) return;
        setState(() => _statusMessage = 'Waiting for project sync...');
        // Allow time for the sync service to react to the project change
        await Future.delayed(const Duration(milliseconds: 200));
        await syncService.waitForProjectSync();
      }
    }
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
                    _statusMessage = 'Connecting...';
                  });

                  try {
                    await _connectAndSetupSession(url);
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  } catch (e) {
                    if (!context.mounted) return;
                    setState(() {
                      _errorMessage = 'Connection Failed: $e';
                      _statusMessage = null;
                    });
                  } finally {
                    if (mounted) {
                      setState(() => _isLoading = false);
                    }
                  }
                },
          child: _isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                      ShadTheme.of(context).colorScheme.primaryForeground,
                    ),
                  ),
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
            contextMenuBuilder: adaptiveContextMenuBuilder,
            controller: _controller,
            placeholder: const Text('wss://...'),
            autocorrect: false,
            enabled: !_isLoading,
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _statusMessage!,
              style: TextStyle(
                color: ShadTheme.of(context).colorScheme.mutedForeground,
                fontSize: 14,
              ),
            ),
          ],
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
