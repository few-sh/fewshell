import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _log = Logger('NotificationService');

/// Service to manage push notifications and device tokens
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const MethodChannel _notificationChannel = MethodChannel(
    'com.fewsh.decamp/notifications',
  );

  bool _initialized = false;
  String? _deviceToken;
  final _tokenController = StreamController<String?>.broadcast();

  /// Stream of device token updates
  Stream<String?> get tokenStream async* {
    // Emit the current token value immediately
    yield _deviceToken;
    // Then yield all future updates
    yield* _tokenController.stream;
  }

  /// Current device token (may be null if not yet initialized)
  String? get deviceToken => _deviceToken;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    _log.info('Initializing notification service');

    // Set up platform channel method handler
    _notificationChannel.setMethodCallHandler(_handleMethodCall);

    // Clear badge on app start
    await clearBadge();

    // Initialize platform-specific settings
    if (Platform.isIOS) {
      await _initializeIOS();
    } else if (Platform.isAndroid) {
      await _initializeAndroid();
    } else if (Platform.isMacOS) {
      await _initializeMacOS();
    }

    _initialized = true;
    _log.info('Notification service initialized');
  }

  /// Handle method calls from platform (iOS/Android)
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    _log.info('Received method call: ${call.method}');

    switch (call.method) {
      case 'onToken':
        final token = call.arguments as String;
        await setDeviceToken(token);
        break;
      case 'onTokenError':
        final error = call.arguments as String;
        _log.severe('Failed to get device token: $error');
        break;
      case 'onNotificationTap':
        final payload = call.arguments as Map?;
        _log.info('Notification tapped with payload: $payload');
        // Handle notification tap - you can emit an event here
        break;
      default:
        _log.warning('Unknown method call: ${call.method}');
    }
  }

  Future<void> _initializeIOS() async {
    _log.info('Initializing iOS notifications');

    // iOS initialization settings
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions
    final granted = await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    if (granted == true) {
      _log.info('iOS notification permissions granted');
      await _getAPNsToken();
    } else {
      _log.warning('iOS notification permissions denied');
    }
  }

  Future<void> _initializeAndroid() async {
    _log.info('Initializing Android notifications');

    // Android initialization settings
    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel
    const androidChannel = AndroidNotificationChannel(
      'decamp_notifications',
      'Decamp Notifications',
      description: 'Notifications from Decamp',
      importance: Importance.high,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);

    _log.info('Android notifications initialized');
  }

  Future<void> _initializeMacOS() async {
    _log.info('Initializing macOS notifications');

    // macOS initialization settings
    const initializationSettingsMacOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      macOS: initializationSettingsMacOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions
    final granted = await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    if (granted == true) {
      _log.info('macOS notification permissions granted');
    } else {
      _log.warning('macOS notification permissions denied');
    }
  }

  /// Get APNs device token for iOS
  /// The token will be received via platform channel when iOS provides it
  Future<void> _getAPNsToken() async {
    // Load cached token if available
    final prefs = await SharedPreferences.getInstance();
    final cachedToken = prefs.getString('apns_device_token');

    if (cachedToken != null) {
      _log.info('Loaded cached APNs token');
      _setDeviceToken(cachedToken);
    } else {
      _log.info(
        'No cached APNs token. Waiting for token from iOS platform channel.',
      );
    }

    // Token will be received via the method channel callback
    // when iOS successfully registers for remote notifications
  }

  /// Set the device token and notify listeners
  Future<void> setDeviceToken(String token) async {
    _setDeviceToken(token);

    // Cache the token
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('apns_device_token', token);
  }

  void _setDeviceToken(String token) {
    if (_deviceToken != token) {
      _log.info('Device token updated: ${token.substring(0, 10)}...');
      _deviceToken = token;
      _tokenController.add(token);
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    _log.info('Notification tapped: ${response.payload}');
    // Handle notification tap - navigate to appropriate screen
    // This would typically use a navigation service or callback
  }

  /// Show a local notification (for testing)
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    const notificationDetails = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      android: AndroidNotificationDetails(
        'decamp_notifications',
        'Decamp Notifications',
        channelDescription: 'Notifications from Decamp',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Send device token to the backend server
  Future<void> registerDeviceToken(String serverUrl) async {
    if (_deviceToken == null) {
      _log.warning('Cannot register: no device token available');
      return;
    }

    _log.info('Registering device token with server: $serverUrl');
    // TODO: Implement HTTP call to register token with decamp-agent
    // This would typically POST to an endpoint like /api/register-device
    // with the device token and user/session information
  }

  /// Clear the app badge count
  Future<void> clearBadge() async {
    try {
      if (Platform.isIOS) {
        // Use platform channel to clear badge on iOS
        await _notificationChannel.invokeMethod('clearBadge');
        _log.info('Badge cleared via platform channel');
      } else {
        // For Android, cancel all notifications
        await _flutterLocalNotificationsPlugin.cancelAll();
        _log.info('Badge cleared');
      }
    } catch (e) {
      _log.warning('Failed to clear badge: $e');
    }
  }

  void dispose() {
    _tokenController.close();
  }
}
