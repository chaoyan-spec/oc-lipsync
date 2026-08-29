#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/papalu-live-tests.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT
export CLANG_MODULE_CACHE_PATH="$TEMP_ROOT/module-cache"

mkdir -p "$TEMP_ROOT/toolchain/usr/lib" "$TEMP_ROOT/toolchain/usr/include/swift"
ln -s /Library/Developer/CommandLineTools/usr/lib/swift "$TEMP_ROOT/toolchain/usr/lib/swift"
rsync -a --exclude bridging.modulemap /Library/Developer/CommandLineTools/usr/include/swift/ "$TEMP_ROOT/toolchain/usr/include/swift/"

SOURCE_DIR="$SCRIPT_DIR/Sources/PAPAluLive"
TEST_DIR="$SCRIPT_DIR/Tests/PAPAluLiveTests"
RESOURCE_DIR="$TEMP_ROOT/toolchain/usr/lib/swift"

xcrun swiftc -swift-version 5 -target arm64-apple-macosx13.0 -resource-dir "$RESOURCE_DIR" -framework AppKit -framework QuartzCore "$SOURCE_DIR/MouthGate.swift" "$SOURCE_DIR/WindowScale.swift" "$SOURCE_DIR/CharacterDefinition.swift" "$SOURCE_DIR/CharacterAssets.swift" "$SOURCE_DIR/CharacterRuntime.swift" "$SOURCE_DIR/CharacterImagePreparer.swift" "$SOURCE_DIR/CustomCharacterStore.swift" "$SOURCE_DIR/AppPreferences.swift" "$SOURCE_DIR/IdleAnimationPlan.swift" "$SOURCE_DIR/ThoughtCloudPlan.swift" "$SOURCE_DIR/ThoughtCloudView.swift" "$SOURCE_DIR/CharacterWindow.swift" "$TEST_DIR/MouthGateTests.swift" "$TEST_DIR/WindowScaleTests.swift" "$TEST_DIR/IdleAnimationPlanTests.swift" "$TEST_DIR/ThoughtCloudPlanTests.swift" "$TEST_DIR/CharacterDefinitionTests.swift" "$TEST_DIR/CharacterRuntimeTests.swift" "$TEST_DIR/CharacterImagePreparerTests.swift" "$TEST_DIR/CustomCharacterStoreTests.swift" "$TEST_DIR/AppPreferencesTests.swift" "$TEST_DIR/main.swift" -o "$TEMP_ROOT/MouthGateTests"
"$TEMP_ROOT/MouthGateTests"

xcrun swiftc -swift-version 5 -target arm64-apple-macosx13.0 -resource-dir "$RESOURCE_DIR" -framework AppKit -framework QuartzCore -framework AVFoundation "$SOURCE_DIR/AppDelegate.swift" "$SOURCE_DIR/MicrophoneMonitor.swift" "$SOURCE_DIR/MouthGate.swift" "$SOURCE_DIR/CharacterDefinition.swift" "$SOURCE_DIR/CharacterAssets.swift" "$SOURCE_DIR/CharacterRuntime.swift" "$SOURCE_DIR/CharacterImagePreparer.swift" "$SOURCE_DIR/CustomCharacterStore.swift" "$SOURCE_DIR/AppPreferences.swift" "$SOURCE_DIR/CharacterSettingsController.swift" "$SOURCE_DIR/IdleAnimationPlan.swift" "$SOURCE_DIR/ThoughtCloudPlan.swift" "$SOURCE_DIR/ThoughtCloudView.swift" "$SOURCE_DIR/CharacterWindow.swift" "$SOURCE_DIR/WindowScale.swift" "$TEST_DIR/AppShellCompileTests.swift" -o "$TEMP_ROOT/PAPAluLiveContracts"

echo "PAPAluLive app-shell compile test passed"
"$SCRIPT_DIR/Tests/verify-camera-removed.sh"
"$SCRIPT_DIR/Tests/verify-app-icon.sh"
"$SCRIPT_DIR/Tests/verify-character-resources.sh"
