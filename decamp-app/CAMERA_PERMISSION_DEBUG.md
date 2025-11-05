# Camera Permission Troubleshooting Guide

## Issue: "Camera permission is not enabled" message

### Possible Causes:

1. **iOS Simulator (Most Common)**
   - iOS Simulator does NOT support camera hardware
   - The app will show "No camera found on this device"
   - **Solution**: Test on a physical iOS device

2. **Permission Actually Denied**
   - User denied permission when prompted
   - **Solution**: Grant permission in Settings

3. **Info.plist Missing** (Already fixed in this project)
   - iOS requires `NSCameraUsageDescription` in Info.plist
   - ✅ Already configured in our project

### Debugging Steps:

#### 1. Check Console Output
Look for these debug messages:
```
Camera permission status: ...
Camera permission after request: ...
Available cameras: ...
```

#### 2. If on iOS Simulator
The message will say:
> "No camera found on this device.
> Note: iOS Simulator does not support camera. Please test on a physical device."

**Action**: Connect a physical iPhone/iPad and run the app there.

#### 3. If on Physical Device - Permission Denied
The message will say:
> "Camera permission was denied.
> Please enable camera access in Settings to use this feature."

**Action**: 
- Tap "Open Settings" button in the app
- Or manually: Settings → Privacy & Security → Camera → [Your App]
- Toggle the switch to ON

#### 4. If Permission is Permanently Denied
The message will say:
> "Camera permission is permanently denied.
> Please go to Settings → Privacy → Camera and enable access for this app."

**Action**:
- Tap "Open Settings" button
- Enable camera access
- Restart the app

### Testing on Physical Device:

```bash
# List connected devices
flutter devices

# Run on specific device
flutter run -d <device-id>

# Example
flutter run -d "John's iPhone"
```

### Expected Behavior:

#### First Time Opening Scanner:
1. iOS shows system permission dialog
2. User taps "Allow"
3. Camera preview appears
4. Text detection begins

#### Subsequent Opens:
- Camera opens immediately (no permission prompt)
- Text detection starts automatically

### Quick Fix Commands:

```bash
# Clean build
flutter clean
flutter pub get

# Rebuild and run
flutter run

# Or for iOS specifically
cd ios
pod install
cd ..
flutter run
```

### Note on iOS Simulator:
The camera feature is **not testable** on iOS Simulator because:
- Simulator has no camera hardware
- Even with permission granted, `availableCameras()` returns empty list
- This is a limitation of iOS Simulator, not a bug in the app

**Always test camera/OCR features on physical devices!**
