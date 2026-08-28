#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_FRAME="$REPO_ROOT/public/papalu-talking/frames/0.png"
MASTER_ICON="$SCRIPT_DIR/Resources/AppIcon-1024.png"
ICNS_ICON="$SCRIPT_DIR/Resources/AppIcon.icns"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/papalu-icon-build.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT

mkdir -p "$TEMP_DIR/toolchain/usr/lib" "$TEMP_DIR/toolchain/usr/include/swift"
ln -s /Library/Developer/CommandLineTools/usr/lib/swift "$TEMP_DIR/toolchain/usr/lib/swift"
rsync -a \
    --exclude bridging.modulemap \
    /Library/Developer/CommandLineTools/usr/include/swift/ \
    "$TEMP_DIR/toolchain/usr/include/swift/"

xcrun swiftc \
    -target arm64-apple-macosx13.0 \
    -resource-dir "$TEMP_DIR/toolchain/usr/lib/swift" \
    -framework AppKit \
    "$SCRIPT_DIR/generate-app-icon.swift" \
    -o "$TEMP_DIR/generate-app-icon"
"$TEMP_DIR/generate-app-icon" "$SOURCE_FRAME" "$MASTER_ICON"

ICONSET="$TEMP_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"
for entry in \
    '16 icon_16x16.png' \
    '32 icon_16x16@2x.png' \
    '32 icon_32x32.png' \
    '64 icon_32x32@2x.png' \
    '128 icon_128x128.png' \
    '256 icon_128x128@2x.png' \
    '256 icon_256x256.png' \
    '512 icon_256x256@2x.png' \
    '512 icon_512x512.png' \
    '1024 icon_512x512@2x.png'; do
    size="${entry%% *}"
    name="${entry#* }"
    sips -z "$size" "$size" "$MASTER_ICON" --out "$ICONSET/$name" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$ICNS_ICON"
printf '%s\n%s\n' "$MASTER_ICON" "$ICNS_ICON"
