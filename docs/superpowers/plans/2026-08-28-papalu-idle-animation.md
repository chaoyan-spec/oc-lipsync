# PAPAlu Idle Animation V1.x Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Add a restrained, irregular idle animation using only the approved PAPAlu frames while preserving immediate talking response and existing wave/teaching behavior.

**Architecture:** A pure IdleAnimationPlan owns frame sequences and random-delay mapping. PAPAluWindow uses cancellable one-shot AppKit timers; ActionCoordinator, MouthGate, and WaveDetector keep their current responsibilities.

**Tech Stack:** Swift 5, AppKit Timer, AVFoundation, Vision, existing shell test harness.

## Global Constraints

- Reuse only public/papalu-talking/frames/0.png through 7.png.
- Do not generate or edit PAPAlu assets.
- State priority remains teaching > talking > idle.
- Idle must never delay the first talking frame.
- Do not change microphone thresholds, camera detection, wave cooldown, or teaching duration.
- Do not add settings UI, gestures, layers, skeletons, speech recognition, or semantic animation.

---

### Task 1: Pure Idle Animation Plan

**Files:**
- Create: realtime-macos/Sources/PAPAluLive/IdleAnimationPlan.swift
- Create: realtime-macos/Tests/PAPAluLiveTests/IdleAnimationPlanTests.swift
- Modify: realtime-macos/Tests/PAPAluLiveTests/main.swift
- Modify: realtime-macos/run-tests.sh
- Modify: realtime-macos/build-app.sh

**Interfaces:**
- Produces: IdleFrameStep, IdleScheduledEvent, IdleAnimationConfiguration.default, and IdleAnimationPlan delay/event methods.
- Consumes: no AppKit or runtime state.

- [ ] **Step 1: Write the failing tests**

Add deterministic tests that assert:

~~~swift
let configuration = IdleAnimationConfiguration.default
try expectEqual(configuration.baseFrame, 0, "idle base")
try expectEqual(configuration.breathSteps.map(\.frame), [7, 0], "breath")
try expectEqual(configuration.blinkSteps.map(\.frame), [5, 7, 0], "blink")
try expectEqual(configuration.settleSteps.map(\.frame), [3, 1, 7, 0], "settle")

let plan = IdleAnimationPlan()
try expectEqual(plan.breathDelay(randomUnit: 0), 2.8, "breath minimum")
try expectEqual(plan.breathDelay(randomUnit: 1), 4.8, "breath maximum")
try expectEqual(plan.blinkDelay(randomUnit: 0), 5.5, "blink minimum")
try expectEqual(plan.blinkDelay(randomUnit: 1), 9.0, "blink maximum")
try expectEqual(
    plan.nextEvent(breathDelay: 3.2, blinkDelay: 1.4),
    .blink(after: 1.4),
    "earlier blink wins"
)
~~~

Register the tests in main.swift and add the new test/source filenames to run-tests.sh.

- [ ] **Step 2: Verify RED**

Run: ./realtime-macos/run-tests.sh

Expected: compilation fails because the idle plan types do not exist.

- [ ] **Step 3: Implement the minimal pure plan**

Create these types and exact defaults:

~~~swift
struct IdleFrameStep: Equatable {
    let frame: Int
    let duration: Double
}

enum IdleScheduledEvent: Equatable {
    case breath(after: Double)
    case blink(after: Double)
}

struct IdleAnimationConfiguration: Equatable {
    static let default = IdleAnimationConfiguration(
        baseFrame: 0,
        breathSteps: [
            IdleFrameStep(frame: 7, duration: 0.28),
            IdleFrameStep(frame: 0, duration: 0.28),
        ],
        blinkSteps: [
            IdleFrameStep(frame: 5, duration: 0.11),
            IdleFrameStep(frame: 7, duration: 0.10),
            IdleFrameStep(frame: 0, duration: 0.12),
        ],
        settleSteps: [
            IdleFrameStep(frame: 3, duration: 0.08),
            IdleFrameStep(frame: 1, duration: 0.08),
            IdleFrameStep(frame: 7, duration: 0.08),
            IdleFrameStep(frame: 0, duration: 0.08),
        ],
        breathDelayRange: 2.8...4.8,
        blinkDelayRange: 5.5...9.0
    )

    let baseFrame: Int
    let breathSteps: [IdleFrameStep]
    let blinkSteps: [IdleFrameStep]
    let settleSteps: [IdleFrameStep]
    let breathDelayRange: ClosedRange<Double>
    let blinkDelayRange: ClosedRange<Double>
}
~~~

