import 'package:flutter/material.dart';
import 'package:agent_core/agent_core.dart';
import 'package:decamp/components/confirmation_dialog.dart';
import 'package:decamp/components/empty_placeholder.dart';

class ProjectList extends StatelessWidget {
  final List<ProjectEntity> projects;
  final String? currentProjectId;
  final Function(ProjectEntity)? onProjectTap;
  final Function(ProjectEntity)? onProjectDelete;

  const ProjectList({
    super.key,
    required this.projects,
    this.currentProjectId,
    this.onProjectTap,
    this.onProjectDelete,
  });

  void _showDeleteConfirmation(
    BuildContext context,
    ProjectEntity project,
  ) async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Delete Project',
      content:
          'Are you sure you want to delete "${project.name}"? This action cannot be undone.',
    );

    if (confirmed == true && context.mounted) {
      if (onProjectDelete != null) {
        onProjectDelete!(project);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Projects list
        Expanded(
          child: projects.isEmpty
              ? const EmptyPlaceholder(
                  icon: Icons.folder_open,
                  title: 'No projects yet',
                  subtitle: 'Create a new project to get started',
                )
              : ListView.builder(
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    final isCurrentProject = project.id == currentProjectId;
                    final theme = Theme.of(context);

                    final absoluteDateTime =
                        DateFormatter.formatAbsoluteDateTime(
                          project.lastSessionDate,
                        );
                    final relativeTime = DateFormatter.formatRelativeTime(
                      project.lastSessionDate,
                    );

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      elevation: isCurrentProject ? 4 : 2,
                      color: isCurrentProject
                          ? theme.colorScheme.primaryContainer
                          : null,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        title: Text(
                          project.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isCurrentProject
                                ? theme.colorScheme.onPrimaryContainer
                                : null,
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
                                    color: isCurrentProject
                                        ? theme.colorScheme.onPrimaryContainer
                                              .withValues(alpha: 0.7)
                                        : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.7),
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
                                  color: isCurrentProject
                                      ? theme.colorScheme.onPrimaryContainer
                                            .withValues(alpha: 0.6)
                                      : theme.colorScheme.onSurface.withValues(
                                          alpha: 0.6,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                relativeTime,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isCurrentProject
                                      ? theme.colorScheme.onPrimaryContainer
                                            .withValues(alpha: 0.5)
                                      : theme.colorScheme.onSurface.withValues(
                                          alpha: 0.5,
                                        ),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              if (isCurrentProject)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 14,
                                        color: theme
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Active',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: theme
                                              .colorScheme
                                              .onPrimaryContainer,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: isCurrentProject
                                ? theme.colorScheme.onPrimaryContainer
                                : null,
                          ),
                          onPressed: () =>
                              _showDeleteConfirmation(context, project),
                          tooltip: 'Delete project',
                        ),
                        onTap: () {
                          if (onProjectTap != null) {
                            onProjectTap!(project);
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
