# PAPAlu Faster Idle Blink Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Increase PAPAlu idle blink frequency by changing the random interval from 5.5–9.0 seconds to 3.0–5.0 seconds.

**Architecture:** Keep the existing random blink scheduler and animation frames unchanged. Update only the centralized default interval, its deterministic unit test, and the README behavior description.

**Tech Stack:** Swift 5, AppKit, existing shell-based native and Node.js regression tests.

## Global Constraints

- Change only the idle blink interval to `3.0...5.0` seconds.
- Do not change sway, talking, microphone, camera, teaching, or character assets.
- Do not add double blinks, new states, UI, or dependencies.

---

### Task 1: Increase Idle Blink Frequency and Rebuild the App

**Files:**
- Modify: `realtime-macos/Tests/PAPAluLiveTests/IdleAnimationPlanTests.swift`
- Modify: `realtime-macos/Sources/PAPAluLive/IdleAnimationPlan.swift`
- Modify: `README.md`
- Build output: `outputs/PAPAlu实时口型.app`

**Interfaces:**
- Preserves: `IdleAnimationPlan.blinkDelay(randomUnit:) -> Double`.
- Changes: `IdleAnimationConfiguration.default.blinkDelayRange` to `3.0...5.0`.

- [ ] **Step 1: Change the blink range assertions first**

Update the existing test assertions to:

```swift
try expectEqual(plan.blinkDelay(randomUnit: 0), 3.0, "minimum blink delay")
try expectEqual(plan.blinkDelay(randomUnit: 1), 5.0, "maximum blink delay")
try expectEqual(plan.blinkDelay(randomUnit: .nan), 3.0, "non-finite random unit")
```

- [ ] **Step 2: Run the native tests and verify RED**

Run `./realtime-macos/run-tests.sh`.

Expected: the blink-range test fails because production still returns `5.5` and `9.0`.

- [ ] **Step 3: Make the minimal production and documentation change**

Change only:

```swift
blinkDelayRange: 3.0...5.0
```

Update README from “5.5～9 秒” to “3～5 秒”.

- [ ] **Step 4: Run fresh complete verification**

Run:

```bash
./realtime-macos/run-tests.sh
npm test
npm run build
git diff --check
```

Expected: 32 native tests, the AppKit shell compile test, 78 web tests, and the web production build pass; `git diff --check` prints nothing.

- [ ] **Step 5: Build and replace the deliverable**

Run `./realtime-macos/build-app.sh`, validate the plist, copy the generated app to `/Users/chaoyan/Documents/Codex/2026-08-08/zhe-s/outputs/PAPAlu实时口型.app`, verify binary equality, and launch it.

- [ ] **Step 6: Commit the implementation**

```bash
git add realtime-macos/Tests/PAPAluLiveTests/IdleAnimationPlanTests.swift realtime-macos/Sources/PAPAluLive/IdleAnimationPlan.swift README.md
git commit -m "tune: increase PAPAlu idle blink frequency"
```