IdleAnimationPlan clamps randomUnit into 0...1, maps it linearly into the configured ranges, and returns blink when blinkDelay <= breathDelay.

Add IdleAnimationPlan.swift to build-app.sh.

- [ ] **Step 4: Verify GREEN**

Run: ./realtime-macos/run-tests.sh

Expected: old and new native tests pass; app-shell compile passes.

- [ ] **Step 5: Commit**

~~~bash
git add realtime-macos/Sources/PAPAluLive/IdleAnimationPlan.swift realtime-macos/Tests/PAPAluLiveTests/IdleAnimationPlanTests.swift realtime-macos/Tests/PAPAluLiveTests/main.swift realtime-macos/run-tests.sh realtime-macos/build-app.sh
git commit -m "feat: define PAPAlu idle animation plan"
~~~

---

### Task 2: Cancellable AppKit Idle Renderer

**Files:**
- Modify: realtime-macos/Sources/PAPAluLive/PAPAluWindow.swift
- Modify: realtime-macos/Sources/PAPAluLive/AppDelegate.swift
- Modify: realtime-macos/Tests/PAPAluLiveTests/AppShellCompileTests.swift

**Interfaces:**
- Consumes: IdleAnimationPlan from Task 1.
- Produces: animated behavior behind the existing PAPAluWindow.setDisplayState API.

- [ ] **Step 1: Write the failing renderer integration contract**

Extend AppShellCompileTests.swift so compilation requires PAPAluWindow to accept an IdleAnimationPlan initializer argument with a default value:

~~~swift
func verifyIdlePlanInjectionCompiles(resourceDirectory: URL) throws {
    _ = try PAPAluWindow(
        resourceDirectory: resourceDirectory,
        idlePlan: IdleAnimationPlan()
    )
}
~~~

- [ ] **Step 2: Verify RED**

Run: ./realtime-macos/run-tests.sh

Expected: app-shell compilation fails because PAPAluWindow has no idlePlan parameter.

- [ ] **Step 3: Implement cancellable idle scheduling**

In PAPAluWindow:

- store IdleAnimationPlan
- make displayState optional so initial idle is a real transition
- add idleTimer, idleSequenceTimer, idleGeneration, and blinkDeadline
- cancel talking and idle timers and increment idleGeneration before every display-state change
- on talking to idle, play 3 -> 1 -> 7 -> 0 at 80ms per frame
- otherwise enter idle on frame 0
- choose the next event by comparing one random breath delay with the remaining blink deadline
- play only one breath or blink sequence at a time
- after a blink, reset its deadline with a new 5.5...9.0 second random delay
- check displayState and idleGeneration before every delayed frame
- on talking, cancel idle work before showing the first talking frame
- on teaching, cancel all timers before showing Teaching.png

Use one-shot Timer instances added to RunLoop.main in common mode. Do not add a permanent high-frequency idle timer.

Implement the renderer with these exact control-flow methods (existing scale and resource-loading code remains unchanged):

~~~swift
private let idlePlan: IdleAnimationPlan
private var idleTimer: Timer?
private var idleSequenceTimer: Timer?
private var idleGeneration = 0
private var blinkDeadline = 0.0
private var displayState: PAPAluDisplayState?

func setDisplayState(_ state: PAPAluDisplayState) {
    guard state != displayState else { return }
    let previousState = displayState
    displayState = state
    cancelAllAnimation()

    switch state {
    case .idle:
        startIdleAnimation(settlingFromTalking: previousState == .talking)
    case .talking:
        talkingFrameIndex = 0
        showTalkingFrame()
        startAnimationTimer()
    case .teaching:
        characterView.image = teachingImage
    }
}

private func cancelAllAnimation() {
    idleGeneration += 1
    animationTimer?.invalidate()
    animationTimer = nil
    idleTimer?.invalidate()
    idleTimer = nil
    idleSequenceTimer?.invalidate()
    idleSequenceTimer = nil
}

private func startIdleAnimation(settlingFromTalking: Bool) {
    let generation = idleGeneration
    blinkDeadline = ProcessInfo.processInfo.systemUptime
        + idlePlan.blinkDelay(randomUnit: Double.random(in: 0...1))
    let beginEvents = { [weak self] in
        self?.scheduleNextIdleEvent(generation: generation)
    }
    if settlingFromTalking {
        playIdleSequence(
            idlePlan.configuration.settleSteps,
            generation: generation,
            completion: beginEvents
        )
    } else {
        characterView.image = frames[idlePlan.configuration.baseFrame]
        beginEvents()
    }
}

