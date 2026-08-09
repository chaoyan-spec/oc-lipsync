# Speech Cadence Lip Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make continuous speech produce repeated open/closed mouth motion and make the browser preview display the exact same cues at animation-frame speed.

**Architecture:** `public/lib/lipsync.js` will derive an adaptive speech threshold and generate a deterministic open/closed cadence inside speech-active regions. A new focused `public/lib/playback-mouth.js` module will own the `requestAnimationFrame` preview loop, while `public/app.js` remains responsible for wiring DOM and shared cues. Export continues to consume the same cue array, so preview and WebM stay aligned.

**Tech Stack:** Browser JavaScript modules, Node.js built-in test runner, Web Audio API, `requestAnimationFrame`, existing local Node/FFmpeg exporter; no third-party dependencies.

## Global Constraints

- Preview and export must consume the same `MouthCue[]` timeline.
- Silence must remain closed; continuous speech must contain visible open and closed intervals.
- Default open duration remains 120 ms; the forced closed interval is two 30 fps frames (about 67 ms).
- Keep 1080×1920, 30 fps, transparent VP9 WebM with Opus audio.
- Do not add speech recognition, phoneme/Viseme models, new mouth artwork, or npm dependencies.
- Preserve MP3, WAV, and M4A input support and the existing export/save workflow.

---

### Task 1: Adaptive Speech Cadence Timeline

**Files:**
- Modify: `public/lib/lipsync.js`
- Modify: `public/app.js`
- Test: `test/lipsync.test.js`

**Interfaces:**
- Produces: `calculateSpeechThreshold(energies: number[], sensitivity: number): number`.
- Preserves: `buildMouthTimeline(energies, { frameSeconds, threshold, minOpenSeconds, minClosedSeconds? }): MouthCue[]`.
- `public/app.js` consumes `calculateSpeechThreshold` and passes the resulting threshold to `buildMouthTimeline`.

- [ ] **Step 1: Write failing threshold and cadence tests**

Add imports and tests equivalent to:

```js
import {
  buildMouthTimeline,
  calculateSpeechThreshold,
  mouthAtTime,
} from '../public/lib/lipsync.js';

it('derives speech activity from the energy distribution instead of one peak', () => {
  const energies = [0.006, 0.011, 0.019, 0.026, 0.032, 0.060];
  const threshold = calculateSpeechThreshold(energies, 35);
  assert.ok(threshold > 0.006);
  assert.ok(threshold < 0.032);
});

it('recognizes a steady loud signal but keeps a steady quiet signal closed', () => {
  assert.ok(calculateSpeechThreshold(Array(12).fill(0.5), 35) < 0.5);
  assert.ok(calculateSpeechThreshold(Array(12).fill(0.001), 35) > 0.001);
});

it('alternates open and closed while a continuous speech region stays active', () => {
  const cues = buildMouthTimeline(Array(18).fill(0.5), {
    frameSeconds: 1 / 30,
    threshold: 0.2,
    minOpenSeconds: 0.12,
    minClosedSeconds: 2 / 30,
  });

  assert.deepEqual(cues, [
    { start: 0, end: 0.133333, state: 'open' },
    { start: 0.133333, end: 0.2, state: 'closed' },
    { start: 0.2, end: 0.333333, state: 'open' },
    { start: 0.333333, end: 0.4, state: 'closed' },
    { start: 0.4, end: 0.533333, state: 'open' },
    { start: 0.533333, end: 0.6, state: 'closed' },
  ]);
});

it('resets the cadence and stays closed across silence', () => {
  const energies = [0.5, 0.5, 0, 0, 0.5, 0.5];
  const cues = buildMouthTimeline(energies, {
    frameSeconds: 0.1,
    threshold: 0.2,
    minOpenSeconds: 0.1,
    minClosedSeconds: 0.1,
  });
  assert.deepEqual(cues, [
    { start: 0, end: 0.1, state: 'open' },
    { start: 0.1, end: 0.4, state: 'closed' },
    { start: 0.4, end: 0.5, state: 'open' },
    { start: 0.5, end: 0.6, state: 'closed' },
  ]);
});
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run: `node --test test/lipsync.test.js`

Expected: FAIL because `calculateSpeechThreshold` is not exported and continuous speech still merges into one open cue.

- [ ] **Step 3: Implement adaptive threshold and speech cadence**

In `public/lib/lipsync.js`:

```js
function percentile(sorted, fraction) {
  if (sorted.length === 0) return 0;
  return sorted[Math.floor((sorted.length - 1) * fraction)];
}

