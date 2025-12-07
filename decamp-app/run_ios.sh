#!/bin/bash

# Target device: iPhone 16e on iOS 18.3
# Using the specific UUID found for iOS 18.3 runtime to avoid the iOS 26.1 issues
DEVICE_ID="B7135523-38A1-4F48-905C-918454CB9DBA"

# Parse command line arguments
CLEAN_DATA=false
while [[ $# -gt 0 ]]; do
  case $1 in
    -c|--clean)
      CLEAN_DATA=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [-c|--clean]"
      echo "  -c, --clean    Delete app data before running"
      exit 1
      ;;
  esac
done

echo "Booting simulator $DEVICE_ID..."
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true

echo "Opening Simulator app..."
open -a Simulator

# Clean app data if requested
if [ "$CLEAN_DATA" = true ]; then
  echo "Cleaning app data..."
  BUNDLE_ID="sh.few.fewshell"
  echo "Uninstalling app with bundle ID: $BUNDLE_ID"
  xcrun simctl uninstall "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || echo "App not currently installed"
fi

echo "Running Flutter app on $DEVICE_ID..."
flutter run -d "$DEVICE_ID"
