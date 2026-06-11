#!/bin/bash
set -euo pipefail

# =============================================================================
# deploy_macos_direct.sh
#
# Builds a signed, notarized .dmg of the Fewshell macOS app and uploads it
# to Cloudflare R2 (bucket: fewshell-releases).
#
# Required env vars (can be set in .env.deploy_appstore):
#   APP_STORE_API_KEY_ID    – App Store Connect API Key ID
#   APP_STORE_API_ISSUER_ID – App Store Connect API Issuer ID
#
# Required env var (or will auto-detect):
#   SIGNING_IDENTITY        – e.g. "Developer ID Application: Fewshot Corp (3DLR98CDX9)"
#                             If not set, the script searches for a Developer ID cert.
#
# The .p8 key file must be at:
#   ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load environment variables
if [ -f ".env.deploy_appstore" ]; then
    echo "📄 Loading environment variables from .env.deploy_appstore..."
    set -a
    source .env.deploy_appstore
    set +a
fi

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
TEAM_ID="3DLR98CDX9"
APP_NAME="Fewshell"
BUNDLE_ID="sh.few.fewshell"
VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
BUILD_DIR="build/macos/Build/Products/Release"
DMG_DIR="build/macos/dmg"
DMG_NAME="Fewshell-${VERSION}.dmg"
DMG_PATH="$DMG_DIR/$DMG_NAME"

if [ -z "$VERSION" ]; then
    echo "❌ Could not extract version from pubspec.yaml"
    exit 1
fi

echo "🚀 Building Fewshell macOS v${VERSION} for direct distribution..."

# -----------------------------------------------------------------------------
# Prerequisites
# -----------------------------------------------------------------------------
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please ensure Flutter is in your PATH."
    exit 1
fi

if ! command -v npx &> /dev/null; then
    echo "❌ npx not found. Required for R2 upload."
    exit 1
fi

# Resolve signing identity
if [ -z "${SIGNING_IDENTITY:-}" ]; then
    echo "🔍 SIGNING_IDENTITY not set. Searching for Developer ID certificate..."
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -n 1 | sed 's/.*"\(.*\)".*/\1/')
    if [ -z "$SIGNING_IDENTITY" ]; then
        echo "❌ No 'Developer ID Application' certificate found."
        echo "   Install one or set SIGNING_IDENTITY env var."
        exit 1
    fi
    echo "   Found: $SIGNING_IDENTITY"
fi

# Resolve notarization API key
if [ -z "${APP_STORE_API_KEY_ID:-}" ] || [ -z "${APP_STORE_API_ISSUER_ID:-}" ]; then
    echo "❌ APP_STORE_API_KEY_ID and APP_STORE_API_ISSUER_ID must be set."
    echo "   Set them in .env.deploy_appstore or export them."
    exit 1
fi

API_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${APP_STORE_API_KEY_ID}.p8"
if [ ! -f "$API_KEY_PATH" ]; then
    echo "❌ API key file not found: $API_KEY_PATH"
    exit 1
fi

# -----------------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------------
echo "🧹 Cleaning project..."
flutter clean
flutter pub get

echo "📦 Installing Pods..."
(cd macos && pod install)

echo "🔨 Building macOS release..."
flutter build macos --release

APP_PATH="$BUILD_DIR/${APP_NAME}.app"
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Build failed – $APP_PATH not found."
    exit 1
fi
echo "✅ Build successful: $APP_PATH"

# -----------------------------------------------------------------------------
# Code Sign (with hardened runtime + explicit entitlements for notarization)
# -----------------------------------------------------------------------------
echo "🔏 Code signing with: $SIGNING_IDENTITY"

ENTITLEMENTS_PATH="macos/Runner/Release.entitlements"
if [ ! -f "$ENTITLEMENTS_PATH" ]; then
    echo "❌ Entitlements file not found: $ENTITLEMENTS_PATH"
    exit 1
fi

