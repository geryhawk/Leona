#!/bin/bash
# Leona App Store screenshot automation.
# Captures real simulator screenshots with deterministic mock data.

set -euo pipefail

ROOT="/Users/chahine/Projects/Leona"
APP_BUNDLE_ID="com.leona.app"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/LeonaScreenshotsDerivedData}"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Leona.app"

IPHONE_NAME="${IPHONE_NAME:-iPhone 17 Pro Max}"
IPAD_NAME="${IPAD_NAME:-iPad Pro 13-inch (M5)}"

OUT_IPHONE="$ROOT/Screenshots/AppStore_iPhone_6.9"
OUT_IPAD="$ROOT/Screenshots/AppStore_iPad_13"

mkdir -p "$OUT_IPHONE" "$OUT_IPAD"

find_device_id() {
    local device_name="$1"
    local line

    line="$(xcrun simctl list devices available | grep -F "    $device_name (" | head -n 1 || true)"
    if [ -z "$line" ]; then
        echo "Unable to find simulator: $device_name" >&2
        exit 1
    fi

    echo "$line" | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/'
}

boot_device() {
    local device_id="$1"

    xcrun simctl boot "$device_id" >/dev/null 2>&1 || true
    xcrun simctl bootstatus "$device_id" -b
    xcrun simctl ui "$device_id" appearance light >/dev/null 2>&1 || true
    xcrun simctl status_bar "$device_id" override \
        --time "9:41" \
        --batteryState charged \
        --batteryLevel 100 \
        --cellularMode active \
        --cellularBars 4 \
        --wifiMode active \
        --wifiBars 3 >/dev/null 2>&1 || true
}

build_app() {
    echo "==> Building app for simulator"
    xcodebuild \
        -project "$ROOT/Leona.xcodeproj" \
        -scheme Leona \
        -sdk iphonesimulator \
        -destination "generic/platform=iOS Simulator" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        build >/dev/null
}

install_app() {
    local device_id="$1"
    echo "==> Installing on $device_id"
    xcrun simctl uninstall "$device_id" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl install "$device_id" "$APP_PATH"
}

capture_screen() {
    local device_id="$1"
    local output_dir="$2"
    local filename="$3"
    local screen="$4"
    shift 4

    echo "  -> $filename [$screen]"
    xcrun simctl terminate "$device_id" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl launch "$device_id" "$APP_BUNDLE_ID" -demo -screen "$screen" "$@" >/dev/null
    sleep 5
    xcrun simctl io "$device_id" screenshot "$output_dir/$filename" >/dev/null
}

capture_device_set() {
    local device_id="$1"
    local output_dir="$2"

    capture_screen "$device_id" "$output_dir" "01_Welcome.png" onboarding -page 0
    capture_screen "$device_id" "$output_dir" "02_Dashboard.png" dashboard
    capture_screen "$device_id" "$output_dir" "03_Sleep.png" sleep
    capture_screen "$device_id" "$output_dir" "04_Forecast.png" forecast
    capture_screen "$device_id" "$output_dir" "05_Statistics.png" stats -variant sleep
    capture_screen "$device_id" "$output_dir" "06_Growth.png" growth -variant weight
    capture_screen "$device_id" "$output_dir" "07_Health.png" health
    capture_screen "$device_id" "$output_dir" "08_Sharing.png" sharing
}

main() {
    local iphone_id ipad_id
    iphone_id="$(find_device_id "$IPHONE_NAME")"
    ipad_id="$(find_device_id "$IPAD_NAME")"

    build_app

    echo "==> Booting iPhone simulator"
    boot_device "$iphone_id"
    install_app "$iphone_id"
    capture_device_set "$iphone_id" "$OUT_IPHONE"

    echo "==> Booting iPad simulator"
    boot_device "$ipad_id"
    install_app "$ipad_id"
    capture_device_set "$ipad_id" "$OUT_IPAD"

    echo ""
    echo "Done."
    echo "iPhone screenshots: $OUT_IPHONE"
    echo "iPad screenshots:   $OUT_IPAD"
}

main "$@"
