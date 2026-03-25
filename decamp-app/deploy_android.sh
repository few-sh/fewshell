#!/bin/bash
set -euo pipefail

# Configuration
DEFAULT_TRACK="internal"
ENV_FILE=".env.deploy_playstore"

# Ensure we are in the decamp-app directory
cd "$(dirname "$0")"

# Load environment variables from .env.deploy_playstore if it exists
if [ -f "$ENV_FILE" ]; then
    echo "Loading environment variables from $ENV_FILE..."
    set -a
    source "$ENV_FILE"
    set +a
fi

echo "Starting Android Release Build & Deploy..."

# Check prerequisites
if ! command -v flutter &> /dev/null; then
    echo "Flutter not found. Please ensure Flutter is in your PATH."
    exit 1
fi

# Derive package name from Gradle unless overridden
PACKAGE_NAME="${PACKAGE_NAME:-$(grep -E 'applicationId\s*=\s*"' android/app/build.gradle.kts | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/')}"
if [ -z "$PACKAGE_NAME" ]; then
    echo "Could not determine PACKAGE_NAME. Set PACKAGE_NAME in $ENV_FILE or environment."
    exit 1
fi

if [[ "$PACKAGE_NAME" == com.example.* ]]; then
    echo "Invalid PACKAGE_NAME: $PACKAGE_NAME"
    echo "Set a real applicationId before publishing to Google Play."
    exit 1
fi

TRACK="${PLAY_TRACK:-$DEFAULT_TRACK}"

# Ensure release keystore config exists
if [ ! -f "android/key.properties" ]; then
    echo "android/key.properties not found."
    echo "Create it with your upload keystore credentials before deploying."
    echo "See Android signing docs: https://docs.flutter.dev/deployment/android#signing-the-app"
    exit 1
fi

# Clean and setup
echo "Cleaning project..."
flutter clean
flutter pub get

# Build AAB
echo "Building Android App Bundle (.aab)..."
flutter build appbundle --release

# Find the AAB file
AAB_FILE=$(find build/app/outputs/bundle/release -name "*.aab" | head -n 1)
if [ -z "$AAB_FILE" ]; then
    echo "AAB file not found!"
    exit 1
fi

echo "Build successful: $AAB_FILE"
echo "Package: $PACKAGE_NAME"
echo "Track: $TRACK"

# Upload to Google Play (Fastlane supply)
# Required env var: PLAY_SERVICE_ACCOUNT_JSON (path to service account json)
if [ -z "${PLAY_SERVICE_ACCOUNT_JSON:-}" ]; then
    echo ""
    echo "PLAY_SERVICE_ACCOUNT_JSON is not set. Skipping automated upload."
    echo "To automate upload, set in $ENV_FILE:"
    echo "  PLAY_SERVICE_ACCOUNT_JSON=/absolute/path/to/google-play-service-account.json"
    echo "Optional:"
    echo "  PLAY_TRACK=internal|alpha|beta|production"
    echo ""
    echo "Manual upload:"
    echo "  1. Open Google Play Console"
    echo "  2. Go to your app -> Release -> $TRACK"
    echo "  3. Upload: $AAB_FILE"
    exit 0
fi

if [ ! -f "$PLAY_SERVICE_ACCOUNT_JSON" ]; then
    echo "PLAY_SERVICE_ACCOUNT_JSON path does not exist: $PLAY_SERVICE_ACCOUNT_JSON"
    exit 1
fi

if ! command -v fastlane &> /dev/null; then
    echo "fastlane is not installed. Install it to automate upload:"
    echo "  brew install fastlane"
    echo "Or upload manually in Google Play Console using: $AAB_FILE"
    exit 0
fi

echo "Uploading to Google Play via fastlane supply..."
fastlane supply \
    --aab "$AAB_FILE" \
    --package_name "$PACKAGE_NAME" \
    --track "$TRACK" \
    --json_key "$PLAY_SERVICE_ACCOUNT_JSON" \
    --skip_upload_metadata true \
    --skip_upload_images true \
    --skip_upload_screenshots true

echo "Upload complete."