export function calculateSpeechThreshold(energies, sensitivity) {
  if (!Number.isFinite(sensitivity) || sensitivity < 0 || sensitivity > 100) {
    throw new Error('sensitivity must be between 0 and 100');
  }
  const sorted = energies.filter(Number.isFinite).sort((a, b) => a - b);
  const floor = percentile(sorted, 0.1);
  const speech = percentile(sorted, 0.9);
  if (speech - floor < 0.002) return Math.max(0.002, speech * 0.5);
  return Math.max(0.002, floor + (speech - floor) * (1 - sensitivity / 100));
}
```

Extend option validation for `minClosedSeconds`, classify speech without mutating it, and build states with a cadence phase that resets in silence:

```js
const openFrames = Math.max(1, Math.ceil(minOpenSeconds / frameSeconds));
const closedFrames = Math.max(1, Math.ceil(minClosedSeconds / frameSeconds));
let phase = 0;

const states = energies.map((energy) => {
  if (!(energy > threshold)) {
    phase = 0;
    return 'closed';
  }
  const state = phase < openFrames ? 'open' : 'closed';
  phase = (phase + 1) % (openFrames + closedFrames);
  return state;
});
```

In `public/app.js`, import `calculateSpeechThreshold`, replace the peak calculation with:

```js
const threshold = calculateSpeechThreshold(state.energies, state.sensitivity);
```

and pass `minClosedSeconds: 2 * FRAME_SECONDS` to `buildMouthTimeline`.

- [ ] **Step 4: Run focused and related tests and verify GREEN**

Run: `node --test test/lipsync.test.js test/audio.test.js src/ui-state.test.js`

Expected: all tests PASS; update obsolete expectations only where the approved cadence intentionally changes them.

- [ ] **Step 5: Commit Task 1**

```bash
git add public/lib/lipsync.js public/app.js test/lipsync.test.js
git commit -m "fix: generate repeated speech mouth cadence"
```

---

### Task 2: Animation-Frame Preview

**Files:**
- Create: `public/lib/playback-mouth.js`
- Create: `test/playback-mouth.test.js`
- Modify: `public/app.js`
- Modify: `package.json`

**Interfaces:**
- Consumes: `mouthAtTime(cues, seconds)` from `public/lib/lipsync.js`.
- Produces: `createMouthPreview({ audio, getCues, render, requestFrame?, cancelFrame? })` returning `{ start(), stop(), sync() }`.
- `public/app.js` calls `start()` on play, `stop()` on pause/end/reset, and `sync()` after seeking.

- [ ] **Step 1: Write the failing preview-loop tests**

Create `test/playback-mouth.test.js` with fake frame scheduling:

```js
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createMouthPreview } from '../public/lib/playback-mouth.js';

test('refreshes mouth state on animation frames while audio plays', () => {
  const callbacks = [];
  const rendered = [];
  const audio = { currentTime: 0.05, paused: false, ended: false };
  const preview = createMouthPreview({
    audio,
    getCues: () => [
      { start: 0, end: 0.1, state: 'open' },
      { start: 0.1, end: 0.2, state: 'closed' },
    ],
    render: (state) => rendered.push(state),
    requestFrame: (callback) => (callbacks.push(callback), callbacks.length),
    cancelFrame: () => {},
  });

  preview.start();
  assert.equal(rendered.at(-1), 'open');
  audio.currentTime = 0.15;
  callbacks.shift()();
  assert.equal(rendered.at(-1), 'closed');
});

test('stops scheduling and closes the mouth when playback stops', () => {
  const callbacks = [];
  const cancelled = [];
  const rendered = [];
  const audio = { currentTime: 0, paused: false, ended: false };
  const preview = createMouthPreview({
    audio,
    getCues: () => [{ start: 0, end: 1, state: 'open' }],
    render: (state) => rendered.push(state),
    requestFrame: (callback) => (callbacks.push(callback), 7),
    cancelFrame: (id) => cancelled.push(id),
  });

  preview.start();
  preview.stop();
  assert.deepEqual(cancelled, [7]);
  assert.equal(rendered.at(-1), 'closed');
});
```

- [ ] **Step 2: Run the new test and verify RED**

Run: `node --test test/playback-mouth.test.js`

Expected: FAIL with `ERR_MODULE_NOT_FOUND` for `public/lib/playback-mouth.js`.

- [ ] **Step 3: Implement the focused preview controller**

Create `public/lib/playback-mouth.js`:

```js
import { mouthAtTime } from './lipsync.js';

