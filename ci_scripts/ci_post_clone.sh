#!/bin/sh

# ci_post_clone.sh
# Xcode Cloud runs this script after cloning the repository.

echo "=== Leona CI: Post-clone script ==="
echo "Xcode version: $(xcodebuild -version)"
echo "Swift version: $(swift --version)"
echo "Build number: ${CI_BUILD_NUMBER}"
echo "=== Post-clone complete ==="
