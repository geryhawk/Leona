#!/bin/bash
# Leona - iOS App Setup Script
# Run this on macOS to set up and build the project

set -e

echo "=== Leona iOS App Setup ==="
echo ""

# Check we're on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "Error: This script must be run on macOS with Xcode installed."
    exit 1
fi

# Check Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: Xcode is not installed. Install it from the App Store."
    exit 1
fi

echo "Xcode version: $(xcodebuild -version | head -1)"
echo ""

# Check if xcodegen is available for project regeneration
if command -v xcodegen &> /dev/null; then
    echo "xcodegen found. Regenerating project..."
    xcodegen generate
    echo "Project regenerated successfully!"
else
    echo "xcodegen not found. Using bundled .xcodeproj file."
    echo "For best results, install xcodegen: brew install xcodegen"
    echo "Then run: xcodegen generate"
fi

echo ""
echo "Building Leona..."
echo ""

# Build for simulator
xcodebuild \
    -project Leona.xcodeproj \
    -scheme Leona \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=latest' \
    -configuration Debug \
    clean build \
    2>&1 | tail -20

echo ""
echo "=== Build Complete ==="
echo ""
echo "To open in Xcode:"
echo "  open Leona.xcodeproj"
echo ""
echo "To run on simulator:"
echo "  1. Open Leona.xcodeproj in Xcode"
echo "  2. Select iPhone 15 Pro simulator"
echo "  3. Press Cmd+R to build and run"
echo ""
echo "For iCloud sync:"
echo "  1. Set your Development Team in Signing & Capabilities"
echo "  2. Enable iCloud capability with CloudKit"
echo "  3. Add container: iCloud.com.leona.app"
