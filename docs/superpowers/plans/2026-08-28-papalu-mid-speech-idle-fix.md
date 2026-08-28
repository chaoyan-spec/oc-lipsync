# PAPAlu Mid-Speech Idle Bug Fix Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use executing-plans to implement this plan task-by-task.

**Goal:** Prevent PAPAlu from entering idle during natural mid-sentence pauses while preserving prompt response and real silence detection.

**Architecture:** Keep the existing `AVAudioEngine → RMS → MouthGate → PAPAluWindow` chain unchanged. Adjust only the centralized default gate configuration, protected by focused regression tests.

**Tech Stack:** Swift, existing shell-based Swift tests, AppKit/AVFoundation app build.

---

### Task 1: Reproduce the confirmed gate failure

**Files:**
- Modify: `realtime-macos/Tests/PAPAluLiveTests/MouthGateTests.swift`

1. Add tests for the approved defaults, a 200ms mid-sentence quiet interval, soft speech at RMS 0.020, sub-threshold background noise, and eventual idle after more than 300ms.
2. Run `./realtime-macos/run-tests.sh` and verify the new tests fail for the old `0.025 / 120ms` configuration.

### Task 2: Apply the minimal parameter fix

**Files:**
- Modify: `realtime-macos/Sources/PAPAluLive/MouthGate.swift`
- Modify: `README.md`

1. Change only `openThreshold` to `0.020` and `releaseDelay` to `0.30`.
2. Run the native test suite and verify all tests pass.
3. Update README timing language from 120ms to about 300ms.

### Task 3: Full regression and delivery

**Files:**
- Output: `outputs/PAPAlu实时口型.app`

1. Run `./realtime-macos/run-tests.sh`.
2. Run `npm test` for the offline web tool.
3. Run `./realtime-macos/build-app.sh`.
4. Synchronize the verified app to `/Users/chaoyan/Documents/Codex/2026-08-08/zhe-s/outputs/PAPAlu实时口型.app`.
5. Launch the formal output and confirm the app remains lightweight.

**Stop condition:** Do not add adaptive thresholds, settings, new animation states, or unrelated tuning.
