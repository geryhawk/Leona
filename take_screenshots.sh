#!/bin/bash
# Leona App Store Screenshot Automation
# Takes real screenshots from the iOS Simulator

set -e

IPHONE_ID="618215CB-0A77-432C-BCF8-45806704DD73"
IPAD_ID="27D2A055-6D7A-4713-A946-B0A0D87A75EE"
APP="com.leona.app"
BUILD_DIR="$HOME/Library/Developer/Xcode/DerivedData/Leona-fvrutsyenmpbqwfngovkwleyjsdh/Build/Products/Debug-iphonesimulator/Leona.app"
OUT_IPHONE="/Users/chahine/Projects/Leona/Screenshots/iPhone"
OUT_IPAD="/Users/chahine/Projects/Leona/Screenshots/iPad"

mkdir -p "$OUT_IPHONE" "$OUT_IPAD"

take_screenshot() {
    local device_id="$1"
    local tab="$2"
    local filename="$3"
    local output_dir="$4"
    local extra_args="${5:-}"

    echo "  Taking: $filename (tab=$tab)..."

    # Terminate any running instance
    xcrun simctl terminate "$device_id" "$APP" 2>/dev/null || true
    sleep 1

    # Launch with demo data and tab selection
    xcrun simctl launch "$device_id" "$APP" -demo -tab "$tab" $extra_args 2>/dev/null

    # Wait for app to load and render
    sleep 4

    # Take screenshot
    xcrun simctl io "$device_id" screenshot "$output_dir/$filename" 2>/dev/null
    echo "    Saved: $output_dir/$filename"
}

# Set clean status bar
setup_statusbar() {
    local device_id="$1"
    echo "Setting clean status bar on $device_id..."
    xcrun simctl status_bar "$device_id" override \
        --time "9:41" \
        --batteryLevel 100 \
        --batteryState charged \
        --cellularBars 4 \
        --wifiBars 3 2>/dev/null || true
}

# ── iPhone Screenshots ──
echo "=== iPhone 17 Pro Max Screenshots ==="

# Install app
echo "Installing app..."
xcrun simctl install "$IPHONE_ID" "$BUILD_DIR"
setup_statusbar "$IPHONE_ID"

# 1. Dashboard (Home)
take_screenshot "$IPHONE_ID" "home" "01_Dashboard.png" "$OUT_IPHONE"

# 2. Stats
take_screenshot "$IPHONE_ID" "stats" "02_Statistics.png" "$OUT_IPHONE"

# 3. Growth
take_screenshot "$IPHONE_ID" "growth" "03_Growth.png" "$OUT_IPHONE"

# 4. Health
take_screenshot "$IPHONE_ID" "health" "04_Health.png" "$OUT_IPHONE"

# 5. Settings
take_screenshot "$IPHONE_ID" "settings" "05_Settings.png" "$OUT_IPHONE"

echo ""
echo "=== iPad Pro 13-inch Screenshots ==="

# Build for iPad
echo "Building for iPad..."
xcodebuild -project Leona.xcodeproj -scheme Leona \
    -destination "id=$IPAD_ID" \
    -configuration Debug build 2>&1 | tail -2

echo "Installing app on iPad..."
xcrun simctl install "$IPAD_ID" "$BUILD_DIR"
setup_statusbar "$IPAD_ID"

# Same screenshots for iPad
take_screenshot "$IPAD_ID" "home" "01_Dashboard.png" "$OUT_IPAD"
take_screenshot "$IPAD_ID" "stats" "02_Statistics.png" "$OUT_IPAD"
take_screenshot "$IPAD_ID" "growth" "03_Growth.png" "$OUT_IPAD"
take_screenshot "$IPAD_ID" "health" "04_Health.png" "$OUT_IPAD"
take_screenshot "$IPAD_ID" "settings" "05_Settings.png" "$OUT_IPAD"

echo ""
echo "=== Done! ==="
echo "iPhone screenshots: $OUT_IPHONE"
echo "iPad screenshots: $OUT_IPAD"
