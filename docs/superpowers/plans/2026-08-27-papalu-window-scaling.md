# PAPAlu Window Scaling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add bounded keyboard-controlled resizing to the transparent PAPAlu realtime window.

**Architecture:** A small pure `WindowScale` value type owns the 50%–200% scale ladder and is covered by deterministic tests. `PAPAluWindow` applies that scale around its current center, while `AppDelegate` exposes only three standard application-menu commands.

**Tech Stack:** Swift 5 compatibility mode, AppKit, existing direct `swiftc` test runner.

## Global Constraints

- Keep the default size at exactly `288×312`.
- Change size in 10% steps, clamped to 50%–200%.
- Preserve the frame aspect ratio and resize around the current window center.
- Do not add visible controls, resize borders, persistence, gestures, or new assets.
- Preserve realtime lip sync and the offline web tool.

---

### Task 1: Test and implement bounded scale state

**Files:**
- Create: `realtime-macos/Sources/PAPAluLive/WindowScale.swift`
- Create: `realtime-macos/Tests/PAPAluLiveTests/WindowScaleTests.swift`
- Modify: `realtime-macos/Tests/PAPAluLiveTests/main.swift`
- Modify: `realtime-macos/run-tests.sh`

**Interfaces:**
- Produces: `WindowScale.increase()`, `WindowScale.decrease()`, `WindowScale.reset()`, and read-only `factor: Double`.
- Consumes: no AppKit APIs; this unit stays deterministic and testable.

- [ ] **Step 1: Write failing scale tests**

Add tests asserting that the initial factor is `1.0`, each increase/decrease moves by `0.1`, repeated changes clamp at `0.5` and `2.0`, and reset returns to `1.0`. Register them in the direct test runner.

- [ ] **Step 2: Run the focused tests and verify RED**

Run: `./realtime-macos/run-tests.sh`

Expected: compilation fails because `WindowScale` does not exist.

- [ ] **Step 3: Add the minimal pure implementation**

Implement immutable constants for minimum `0.5`, maximum `2.0`, default `1.0`, and step `0.1`. Round each result to one decimal place before clamping so repeated operations do not accumulate floating-point drift.

- [ ] **Step 4: Run the focused tests and verify GREEN**

Run: `./realtime-macos/run-tests.sh`

Expected: all MouthGate and WindowScale tests pass, followed by the application-shell compile check.

### Task 2: Connect menu commands to centered window resizing

**Files:**
- Modify: `realtime-macos/Sources/PAPAluLive/PAPAluWindow.swift`
- Modify: `realtime-macos/Sources/PAPAluLive/AppDelegate.swift`
- Modify: `realtime-macos/Tests/PAPAluLiveTests/AppShellCompileTests.swift`
- Modify: `README.md`

**Interfaces:**
- Consumes: `WindowScale.factor` from Task 1.
- Produces: `PAPAluWindow.increaseScale()`, `decreaseScale()`, and `resetScale()` for menu actions.

- [ ] **Step 1: Add failing application-shell contracts**

Extend the compile contract to reference the three window scaling methods and the `WindowScale` type.

- [ ] **Step 2: Run tests and verify RED**

Run: `./realtime-macos/run-tests.sh`

Expected: compilation fails because the three `PAPAluWindow` methods do not exist.

- [ ] **Step 3: Implement centered resizing and menu commands**

For each scale change, calculate `defaultSize × factor`, preserve the old frame center, and call `setFrame(_:display:animate:)` with animation disabled. Add application-menu items for `Command +`, `Command -`, and `Command 0`, routed through `AppDelegate` selector methods.

- [ ] **Step 4: Document the shortcuts**

Add the three shortcuts to the realtime section of `README.md`; do not change the offline workflow documentation.

- [ ] **Step 5: Run complete verification**

Run:

```bash
./realtime-macos/run-tests.sh
./realtime-macos/build-app.sh
npm test
npm run build
```

Expected: native tests and compile check pass, all 78 offline tests pass, and the application builds.

- [ ] **Step 6: Perform visual smoke test and commit**

Launch the built app, trigger each shortcut, confirm the center stays stable and the transparent floating character visibly changes size, then copy the verified app to the main `outputs/` directory and commit the source changes.
