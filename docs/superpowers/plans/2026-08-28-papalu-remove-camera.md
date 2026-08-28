# PAPAlu Remove Camera Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove all camera, Vision, wave detection, and teaching-overlay behavior from the native PAPAlu real-time app while preserving microphone lip sync, idle animation, scaling, QuickTime capture, the offline web tool, and the shared teaching asset.

**Architecture:** Add a shell contract that scans only the native runtime and build surface for forbidden camera dependencies. Then simplify the native state to `idle`/`talking`, remove camera-specific source and tests, and stop packaging `Teaching.png`. The public approved teaching image remains untouched outside the app bundle.

**Tech Stack:** Swift 5, AppKit, QuartzCore, AVFoundation audio, shell build/tests, Node.js offline-tool tests.

## Global Constraints

- The native app must request microphone permission only.
- Remove Vision, video capture, wave detection, teaching state, and Teaching.png bundle dependency.
- Preserve `public/papalu-states/teaching.png` in the repository.
- Do not change mouth thresholds, talking frames, idle sway, blink timing, scaling, or the offline web tool.

---

### Task 1: Add a Failing No-Camera Runtime Contract

**Files:**
- Create: `realtime-macos/Tests/verify-camera-removed.sh`
- Modify: `realtime-macos/run-tests.sh`

**Interfaces:**
- Produces: a deterministic shell check invoked by `run-tests.sh`.
- Checks: removed source/test files are absent; runtime/build/plist files contain no camera, Vision, wave, or Teaching.png dependencies; public teaching asset still exists.

- [ ] **Step 1: Write the failing removal contract**

Create an executable shell test that fails if any of these files still exist:

```text
Sources/PAPAluLive/CameraMonitor.swift
Sources/PAPAluLive/WaveDetector.swift
Sources/PAPAluLive/ActionCoordinator.swift
Tests/PAPAluLiveTests/WaveDetectorTests.swift
Tests/PAPAluLiveTests/ActionCoordinatorTests.swift
```

It must also fail if `AppDelegate.swift`, `PAPAluWindow.swift`, `AppShellCompileTests.swift`, `Info.plist`, `build-app.sh`, or `run-tests.sh` contains the removed runtime identifiers. It must independently assert that `../public/papalu-states/teaching.png` still exists.

- [ ] **Step 2: Invoke the contract from the native test runner**

Append:

```bash
"$TEST_DIR/verify-camera-removed.sh"
```

after the AppKit compile test.

- [ ] **Step 3: Run tests and verify RED**

Run `./realtime-macos/run-tests.sh`.

Expected: the existing Swift tests compile and pass, then the new contract fails because `CameraMonitor.swift` still exists.

- [ ] **Step 4: Commit the failing contract**

```bash
git add realtime-macos/Tests/verify-camera-removed.sh realtime-macos/run-tests.sh
git commit -m "test: require camera-free PAPAlu runtime"
```

### Task 2: Remove Camera Runtime and Temporary Teaching State

**Files:**
- Delete: `realtime-macos/Sources/PAPAluLive/CameraMonitor.swift`
- Delete: `realtime-macos/Sources/PAPAluLive/WaveDetector.swift`
- Delete: `realtime-macos/Sources/PAPAluLive/ActionCoordinator.swift`
- Delete: `realtime-macos/Tests/PAPAluLiveTests/WaveDetectorTests.swift`
- Delete: `realtime-macos/Tests/PAPAluLiveTests/ActionCoordinatorTests.swift`
- Modify: `realtime-macos/Sources/PAPAluLive/AppDelegate.swift`
- Modify: `realtime-macos/Sources/PAPAluLive/PAPAluWindow.swift`
- Modify: `realtime-macos/Tests/PAPAluLiveTests/AppShellCompileTests.swift`
- Modify: `realtime-macos/Tests/PAPAluLiveTests/main.swift`
- Modify: `realtime-macos/run-tests.sh`

**Interfaces:**
- Produces: `PAPAluDisplayState` with only `.idle` and `.talking` in `PAPAluWindow.swift`.
- Changes: microphone state maps directly to the display state.
- Removes: all camera startup, camera alerts, wave handling, teaching timing, and teaching rendering.

- [ ] **Step 1: Simplify the app state and window renderer**

Move the two-value display enum next to `PAPAluWindow`, remove teaching image errors/loading/properties, and delete the `.teaching` switch case. In `AppDelegate`, keep only `MicrophoneMonitor`, `MouthGate`, current microphone state, and direct idle/talking rendering.

- [ ] **Step 2: Delete camera and temporary-action modules and tests**

Delete the five exact source/test files listed above. Update `main.swift`, the native unit compile command, and the AppKit compile command so they only reference remaining modules. Remove `-framework Vision`; retain AVFoundation for microphone audio.

- [ ] **Step 3: Run native tests and verify GREEN**

Run `./realtime-macos/run-tests.sh`.

Expected: 15 remaining native tests pass, AppKit shell compiles, and the no-camera contract prints PASS.

- [ ] **Step 4: Commit runtime removal**

```bash
git add -A realtime-macos/Sources realtime-macos/Tests realtime-macos/run-tests.sh
git commit -m "refactor: remove PAPAlu camera runtime"
```

### Task 3: Remove Permissions and Bundle Dependencies, Then Deliver

**Files:**
- Modify: `realtime-macos/Resources/Info.plist`
- Modify: `realtime-macos/build-app.sh`
- Modify: `README.md`
- Preserve: `public/papalu-states/teaching.png`
- Build output: `outputs/PAPAlu实时口型.app`

**Interfaces:**
- Build consumes only eight talking frames as image resources.
- App Info.plist contains `NSMicrophoneUsageDescription` and no `NSCameraUsageDescription`.

- [ ] **Step 1: Remove camera permission and teaching bundle logic**

Delete the camera usage key/string from Info.plist. Delete the teaching-image variable, existence check, copy command, camera source files, and Vision framework from `build-app.sh`.

- [ ] **Step 2: Update the README**

Remove the camera experiment and wave instructions. State that the real-time app requests only microphone permission and uses only talking/idle behavior.

- [ ] **Step 3: Run fresh complete verification**

Run:

```bash
./realtime-macos/run-tests.sh
npm test
npm run build
git diff --check
```

Expected: 15 native tests, the camera-removal contract, AppKit compile, all 78 web tests, and web build pass.

- [ ] **Step 4: Build and inspect the final app**

Run `./realtime-macos/build-app.sh`, then verify:

```bash
! plutil -p outputs/PAPAlu实时口型.app/Contents/Info.plist | grep -q NSCameraUsageDescription
test ! -e outputs/PAPAlu实时口型.app/Contents/Resources/Teaching.png
test -f public/papalu-states/teaching.png
```

Replace `/Users/chaoyan/Documents/Codex/2026-08-08/zhe-s/outputs/PAPAlu实时口型.app`, verify binary equality, and launch it.

- [ ] **Step 5: Smoke-check runtime cost and permissions**

Confirm the app process runs, has no network sockets, and samples near-idle CPU after the camera/Vision loop is gone. Physical speech and QuickTime recording remain user acceptance checks.

- [ ] **Step 6: Commit permissions, build, and documentation cleanup**

```bash
git add realtime-macos/Resources/Info.plist realtime-macos/build-app.sh README.md
git commit -m "build: remove PAPAlu camera permission and assets"
```
