# Push Notification Setup - Quick Start

## What Was Set Up

### 1. decamp-relay (Rust Service)
A standalone Rust service that handles sending push notifications via APNs.

**Location**: `decamp-relay/`

**Key files**:
- `src/main.rs` - Web server with `/send` endpoint
- `src/apns.rs` - APNs client implementation
- `.env.example` - Configuration template

**Configuration required**:
```bash
cd decamp-relay
cp .env.example .env
# Edit .env and add your APNs credentials:
# - APNS_KEY_PATH: Path to your .p8 key file
# - APNS_KEY_ID: Your Key ID (10 characters)
# - APNS_TEAM_ID: Your Team ID (10 characters)
# - APNS_BUNDLE_ID: Your app's bundle ID
# - APNS_USE_SANDBOX: true for development, false for production
```

**To run**:
```bash
cargo run --release
```

### 2. decamp-app (Flutter App)
Mobile app updated to receive push notifications.

**New files**:
- `lib/services/notification_service.dart` - Core notification handling
- `lib/providers/notification_provider.dart` - Riverpod provider
- `lib/components/notification_debug_widget.dart` - Testing UI widget
- `docs/PUSH_NOTIFICATIONS.md` - Detailed documentation

**Updated files**:
- `pubspec.yaml` - Added flutter_local_notifications dependency
- `ios/Runner/AppDelegate.swift` - APNs registration and handling
- `ios/Runner/Info.plist` - Background modes configuration
- `lib/main.dart` - Initialize notification service
- `lib/providers/providers.dart` - Export notification provider

## How to Test

### 1. Get Device Token

1. Build and run the app on a **physical iOS device** (push notifications don't work on simulator)
2. Accept notification permissions when prompted
3. Check the Xcode console logs for the device token (starts with "Device Token:")
4. Alternatively, add the `NotificationDebugWidget` to any page in the app to see and copy the token

### 2. Send a Test Notification

1. Start the decamp-relay service:
   ```bash
   cd decamp-relay
   cargo run --release
   ```

2. Send a notification using curl:
   ```bash
   curl -X POST http://localhost:8090/send \
     -H "Content-Type: application/json" \
     -H "Authorization: test-api-key" \
     -d '{
       "device_tokens": ["YOUR_DEVICE_TOKEN_HERE"],
       "title": "Hello from Decamp!",
       "body": "This is a test notification",
       "badge": 1,
       "sound": "default"
     }'
   ```

3. You should see the notification on your device!

### 3. Add Debug Widget (Optional)

To see the device token in the app UI, add this to any page:

```dart
import 'package:decamp/components/notification_debug_widget.dart';

// In your widget's build method:
NotificationDebugWidget()
```

## Next Steps

### For Production Use:

1. **Xcode Configuration**:
   - Open `decamp-app/ios/Runner.xcworkspace`
   - Add "Push Notifications" capability
   - Add "Background Modes" capability and check "Remote notifications"

2. **Backend Integration**:
   - Add API endpoint in decamp-agent to receive device token registrations
   - Store device tokens in database
   - Call decamp-relay when you need to send notifications

3. **Security**:
   - Add authentication to decamp-relay API
   - Use HTTPS for all communication
   - Validate and sanitize device tokens

## Architecture Flow

```
User Action → decamp-agent → decamp-relay → APNs → iOS Device → decamp-app
```

1. Something happens on decamp-agent (e.g., command completes)
2. decamp-agent calls decamp-relay with device token and message
3. decamp-relay sends to Apple's APNs
4. APNs delivers to the iOS device
5. decamp-app displays the notification

## Troubleshooting

**No device token received**:
- Ensure you're on a physical device (not simulator)
- Check notification permissions are granted
- Look for errors in Xcode console

**Notifications not received**:
- Verify correct environment (sandbox vs production)
- Check APNs credentials are correct
- Ensure device token is valid

**Can't compile decamp-app**:
- Run `flutter pub get` in decamp-app folder
- Run `flutter clean` and try again

**Can't compile decamp-relay**:
- Ensure Rust is installed
- Run `cargo clean` and try again

## Files Reference

### Main Implementation Files:
- **Relay Service**: `decamp-relay/src/main.rs`, `decamp-relay/src/apns.rs`
- **Mobile Service**: `decamp-app/lib/services/notification_service.dart`
- **iOS Bridge**: `decamp-app/ios/Runner/AppDelegate.swift`
- **Provider**: `decamp-app/lib/providers/notification_provider.dart`

### Documentation:
- **Detailed Guide**: `decamp-app/docs/PUSH_NOTIFICATIONS.md`
- **This Guide**: `PUSH_NOTIFICATIONS_SETUP.md`
