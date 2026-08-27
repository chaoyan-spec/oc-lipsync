# PAPAlu Low-Latency Mouth Response Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make PAPAlu enter talking on the first clear speech buffer after silence while preserving smooth delayed closing.

**Architecture:** `MouthGate` will use sanitized raw RMS only for the idle-to-talking attack decision and retain EMA for talking-to-idle release behavior. `MicrophoneMonitor` will reduce its centralized AVAudioEngine tap buffer from 512 to 256 frames without changing the audio pipeline.

**Tech Stack:** Swift 5 compatibility mode, AVFoundation, existing direct `swiftc` tests.

## Global Constraints

- Keep open threshold `0.025`, close threshold `0.015`, EMA factor `0.35`, and release delay `0.12s`.
- Do not change talking animation fps, frame sequence, character assets, window behavior, or offline web behavior.
- Do not add settings, recording, upload, recognition, or networking.

---

### Task 1: Reproduce and fix slow attack

**Files:**
- Modify: `realtime-macos/Tests/PAPAluLiveTests/MouthGateTests.swift`
- Modify: `realtime-macos/Sources/PAPAluLive/MouthGate.swift`

**Interfaces:**
- Consumes: `MouthGate.update(rms:duration:) -> MouthState`.
- Produces: immediate `.talking` when a sanitized raw RMS sample reaches `openThreshold`, even after sustained quiet input.

- [ ] **Step 1: Write the failing regression test**

Feed `0.003` RMS for 100 × 10ms updates, then feed one `0.03` RMS update and assert that the returned state is `.talking`.

- [ ] **Step 2: Run the native test script and verify RED**

Run: `./realtime-macos/run-tests.sh`

Expected: the new test fails because the smoothed RMS remains below `0.025` after the first speech buffer.

- [ ] **Step 3: Implement the single attack-path fix**

Keep EMA calculation unchanged. In the `.idle` branch, compare sanitized `sample` rather than `smoothedRms` against `configuration.openThreshold`. Leave the `.talking` branch unchanged so close hysteresis and release delay still use smoothed RMS.

- [ ] **Step 4: Run tests and verify GREEN**

Run: `./realtime-macos/run-tests.sh`

Expected: nine logic tests pass and the app-shell compile check passes.

### Task 2: Reduce capture buffer and deliver

**Files:**
- Modify: `realtime-macos/Sources/PAPAluLive/MicrophoneMonitor.swift`
- Modify: `README.md`

**Interfaces:**
- Consumes: existing `AVAudioEngine` input tap.
- Produces: RMS callbacks from a centralized `AVAudioFrameCount(256)` buffer.

- [ ] **Step 1: Change only the tap buffer constant**

Set `MicrophoneMonitor.tapBufferSize` from `512` to `256`. Do not change the RMS calculation, sample format, engine startup, or permission flow.

- [ ] **Step 2: Document the response behavior**

Update the realtime README sentence to state that clear speech opens immediately while stopping still closes after about 120ms.

- [ ] **Step 3: Run full verification**

Run:

```bash
./realtime-macos/run-tests.sh
./realtime-macos/build-app.sh
npm test
npm run build
```

Expected: nine native logic tests and the app compile check pass, all 78 offline tests pass, and the app builds.

- [ ] **Step 4: Perform an end-to-end microphone smoke test**

Launch the app, record a short screen video while playing the existing tone/silence fixture through the speakers, and verify that the first clear sound switches to a talking frame while silence still returns to frame 0.

- [ ] **Step 5: Update delivery and commit**

Copy the verified `.app` to `/Users/chaoyan/Documents/Codex/2026-08-08/zhe-s/outputs/PAPAlu实时口型.app`, verify the executable and all eight frames match the fresh build, then commit the source and test changes.
