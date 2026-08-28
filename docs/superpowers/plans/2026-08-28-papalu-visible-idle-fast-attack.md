# PAPAlu Visible Idle Sway and Fast Attack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make PAPAlu visibly sway while silent and show a clearly open mouth on the first talking frame without changing microphone sensitivity or character assets.

**Architecture:** Replace the ineffective frame-0/frame-7 pseudo-breath with a pure Swift idle-sway plan that produces bounded left/right poses. `PAPAluWindow` applies those poses to the existing image view with lightweight Core Animation, while blink frame scheduling remains independent. Talking and teaching cancel the layer animation and restore the neutral transform before rendering.

**Tech Stack:** Swift 5, AppKit, QuartzCore/Core Animation, AVFoundation, existing shell-based Swift tests.

## Global Constraints

- Reuse the existing eight PAPAlu PNG frames and approved teaching image unchanged.
- Keep the floating window's screen position fixed; move only the character rendering inside it.
- Keep `MouthGate`, microphone thresholds, EMA, hysteresis, and 120ms release delay unchanged.
- Keep camera wave detection and teaching priority unchanged.
- Add no third-party dependency, settings UI, gesture, or new animation asset.

---

### Task 1: Replace Invisible Pseudo-Breath with a Testable Sway Plan

**Files:**
- Modify: `realtime-macos/Sources/PAPAluLive/IdleAnimationPlan.swift`
- Modify: `realtime-macos/Tests/PAPAluLiveTests/IdleAnimationPlanTests.swift`

**Interfaces:**
- Produces: `IdleSwayDirection`, `IdleSwayStep`, `IdleAnimationConfiguration.swayHorizontalOffset`, `swayRotationDegrees`, `swayDurationRange`, `swayHoldRange`.
- Produces: `IdleAnimationPlan.swayStep(direction:durationRandomUnit:holdRandomUnit:) -> IdleSwayStep`.
- Preserves: base frame, blink steps, settle steps, and blink delay mapping.

- [ ] **Step 1: Write failing sway-plan tests**

Add tests that require left and right poses to have opposite `±4` point offsets and `±1` degree rotations, duration mapping of `0.95...1.15` seconds, hold mapping of `0.08...0.25` seconds, and no frame-based breath sequence. Keep tests for approved blink/settle frames and delay clamping.

- [ ] **Step 2: Run the native tests and verify RED**

Run:

```bash
./realtime-macos/run-tests.sh
```

Expected: compilation fails because `IdleSwayDirection`, `IdleSwayStep`, and sway configuration members do not exist.

- [ ] **Step 3: Implement the minimal pure Swift sway plan**

Define:

```swift
enum IdleSwayDirection: Equatable {
    case left
    case right
}

struct IdleSwayStep: Equatable {
    let horizontalOffset: Double
    let rotationDegrees: Double
    let duration: Double
    let holdDuration: Double
}
```

Update the default configuration to use `4pt`, `1°`, `0.95...1.15s`, and `0.08...0.25s`. Map random units through the existing clamped range helper and apply a negative sign for left and positive sign for right. Remove the ineffective breath sequence and breath event selection.

- [ ] **Step 4: Run the native tests and verify GREEN**

Run `./realtime-macos/run-tests.sh`.

Expected: all pure Swift tests pass and the AppKit shell still compiles.

- [ ] **Step 5: Commit the sway-plan unit**

```bash
git add realtime-macos/Sources/PAPAluLive/IdleAnimationPlan.swift realtime-macos/Tests/PAPAluLiveTests/IdleAnimationPlanTests.swift
git commit -m "feat: define visible PAPAlu idle sway"
```

### Task 2: Animate the Character View and Remove Visual Mouth Attack Delay

**Files:**
- Modify: `realtime-macos/Sources/PAPAluLive/PAPAluWindow.swift`
- Modify: `realtime-macos/Tests/PAPAluLiveTests/IdleAnimationPlanTests.swift`
- Modify: `realtime-macos/run-tests.sh`
- Modify: `realtime-macos/build-app.sh`

