import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:decamp/providers/project_provider.dart';
import 'package:decamp/providers/database_provider.dart';
import 'package:decamp/themes/terminal_theme.dart';
import 'package:decamp/components/expandable_code_block.dart';
import 'package:decamp/utils/project_utils.dart';
import 'package:decamp/pages/main_settings.dart';
import 'package:decamp/pages/qr_scanner_page.dart';
import 'package:decamp/services/project_importer.dart';
import 'package:decamp/components/connect_to_agent_server.dart';

class ProjectSetupView extends ConsumerWidget {
  const ProjectSetupView({super.key});

  Future<void> _handleScanQrCode(
    BuildContext context,
    WidgetRef ref,
    List<String> existingNames,
  ) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final jsonString = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => const QrScannerPage()),
      );

      if (jsonString != null && context.mounted) {
        if (jsonString.isEmpty) {
          await _createProjectWithRandomName(context, ref, existingNames);
          return;
        }

        try {
          final importer = ref.read(projectImporterProvider);
          // Capture navigator and notifier before async operation
          final navigator = Navigator.of(context, rootNavigator: true);
          final projectNotifier = ref.read(currentProjectIdProvider.notifier);

          final projectId = await importer.importFromQrCode(jsonString);

          // Don't await select to avoid blocking UI if DB init takes time
          projectNotifier.select(projectId);

          await navigator.push(
            MaterialPageRoute(builder: (context) => const MainSettingsPage()),
          );
        } catch (e) {
          if (context.mounted) {
            ShadToaster.of(context).show(
              ShadToast(
                description: Text('Error importing project: $e'),
                action: ShadButton.destructive(
                  child: const Text('Dismiss'),
                  onPressed: () => ShadToaster.of(context).hide(),
                ),
              ),
            );
          }
        }
      }
    } else {
      await _createProjectWithRandomName(context, ref, existingNames);
    }
  }

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
    final terminalTheme = Theme.of(context).extension<TerminalTheme>()!;
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
                const SizedBox(height: 16),
                Text(
                  'run this command from a host',
                  style: theme.textTheme.h4.copyWith(
                    color: theme.colorScheme.mutedForeground,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ExpandableCodeBlock(
                    code: 'curl -LsSf get.few.sh | bash',
                    language: 'bash',
                    heroTag: 'projects_setup_command',
                    terminalTheme: terminalTheme,
                    centered: true,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'then scan the QR code',
                  style: theme.textTheme.h4.copyWith(
                    color: theme.colorScheme.mutedForeground,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 24),
                ShadButton.outline(
                  onPressed: () =>
                      _handleScanQrCode(context, ref, existingNames),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(LucideIcons.qrCode),
                      SizedBox(width: 8),
                      Text('Scan QR Code'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ShadButton.outline(
                  onPressed: () =>
                      _createProjectWithRandomName(context, ref, existingNames),
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
                ShadButton.outline(
                  onPressed: () => ConnectToAgentServerDialog.show(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(LucideIcons.globe),
                      SizedBox(width: 8),
                      Text('Connect to Agent Server'),
                    ],
                  ),
                ),
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
