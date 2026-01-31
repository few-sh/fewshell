import 'dart:io';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:agent_core/agent_core.dart';

/// Service for dispatching push notifications to subscribed devices.
///
/// Sends notifications via the decamp-relay service to APNs for iOS devices.
class NotificationDispatcher {
  static final _log = Logger('NotificationDispatcher');

  final String? _pushNotificationUrl;
  final Dio _dio;

  /// Maximum number of retry attempts for failed notifications.
  static const int _maxRetries = 3;

  /// Base delay between retries (will be multiplied by attempt number).
  static const Duration _baseRetryDelay = Duration(seconds: 1);

  NotificationDispatcher._({
    required String? pushNotificationUrl,
    Dio? dio,
  })  : _pushNotificationUrl = pushNotificationUrl,
        _dio = dio ?? Dio();

  /// Creates a NotificationDispatcher, reading configuration from environment.
  ///
  /// The URL for the push notification relay service is read from the
  /// `PUSH_NOTIFICATION_URL` environment variable.
  factory NotificationDispatcher.fromEnvironment({Dio? dio}) {
    final url = Platform.environment['PUSH_NOTIFICATION_URL'];
    if (url == null || url.isEmpty) {
      _log.warning(
        'PUSH_NOTIFICATION_URL environment variable not set. '
        'Push notifications will be disabled.',
      );
    } else {
      _log.info('NotificationDispatcher initialized with URL: $url');
    }
    return NotificationDispatcher._(pushNotificationUrl: url, dio: dio);
  }

  /// Whether the dispatcher is configured and can send notifications.
  bool get isConfigured =>
      _pushNotificationUrl != null && _pushNotificationUrl.isNotEmpty;

  /// Sends a push notification to all iOS subscribers of a message.
  ///
  /// [projectDb] - The project database to query subscribers from.
  /// [projectId] - The ID of the project (for logging/context).
  /// [sessionId] - The ID of the session (for logging/context).
  /// [messageId] - The ID of the message to find subscribers for.
  /// [title] - The notification title.
  /// [body] - The notification body text.
  /// [data] - Optional additional data to include in the notification payload.
  Future<void> sendNotification({
    required ProjectDatabase projectDb,
    required String projectId,
    required String sessionId,
    required String messageId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (!isConfigured) {
      _log.fine(
        'Push notifications disabled (no URL configured). '
        'Skipping notification for message $messageId',
      );
      return;
    }

    try {
      // Get all subscribers for this message
      final subscribers = await projectDb.messageSubscriberDao
          .watchSubscribersByMessage(messageId)
          .first;

      // Filter to only iOS subscribers
      final iosSubscribers =
          subscribers.where((s) => s.platform == DevicePlatform.ios).toList();

      if (iosSubscribers.isEmpty) {
        _log.fine(
          'No iOS subscribers for message $messageId. Skipping notification.',
        );
        return;
      }

      // Extract device tokens
      final deviceTokens =
          iosSubscribers.map((s) => s.deviceToken).toSet().toList();

      _log.info(
        'Sending push notification for message $messageId to '
        '${deviceTokens.length} iOS device(s)',
      );

      await _sendWithRetry(
        deviceTokens: deviceTokens,
        title: title,
        body: body,
        data: data,
      );

      _log.info(
        'Successfully sent push notification for message $messageId',
      );
    } catch (e, st) {
      _log.severe(
        'Failed to send push notification for message $messageId',
        e,
        st,
      );
    }
  }

  /// Sends the notification with retry logic.
  Future<void> _sendWithRetry({
    required List<String> deviceTokens,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final payload = {
      'device_tokens': deviceTokens,
      'title': title,
      'body': body,
      'badge': 1,
      if (data != null) 'data': data,
    };

    Exception? lastException;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _dio.post(
          '$_pushNotificationUrl/send',
          data: payload,
          options: Options(
            headers: {'Content-Type': 'application/json'},
            sendTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );

        if (response.statusCode == 200) {
          return; // Success
        }

        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Unexpected status code: ${response.statusCode}',
        );
      } on DioException catch (e) {
        lastException = e;
        _log.warning(
          'Push notification attempt $attempt/$_maxRetries failed: '
          '${e.message}',
        );

        if (attempt < _maxRetries) {
          final delay = _baseRetryDelay * attempt;
          _log.info('Retrying in ${delay.inSeconds} seconds...');
          await Future.delayed(delay);
        }
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        _log.warning(
          'Push notification attempt $attempt/$_maxRetries failed: $e',
        );

        if (attempt < _maxRetries) {
          final delay = _baseRetryDelay * attempt;
          _log.info('Retrying in ${delay.inSeconds} seconds...');
          await Future.delayed(delay);
        }
      }
    }

    // All retries exhausted
    _log.severe(
      'Push notification failed after $_maxRetries attempts. '
      'Last error: $lastException',
    );
  }
}