**Interfaces:**
- Consumes: `IdleAnimationPlan.swayStep(...)` from Task 1.
- Preserves: `PAPAluWindow.setDisplayState(_:)`, scaling commands, blink scheduling, settle sequence, and teaching image rendering.
- Changes: `PAPAluWindow.Configuration.talkingFrames.first` becomes frame `2`.

- [ ] **Step 1: Write the failing fast-attack test**

Add a test asserting:

```swift
try expectEqual(
    PAPAluWindow.Configuration.talkingFrames.first,
    2,
    "talking must start with a clearly open mouth"
)
```

Update the first native test compile command to include `PAPAluWindow.swift` and link AppKit/QuartzCore so the assertion is executed rather than compile-only.

- [ ] **Step 2: Run the native tests and verify RED**

Run `./realtime-macos/run-tests.sh`.

Expected: the new test fails because the current first talking frame is `1`.

- [ ] **Step 3: Implement character-only sway and immediate open-mouth rendering**

In `PAPAluWindow`:

- Change talking frames to begin with frame `2`.
- Enable a backing layer on `characterView`.
- Add one sway timer and alternate left/right poses using a `CABasicAnimation` on the layer transform.
- Keep blink scheduling independent from sway scheduling.
- On every state transition, invalidate sway timers, remove layer animations, and synchronously restore `CATransform3DIdentity` with implicit actions disabled.
- Start sway only after the existing talking-to-idle settle sequence finishes.
- Start talking by resetting the transform and synchronously showing frame `2` before starting the 8fps timer.
- Keep teaching at the neutral transform.

Link QuartzCore in both build and test shell commands.

- [ ] **Step 4: Run native tests and verify GREEN**

Run `./realtime-macos/run-tests.sh`.

Expected: all native behavior tests pass and the AppKit shell compile test passes.

- [ ] **Step 5: Commit the renderer unit**

```bash
git add realtime-macos/Sources/PAPAluLive/PAPAluWindow.swift realtime-macos/Tests/PAPAluLiveTests/IdleAnimationPlanTests.swift realtime-macos/run-tests.sh realtime-macos/build-app.sh
git commit -m "feat: animate PAPAlu idle sway and fast mouth attack"
```

### Task 3: Documentation, Full Regression, and App Delivery

**Files:**
- Modify: `README.md`
- Build output: `outputs/PAPAlu实时口型.app`

**Interfaces:**
- Documents: visible character-only idle sway, immediate open-mouth entry, unchanged mic/camera privacy behavior.

- [ ] **Step 1: Update the README behavior description**

Replace the frame-based breath description with the `±4pt`/`±1°` character-only sway, random timing, random blink, and immediate frame-2 talking entry. State that no new character asset is used.

- [ ] **Step 2: Run fresh complete verification**

Run:

```bash
./realtime-macos/run-tests.sh
npm test
npm run build
git diff --check
```

Expected: native tests, AppKit compile, all 78 web tests, and production build pass; `git diff --check` prints nothing.

- [ ] **Step 3: Build and verify the app bundle**

Run:

```bash
./realtime-macos/build-app.sh
plutil -lint outputs/PAPAlu实时口型.app/Contents/Info.plist
du -sh outputs/PAPAlu实时口型.app
```

Expected: app exists at `outputs/PAPAlu实时口型.app`, plist is valid, and bundle remains lightweight.

- [ ] **Step 4: Launch for a local smoke check**

Open the app, observe at least two complete idle sway cycles, and verify the panel itself does not change screen coordinates. Physical speech, camera wave, and QuickTime capture remain user acceptance checks if no human input is available to the executing environment.

- [ ] **Step 5: Commit documentation**

```bash
git add README.md
git commit -m "docs: describe visible PAPAlu idle sway"
```
