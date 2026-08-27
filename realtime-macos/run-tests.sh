#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/papalu-live-tests.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT

mkdir -p "$TEMP_ROOT/toolchain/usr/lib" "$TEMP_ROOT/toolchain/usr/include/swift"
ln -s /Library/Developer/CommandLineTools/usr/lib/swift "$TEMP_ROOT/toolchain/usr/lib/swift"
rsync -a --exclude bridging.modulemap /Library/Developer/CommandLineTools/usr/include/swift/ "$TEMP_ROOT/toolchain/usr/include/swift/"

SOURCE_DIR="$SCRIPT_DIR/Sources/PAPAluLive"
TEST_DIR="$SCRIPT_DIR/Tests/PAPAluLiveTests"
RESOURCE_DIR="$TEMP_ROOT/toolchain/usr/lib/swift"

xcrun swiftc "$SOURCE_DIR/MouthGate.swift" "$SOURCE_DIR/WindowScale.swift" "$TEST_DIR/MouthGateTests.swift" "$TEST_DIR/WindowScaleTests.swift" "$TEST_DIR/main.swift" -o "$TEMP_ROOT/MouthGateTests"
"$TEMP_ROOT/MouthGateTests"

xcrun swiftc -swift-version 5 -target arm64-apple-macosx13.0 -resource-dir "$RESOURCE_DIR" -framework AppKit -framework AVFoundation "$SOURCE_DIR/AppDelegate.swift" "$SOURCE_DIR/MicrophoneMonitor.swift" "$SOURCE_DIR/MouthGate.swift" "$SOURCE_DIR/PAPAluWindow.swift" "$SOURCE_DIR/WindowScale.swift" "$TEST_DIR/AppShellCompileTests.swift" -o "$TEMP_ROOT/PAPAluLiveContracts"

echo "PAPAluLive app-shell compile test passed"
