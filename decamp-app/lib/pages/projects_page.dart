import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decamp/providers/project_provider.dart';
import 'package:decamp/providers/database_provider.dart';
import 'package:decamp/themes/terminal_theme.dart';
import 'package:decamp/components/expandable_code_block.dart';
import '../utils/date_formatter.dart';
import '../pages/main_settings.dart';

class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  static const _descriptors = [
    'Analog',
    'Binary',
    'Copper',
    'Crystal',
    'Dynamo',
    'Electric',
    'Fiber',
    'Iron',
    'Quantum',
    'Relay',
    'Silicon',
    'Static',
    'Steam',
    'Turing',
    'Vacuum',
    'Vintage',
    'Wired',
    'Magnetic',
    'Solid-State',
    'Turbo',
  ];

  static const _objects = [
    'Abacus',
    'Babbage',
    'Calculator',
    'Colossus',
    'Commodore',
    'Core',
    'ENIAC',
    'Jacquard',
    'Mainframe',
    'Microchip',
    'Minicomputer',
    'PDP',
    'Punchcard',
    'Radar',
    'RISC',
    'Tape Drive',
    'Terminal',
    'Transistor',
    'VAX',
    'Workstation',
  ];

  String _generateUniqueName(List<String> existingNames) {
    final random = Random();
    String name;
    int attempts = 0;
    const maxAttempts = 1000;

    do {
      final descriptor = _descriptors[random.nextInt(_descriptors.length)];
      final object = _objects[random.nextInt(_objects.length)];
      name = '$descriptor $object';
      attempts++;

      if (attempts >= maxAttempts) {
        // Fallback: append a number
        name = '$name ${random.nextInt(9999)}';
        break;
      }
    } while (existingNames.contains(name));

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

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    String projectId,
    String projectName,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Project'),
          content: Text(
            'Are you sure you want to delete "$projectName"?\n\nThis will also delete all sessions and messages associated with this project. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await deleteProject(ref, projectId);

                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Project "$projectName" deleted'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error deleting project: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showEditProjectDialog(
    BuildContext context,
    WidgetRef ref,
    String projectId,
    String currentName,
    String? currentDescription,
  ) {
    final nameController = TextEditingController(text: currentName);
    final descriptionController = TextEditingController(
      text: currentDescription ?? '',
    );

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Edit Project'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Project Name',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Project name cannot be empty'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final description = descriptionController.text.trim();

                try {
                  await updateProject(
                    ref,
                    id: projectId,
                    name: name,
                    description: description.isEmpty ? null : description,
                  );

                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Project "$name" updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error updating project: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
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
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditProjectDialog(
                          context,
                          ref,
                          project.id,
                          project.name,
                          project.description,
                        );
                      } else if (value == 'delete') {
                        _showDeleteConfirmation(
                          context,
                          ref,
                          project.id,
                          project.name,
                        );
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Delete',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
