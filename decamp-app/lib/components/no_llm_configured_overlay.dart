import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:decamp/pages/main_settings.dart';

class NoLlmConfiguredOverlay extends StatelessWidget {
  const NoLlmConfiguredOverlay({super.key});

  static Future<void> show(BuildContext context) async {
    await showShadSheet(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (context) => const NoLlmConfiguredOverlay(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return ShadSheet(
      title: const Text('No AI Model Configured'),
      description: const Text(
        'You need to configure an AI model provider before you can start chatting.',
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.destructive.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.triangleAlert,
                  size: 48,
                  color: theme.colorScheme.destructive,
                ),
              ),
            ),
            const SizedBox(height: 32),
            ShadButton(
              onPressed: () {
                Navigator.pop(context); // Close overlay
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MainSettingsPage(),
                  ),
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(LucideIcons.settings, size: 16),
                  SizedBox(width: 8),
                  Text('Configure AI Models'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ShadButton.ghost(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
