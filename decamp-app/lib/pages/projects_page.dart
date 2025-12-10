import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decamp/providers/project_provider.dart';

import '../utils/project_utils.dart';
import 'project_setup_page.dart';
import '../components/project_setup_view.dart';
import '../components/project_list.dart';

class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the projects stream
    final projectsAsync = ref.watch(projectsStreamProvider);
    final currentProject = ref.watch(currentProjectProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: projectsAsync.when(
        data: (projects) {
          if (projects.isEmpty) {
            return const ProjectSetupView();
          }

          return ProjectList(
            projects: projects,
            currentProjectId: currentProject?.id,
            onProjectTap: (project) async {
              // Select this project and navigate back
              await ref
                  .read(currentProjectIdProvider.notifier)
                  .select(project.id);
              if (!context.mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Switched to project: ${project.name}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            onProjectDelete: (project) => showDeleteProjectDialog(
              context: context,
              ref: ref,
              projectId: project.id,
              projectName: project.name,
            ),
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
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProjectSetupPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('New Project'),
              ),
        loading: () => null,
        error: (_, _) => null,
      ),
    );
  }
}
