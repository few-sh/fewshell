import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decamp/providers/user_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../utils/ui_utils.dart';

class UserBadge extends ConsumerWidget {
  const UserBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = ref.watch(userProvider);
    final theme = ShadTheme.of(context);

    return ShadButton.ghost(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      onPressed: () => _showEditUsernameDialog(context, ref, username),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.user, size: 16),
          const SizedBox(width: 8),
          Text(
            username,
            style: theme.textTheme.p.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Icon(
            LucideIcons.pencil,
            size: 12,
            color: theme.colorScheme.mutedForeground,
          ),
        ],
      ),
    );
  }

  Future<void> _showEditUsernameDialog(
    BuildContext context,
    WidgetRef ref,
    String currentUsername,
  ) async {
    final controller = TextEditingController(text: currentUsername);
    try {
      await showShadDialog(
        context: context,
        builder: (context) => ShadDialog(
          title: const Text('Edit Username'),
          actions: [
            ShadButton.outline(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ShadButton(
              onPressed: () {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  ref.read(userProvider.notifier).setUsername(newName);
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
          child: ShadInput(
            contextMenuBuilder: adaptiveContextMenuBuilder,
            controller: controller,
            placeholder: const Text('Enter username'),
            autocorrect: false,
            autofocus: true,
            onSubmitted: (_) {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                ref.read(userProvider.notifier).setUsername(newName);
              }
              Navigator.pop(context);
            },
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }
}
