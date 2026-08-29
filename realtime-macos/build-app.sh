#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$REPO_ROOT/outputs"
OUTPUT_APP="$OUTPUT_DIR/悬浮说话角色.app"
SOURCE_DIR="$SCRIPT_DIR/Sources/PAPAluLive"
CAT_DIR="$SCRIPT_DIR/Resources/Characters/CatMeme"
PAPALU_DIR="$REPO_ROOT/public/papalu-talking/frames"
ICON_FILE="$SCRIPT_DIR/Resources/AppIcon.icns"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/papalu-live-build.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT
export CLANG_MODULE_CACHE_PATH="$TEMP_ROOT/module-cache"

for asset in idle talking; do
  if [[ ! -f "$CAT_DIR/$asset.png" ]]; then
    echo "Missing built-in cat asset: $CAT_DIR/$asset.png" >&2
    exit 1
  fi
done

for frame in 0 1 2 3 4 5 6 7; do
  if [[ ! -f "$PAPALU_DIR/$frame.png" ]]; then
    echo "Missing authoritative PAPAlu frame: $PAPALU_DIR/$frame.png" >&2
    exit 1
  fi
done

if [[ ! -f "$ICON_FILE" ]]; then
  echo "Missing PAPAlu app icon: $ICON_FILE" >&2
  exit 1
fi

mkdir -p "$TEMP_ROOT/toolchain/usr/lib" "$TEMP_ROOT/toolchain/usr/include/swift"
ln -s /Library/Developer/CommandLineTools/usr/lib/swift "$TEMP_ROOT/toolchain/usr/lib/swift"
rsync -a --exclude bridging.modulemap /Library/Developer/CommandLineTools/usr/include/swift/ "$TEMP_ROOT/toolchain/usr/include/swift/"

STAGED_APP="$TEMP_ROOT/悬浮说话角色.app"
CONTENTS="$STAGED_APP/Contents"
CHARACTER_RESOURCES="$CONTENTS/Resources/Characters"
mkdir -p \
  "$CONTENTS/MacOS" \
  "$CHARACTER_RESOURCES/CatMeme" \
  "$CHARACTER_RESOURCES/PAPAlu"

xcrun swiftc -O -swift-version 5 -target arm64-apple-macosx13.0 -resource-dir "$TEMP_ROOT/toolchain/usr/lib/swift" -framework AppKit -framework QuartzCore -framework AVFoundation "$SOURCE_DIR/AppDelegate.swift" "$SOURCE_DIR/MicrophoneMonitor.swift" "$SOURCE_DIR/MouthGate.swift" "$SOURCE_DIR/CharacterDefinition.swift" "$SOURCE_DIR/CharacterAssets.swift" "$SOURCE_DIR/CharacterRuntime.swift" "$SOURCE_DIR/IdleAnimationPlan.swift" "$SOURCE_DIR/ThoughtCloudPlan.swift" "$SOURCE_DIR/ThoughtCloudView.swift" "$SOURCE_DIR/CharacterWindow.swift" "$SOURCE_DIR/WindowScale.swift" -o "$CONTENTS/MacOS/PAPAluLive"

cp "$SCRIPT_DIR/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$ICON_FILE" "$CONTENTS/Resources/AppIcon.icns"
cp "$CAT_DIR/idle.png" "$CHARACTER_RESOURCES/CatMeme/idle.png"
cp "$CAT_DIR/talking.png" "$CHARACTER_RESOURCES/CatMeme/talking.png"
for frame in 0 1 2 3 4 5 6 7; do
  cp "$PAPALU_DIR/$frame.png" "$CHARACTER_RESOURCES/PAPAlu/$frame.png"
done
chmod +x "$CONTENTS/MacOS/PAPAluLive"
plutil -lint "$CONTENTS/Info.plist" >/dev/null

mkdir -p "$OUTPUT_DIR"
if [[ -e "$OUTPUT_APP" ]]; then
  mv "$OUTPUT_APP" "$TEMP_ROOT/previous.app"
fi
mv "$STAGED_APP" "$OUTPUT_APP"

echo "$OUTPUT_APP"