export function createMouthPreview({
  audio,
  getCues,
  render,
  requestFrame = requestAnimationFrame,
  cancelFrame = cancelAnimationFrame,
}) {
  let frameId = null;

  const draw = () => {
    frameId = null;
    render(mouthAtTime(getCues(), audio.currentTime));
    if (!audio.paused && !audio.ended) frameId = requestFrame(draw);
  };

  return {
    start() {
      if (frameId === null) draw();
    },
    stop() {
      if (frameId !== null) cancelFrame(frameId);
      frameId = null;
      render('closed');
    },
    sync() {
      render(mouthAtTime(getCues(), audio.currentTime));
    },
  };
}
```

Wire it in `public/app.js`: create one controller after `setMouth`, call `mouthPreview.start()` on `play`, `mouthPreview.stop()` on `pause`, `ended`, and transport reset, remove mouth rendering from `timeupdate`, and call `mouthPreview.sync()` after progress seeking.

Add `node --check public/lib/playback-mouth.js` to the `build` script.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run: `node --test test/playback-mouth.test.js test/lipsync.test.js src/app-export-state.test.js`

Expected: all tests PASS and no preview frame remains scheduled after stop.

- [ ] **Step 5: Commit Task 2**

```bash
git add public/lib/playback-mouth.js public/app.js package.json test/playback-mouth.test.js
git commit -m "fix: refresh mouth preview every animation frame"
```

---

### Task 3: Real-Audio Verification and Release Package

**Files:**
- Regenerate (ignored artifact): `outputs/oc-lipsync-sample.webm`
- Regenerate (ignored artifact): `outputs/OC口播机.zip`
- Copy deliverables to: `/Users/chaoyan/Documents/Codex/2026-08-08/zhe-s/outputs/`

**Interfaces:**
- Consumes the production browser decode, shared cue timeline, `/api/export`, and FFmpeg pipeline.
- Produces a runtime-only ZIP and verified transparent sample WebM.

- [ ] **Step 1: Run the full automated verification**

Run:

```bash
npm test
npm run build
zsh -n '启动OC口播机.command'
git diff --check
```

Expected: all tests pass, all syntax checks exit 0, and diff check is clean.

- [ ] **Step 2: Verify the exact user audio in the real browser**

Start `npm start`, open `http://127.0.0.1:4173`, select `/Users/chaoyan/Downloads/田林东路.m4a`, and use the browser runtime to inspect the generated cues.

Acceptance criteria:

```text
filename = 田林东路.m4a
duration is approximately 13.46 seconds
open cue count >= 10
closed cue count >= 10
playback visibly changes mouth state more than once
```

- [ ] **Step 3: Export and verify the real production media path**

Export from the UI, click the persistent save link, then inspect the WebM:

```bash
ffprobe -v error \
  -show_entries stream=index,codec_name,width,height,r_frame_rate:stream_tags=alpha_mode \
  -of json outputs/oc-lipsync-sample.webm
```

Expected: VP9 video, Opus audio, 1080×1920, `30/1`, `alpha_mode=1`. Decode a top-left RGBA pixel and require `0 0 0 0`.

- [ ] **Step 4: Rebuild the runtime-only ZIP from an explicit allowlist**

Create a fresh archive containing exactly:

```text
package.json
README.md
启动OC口播机.command
public/
public/lib/
public/app.js
public/index.html
public/styles.css
public/oc-mouth-closed.png
public/oc-mouth-open.png
public/lib/audio.js
public/lib/export-client.js
public/lib/lipsync.js
public/lib/playback-mouth.js
public/lib/request-envelope.js
public/lib/ui-state.js
server/export-video.js
server/index.js
server/resolve-executable.js
server/static-server.js
```

Use `/usr/bin/zip -q -UN=UTF8` against a new temporary archive, then run `unzip -t`, extract to a fresh temporary directory, run `npm run build --prefix <fresh-dir>`, launch it, verify `/__oc-lipsync/ready`, and confirm the page title.

- [ ] **Step 5: Copy the verified artifacts and commit tracked release notes only**

Copy the final ZIP and sample to `/Users/chaoyan/Documents/Codex/2026-08-08/zhe-s/outputs/`.

```bash
git status --short
git log -3 --oneline
```

Expected: only the pre-existing untracked `findings.md`, `progress.md`, and `task_plan.md` remain; generated outputs stay ignored.
