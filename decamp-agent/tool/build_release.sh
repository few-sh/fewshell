#!/bin/bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$PROJECT_ROOT")"
IMAGE_NAME="decamp-builder"
BUILD_DIR="$PROJECT_ROOT/build/releases"

# -----------------------------------------------------------------------------
# Prerequisites Check
# -----------------------------------------------------------------------------
if ! command -v docker &> /dev/null; then
    echo "Error: docker is not installed."
    exit 1
fi

if ! command -v gh &> /dev/null; then
    echo "Error: gh (GitHub CLI) is not installed."
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "Error: gh is not authenticated. Please run 'gh auth login'."
    exit 1
fi

# -----------------------------------------------------------------------------
# Get Version
# -----------------------------------------------------------------------------
VERSION=$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | awk '{print $2}')
if [ -z "$VERSION" ]; then
    echo "Error: Could not extract version from pubspec.yaml"
    exit 1
fi
echo "🚀 Preparing release for version: $VERSION"

# -----------------------------------------------------------------------------
# Build & Compile
# -----------------------------------------------------------------------------
mkdir -p "$BUILD_DIR"

build_arch() {
    local ARCH=$1
    local PLATFORM=$2 # Renamed from DOCKER_PLATFORM to PLATFORM
    local IMAGE_TAG="${IMAGE_NAME}:${ARCH}"
    local OUTPUT_NAME="decamp-agent-linux-$ARCH"
    local OUTPUT_PATH="$BUILD_DIR/$OUTPUT_NAME"
    local OUTPUT_DIR="$BUILD_DIR" # Directory where the binary and libs will go

    echo "🏗️  Preparing builder for $ARCH ($PLATFORM)..."
    docker build \
        --no-cache \
        --platform "$PLATFORM" \
        -t "$IMAGE_TAG" \
        -f "$SCRIPT_DIR/Dockerfile.build" \
        "$SCRIPT_DIR" \
        --load

    echo "🔨 Building binary for $ARCH..."

    # We mount REPO_ROOT (the parent with all packages) to /app
    # default WORKDIR in Dockerfile is /app/decamp-agent
    docker run --rm \
        --platform "$PLATFORM" \
        -v "$REPO_ROOT:/app" \
        "$IMAGE_TAG" \
        /bin/bash -c "
            echo '📦 resolving dependencies...' && \
            flutter pub get && \
            echo '🔌 Compiling server...' && \
            mkdir -p build/bin && \
            dart compile exe bin/server.dart -o build/bin/server
        "


    # Copy binary to release artifact name (e.g. decamp-agent-linux-amd64)
    cp "$PROJECT_ROOT/build/bin/server" "$OUTPUT_PATH"
    chmod +x "$OUTPUT_PATH"
}

# Build for AMD64 (x86_64)
build_arch "amd64" "linux/amd64"

# Build for ARM64
build_arch "arm64" "linux/arm64"

# -----------------------------------------------------------------------------
# Create GitHub Release
# -----------------------------------------------------------------------------
echo "📤 Pushing release v$VERSION to GitHub..."

# Check if release exists
if gh release view "v$VERSION" &> /dev/null; then
    echo "⚠️ Release v$VERSION already exists. Uploading assets to existing release..."
    gh release upload "v$VERSION" "$BUILD_DIR/decamp-agent-linux-"* --clobber
else
    echo "✨ Creating new release v$VERSION..."
    gh release create "v$VERSION" \
        "$BUILD_DIR/decamp-agent-linux-amd64" \
        "$BUILD_DIR/decamp-agent-linux-arm64" \
        --title "v$VERSION" \
        --notes "Release v$VERSION of decamp-agent"
fi

echo "✅ Done! Release v$VERSION is live."

# -----------------------------------------------------------------------------
# Upload to Cloudflare R2
# -----------------------------------------------------------------------------
echo "☁️  Uploading to Cloudflare R2 (Bucket: fewshell-releases)..."

if ! command -v npx &> /dev/null; then
    echo "⚠️  npx not found. Skipping R2 upload."
else
    # Upload binary files
    for FILE in "$BUILD_DIR"/decamp-agent-linux-*; do
        if [ -f "$FILE" ]; then
            FILENAME=$(basename "$FILE")
            OBJECT_KEY="releases/$VERSION/$FILENAME"
            
            echo "    ⬆️  Uploading $FILENAME to $OBJECT_KEY..."
            
            # Use npx wrangler for upload
            npx wrangler r2 object put "fewshell-releases/$OBJECT_KEY" --file "$FILE" --remote
        fi
    done
    echo "✅ Uploaded to R2."
fi

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------
echo "🧹 Restoring local environment..."
cd "$PROJECT_ROOT"
flutter pub get

