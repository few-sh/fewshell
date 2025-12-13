import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:decamp/providers/project_provider.dart';
import 'package:decamp/providers/database_provider.dart';
import 'package:decamp/components/selectable_list_view.dart';
import 'project_setup_page.dart';

class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProject = ref.watch(currentProjectProvider);
    final projectDao = ref.read(globalDatabaseProvider).projectDao;

    return SelectableListView<ProjectEntity>(
      title: 'Projects',
      dao: projectDao,
      activeData: ref.watch(activeProjectsProvider),
      archivedData: ref.watch(archivedProjectsProvider),

      // Getters for entity properties
      getId: (p) => p.id,
      getName: (p) => p.name,
      getIsStarred: (p) => p.isStarred,
      getCreatedAt: (p) => p.createdAt,
      getUpdatedAt: (p) => p.lastSessionDate,

      // Selection
      isSelected: (p) => p.id == currentProject?.id,
      onSelect: (project) async {
        await ref.read(currentProjectIdProvider.notifier).select(project.id);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Switched to: ${project.name}')),
          );
        }
      },

      // FAB
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProjectSetupPage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Project'),
      ),
    );
  }
}
