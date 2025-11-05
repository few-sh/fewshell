# iOS Simulator Build Fix

## Issue
ML Kit (Google's text recognition library) has architecture compatibility issues with iOS Simulator, particularly the `MLImage` framework which is built for device (arm64) but not simulator architectures.

## Solution Applied

### 1. Updated Podfile
- Set minimum iOS version to 13.0 (required by ML Kit)
- Configured build settings to exclude arm64 for simulator builds
- Force x86_64 architecture for iOS Simulator (works with Rosetta 2 on Apple Silicon)

### 2. Build Settings
```ruby
config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
config.build_settings['ARCHS[sdk=iphonesimulator*]'] = 'x86_64'
```

## Testing

### On Simulator (Intel or Apple Silicon Mac)
The app will run on x86_64 simulator using Rosetta 2 on Apple Silicon Macs.

```bash
flutter run
# or
flutter run -d "iPhone SE (3rd generation)"
```

### On Physical Device
The app will build normally with arm64 architecture.

```bash
flutter run -d <your-device-id>
```

## Alternative: Test on Physical Device Only

If simulator issues persist, you can:
1. Test the OCR feature only on physical iOS devices
2. The camera won't work on simulators anyway (no camera hardware)
3. For development, mock the OCR functionality for simulators

## Clean Build Steps (if needed)

If you encounter build issues:

```bash
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
flutter clean
flutter pub get
flutter run
```

## Note

The camera and OCR features require a physical device for proper testing anyway, as iOS Simulator doesn't have camera access. This fix allows the app to build and run on simulator for testing non-camera features.
