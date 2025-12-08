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
    echo "Error: gh is not authenticated. file run 'gh auth login'."
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
            dart compile exe bin/server.dart -o build/releases/$OUTPUT_NAME
        "
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
    gh release upload "v$VERSION" "$BUILD_DIR/"* --clobber
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
# Cleanup
# -----------------------------------------------------------------------------
echo "🧹 Restoring local environment..."
flutter pub get

