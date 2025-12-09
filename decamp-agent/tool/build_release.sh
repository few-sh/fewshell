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
    local DOCKER_PLATFORM=$2
    local IMAGE_TAG="${IMAGE_NAME}:${ARCH}"
    local OUTPUT_NAME="decamp-agent-linux-$ARCH"
    local OUTPUT_PATH="$BUILD_DIR/$OUTPUT_NAME"
    local OUTPUT_DIR="$BUILD_DIR" # Directory where the binary and libs will go

    echo "🏗️  Preparing builder for $ARCH ($DOCKER_PLATFORM)..."
    docker build -t "$IMAGE_TAG" --platform "$DOCKER_PLATFORM" -f "$SCRIPT_DIR/Dockerfile.build" "$SCRIPT_DIR" --load

    echo "🔨 Building binary for $ARCH..."

    # We mount REPO_ROOT (the parent with all packages) to /app
    # default WORKDIR in Dockerfile is /app/decamp-agent
    docker run --rm \
        --platform "$DOCKER_PLATFORM" \
        -v "$REPO_ROOT:/app" \
        "$IMAGE_TAG" \
        /bin/bash -c "
            echo '📦 resolving dependencies...' && \
            flutter pub get && \
            echo '🔌 Compiling server...' && \
            mkdir -p build/bin && \
            dart compile exe bin/server.dart -o build/bin/server
        "


    # Create a directory for this architecture
    local ARCH_DIR="$BUILD_DIR/$ARCH"
    mkdir -p "$ARCH_DIR"

    # Copy binary to release artifact name (simple 'decamp-agent' for user convenience inside zip)
    # Or keep specific name? Simple name is better for valid commands like ./decamp-agent
    cp "$PROJECT_ROOT/build/bin/server" "$ARCH_DIR/decamp-agent"
    chmod +x "$ARCH_DIR/decamp-agent"

    # Extract system libsqlite3.so (guarantees correct architecture: amd64 vs arm64)
    # Use cp -L to dereference symlink so we get the real file
    local id=$(docker create "$IMAGE_TAG")
    
    local LIB_SRC=""
    if [ "$ARCH" == "amd64" ]; then
        LIB_SRC="/usr/lib/x86_64-linux-gnu/libsqlite3.so"
    elif [ "$ARCH" == "arm64" ]; then
        LIB_SRC="/usr/lib/aarch64-linux-gnu/libsqlite3.so"
    fi

    # Perform copy via temp container command to dereference
    # Actually, docker cp does not dereference.
    # We can run a command to copy it to a temp file in container, then docker cp that.
    docker run --rm -v "$ARCH_DIR:/output" "$IMAGE_TAG" sh -c "cp -L $LIB_SRC /output/libsqlite3.so" || echo "Warning: Failed to copy libsqlite3.so from $LIB_SRC"

    docker rm -v "$id" # This container was created but unused by our new logic, remove it.

    # Create ZIP archive
    echo "📦 Zipping $ARCH release..."
    cd "$BUILD_DIR"
    zip -r "$OUTPUT_NAME.zip" "$ARCH"
    cd "$PROJECT_ROOT"
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
    gh release upload "v$VERSION" "$BUILD_DIR/"*.zip --clobber
else
    echo "✨ Creating new release v$VERSION..."
    gh release create "v$VERSION" \
        "$BUILD_DIR/"*.zip \
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
    for FILE in "$BUILD_DIR"/decamp-agent-linux-*.zip; do
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

