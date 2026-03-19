import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:decamp/components/confirmation_dialog.dart';
import 'package:decamp/providers/providers.dart';

const _descriptors = [
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

const _objects = [
  'Abacus',
  'Core',
  'ENIAC',
  'Relay',
  'Radar',
  'RISC',
  'Chip',
  'Vacuum',
];

String generateUniqueProjectName(List<String> existingNames) {
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

/// Shows a confirmation dialog and deletes the project if confirmed
Future<void> showDeleteProjectDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String projectId,
  required String projectName,
  VoidCallback? onDeleted,
}) async {
  final confirmed = await showConfirmationDialog(
    context: context,
    title: 'Delete Project',
    content:
        'Are you sure you want to delete "$projectName"?\n\nThis will also delete all sessions and messages associated with this project. This action cannot be undone.',
    confirmLabel: 'Delete',
  );

  if (confirmed == true) {
    try {
      await ref.read(projectControllerProvider).deleteProject(projectId);
      if (context.mounted) {
        ShadToaster.of(
          context,
        ).show(ShadToast(description: Text('Project "$projectName" deleted')));
        onDeleted?.call();
      }
    } catch (e) {
      if (context.mounted) {
        ShadToaster.of(
          context,
        ).show(ShadToast(description: Text('Error deleting project: $e')));
      }
    }
  }
}
