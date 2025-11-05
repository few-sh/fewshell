# OCR Scanner Feature

## Overview
The OCR scanner allows users to scan API keys and URLs using their phone camera with real-time text detection and pattern matching.

## Features

### 1. **Live Camera Preview with Overlay**
- Real-time camera feed with ML Kit text recognition
- Visual overlay highlighting only matching text
- Smooth performance with continuous image processing

### 2. **Smart Pattern Detection**
Uses regular expressions to identify:

#### API Keys
- OpenAI format: `sk-...` (20+ chars)
- Generic formats: `api_key_...`, `apikey:...`
- Long alphanumeric strings (32+ characters)

#### URLs
- HTTP and HTTPS URLs
- Proper domain validation
- Path and query string support

### 3. **User Experience**
- Camera button next to API Key and URL input fields
- Tap highlighted text to select and auto-fill
- Clear instructions and visual feedback
- Permission handling with helpful error messages

## Files Created

1. **`lib/utils/text_pattern_matcher.dart`**
   - Regex patterns for API keys and URLs
   - Pattern matching and extraction utilities
   - `ScanType` enum for different scan modes

2. **`lib/pages/ocr_scanner_page.dart`**
   - Main scanner page with camera preview
   - ML Kit text recognition integration
   - Custom overlay painter for highlighting matches
   - Tap-to-select functionality

3. **Updated `lib/pages/main_settings.dart`**
   - Added camera buttons to API Key and URL fields
   - Integration with OCR scanner page
   - Auto-fill scanned values

## Dependencies Added

```yaml
# OCR and Camera
google_mlkit_text_recognition: ^0.13.1
camera: ^0.11.0+2
permission_handler: ^11.3.1
```

## Permissions Configured

### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-feature android:name="android.hardware.camera" android:required="false" />
<uses-permission android:name="android.permission.CAMERA" />
```

### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to scan API keys and URLs using OCR</string>
```

## Usage

1. **Navigate to Settings** → Add/Edit AI Model
2. **Click the camera icon** next to API Key or URL field
3. **Point camera** at the text you want to scan
4. **Wait for highlight** - only matching patterns will be highlighted
5. **Tap highlighted text** to select and auto-fill

## Technical Details

### Text Recognition
- Uses Google ML Kit's on-device text recognition
- Processes camera frames in real-time
- Filters results based on regex patterns

### Performance Optimizations
- Prevents concurrent image processing with `_isDetecting` flag
- Uses efficient camera preview resolution
- Lightweight overlay painter for smooth rendering

### Pattern Matching
- 70% match threshold ensures accurate detection
- Extracts clean text without surrounding noise
- Validates URL format (http/https required)

## Future Enhancements

Possible improvements:
- Support for more API key formats
- QR code detection for structured data
- Batch scanning for multiple keys
- History of scanned values
- Manual text editing after scan
