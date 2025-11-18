#!/bin/bash
# Script to reset the database during development
# This deletes the existing database so the app will recreate it with the latest schema

set -e

echo "🗑️  Resetting database..."

# Find and delete all decamp.db files in iOS Simulator
find ~/Library/Developer/CoreSimulator -name "decamp.db*" -type f -exec rm -f {} \; 2>/dev/null || true

# Find and delete all decamp.db files in Android Emulator
find ~/Library/Android -name "decamp.db*" -type f -exec rm -f {} \; 2>/dev/null || true

echo "✅ Database deleted. The app will recreate it on next launch with the new schema."
echo ""
echo "💡 Note: This only works for simulators/emulators. For physical devices:"
echo "   - Uninstall and reinstall the app, OR"
echo "   - Clear app data from device settings"
