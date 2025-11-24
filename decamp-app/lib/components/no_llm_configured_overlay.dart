import 'package:flutter/material.dart';
import 'package:decamp/pages/main_settings.dart';

class NoLlmConfiguredOverlay extends StatelessWidget {
  const NoLlmConfiguredOverlay({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const NoLlmConfiguredOverlay(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 48,
            color: colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'No AI Model Configured',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'You need to configure an AI model provider before you can start chatting.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context); // Close overlay
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MainSettingsPage(),
                ),
              );
            },
            icon: const Icon(Icons.settings),
            label: const Text('Configure AI Models'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          const SizedBox(height: 16), // Bottom padding
        ],
      ),
    );
  }
}
