# PAPAlu Idle Thought Cloud Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use executing-plans to implement this plan task-by-task.

**Goal:** Show a restrained white comic thought cloud above PAPAlu after 0.5 seconds of silence, animate its three dots, and hide it immediately when speech resumes.

**Architecture:** Keep microphone `idle` / `talking` as the only business states. Add a pure timing/layout plan for deterministic tests, an AppKit-drawn overlay view for the cloud, and two small timers owned by `PAPAluWindow`. The overlay is a sibling of the character image so the existing idle sway does not move it.

**Tech Stack:** Swift, AppKit, Core Animation, existing shell-based Swift tests.

---

### Task 1: Define and test the thought-cloud plan

**Files:**
- Create: `realtime-macos/Sources/PAPAluLive/ThoughtCloudPlan.swift`
- Create: `realtime-macos/Tests/PAPAluLiveTests/ThoughtCloudPlanTests.swift`
- Modify: `realtime-macos/Tests/PAPAluLiveTests/main.swift`
- Modify: `realtime-macos/run-tests.sh`

**Step 1: Write the failing tests**

Cover the approved 0.5-second appearance delay, 0.18-second fade, 0.3-second dot interval, dot sequence `0 → 1 → 2 → 0`, active/inactive dot alpha, and proportional layout at two window sizes.

**Step 2: Run the native test script and verify RED**

Run: `./realtime-macos/run-tests.sh`

Expected: compilation fails because `ThoughtCloudPlan` does not exist.

**Step 3: Implement the minimum pure plan**

Add centralized constants and pure helpers for the dot sequence, alpha values, and normalized cloud frame.

**Step 4: Run tests and verify GREEN**

Run: `./realtime-macos/run-tests.sh`

Expected: all existing tests plus the new thought-cloud plan tests pass.

**Step 5: Commit**

```bash
git add realtime-macos/Sources/PAPAluLive/ThoughtCloudPlan.swift realtime-macos/Tests/PAPAluLiveTests/ThoughtCloudPlanTests.swift realtime-macos/Tests/PAPAluLiveTests/main.swift realtime-macos/run-tests.sh
git commit -m "test: define PAPAlu thought cloud timing"
```

### Task 2: Draw and integrate the overlay

**Files:**
- Create: `realtime-macos/Sources/PAPAluLive/ThoughtCloudView.swift`
- Modify: `realtime-macos/Sources/PAPAluLive/PAPAluWindow.swift`
- Modify: `realtime-macos/Tests/PAPAluLiveTests/AppShellCompileTests.swift`
- Modify: `realtime-macos/run-tests.sh`
- Modify: `realtime-macos/build-app.sh`

**Step 1: Write a failing compile contract**

Reference `ThoughtCloudView` and the window's injectable `ThoughtCloudPlan` from the AppKit compile test.

**Step 2: Run tests and verify RED**

Run: `./realtime-macos/run-tests.sh`

Expected: AppKit compile fails because the view and integration do not exist.

**Step 3: Implement the AppKit overlay**

Draw a white cloud, dark-purple outline, two tail bubbles, and three dark-purple dots. Make it ignore hit testing. Add it beside the character image inside a draggable container.

**Step 4: Integrate idle/talking behavior**

On idle, schedule the cloud after 0.5 seconds, fade it in, and advance the active dot every 0.3 seconds. On talking, cancel both timers and hide it immediately. Recompute its normalized frame whenever PAPAlu is resized.

**Step 5: Run tests and verify GREEN**

Run: `./realtime-macos/run-tests.sh`

Expected: all native and web regression tests pass.

**Step 6: Commit**

```bash
git add realtime-macos/Sources/PAPAluLive/ThoughtCloudView.swift realtime-macos/Sources/PAPAluLive/PAPAluWindow.swift realtime-macos/Tests/PAPAluLiveTests/AppShellCompileTests.swift realtime-macos/run-tests.sh realtime-macos/build-app.sh
git commit -m "feat: add PAPAlu idle thought cloud"
```

### Task 3: Document, build, and visually verify

**Files:**
- Modify: `README.md`
- Output: `outputs/PAPAlu实时口型.app`

**Step 1: Document the visible behavior**

State that the thought cloud appears after a short silence and disappears immediately when speech resumes. Reiterate that microphone audio stays in memory and there is no camera feature.

**Step 2: Run full verification**

Run:

```bash
./realtime-macos/run-tests.sh
./realtime-macos/build-app.sh
```

Expected: all tests pass and the `.app` is rebuilt at the established output path.

**Step 3: Launch and inspect**

Launch the rebuilt app, wait at least 0.7 seconds in silence, capture the screen, and verify the cloud is visible above the character without clipping or obscuring the face. Speak to verify it disappears promptly.

**Step 4: Record package size and lightweight CPU sample**

Use `du` and `ps` after launch; compare against the previous approximate 548 KB / 0.1–0.3% idle baseline.

**Step 5: Commit**

```bash
git add README.md
git commit -m "docs: describe PAPAlu idle thought cloud"
```

**Stop condition:** Do not add camera actions, new PAPAlu assets, settings, or additional character states. Hand off the rebuilt V1.x app for real recording feedback.
