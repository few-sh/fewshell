import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/project_provider.dart';

/// Shows a confirmation dialog and deletes the project if confirmed
Future<void> showDeleteProjectDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String projectId,
  required String projectName,
  VoidCallback? onDeleted,
}) async {
  final theme = Theme.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Project'),
      content: Text(
        'Are you sure you want to delete "$projectName"?\n\nThis will also delete all sessions and messages associated with this project. This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    try {
      await deleteProject(ref, projectId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Project "$projectName" deleted')),
        );
        onDeleted?.call();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting project: $e'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }
}
