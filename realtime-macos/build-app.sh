#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$REPO_ROOT/outputs"
OUTPUT_APP="$OUTPUT_DIR/PAPAlu实时口型.app"
SOURCE_DIR="$SCRIPT_DIR/Sources/PAPAluLive"
FRAME_DIR="$REPO_ROOT/public/papalu-talking/frames"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/papalu-live-build.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT

for frame in 0 1 2 3 4 5 6 7; do
  if [[ ! -f "$FRAME_DIR/$frame.png" ]]; then
    echo "Missing authoritative PAPAlu frame: $FRAME_DIR/$frame.png" >&2
    exit 1
  fi
done

mkdir -p "$TEMP_ROOT/toolchain/usr/lib" "$TEMP_ROOT/toolchain/usr/include/swift"
ln -s /Library/Developer/CommandLineTools/usr/lib/swift "$TEMP_ROOT/toolchain/usr/lib/swift"
rsync -a --exclude bridging.modulemap /Library/Developer/CommandLineTools/usr/include/swift/ "$TEMP_ROOT/toolchain/usr/include/swift/"

STAGED_APP="$TEMP_ROOT/PAPAlu实时口型.app"
CONTENTS="$STAGED_APP/Contents"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources/Frames"

xcrun swiftc -O -swift-version 5 -target arm64-apple-macosx13.0 -resource-dir "$TEMP_ROOT/toolchain/usr/lib/swift" -framework AppKit -framework AVFoundation "$SOURCE_DIR/AppDelegate.swift" "$SOURCE_DIR/MicrophoneMonitor.swift" "$SOURCE_DIR/MouthGate.swift" "$SOURCE_DIR/PAPAluWindow.swift" "$SOURCE_DIR/WindowScale.swift" -o "$CONTENTS/MacOS/PAPAluLive"

cp "$SCRIPT_DIR/Resources/Info.plist" "$CONTENTS/Info.plist"
for frame in 0 1 2 3 4 5 6 7; do
  cp "$FRAME_DIR/$frame.png" "$CONTENTS/Resources/Frames/$frame.png"
done
chmod +x "$CONTENTS/MacOS/PAPAluLive"
plutil -lint "$CONTENTS/Info.plist" >/dev/null

mkdir -p "$OUTPUT_DIR"
if [[ -e "$OUTPUT_APP" ]]; then
  mv "$OUTPUT_APP" "$TEMP_ROOT/previous.app"
fi
mv "$STAGED_APP" "$OUTPUT_APP"

echo "$OUTPUT_APP"
