#!/bin/bash
set -e

# Configuration
TEAM_ID="3DLR98CDX9"
EXPORT_OPTIONS_PLIST="ios/ExportOptions.plist"

# Ensure we are in the decamp-app directory
cd "$(dirname "$0")"

# Load environment variables from .env.deploy_appstore if it exists
if [ -f ".env.deploy_appstore" ]; then
    echo "📄 Loading environment variables from .env.deploy_ios..."
    set -a
    source .env.deploy_appstore
    set +a
fi

echo "🚀 Starting iOS Release Build & Deploy..."

# Check for Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please ensure Flutter is in your PATH."
    exit 1
fi

# Create ExportOptions.plist if it doesn't exist
if [ ! -f "$EXPORT_OPTIONS_PLIST" ]; then
    echo "📝 Creating $EXPORT_OPTIONS_PLIST..."
    cat <<EOF > "$EXPORT_OPTIONS_PLIST"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
EOF
fi

# Clean and Setup
echo "🧹 Cleaning project..."
flutter clean
flutter pub get

echo "📦 Installing Pods..."
cd ios
pod install
cd ..

# Build IPA
echo "🔨 Building IPA..."
flutter build ipa --release --export-options-plist="$EXPORT_OPTIONS_PLIST"

# Find the IPA file
IPA_FILE=$(find build/ios/ipa -name "*.ipa" | head -n 1)

if [ -z "$IPA_FILE" ]; then
    echo "❌ IPA file not found!"
    exit 1
fi

echo "✅ Build successful: $IPA_FILE"

# Find the Archive file
ARCHIVE_FILE=$(find build/ios/archive -name "*.xcarchive" | head -n 1)
if [ -n "$ARCHIVE_FILE" ]; then
    echo "📂 Opening archive in Xcode Organizer..."
    open "$ARCHIVE_FILE"
fi

# Upload to App Store Connect
echo "📤 Ready to upload to App Store Connect."

if [ -z "$APP_STORE_API_KEY_ID" ] || [ -z "$APP_STORE_API_ISSUER_ID" ]; then
    echo "⚠️  APP_STORE_API_KEY_ID or APP_STORE_API_ISSUER_ID environment variables are not set."
    echo "   Please set them in .env.deploy_ios to automate the upload."
    echo "   Note: Ensure your API Key file (AuthKey_<KEY_ID>.p8) is in ~/.appstoreconnect/private_keys/ or ./private_keys/"
    echo ""
    echo "   Or run the upload command manually:"
    echo "   xcrun altool --upload-app --type ios --file \"$IPA_FILE\" --apiKey \"<KEY_ID>\" --apiIssuer \"<ISSUER_ID>\""
else
    echo "🚀 Uploading to App Store Connect..."
    xcrun altool --upload-app --type ios --file "$IPA_FILE" --apiKey "$APP_STORE_API_KEY_ID" --apiIssuer "$APP_STORE_API_ISSUER_ID"
fi
