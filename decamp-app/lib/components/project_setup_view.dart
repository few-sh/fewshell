import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decamp/providers/project_provider.dart';
import 'package:decamp/providers/database_provider.dart';
import 'package:decamp/themes/terminal_theme.dart';
import 'package:decamp/components/expandable_code_block.dart';
import 'package:decamp/utils/project_utils.dart';
import 'package:decamp/pages/main_settings.dart';
import 'package:decamp/pages/qr_scanner_page.dart';
import 'package:decamp/services/project_importer.dart';
import '../providers/project_selection_provider.dart';

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
          final projectId = await importer.importFromQrCode(jsonString);

          if (!context.mounted) return;

          // Capture navigator before selecting project
          final navigator = Navigator.of(context, rootNavigator: true);

          await selectProject(ref, projectId);

          await navigator.push(
            MaterialPageRoute(builder: (context) => const MainSettingsPage()),
          );
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error importing project: $e'),
                backgroundColor: Colors.red,
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
      final projectId = await projectDao.createProjectWithId(name: name);

      if (!context.mounted) return;

      // Capture navigator before selecting project
      final navigator = Navigator.of(context, rootNavigator: true);

      await selectProject(ref, projectId);

      await navigator.push(
        MaterialPageRoute(builder: (context) => const MainSettingsPage()),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating project: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsStreamProvider);
    final terminalTheme = Theme.of(context).extension<TerminalTheme>()!;

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
                  Icons.folder_open,
                  size: 64,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'run this command from a host',
                  style: TextStyle(
                    fontSize: 18,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
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
                  style: TextStyle(
                    fontSize: 18,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () =>
                      _handleScanQrCode(context, ref, existingNames),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR Code'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () =>
                      _createProjectWithRandomName(context, ref, existingNames),
                  icon: const Icon(Icons.edit),
                  label: const Text('Enter Manually'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
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
