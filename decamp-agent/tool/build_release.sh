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
            echo \"const packageVersion = '\$VERSION';\" > lib/version.dart && \
            dart build cli -t bin/server.dart -o build/cli_out && \
            cp build/cli_out/bundle/bin/server build/bin/fewshell-server && \
            if [ -d "build/cli_out/bundle/lib" ]; then cp -r build/cli_out/bundle/lib/* build/bin/ || true; fi && \
            echo '🔧 Patching binary...' && \
            patchelf --set-rpath '\$ORIGIN' build/bin/fewshell-server && \
            echo '📦 Bundling system library...' && \
            cp /usr/lib/*-linux-gnu/libsqlite3.so.0 build/bin/libsqlite3.so
        "

    local TGZ_NAME="fewshell-agent-linux-$ARCH.tar.gz"
    local TGZ_PATH="$BUILD_DIR/$TGZ_NAME"
    
    echo "📦 Creating tarball..."
    # CD into build/bin so the archive structure is flat
    (cd "$PROJECT_ROOT/build/bin" && tar czf "$TGZ_PATH" .)
    
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
    MACOS_BUILD_BIN="$PROJECT_ROOT/build/macos_bin"
    
    echo "🔨 Building binary for macOS ($MACOS_ARCH)..."
    
    # Native compilation - must run inside fewshell-agent dir
    (
        cd "$PROJECT_ROOT"
        
        # Generate version file
        VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
        echo "const packageVersion = '$VERSION';" > lib/version.dart

        dart pub get
        dart build cli -t bin/server.dart -o build/macos_cli_out

        # Stage binary and libs into a flat directory (consistent with Linux)
        rm -rf "$MACOS_BUILD_BIN"
        mkdir -p "$MACOS_BUILD_BIN"
        cp build/macos_cli_out/bundle/bin/server "$MACOS_BUILD_BIN/fewshell-server"
        if [ -d "build/macos_cli_out/bundle/lib" ]; then
            cp -r build/macos_cli_out/bundle/lib/* "$MACOS_BUILD_BIN/" || true
        fi
    )
    
    # Create tarball from flat staging dir (consistent with Linux)
    echo "📦 Creating macOS tarball..."
    TGZ_NAME="fewshell-agent-macos-$MACOS_ARCH.tar.gz"
    TGZ_PATH="$BUILD_DIR/$TGZ_NAME"
    (cd "$MACOS_BUILD_BIN" && tar czf "$TGZ_PATH" .)
    
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
