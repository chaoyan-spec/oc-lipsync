#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REALTIME_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$REALTIME_DIR/.." && pwd)"
MASTER_ICON="$REALTIME_DIR/Resources/AppIcon-1024.png"
ICNS_ICON="$REALTIME_DIR/Resources/AppIcon.icns"
ICON_GENERATOR="$REALTIME_DIR/generate-app-icon.swift"
APP_BUNDLE="$REPO_ROOT/outputs/悬浮说话角色.app"
APP_ICON="$APP_BUNDLE/Contents/Resources/AppIcon.icns"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/papalu-icon-test.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT

grep -Fq 'NSColor.white.setFill()' "$ICON_GENERATOR"
grep -Fq 'from: NSRect(x: 0, y: 0, width: 192, height: 208)' "$ICON_GENERATOR"
grep -Fq 'in: NSRect(x: 152, y: 112, width: 720, height: 780)' "$ICON_GENERATOR"
[[ -f "$MASTER_ICON" ]]
[[ "$(sips -g pixelWidth "$MASTER_ICON" | awk '/pixelWidth/ {print $2}')" == "1024" ]]
[[ "$(sips -g pixelHeight "$MASTER_ICON" | awk '/pixelHeight/ {print $2}')" == "1024" ]]
[[ -f "$ICNS_ICON" ]]
iconutil -c iconset "$ICNS_ICON" -o "$TEMP_DIR/AppIcon.iconset"
[[ -f "$TEMP_DIR/AppIcon.iconset/icon_512x512@2x.png" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$REALTIME_DIR/Resources/Info.plist")" == "AppIcon.icns" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$REALTIME_DIR/Resources/Info.plist")" == "悬浮说话角色" ]]
[[ -f "$APP_ICON" ]]
cmp -s "$ICNS_ICON" "$APP_ICON"
[[ -f "$APP_BUNDLE/Contents/Resources/Characters/CatMeme/idle.png" ]]
[[ -f "$APP_BUNDLE/Contents/Resources/Characters/PAPAlu/0.png" ]]

echo "Live character app bundle contract passed"