# Re-sign nested frameworks first (without entitlements – they don't take any),
# then sign the outer .app with explicit entitlements. We avoid `--deep` because
# it would apply the app's entitlements to every nested binary, and would also
# silently preserve whatever entitlements were already there on re-sign.
for fw in "$APP_PATH"/Contents/Frameworks/*.framework "$APP_PATH"/Contents/Frameworks/*.dylib; do
    [ -e "$fw" ] || continue
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$fw"
done

codesign --force --options runtime \
    --entitlements "$ENTITLEMENTS_PATH" \
    --sign "$SIGNING_IDENTITY" \
    --timestamp \
    "$APP_PATH"

echo "   Verifying signature..."
codesign --verify --deep --strict "$APP_PATH"
# if codesign -d --entitlements :- "$APP_PATH" 2>/dev/null | grep -q keychain-access-groups; then
#     echo "❌ keychain-access-groups still present in entitlements – aborting."
#     exit 1
# fi
echo "✅ Code signing verified."

# -----------------------------------------------------------------------------
# Create DMG
# -----------------------------------------------------------------------------
echo "💿 Creating DMG..."
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"

# Two-step DMG creation to avoid hdiutil following the /Applications symlink
# (which can fail with "Operation not permitted" if /Applications contains
# protected apps – e.g. a previously-installed copy of Fewshell.app).
#
# Step 1: create an empty writable image sized to fit the app + headroom.
# Step 2: mount it, copy contents in (without following symlinks),
#         create the /Applications symlink, unmount.
# Step 3: convert to compressed read-only UDZO.
APP_SIZE_KB=$(du -sk "$APP_PATH" | awk '{print $1}')
IMAGE_SIZE_KB=$((APP_SIZE_KB + 50000))   # +50 MB headroom
TMP_DMG="$DMG_DIR/tmp.dmg"
VOL_NAME="$APP_NAME"

hdiutil create \
    -size "${IMAGE_SIZE_KB}k" \
    -fs HFS+ \
    -volname "$VOL_NAME" \
    -ov \
    "$TMP_DMG"

MOUNT_INFO=$(hdiutil attach "$TMP_DMG" -nobrowse -noautoopen -mountrandom /tmp)
MOUNT_POINT=$(echo "$MOUNT_INFO" | grep -E '^/dev/' | tail -n1 | awk '{for(i=3;i<=NF;i++) printf "%s ",$i; print ""}' | sed 's/ *$//')

if [ -z "$MOUNT_POINT" ] || [ ! -d "$MOUNT_POINT" ]; then
    echo "❌ Failed to mount temporary DMG."
    exit 1
fi

# Ensure unmount happens even on error
trap 'hdiutil detach "$MOUNT_POINT" -quiet || true' EXIT

# Copy the .app preserving symlinks/attrs but NOT following them.
cp -R "$APP_PATH" "$MOUNT_POINT/"
ln -s /Applications "$MOUNT_POINT/Applications"

hdiutil detach "$MOUNT_POINT" -quiet
trap - EXIT

hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -ov -o "$DMG_PATH"
rm -f "$TMP_DMG"

if [ ! -f "$DMG_PATH" ]; then
    echo "❌ DMG creation failed."
    exit 1
fi
echo "✅ DMG created: $DMG_PATH"

# Sign the DMG itself
echo "🔏 Signing DMG..."
codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"

# -----------------------------------------------------------------------------
# Notarize
# -----------------------------------------------------------------------------
echo "📋 Submitting DMG for notarization..."

xcrun notarytool submit "$DMG_PATH" \
    --key "$API_KEY_PATH" \
    --key-id "$APP_STORE_API_KEY_ID" \
    --issuer "$APP_STORE_API_ISSUER_ID" \
    --wait

echo "📌 Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH"

echo "✅ Notarization complete."

# -----------------------------------------------------------------------------
# Upload to Cloudflare R2
# -----------------------------------------------------------------------------
echo "☁️  Uploading to Cloudflare R2 (Bucket: fewshell-releases)..."

OBJECT_KEY="releases/$VERSION/$DMG_NAME"
echo "    ⬆️  Uploading $DMG_NAME to $OBJECT_KEY..."
npx wrangler r2 object put "fewshell-releases/$OBJECT_KEY" --file "$DMG_PATH" --remote

LATEST_KEY="releases/latest/$DMG_NAME"
echo "    ⬆️  Uploading $DMG_NAME to $LATEST_KEY..."
npx wrangler r2 object put "fewshell-releases/$LATEST_KEY" --file "$DMG_PATH" --remote --cc "max-age=60"

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo ""
echo "🎉 Done! Fewshell v${VERSION} macOS DMG is live."
echo ""
echo "🔗 Release URLs:"
echo "   https://release.few.sh/releases/$VERSION/$DMG_NAME"
echo "   https://release.few.sh/releases/latest/$DMG_NAME"
