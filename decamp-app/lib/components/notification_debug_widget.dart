import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decamp/providers/notification_provider.dart';

/// Debug widget for testing push notifications
/// Shows the current device token and allows sending test notifications
class NotificationDebugWidget extends ConsumerWidget {
  const NotificationDebugWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceTokenAsync = ref.watch(deviceTokenProvider);
    final notificationService = ref.read(notificationServiceProvider);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Push Notifications',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            deviceTokenAsync.when(
              data: (token) {
                if (token == null) {
                  return const Text('No device token yet. Waiting for APNs...');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Device Token:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SelectableText(
                        token,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: token));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Token copied to clipboard'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Token'),
                    ),
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('Error: $error'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await notificationService.showNotification(
                    title: 'Test Notification',
                    body: 'This is a local test notification',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Test notification sent')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              icon: const Icon(Icons.send),
              label: const Text('Send Test Local Notification'),
            ),
            const SizedBox(height: 8),
            Text(
              'To test remote push notifications:\n'
              '1. Copy the device token above\n'
              '2. Start decamp-relay service\n'
              '3. Use curl or the relay API to send a notification',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
