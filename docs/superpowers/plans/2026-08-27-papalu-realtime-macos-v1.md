# PAPAlu Realtime macOS V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS PAPAlu overlay that opens and closes its mouth from live microphone energy while remaining capturable in QuickTime screen recordings.

**Architecture:** Add an isolated Swift Package under `realtime-macos/`. A pure MouthGate converts smoothed RMS into idle/talking state, MicrophoneMonitor owns AVAudioEngine and permission flow, PAPAluWindow owns the transparent floating panel and frame animation, and AppDelegate wires them together. A shell script packages the executable and copies the existing authoritative PNG frames into the `.app` without duplicating source assets.

**Tech Stack:** Swift 5 language mode, Swift Package Manager, AppKit, AVFoundation, XCTest, existing Node.js test suite.

## Global Constraints

- Preserve the existing offline Node.js Lip Sync tool without refactoring it.
- Use only Apple system frameworks; no Electron, Tauri, or third-party audio libraries.
- Reuse `public/papalu-talking/frames/` byte-for-byte; do not generate or modify PAPAlu artwork.
- Keep microphone audio in memory only; do not save, upload, or access the network.
- V1 has only idle and talking behavior and no settings UI.
- Stop after the stated QuickTime tutorial-recording workflow works.

---

### Task 1: Test and implement the realtime mouth gate

**Files:**
- Create: `realtime-macos/Package.swift`
- Create: `realtime-macos/Sources/PAPAluLive/MouthGate.swift`
- Create: `realtime-macos/Tests/PAPAluLiveTests/MouthGateTests.swift`

**Interfaces:**
- Produces: `MouthState`, `MouthGateConfiguration`, and `MouthGate.update(rms:duration:) -> MouthState`.
- Consumes: no AppKit or AVFoundation APIs.

- [ ] **Step 1: Write tests for silence, speech attack, short silence, release, and threshold hysteresis.**
- [ ] **Step 2: Run `swift test --package-path realtime-macos` and verify RED because MouthGate does not exist.**
- [ ] **Step 3: Implement the minimum pure Swift state machine with centralized defaults: 0.025 open, 0.015 close, 0.35 EMA, 0.12-second release.**
- [ ] **Step 4: Run `swift test --package-path realtime-macos` and verify all MouthGate tests pass.**

### Task 2: Implement microphone input and the floating PAPAlu window

**Files:**
- Create: `realtime-macos/Sources/PAPAluLive/MicrophoneMonitor.swift`
- Create: `realtime-macos/Sources/PAPAluLive/PAPAluWindow.swift`
- Create: `realtime-macos/Sources/PAPAluLive/AppDelegate.swift`

**Interfaces:**
- Consumes: `MouthGate.update(rms:duration:)` and packaged `Resources/Frames/<index>.png`.
- Produces: an AppKit executable that requests microphone access, drives idle/talking, and displays a draggable floating panel.

- [ ] **Step 1: Implement MicrophoneMonitor with standard authorization states, a 512-frame AVAudioEngine tap, multi-channel RMS, and no recording path.**
- [ ] **Step 2: Implement PAPAluWindow with centralized 288×312 size, 8 fps, `[1,2,3,4,6,3]`, clear borderless panel, floating level, all-spaces behavior, standard sharing, and background dragging.**
- [ ] **Step 3: Implement AppDelegate to show the window, start the monitor, update animation only when state changes, show one clear permission/startup error, retain the Dock icon, and stop audio on termination.**
- [ ] **Step 4: Run `swift build -c release --package-path realtime-macos` and fix only compiler or integration failures.**

### Task 3: Package the app and document the real recording workflow

**Files:**
- Create: `realtime-macos/Resources/Info.plist`
- Create: `realtime-macos/build-app.sh`
- Modify: `.gitignore`
- Modify: `README.md`

**Interfaces:**
- Consumes: Swift release executable and `public/papalu-talking/frames/0.png` through `7.png`.
- Produces: `outputs/PAPAlu实时口型.app`.

- [ ] **Step 1: Add an Info.plist with bundle identity, executable name, minimum macOS version, high-resolution support, and `NSMicrophoneUsageDescription`.**
- [ ] **Step 2: Add a deterministic build script that creates the `.app`, copies the existing frames into `Contents/Resources/Frames`, and makes the executable runnable.**
- [ ] **Step 3: Ignore Swift build artifacts while keeping source and tests tracked.**
- [ ] **Step 4: Document build, launch, microphone permission, dragging, Command-Q, and QuickTime whole-screen/selected-region guidance; explicitly state single-window capture is not guaranteed.**
- [ ] **Step 5: Run `realtime-macos/build-app.sh`, verify the bundle structure and compare all packaged frame hashes with the authoritative frames.**

### Task 4: Fresh end-to-end verification

**Files:**
- Modify only files required to correct a verified V1 defect.

**Interfaces:**
- Consumes: all V1 implementation and existing offline application.
- Produces: verification evidence and the final application bundle.

- [ ] **Step 1: Run `swift test --package-path realtime-macos` and require zero failures.**
- [ ] **Step 2: Run `swift build -c release --package-path realtime-macos` and require exit 0.**
- [ ] **Step 3: Run `npm test` and `npm run build` and require the full offline suite to remain green.**
- [ ] **Step 4: Launch the generated app, inspect its visible transparent floating window, verify its process remains alive, and check that no audio files or network code were introduced.**
- [ ] **Step 5: Verify QuickTime guidance against a whole-screen or selected-region smoke recording when macOS permissions allow; otherwise report the exact manual acceptance step without claiming it passed.**
- [ ] **Step 6: Review `git diff --check`, scope, and status; commit only V1 source, tests, docs, and build files while preserving unrelated planning files.**
