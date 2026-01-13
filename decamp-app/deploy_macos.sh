#!/bin/bash
set -e

# Configuration
TEAM_ID="3DLR98CDX9"
EXPORT_OPTIONS_PLIST="macos/ExportOptions.plist"

# Ensure we are in the decamp-app directory
cd "$(dirname "$0")"

# Load environment variables from .env.deploy_appstore if it exists
if [ -f ".env.deploy_appstore" ]; then
    echo "📄 Loading environment variables from .env.deploy_appstore..."
    set -a
    source .env.deploy_appstore
    set +a
fi

echo "🚀 Starting macOS Release Build & Deploy..."

# Check for Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please ensure Flutter is in your PATH."
    exit 1
fi

# Create ExportOptions.plist if it doesn't exist
if [ ! -f "$EXPORT_OPTIONS_PLIST" ]; then
    echo "📝 Creating $EXPORT_OPTIONS_PLIST..."
    # Ensure macos directory exists
    if [ ! -d "macos" ]; then
         echo "❌ macos directory not found! Are you in the root of the flutter project?"
         exit 1
    fi

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
cd macos
pod install
cd ..

# Pre-build to ensure ephemeral files are generated
echo "🛠️ Pre-building macOS application..."
flutter build macos --release

# Build Archive
# Unlike iOS 'flutter build ipa', for macOS we use xcodebuild directly to create an archive
echo "🔨 Building macOS Archive..."
ARCHIVE_PATH="build/macos/archive/Runner.xcarchive"
# Ensure the directory exists
mkdir -p "$(dirname "$ARCHIVE_PATH")"
# Remove previous archive to avoid confusion
rm -rf "$ARCHIVE_PATH"

xcrun xcodebuild -workspace macos/Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    archive \
    -archivePath "$ARCHIVE_PATH"

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo "❌ Archive failed! $ARCHIVE_PATH not found."
    exit 1
fi

echo "✅ Archive successful: $ARCHIVE_PATH"

# Open in Organizer
echo "📂 Opening archive in Xcode Organizer..."
open "$ARCHIVE_PATH"

# Export the archive to create a distribution package
echo "📦 Exporting Archive..."
EXPORT_PATH="build/macos/export"
rm -rf "$EXPORT_PATH"
mkdir -p "$EXPORT_PATH"

xcrun xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
    -exportPath "$EXPORT_PATH" \
    -allowProvisioningUpdates

# Find the exported file (usually .pkg for App Store, or .app)
PKG_FILE=$(find "$EXPORT_PATH" -name "*.pkg" | head -n 1)
APP_FILE=$(find "$EXPORT_PATH" -name "*.app" | head -n 1)

UPLOAD_FILE=""
FILE_TYPE="macos"

if [ -n "$PKG_FILE" ]; then
    UPLOAD_FILE="$PKG_FILE"
    echo "✅ Export successful: $PKG_FILE"
elif [ -n "$APP_FILE" ]; then
    # If we only have an .app, altool requires it to be a package or zip depending on API version but usually pkg is preferred for Mac App Store
    echo "✅ Export successful: $APP_FILE"
    echo "⚠️  Note: The export produced a .app bundle. Uploading to App Store Connect via CLI usually requires a .pkg."
else
    echo "❌ Export produced no recognizable output in $EXPORT_PATH."
fi

# Upload to App Store Connect
echo "📤 Ready to upload to App Store Connect."

if [ -z "$APP_STORE_API_KEY_ID" ] || [ -z "$APP_STORE_API_ISSUER_ID" ]; then
    echo "⚠️  APP_STORE_API_KEY_ID or APP_STORE_API_ISSUER_ID environment variables are not set."
    echo "   Please set them in .env.deploy_macos to automate the upload."
    echo "   Note: Ensure your API Key file (AuthKey_<KEY_ID>.p8) is in ~/.appstoreconnect/private_keys/ or ./private_keys/"
    echo ""
    if [ -n "$UPLOAD_FILE" ]; then
        echo "   Or run the upload command manually:"
        echo "   xcrun altool --upload-app --type macos --file \"$UPLOAD_FILE\" --apiKey \"<KEY_ID>\" --apiIssuer \"<ISSUER_ID>\""
    fi
else
    if [ -n "$UPLOAD_FILE" ]; then
        echo "🚀 Uploading to App Store Connect..."
        xcrun altool --upload-app --type macos --file "$UPLOAD_FILE" --apiKey "$APP_STORE_API_KEY_ID" --apiIssuer "$APP_STORE_API_ISSUER_ID"
    else
        echo "⚠️  Skipping automatic upload because no suitable package file was found."
        echo "   Please use the Xcode Organizer window to upload."
    fi
fi
