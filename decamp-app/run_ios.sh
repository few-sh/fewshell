#!/bin/bash

# Target device: iPhone 16e on iOS 18.3
# Using the specific UUID found for iOS 18.3 runtime to avoid the iOS 26.1 issues
DEVICE_ID="B7135523-38A1-4F48-905C-918454CB9DBA"

echo "Booting simulator $DEVICE_ID..."
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true

echo "Opening Simulator app..."
open -a Simulator

echo "Running Flutter app on $DEVICE_ID..."
flutter run -d "$DEVICE_ID"
