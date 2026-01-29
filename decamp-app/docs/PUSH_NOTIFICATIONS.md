# Push Notifications Setup

This document explains how push notifications are set up in the Decamp mobile app.

## Overview

The app uses Apple Push Notification service (APNs) for iOS to receive push notifications from the decamp-relay service. When the server needs to notify users about events (like session updates, errors, or alerts), it sends notifications through the relay.

## Architecture

```
decamp-agent (server) → decamp-relay (Rust service) → APNs → iOS Device → decamp-app
```

1. **decamp-agent**: The backend server that decides when to send notifications
2. **decamp-relay**: A Rust microservice that handles APNs communication
3. **APNs**: Apple's push notification service
4. **decamp-app**: The Flutter mobile app that receives and displays notifications

## iOS Setup

### 1. Enable Push Notifications Capability

In Xcode:
1. Open the iOS project: `decamp-app/ios/Runner.xcworkspace`
2. Select the Runner target
3. Go to "Signing & Capabilities"
4. Click "+ Capability" and add "Push Notifications"
5. Also add "Background Modes" and check "Remote notifications"

### 2. Configure APNs

The app is configured to:
- Request notification permissions on startup
- Register for remote notifications with APNs
- Receive device tokens via platform channel
- Handle notifications in foreground and background

### 3. Info.plist Configuration

The following is already configured in `ios/Runner/Info.plist`:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

## Flutter Implementation

### Key Components

1. **NotificationService** (`lib/services/notification_service.dart`)
   - Manages notification lifecycle
   - Receives device tokens from iOS
   - Stores tokens locally
   - Can register tokens with the backend

2. **notificationServiceProvider** (`lib/providers/notification_provider.dart`)
   - Provides access to the NotificationService
   - Exposes device token stream

3. **AppDelegate.swift** (`ios/Runner/AppDelegate.swift`)
   - Registers for remote notifications
   - Receives device token from APNs
   - Sends token to Flutter via MethodChannel
   - Handles incoming notifications

### Getting the Device Token

```dart
// In your widget
final deviceToken = ref.watch(deviceTokenProvider);

deviceToken.when(
  data: (token) => Text('Token: $token'),
  loading: () => Text('Loading...'),
  error: (e, st) => Text('Error: $e'),
);
```

### Sending Device Token to Backend

```dart
final notificationService = ref.read(notificationServiceProvider);
await notificationService.registerDeviceToken('https://your-server.com');
```

## Testing

### Test with decamp-relay

1. Start the decamp-relay service:
   ```bash
   cd decamp-relay
   cargo run --release
   ```

2. Get the device token from the app (check logs or UI)

3. Send a test notification:
   ```bash
   curl -X POST http://localhost:8080/send \
     -H "Content-Type: application/json" \
     -d '{
       "device_tokens": ["your-device-token-here"],
       "title": "Test Notification",
       "body": "This is a test from decamp-relay",
       "badge": 1
     }'
   ```

### Testing on Physical Device

Push notifications only work on physical iOS devices, not simulators. To test:

1. Build and run on a physical iPhone/iPad
2. Accept notification permissions when prompted
3. Check the logs for the device token
4. Use the token to send a test notification via decamp-relay

### Sandbox vs Production

- **Development/Debug builds**: Use APNs Sandbox environment
- **Release builds**: Use APNs Production environment

Configure this in decamp-relay's `.env`:
```
APNS_USE_SANDBOX=true  # for development
APNS_USE_SANDBOX=false # for production
```

## Integration with decamp-agent

To integrate with the main Decamp server (decamp-agent):

1. Add an API endpoint in decamp-agent to receive device token registrations
2. Store device tokens in the database associated with user/session
3. When events occur that need notifications, call decamp-relay:

```dart
// Example in decamp-agent
final response = await dio.post(
  'http://localhost:8080/send',
  data: {
    'device_tokens': [userDeviceToken],
    'title': 'Session Update',
    'body': 'Your command completed successfully',
    'data': {'session_id': sessionId},
  },
);
```

## Security Considerations

- Device tokens should be treated as sensitive data
- Use HTTPS for all communication between services
- Validate tokens before storing
- Implement token refresh logic (tokens can change)
- Add authentication for the relay service API

## Troubleshooting

### No device token received

1. Check that push notifications capability is enabled in Xcode
2. Verify you're testing on a physical device (not simulator)
3. Check that the app has notification permissions
4. Look for errors in Xcode console during APNs registration

### Notifications not received

1. Verify the device token is correct
2. Check that decamp-relay is using the correct environment (sandbox vs production)
3. Ensure the APNs key/credentials are correct
4. Check decamp-relay logs for errors

### Token registration fails

1. Verify network connectivity
2. Check that the backend endpoint is accessible
3. Review server logs for errors
