#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REALTIME_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$REALTIME_DIR/.." && pwd)"
MASTER_ICON="$REALTIME_DIR/Resources/AppIcon-1024.png"
ICNS_ICON="$REALTIME_DIR/Resources/AppIcon.icns"
APP_ICON="$REPO_ROOT/outputs/PAPAlu实时口型.app/Contents/Resources/AppIcon.icns"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/papalu-icon-test.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT

[[ -f "$MASTER_ICON" ]]
[[ "$(sips -g pixelWidth "$MASTER_ICON" | awk '/pixelWidth/ {print $2}')" == "1024" ]]
[[ "$(sips -g pixelHeight "$MASTER_ICON" | awk '/pixelHeight/ {print $2}')" == "1024" ]]
[[ -f "$ICNS_ICON" ]]
iconutil -c iconset "$ICNS_ICON" -o "$TEMP_DIR/AppIcon.iconset"
[[ -f "$TEMP_DIR/AppIcon.iconset/icon_512x512@2x.png" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$REALTIME_DIR/Resources/Info.plist")" == "AppIcon.icns" ]]
[[ -f "$APP_ICON" ]]
cmp -s "$ICNS_ICON" "$APP_ICON"

echo "PAPAlu app icon contract passed"
