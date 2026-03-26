import 'package:decamp/providers/providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:decamp/utils/project_utils.dart';
import 'package:decamp/pages/main_settings.dart';
import 'package:decamp/components/connect_to_agent_server.dart';

class ProjectSetupView extends ConsumerWidget {
  const ProjectSetupView({super.key});

  Future<void> _createProjectWithRandomName(
    BuildContext context,
    WidgetRef ref,
    List<String> existingNames,
  ) async {
    final name = generateUniqueProjectName(existingNames);
    final projectDao = ref.read(databaseProvider).projectDao;

    try {
      // Capture navigator before selecting project
      final navigator = Navigator.of(context, rootNavigator: true);
      final projectNotifier = ref.read(currentProjectIdProvider.notifier);

      final projectId = await projectDao.createProjectWithId(name: name);

      // Don't await select to avoid blocking UI if DB init takes time
      projectNotifier.select(projectId);

      await navigator.push(
        MaterialPageRoute(builder: (context) => const MainSettingsPage()),
      );
    } catch (e) {
      if (context.mounted) {
        ShadToaster.of(context).show(
          ShadToast(
            description: Text('Error creating project: $e'),
            action: ShadButton.destructive(
              child: const Text('Dismiss'),
              onPressed: () => ShadToaster.of(context).hide(),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsStreamProvider);
    final theme = ShadTheme.of(context);

    return projectsAsync.when(
      data: (projects) {
        final existingNames = projects.map((p) => p.name).toList();

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.folderOpen,
                  size: 64,
                  color: theme.colorScheme.mutedForeground.withValues(
                    alpha: 0.3,
                  ),
                ),
                ShadButton.outline(
                  onPressed: () =>
                      ConnectToAgentServerDialog.show(context, ref),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(LucideIcons.globe),
                      SizedBox(width: 8),
                      Text('Connect via SSH'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 16),
                if (kDebugMode)
                  ShadButton.outline(
                    onPressed: () => _createProjectWithRandomName(
                      context,
                      ref,
                      existingNames,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(LucideIcons.pencil),
                        SizedBox(width: 8),
                        Text('Enter Manually'),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }
}
