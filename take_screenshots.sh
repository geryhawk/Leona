#!/bin/bash
# Leona App Store screenshot automation.
# Captures real simulator screenshots of the Thread v2 screens with deterministic demo data,
# on the two App Store reference devices, in English and in French.
# The status bar shows the real capture time so it matches the app's own "now" divider and
# timers; the demo day reads best when captured between 16:05 and 16:20 local time.
#
#   ./take_screenshots.sh              # build, then capture everything
#   SKIP_BUILD=1 ./take_screenshots.sh # reuse the last build
#   LANGS="fr" ./take_screenshots.sh   # one language only
#
# Output: Screenshots/AppStore_iPhone_6.9/<lang>/*.png and Screenshots/AppStore_iPad_13/<lang>/*.png
# Then run generate_marketing_screenshots.py (via Docker) to compose the promotional frames.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_BUNDLE_ID="com.leona.app"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/LeonaScreenshotsDerivedData}"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Leona.app"

IPHONE_NAME="${IPHONE_NAME:-iPhone 17 Pro Max}"
IPAD_NAME="${IPAD_NAME:-iPad Pro 13-inch (M5)}"
LANGS="${LANGS:-en fr}"
SETTLE_SECONDS="${SETTLE_SECONDS:-6}"

OUT_IPHONE="$ROOT/Screenshots/AppStore_iPhone_6.9"
OUT_IPAD="$ROOT/Screenshots/AppStore_iPad_13"

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
    # First boot after install shows a one-off system notification (Apple Intelligence);
    # give it time to go away before the first capture.
    sleep "${BOOT_SETTLE_SECONDS:-15}"
    xcrun simctl status_bar "$device_id" override \
        --time "$(date +%H:%M)" \
        --batteryState charged \
        --batteryLevel 100 \
        --cellularMode active \
        --cellularBars 4 \
        --wifiMode active \
        --wifiBars 3 >/dev/null 2>&1 || true
}

build_app() {
    if [ "${SKIP_BUILD:-0}" = "1" ] && [ -d "$APP_PATH" ]; then
        echo "==> Reusing build at $APP_PATH"
        return
    fi
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

locale_for() {
    case "$1" in
        fr) echo "fr_FR" ;;
        fi) echo "fi_FI" ;;
        *)  echo "en_US" ;;
    esac
}

capture_screen() {
    local device_id="$1"
    local output_dir="$2"
    local filename="$3"
    local lang="$4"
    local screen="$5"
    shift 5

    echo "  -> $lang/$filename [$screen]"
    xcrun simctl terminate "$device_id" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl launch "$device_id" "$APP_BUNDLE_ID" \
        -demo -screen "$screen" "$@" \
        -AppleLanguages "($lang)" -AppleLocale "$(locale_for "$lang")" >/dev/null
    sleep "$SETTLE_SECONDS"
    xcrun simctl io "$device_id" screenshot "$output_dir/$filename" >/dev/null
}

capture_device_set() {
    local device_id="$1"
    local base_dir="$2"
    local lang="$3"
    local output_dir="$base_dir/$lang"
    mkdir -p "$output_dir"

    capture_screen "$device_id" "$output_dir" "01_Welcome.png"  "$lang" onboarding
    capture_screen "$device_id" "$output_dir" "02_Thread.png"   "$lang" dashboard
    capture_screen "$device_id" "$output_dir" "03_Sleep.png"    "$lang" sleep
    capture_screen "$device_id" "$output_dir" "04_Trends.png"   "$lang" stats
    capture_screen "$device_id" "$output_dir" "05_Growth.png"   "$lang" growth
    capture_screen "$device_id" "$output_dir" "06_Health.png"   "$lang" health
    capture_screen "$device_id" "$output_dir" "07_Sharing.png"  "$lang" sharing
    capture_screen "$device_id" "$output_dir" "08_Profile.png"  "$lang" settings
}

main() {
    local iphone_id ipad_id lang
    iphone_id="$(find_device_id "$IPHONE_NAME")"
    ipad_id="$(find_device_id "$IPAD_NAME")"

    build_app

    echo "==> Booting iPhone simulator ($IPHONE_NAME)"
    boot_device "$iphone_id"
    install_app "$iphone_id"
    for lang in $LANGS; do
        capture_device_set "$iphone_id" "$OUT_IPHONE" "$lang"
    done
    xcrun simctl terminate "$iphone_id" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true

    echo "==> Booting iPad simulator ($IPAD_NAME)"
    boot_device "$ipad_id"
    install_app "$ipad_id"
    for lang in $LANGS; do
        capture_device_set "$ipad_id" "$OUT_IPAD" "$lang"
    done
    xcrun simctl terminate "$ipad_id" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true

    echo ""
    echo "Done."
    echo "iPhone screenshots: $OUT_IPHONE/{$(echo $LANGS | tr ' ' ',')}"
    echo "iPad screenshots:   $OUT_IPAD/{$(echo $LANGS | tr ' ' ',')}"
}

main "$@"
