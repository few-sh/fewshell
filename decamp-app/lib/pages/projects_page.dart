import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decamp/providers/project_provider.dart';
import 'package:decamp/providers/database_provider.dart';
import 'package:decamp/themes/terminal_theme.dart';
import 'package:decamp/components/expandable_code_block.dart';
import '../utils/date_formatter.dart';
import '../utils/project_utils.dart';
import '../pages/main_settings.dart';

class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  static const _descriptors = [
    'Analog',
    'Binary',
    'Copper',
    'Crystal',
    'Dynamo',
    'Fiber',
    'Iron',
    'Static',
    'Steam',
    'Turing',
    'Wired',
    'Turbo',
  ];

  static const _objects = [
    'Abacus',
    'Core',
    'ENIAC',
    'Relay',
    'Radar',
    'RISC',
    'Chip',
    'Vacuum',
  ];

  String _generateUniqueName(List<String> existingNames) {
    final random = Random();
    String name;
    int attempts = 0;
    const maxAttempts = 1000;

    do {
      final descriptor = _descriptors[random.nextInt(_descriptors.length)];
      final object = _objects[random.nextInt(_objects.length)];
      name = '$descriptor$object';
      attempts++;

      if (attempts >= maxAttempts) {
        // Fallback: append a number
        name = '$descriptor${random.nextInt(99)}';
        break;
      }
    } while (existingNames.contains(name) || name.length > 12);

    return name;
  }

  Future<void> _createProjectWithRandomName(
    BuildContext context,
    WidgetRef ref,
    List<String> existingNames,
  ) async {
    final name = _generateUniqueName(existingNames);
    final projectDao = ref.read(databaseProvider).projectDao;

    try {
      final projectId = await projectDao.createProjectWithId(name: name);
      await selectProject(ref, projectId);

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MainSettingsPage()),
        );
      }
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
    // Watch the projects stream
    final projectsAsync = ref.watch(projectsStreamProvider);
    final terminalTheme = Theme.of(context).extension<TerminalTheme>()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: projectsAsync.when(
        data: (projects) {
          if (projects.isEmpty) {
            return Center(
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
                    padding: const EdgeInsets.symmetric(horizontal: 32),
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
                  const SizedBox(height: 12),
                  Text(
                    'fewshell will:\n1. get your host\'s IP address\n2. create new ssh keys\n3. select LLM provider and key',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _createProjectWithRandomName(
                      context,
                      ref,
                      projects.map((p) => p.name).toList(),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Your First Project'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              final absoluteDateTime = DateFormatter.formatAbsoluteDateTime(
                project.lastSessionDate,
              );
              final relativeTime = DateFormatter.formatRelativeTime(
                project.lastSessionDate,
              );

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  title: Text(
                    project.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (project.description != null &&
                            project.description!.isNotEmpty) ...[
                          Text(
                            project.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          'Last session: $absoluteDateTime',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          relativeTime,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.5),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => showDeleteProjectDialog(
                      context: context,
                      ref: ref,
                      projectId: project.id,
                      projectName: project.name,
                    ),
                    tooltip: 'Delete project',
                  ),
                  onTap: () async {
                    // Select this project and navigate back
                    await selectProject(ref, project.id);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Switched to project: ${project.name}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading projects',
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: projectsAsync.when(
        data: (projects) => projects.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _createProjectWithRandomName(
                  context,
                  ref,
                  projects.map((p) => p.name).toList(),
                ),
                icon: const Icon(Icons.add),
                label: const Text('New Project'),
              ),
        loading: () => null,
        error: (_, __) => null,
      ),
    );
  }
}
