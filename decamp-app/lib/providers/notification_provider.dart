import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decamp/services/notification_service.dart';

/// Provider for the notification service singleton
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  // Initialize on first access
  service.initialize();
  return service;
});

/// Provider for the current device token
final deviceTokenProvider = StreamProvider<String?>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.tokenStream;
});