private func scheduleNextIdleEvent(generation: Int) {
    guard displayState == .idle, generation == idleGeneration else { return }
    let breathDelay = idlePlan.breathDelay(randomUnit: Double.random(in: 0...1))
    let blinkDelay = max(0, blinkDeadline - ProcessInfo.processInfo.systemUptime)
    let event = idlePlan.nextEvent(breathDelay: breathDelay, blinkDelay: blinkDelay)
    let delay: Double
    switch event {
    case .breath(let after), .blink(let after): delay = after
    }
    idleTimer = makeTimer(after: delay) { [weak self] in
        self?.runIdleEvent(event, generation: generation)
    }
}

private func runIdleEvent(_ event: IdleScheduledEvent, generation: Int) {
    let steps: [IdleFrameStep]
    switch event {
    case .breath:
        steps = idlePlan.configuration.breathSteps
    case .blink:
        steps = idlePlan.configuration.blinkSteps
        blinkDeadline = ProcessInfo.processInfo.systemUptime
            + idlePlan.blinkDelay(randomUnit: Double.random(in: 0...1))
    }
    playIdleSequence(steps, generation: generation) { [weak self] in
        self?.scheduleNextIdleEvent(generation: generation)
    }
}

private func playIdleSequence(
    _ steps: [IdleFrameStep],
    index: Int = 0,
    generation: Int,
    completion: @escaping () -> Void
) {
    guard displayState == .idle, generation == idleGeneration else { return }
    guard index < steps.count else {
        completion()
        return
    }
    let step = steps[index]
    characterView.image = frames[step.frame]
    idleSequenceTimer = makeTimer(after: step.duration) { [weak self] in
        self?.playIdleSequence(
            steps,
            index: index + 1,
            generation: generation,
            completion: completion
        )
    }
}

private func makeTimer(after delay: Double, action: @escaping () -> Void) -> Timer {
    let timer = Timer(timeInterval: max(0, delay), repeats: false) { _ in action() }
    RunLoop.main.add(timer, forMode: .common)
    return timer
}
~~~

- [ ] **Step 4: Start idle at application launch**

Change AppDelegate.renderedState to optional. After assigning the new PAPAluWindow, call render(.idle) before orderFrontRegardless so silence immediately begins idle scheduling.

~~~swift
private var renderedState: PAPAluDisplayState?

let window = try PAPAluWindow()
self.window = window
render(.idle)
window.orderFrontRegardless()
~~~

- [ ] **Step 5: Verify GREEN**

Run: ./realtime-macos/run-tests.sh

Expected: all native tests pass and app-shell compile passes.

- [ ] **Step 6: Commit**

~~~bash
git add realtime-macos/Sources/PAPAluLive/PAPAluWindow.swift realtime-macos/Sources/PAPAluLive/AppDelegate.swift realtime-macos/Tests/PAPAluLiveTests/AppShellCompileTests.swift
git commit -m "feat: animate PAPAlu idle state"
~~~

---

### Task 3: Regression, Packaging, and Runtime Validation

**Files:**
- Modify: README.md
- Build output: outputs/PAPAlu实时口型.app

**Interfaces:**
- Consumes: completed idle implementation.
- Produces: documented, tested, locally runnable final app.

- [ ] **Step 1: Document behavior**

Add a concise README note: quiet periods use irregular breathing and blinking from existing frames; speech interrupts idle immediately; no new assets are included.

- [ ] **Step 2: Run complete verification**

~~~bash
./realtime-macos/run-tests.sh
npm run build
npm test
git diff --check
~~~

Expected: native tests and app-shell compile pass, all 78 offline tests pass, and diff check is clean.

- [ ] **Step 3: Build and deliver**

~~~bash
./realtime-macos/build-app.sh
ditto 'outputs/PAPAlu实时口型.app' '/Users/chaoyan/Documents/Codex/2026-08-08/zhe-s/outputs/PAPAlu实时口型.app'
~~~

Verify executable parity with cmp, Info.plist with plutil -lint, and package size with du -sh.

- [ ] **Step 4: Runtime checks**

Launch the delivered app. Check that idle starts during silence, speech cancels idle immediately, stopping speech settles into idle, wave/teaching still returns to current base state, no camera preview appears, lsof shows no network socket, and CPU remains in the same general range as the camera-enabled build.

Physical speech, wave, and QuickTime visual quality remain final user-acceptance checks.

- [ ] **Step 5: Commit documentation**

~~~bash
git add README.md
git commit -m "docs: describe PAPAlu idle animation"
~~~
