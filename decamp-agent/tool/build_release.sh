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
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

build_arch() {
    local ARCH=$1
    local PLATFORM=$2 # Renamed from DOCKER_PLATFORM to PLATFORM
    local IMAGE_TAG="${IMAGE_NAME}:${ARCH}"
    local OUTPUT_NAME="fewshell-agent-linux-$ARCH"
    local OUTPUT_PATH="$BUILD_DIR/$OUTPUT_NAME"
    local OUTPUT_DIR="$BUILD_DIR" # Directory where the binary and libs will go

    echo "🏗️  Preparing builder for $ARCH ($PLATFORM)..."
    docker build \
        --platform "$PLATFORM" \
        -t "$IMAGE_TAG" \
        -f "$SCRIPT_DIR/Dockerfile.build" \
        "$SCRIPT_DIR" \
        --load

    echo "🔨 Building binary for $ARCH..."

    # We mount REPO_ROOT (the parent with all packages) to /app
    # default WORKDIR in Dockerfile is /app/fewshell-agent
    docker run --rm \
        --platform "$PLATFORM" \
        -v "$REPO_ROOT:/app" \
        "$IMAGE_TAG" \
        /bin/bash -c "
            echo '📦 resolving dependencies...' && \
            flutter pub get && \
            echo '🔌 Compiling fewshell-server...' && \
            mkdir -p build/bin && \
            VERSION=\$(sed -n 's/^version: //p' pubspec.yaml) && \
            dart build cli -t bin/server.dart -DAPP_VERSION=\$VERSION -o build/bin/fewshell-server && \
            echo '🔧 Patching binary...' && \
            patchelf --set-rpath '\$ORIGIN' build/bin/fewshell-server && \
            echo '📦 Bundling system library...' && \
            cp /usr/lib/*-linux-gnu/libsqlite3.so.0 build/bin/libsqlite3.so
        "

    # Copy binary to release artifact name (e.g. fewshell-agent-linux-amd64)
    local ZIP_NAME="fewshell-agent-linux-$ARCH.zip"
    local ZIP_PATH="$BUILD_DIR/$ZIP_NAME"
    
    echo "🤐 Zipping binary and library..."
    # CD into build/bin so the zip structure is flat
    (cd "$PROJECT_ROOT/build/bin" && zip -r "$ZIP_PATH" fewshell-server libsqlite3.so)
    
    # Also keep the raw binary for reference (or if user wants just that)
    cp "$PROJECT_ROOT/build/bin/fewshell-server" "$OUTPUT_PATH"
    chmod +x "$OUTPUT_PATH"
}

# Build for AMD64 (x86_64)
build_arch "amd64" "linux/amd64"

# Build for ARM64
build_arch "arm64" "linux/arm64"

# -----------------------------------------------------------------------------
# MacOS Build (if running on Mac)
# -----------------------------------------------------------------------------
if [[ "$(uname)" == "Darwin" ]]; then
    echo "🍎 Detected macOS. Building native artifact..."
    
    # Assuming Apple Silicon (arm64) for M-class macs
    MACOS_ARCH="arm64"
    MACOS_OUTPUT_NAME="fewshell-agent-macos-$MACOS_ARCH"
    MACOS_OUTPUT_PATH="$BUILD_DIR/$MACOS_OUTPUT_NAME"
    
    echo "🔨 Building binary for macOS ($MACOS_ARCH)..."
    
    # Native compilation - must run inside fewshell-agent dir
    (
        cd "$PROJECT_ROOT"
        dart pub get
        dart build exe bin/server.dart -o "$MACOS_OUTPUT_PATH"
    )
    
    # Zip it (no need to bundle sqlite on macOS, it uses system framework)
    echo "🤐 Zipping macOS binary..."
    ZIP_NAME="fewshell-agent-macos-$MACOS_ARCH.zip"
    ZIP_PATH="$BUILD_DIR/$ZIP_NAME"
    (cd "$BUILD_DIR" && zip -r "$ZIP_PATH" "$MACOS_OUTPUT_NAME")
    
    # Keep raw binary executable
    chmod +x "$MACOS_OUTPUT_PATH"
else
    echo "🐧 Not running on macOS. Skipping native build."
fi

# -----------------------------------------------------------------------------
# Create GitHub Release
# -----------------------------------------------------------------------------
echo "📤 Pushing release v$VERSION to GitHub..."

# Check if release exists
if gh release view "v$VERSION" &> /dev/null; then
    echo "⚠️ Release v$VERSION already exists. Uploading assets to existing release..."
    gh release upload "v$VERSION" "$BUILD_DIR/fewshell-agent-linux-"* --clobber
else
    echo "✨ Creating new release v$VERSION..."
    gh release create "v$VERSION" \
        "$BUILD_DIR/fewshell-agent-"* \
        --title "v$VERSION" \
        --notes "Release v$VERSION of fewshell-agent (Linux AMD64/ARM64 + macOS ARM64)"
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
    for FILE in "$BUILD_DIR"/fewshell-agent-*; do
        if [ -f "$FILE" ]; then
            FILENAME=$(basename "$FILE")
            OBJECT_KEY="releases/$VERSION/$FILENAME"
            
            echo "    ⬆️  Uploading $FILENAME to $OBJECT_KEY..."
            
            # Use npx wrangler for upload
            npx wrangler r2 object put "fewshell-releases/$OBJECT_KEY" --file "$FILE" --remote

            # Upload to latest
            LATEST_KEY="releases/latest/$FILENAME"
            echo "    ⬆️  Uploading $FILENAME to $LATEST_KEY..."
            # Use 'no-cache' to force clients to validate the ETag with R2 every time.
            # R2 handles ETags automatically. If the file hasn't changed, R2 returns 304.
            npx wrangler r2 object put "fewshell-releases/$LATEST_KEY" --file "$FILE" --remote --cc "no-cache"
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

echo ""
echo "🔗 Release URLs:"
for FILE in "$BUILD_DIR"/fewshell-agent-*; do
    if [ -f "$FILE" ]; then
        FILENAME=$(basename "$FILE")
        echo "https://release.few.sh/releases/$VERSION/$FILENAME"
    fi
done
