#!/bin/bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$PROJECT_ROOT")"
IMAGE_NAME="fewshell-app-linux-builder"
BUILD_DIR="$PROJECT_ROOT/build/releases"

# -----------------------------------------------------------------------------
# Prerequisites Check
# -----------------------------------------------------------------------------
if ! command -v docker &> /dev/null; then
    echo "Error: docker is not installed."
    exit 1
fi

# -----------------------------------------------------------------------------
# Get Version
# -----------------------------------------------------------------------------
VERSION=$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | awk '{print $2}' | cut -d'+' -f1)
if [ -z "$VERSION" ]; then
    echo "Error: Could not extract version from pubspec.yaml"
    exit 1
fi
echo "🚀 Building fewshell-app Linux release v$VERSION"

# -----------------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------------
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

build_arch() {
    local ARCH=$1
    local PLATFORM=$2
    local IMAGE_TAG="${IMAGE_NAME}:${ARCH}"

    echo "🏗️  Building Docker image for $ARCH ($PLATFORM)..."
    docker build \
        --platform "$PLATFORM" \
        -t "$IMAGE_TAG" \
        -f "$SCRIPT_DIR/Dockerfile.build-linux" \
        "$SCRIPT_DIR" \
        --load

    echo "🔨 Building Flutter Linux app for $ARCH..."

    docker run --rm \
        --platform "$PLATFORM" \
        -v "$REPO_ROOT:/app" \
        "$IMAGE_TAG" \
        /bin/bash -c "
            echo '📦 Resolving dependencies...' && \
            flutter pub get && \
            echo '🔨 Building Linux release...' && \
            flutter build linux --release
        "

    local BUNDLE_DIR="$PROJECT_ROOT/build/linux"
    # Flutter outputs to x64 or arm64 depending on arch
    if [ "$ARCH" = "amd64" ]; then
        BUNDLE_DIR="$BUNDLE_DIR/x64/release/bundle"
    else
        BUNDLE_DIR="$BUNDLE_DIR/arm64/release/bundle"
    fi

    if [ ! -d "$BUNDLE_DIR" ]; then
        echo "Error: Build output not found at $BUNDLE_DIR"
        exit 1
    fi

    local TGZ_NAME="fewshell-app-linux-$ARCH.tar.gz"
    local TGZ_PATH="$BUILD_DIR/$TGZ_NAME"

    echo "📦 Creating tarball $TGZ_NAME..."
    (cd "$BUNDLE_DIR" && tar czf "$TGZ_PATH" .)

    echo "✅ Built $TGZ_NAME"
}

# Build for AMD64 (x86_64)
build_arch "amd64" "linux/amd64"

# Build for ARM64
build_arch "arm64" "linux/arm64"

# -----------------------------------------------------------------------------
# Upload to Cloudflare R2
# -----------------------------------------------------------------------------
echo "☁️  Uploading to Cloudflare R2 (Bucket: fewshell-releases)..."

if ! command -v npx &> /dev/null; then
    echo "⚠️  npx not found. Skipping R2 upload."
else
    for FILE in "$BUILD_DIR"/fewshell-app-linux-*; do
        if [ -f "$FILE" ]; then
            FILENAME=$(basename "$FILE")
            OBJECT_KEY="releases/$VERSION/$FILENAME"

            echo "    ⬆️  Uploading $FILENAME to $OBJECT_KEY..."
            npx wrangler r2 object put "fewshell-releases/$OBJECT_KEY" --file "$FILE" --remote

            LATEST_KEY="releases/latest/$FILENAME"
            echo "    ⬆️  Uploading $FILENAME to $LATEST_KEY..."
            npx wrangler r2 object put "fewshell-releases/$LATEST_KEY" --file "$FILE" --remote --cc "max-age=60"
        fi
    done

    echo "✅ Uploaded to R2."
fi

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo ""
echo "🔗 Release URLs:"
for FILE in "$BUILD_DIR"/fewshell-app-linux-*; do
    if [ -f "$FILE" ]; then
        FILENAME=$(basename "$FILE")
        echo "  https://release.few.sh/releases/$VERSION/$FILENAME"
    fi
done

echo ""
echo "✅ Done! fewshell-app Linux v$VERSION built."
