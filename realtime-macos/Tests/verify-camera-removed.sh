#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REALTIME_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$REALTIME_DIR/.." && pwd)"

removed_files=(
  "$REALTIME_DIR/Sources/PAPAluLive/CameraMonitor.swift"
  "$REALTIME_DIR/Sources/PAPAluLive/WaveDetector.swift"
  "$REALTIME_DIR/Sources/PAPAluLive/ActionCoordinator.swift"
  "$SCRIPT_DIR/PAPAluLiveTests/WaveDetectorTests.swift"
  "$SCRIPT_DIR/PAPAluLiveTests/ActionCoordinatorTests.swift"
)

for path in "${removed_files[@]}"; do
  if [[ -e "$path" ]]; then
    echo "Camera feature file still exists: $path" >&2
    exit 1
  fi
done

assert_absent() {
  local pattern="$1"
  shift
  if rg -n "$pattern" "$@"; then
    echo "Camera feature reference still exists: $pattern" >&2
    exit 1
  fi
}

assert_absent \
  'CameraMonitor|WaveDetector|cameraMonitor|waveDetector|showCamera|handleWave|ActionCoordinator' \
  "$REALTIME_DIR/Sources/PAPAluLive/AppDelegate.swift"
assert_absent \
  'teaching|Teaching\.png|teachingImage' \
  "$REALTIME_DIR/Sources/PAPAluLive/PAPAluWindow.swift"
assert_absent \
  'CameraMonitor|HandPoseSample|teaching' \
  "$SCRIPT_DIR/PAPAluLiveTests/AppShellCompileTests.swift"
assert_absent \
  'NSCameraUsageDescription' \
  "$REALTIME_DIR/Resources/Info.plist"
assert_absent \
  'CameraMonitor\.swift|WaveDetector\.swift|ActionCoordinator\.swift|-framework Vision|Teaching\.png|TEACHING_IMAGE' \
  "$REALTIME_DIR/build-app.sh" \
  "$REALTIME_DIR/run-tests.sh"

if [[ ! -f "$REPO_ROOT/public/papalu-states/teaching.png" ]]; then
  echo "Shared approved teaching asset must remain in the repository" >&2
  exit 1
fi

echo "PAPAluLive camera-removal contract passed"
