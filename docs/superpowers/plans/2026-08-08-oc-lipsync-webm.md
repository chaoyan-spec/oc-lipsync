# OC Lip-Sync WebM Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local single-page Mac tool that turns a voice recording into a 1080×1920, 30 fps transparent WebM with the bundled OC switching between open- and closed-mouth PNG states.

**Architecture:** A small dependency-free browser client decodes audio for preview and produces a deterministic mouth timeline. A local Node server receives one compact binary envelope containing metadata plus the audio, then invokes the already-installed FFmpeg/libvpx-vp9 encoder and verifies the WebM with ffprobe before returning it. All media remains on the Mac.

**Tech Stack:** Browser Web APIs, TypeScript executed by Node 24 type stripping, Node `http` and `node:test`, FFmpeg 8/libvpx-vp9, ffprobe. No third-party npm dependencies.

## Global Constraints

- Output is always 1080×1920, 30 fps, transparent WebM with the original audio.
- Bundle `/Users/chaoyan/Desktop/来自：iPad/2026-08-07 173654.png` as the open-mouth state and `/Users/chaoyan/Desktop/来自：iPad/2026-08-07 173709.png` as the closed-mouth state.
- The OC is horizontally centered and bottom-aligned; only its scale is adjustable.
- Lip sync is driven by audio energy, not phoneme recognition.
- User controls are limited to sensitivity, minimum open-mouth time, and OC size.
- Accepted audio types are MP3, WAV, and M4A.
- Do not add Live2D, subtitles, AI voice, accounts, cloud uploads, or multi-character management.
- First release is local-only and must not use Sites hosting.

## File Map

- `package.json`, `tsconfig.json` — dependency-free scripts and type checking conventions.
- `src/lipsync.ts` — pure energy-to-mouth-state functions.
- `src/lipsync.test.ts` — threshold, silence, minimum-duration, and boundary tests.
- `src/audio.ts` — browser audio decoding and RMS extraction.
- `src/audio.test.ts` — deterministic RMS extraction tests using numeric sample arrays.
- `public/index.html`, `public/app.js`, `public/styles.css` — one-page import, preview, controls, export flow, and product-specific styling.
- `src/request-envelope.ts`, `src/request-envelope.test.ts` — encode/decode the metadata-plus-audio request format.
- `public/oc-mouth-open.png`, `public/oc-mouth-closed.png` — bundled RGBA OC assets.
- `server/export-video.ts` — FFmpeg input preparation, command execution, and ffprobe verification.
- `server/export-video.test.ts` — command and real transparent WebM integration tests.
- `server/index.ts` — local `/api/export` endpoint and static production serving.
- `server/index.test.ts` — request validation and successful-download API tests using Node fetch.
- `test/fixtures/tone-silence.wav` — short generated audio fixture containing tone, silence, and tone.
- `README.md` — exact start and use instructions for the user.

---

### Task 1: Project foundation and deterministic mouth timeline

**Files:**
- Create: `package.json`
- Create: `tsconfig.json`
- Create: `src/lipsync.test.ts`
- Create: `src/lipsync.ts`

**Interfaces:**
- Produces: `buildMouthTimeline(energies: number[], options: TimelineOptions): MouthCue[]`
- Produces: `mouthAtTime(cues: MouthCue[], seconds: number): MouthState`
- Types: `MouthState = 'open' | 'closed'`, `MouthCue = { start: number; end: number; state: MouthState }`, `TimelineOptions = { frameSeconds: number; threshold: number; minOpenSeconds: number }`

- [ ] **Step 1: Create the minimal dependency-free Node test setup and the failing timeline tests**

Use scripts `dev`, `start`, and `test`, with `test` running Node 24's built-in test runner over TypeScript. Add tests with these exact behaviors, expressed with `node:test` and `node:assert/strict`:

```ts
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { buildMouthTimeline, mouthAtTime } from './lipsync';

describe('buildMouthTimeline', () => {
  it('keeps silence closed', () => {
    assert.deepEqual(buildMouthTimeline([0, 0, 0], {
      frameSeconds: 0.1, threshold: 0.2, minOpenSeconds: 0.1,
    }), [{ start: 0, end: 0.3, state: 'closed' }]);
  });

  it('opens above the threshold and merges adjacent frames', () => {
    assert.deepEqual(buildMouthTimeline([0, 0.4, 0.5, 0], {
      frameSeconds: 0.1, threshold: 0.2, minOpenSeconds: 0.1,
    }), [
      { start: 0, end: 0.1, state: 'closed' },
      { start: 0.1, end: 0.3, state: 'open' },
      { start: 0.3, end: 0.4, state: 'closed' },
    ]);
  });

  it('extends short open bursts to the configured minimum without exceeding duration', () => {
    assert.deepEqual(buildMouthTimeline([0, 0.5, 0, 0], {
      frameSeconds: 0.1, threshold: 0.2, minOpenSeconds: 0.2,
    }), [
      { start: 0, end: 0.1, state: 'closed' },
      { start: 0.1, end: 0.3, state: 'open' },
      { start: 0.3, end: 0.4, state: 'closed' },
    ]);
  });
});

it('uses a closed final boundary', () => {
  const cues = [{ start: 0, end: 0.2, state: 'open' as const }];
  assert.equal(mouthAtTime(cues, 0.2), 'closed');
});
```

- [ ] **Step 2: Run the test and verify RED**

Run: `npm test -- src/lipsync.test.ts`

Expected: FAIL because `src/lipsync.ts` does not exist or does not export the required functions.

- [ ] **Step 3: Implement the smallest timeline module**

Implement strict option validation, threshold classification, minimum-open extension, adjacent-state merging, decimal rounding to six places, and closed fallback outside the cue range. Do not add phoneme or smoothing settings.

- [ ] **Step 4: Run the test and verify GREEN**

Run: `npm test -- src/lipsync.test.ts`

Expected: all four tests PASS.

- [ ] **Step 5: Commit the tested unit**

Run:

```bash
git add package.json tsconfig.json src/lipsync.ts src/lipsync.test.ts
git commit -m "feat: add deterministic mouth timeline"
```

Expected: one task commit with only project setup and timeline files.

---

### Task 2: Browser audio analysis and bundled OC assets

**Files:**
- Create: `src/audio.test.ts`
- Create: `src/audio.ts`
- Create: `public/oc-mouth-open.png`
- Create: `public/oc-mouth-closed.png`

**Interfaces:**
- Consumes: `TimelineOptions` from `src/lipsync.ts` only in callers, not inside the audio module.
- Produces: `calculateWindowRms(samples: Float32Array, sampleRate: number, windowSeconds: number): number[]`
- Produces: `decodeAudio(file: File): Promise<{ buffer: AudioBuffer; energies: number[] }>`

- [ ] **Step 1: Copy the two supplied RGBA PNGs to their fixed public names**

Copy the open-mouth image to `public/oc-mouth-open.png` and the closed-mouth image to `public/oc-mouth-closed.png`. Verify both remain `1000 x 1000`, `8-bit/color RGBA` with `file public/oc-mouth-*.png`.

- [ ] **Step 2: Write the failing RMS tests**

```ts
import { it } from 'node:test';
import assert from 'node:assert/strict';
import { calculateWindowRms } from './audio';

it('calculates one RMS value per complete or partial window', () => {
  const values = calculateWindowRms(new Float32Array([1, -1, 0, 0]), 4, 0.5);
  assert.deepEqual(values, [1, 0]);
});

it('returns zeros for silent samples', () => {
  assert.deepEqual(calculateWindowRms(new Float32Array(6), 6, 0.5), [0, 0]);
});
```

- [ ] **Step 3: Run the test and verify RED**

Run: `npm test -- src/audio.test.ts`

Expected: FAIL because `calculateWindowRms` is missing.

- [ ] **Step 4: Implement audio decoding and RMS extraction**

`calculateWindowRms` must compute `sqrt(sum(sample²)/count)` per window. `decodeAudio` must create an `AudioContext`, decode the file's `ArrayBuffer`, mix all channels by averaging their samples, calculate RMS in `1/30` second windows, and close the context in `finally`.

- [ ] **Step 5: Run tests and commit**

Run: `npm test -- src/audio.test.ts src/lipsync.test.ts`

Expected: all tests PASS.

Commit message: `feat: analyze voice energy and bundle OC states`.

---

### Task 3: One-page preview workflow

**Files:**
- Rename: `src/lipsync.ts` to `public/lib/lipsync.js`
- Rename: `src/audio.ts` to `public/lib/audio.js`
- Rename: `src/lipsync.test.ts` to `test/lipsync.test.js`
- Rename: `src/audio.test.ts` to `test/audio.test.js`
- Create: `src/ui-state.test.js`
- Create: `src/ui-state.js`
- Create: `public/index.html`
- Create: `public/app.js`
- Create: `public/styles.css`
- Create: `server/static-server.js`
- Modify: `package.json`

**Interfaces:**
- Consumes: `decodeAudio(file)` from `public/lib/audio.js`.
- Consumes: `buildMouthTimeline(...)` and `mouthAtTime(...)` from `public/lib/lipsync.js`.
- Produces: `isSupportedAudio(fileName: string): boolean` and `createInitialUiState()` from `src/ui-state.js`.
- Produces: browser form state `{ file, sensitivity, minOpenSeconds, characterScale, cues }` later submitted to `/api/export`.

- [ ] **Step 1: Write failing tests for the browser state contract**

Use `node:test` and `node:assert/strict` to cover:

```js
test('starts with playback and export disabled', () => {
  assert.deepEqual(createInitialUiState(), {
    file: null, sensitivity: 35, minOpenMs: 120, characterScale: 72,
    canPlay: false, canExport: false, error: '',
  });
});

test('accepts only the three agreed audio extensions case-insensitively', () => {
  assert.equal(isSupportedAudio('讲解.M4A'), true);
  assert.equal(isSupportedAudio('讲解.mp3'), true);
  assert.equal(isSupportedAudio('讲解.wav'), true);
  assert.equal(isSupportedAudio('讲解.aac'), false);
});
```

- [ ] **Step 2: Run the state test and verify RED**

Run: `npm test -- src/ui-state.test.js`

Expected: FAIL because `src/ui-state.js` does not exist.

- [ ] **Step 3: Convert the shared audio/lipsync modules to browser-compatible JavaScript**

Move the reviewed logic to `public/lib/*.js`, replace TypeScript-only syntax with JSDoc, and update the existing tests to import those files. Preserve all six passing behaviors exactly; do not duplicate the energy or timeline algorithms in `public/app.js`.

- [ ] **Step 4: Implement the complete preview page and local static server**

Build one responsive page with:

- title `OC 口播机` and concise local-processing copy;
- 9:16 checkerboard stage with the OC centered at the bottom;
- drag/drop plus visible file picker accepting `.mp3,.wav,.m4a,audio/mpeg,audio/wav,audio/mp4`;
- filename, duration, play/pause, and progress;
- three labeled range controls with visible values and defaults: sensitivity `35`, minimum open time `120 ms`, OC size `72%`;
- an `<audio>` element whose `timeupdate` selects the proper mouth image with `mouthAtTime`;
- disabled export button reserved for Task 5;
- decode and silent-audio error messages from the design.

The browser script must use the shared modules directly. `server/static-server.js` must serve only files under `public/`, reject path traversal, bind `127.0.0.1`, and print the exact local URL. `npm run dev` and `npm start` both launch this server for now; `npm run build` checks all JavaScript syntax with Node.

Use warm off-white controls and dark plum/pink accents derived from the OC. Avoid dashboard navigation, gradients, decorative cards, and generic landing-page sections.

- [ ] **Step 5: Run tests and syntax build**

Run:

```bash
npm test
npm run build
```

Expected: all tests PASS; syntax build exits 0; no dependencies are installed.

- [ ] **Step 6: Commit**

Commit message: `feat: add OC voice preview workflow`.

---

### Task 4: Transparent WebM export service

**Files:**
- Create: `server/export-video.test.js`
- Create: `server/export-video.js`
- Create: `test/fixtures/tone-silence.wav`
- Modify: `package.json`

**Interfaces:**
- Consumes: `mouthCues: MouthCue[]`, `characterScale: number`, and an uploaded audio path.
- Produces: `exportTransparentWebm(input): Promise<ExportResult>`.
- `ExportResult = { path, width: 1080, height: 1920, fps: 30, hasAudio: true, pixelFormat }`.

- [ ] **Step 1: Generate a deterministic two-second audio fixture**

Use FFmpeg lavfi sources to make 0.7 s tone, 0.6 s silence, and 0.7 s tone, concatenate them, and save mono PCM WAV as `test/fixtures/tone-silence.wav`. Verify duration is exactly 2 seconds within 0.02-second tolerance using ffprobe.

- [ ] **Step 2: Write the failing real-export integration test**

The test must call `exportTransparentWebm` with cues for closed/open/closed/open/closed, scale `0.72`, the fixture audio, and the bundled PNG paths. Assert that ffprobe reports:

- width `1080`;
- height `1920`;
- average frame rate `30/1`;
- one audio stream;
- VP9 video codec;
- alpha metadata or a decoded RGBA corner pixel with alpha `0`.

The test must clean only its own `mkdtemp` output directory in `afterEach`.

- [ ] **Step 3: Run the integration test and verify RED**

Run: `npm test -- server/export-video.test.js`

Expected: FAIL because `exportTransparentWebm` is missing.

- [ ] **Step 4: Implement FFmpeg rendering and verification**

Implementation requirements:

- create a unique temporary directory with `mkdtemp`;
- create an FFmpeg concat-demuxer manifest from the mouth cues, alternating the two bundled PNG paths and exact cue durations; repeat the final image entry as required by the concat demuxer;
- in one FFmpeg invocation, convert the manifest to 30 fps, scale the square RGBA OC to `characterScale × 1000` pixels, horizontally center and bottom-align it on a transparent 1080×1920 canvas, map the original audio, and encode with `libvpx-vp9`, `-pix_fmt yuva420p`, `-auto-alt-ref 0`, and Opus audio;
- run ffprobe after encoding and reject width, height, fps, codec, or audio verification failures; decode one corner pixel as RGBA and reject alpha values other than `0`;
- remove the concat manifest after a successful export while keeping the returned WebM until the server response finishes;
- surface a concise `ExportError` without exposing the command line to the UI.

- [ ] **Step 5: Run tests and commit**

Run: `npm test -- server/export-video.test.js`

Expected: integration test PASS and verified WebM exists.

Commit message: `feat: export verified transparent WebM`.

---

### Task 5: Export API and browser download

**Files:**
- Create: `server/index.test.ts`
- Create: `server/index.ts`
- Modify: `src/App.test.tsx`
- Modify: `src/App.tsx`
- Modify: `package.json`

**Interfaces:**
- Consumes: `exportTransparentWebm(...)` from `server/export-video.ts`.
- Produces: `POST /api/export`, multipart fields `audio`, `mouthCues`, `characterScale`.
- Returns: `video/webm` attachment named `<source-base>-oc-lipsync.webm`.

- [ ] **Step 1: Write failing API validation tests**

Use Supertest to assert:

- missing audio returns `400` and `{ error: '请先选择口播音频' }`;
- unsupported extension returns `400` and the agreed unsupported-audio message;
- invalid JSON cues or a scale outside `0.4..1` returns `400`;
- a valid fixture request returns `200`, `Content-Type: video/webm`, and an attachment filename ending `-oc-lipsync.webm`.

- [ ] **Step 2: Run the API tests and verify RED**

Run: `npm test -- server/index.test.ts`

Expected: FAIL because the Express app is missing.

- [ ] **Step 3: Implement the local export endpoint**

Use Multer with one-file upload, a 500 MB limit, explicit `.mp3/.wav/.m4a` validation, JSON cue validation, and guaranteed cleanup after `res.download` completes or errors. Export `createApp()` for tests. In production, serve `dist/` and listen only on `127.0.0.1`.

- [ ] **Step 4: Write the failing browser export-state tests**

Mock `fetch` to test that clicking export:

- changes button copy to `正在导出…` and disables controls;
- downloads the returned blob as `<audio-base>-oc-lipsync.webm`;
- restores all controls after completion;
- shows `导出失败，请重试` while preserving the loaded audio and settings when the request fails.

- [ ] **Step 5: Run the browser tests and verify RED**

Run: `npm test -- src/App.test.tsx`

Expected: new export tests FAIL because the click handler is absent.

- [ ] **Step 6: Implement export submission, progress state, and download**

Post `FormData` with the original audio, serialized cues, and scale. Use the returned `Blob`, `URL.createObjectURL`, a temporary download anchor, and `URL.revokeObjectURL`. Keep loaded state on failure.

- [ ] **Step 7: Run all tests, build, and commit**

Run:

```bash
npm test
npm run build
```

Expected: all unit, component, API, and integration tests PASS; build exits 0.

Commit message: `feat: connect transparent video download`.

---

### Task 6: End-to-end handoff and real-asset verification

**Files:**
- Create: `README.md`
- Modify only if verification finds a scoped defect: files from Tasks 1–5 plus their corresponding tests.

**Interfaces:**
- Consumes: the complete local tool.
- Produces: a repeatable `npm start` workflow and one verified sample export under `outputs/`.

- [ ] **Step 1: Write concise user instructions**

Document exactly:

1. run `npm install` once;
2. run `npm start`;
3. open the printed local address;
4. import MP3/WAV/M4A;
5. preview and adjust the three controls;
6. export WebM and import it into the editing workflow.

Also state that files remain local and FFmpeg is required at `/opt/homebrew/bin/ffmpeg` or on `PATH`.

- [ ] **Step 2: Run the complete automated verification**

Run:

```bash
npm test
npm run build
```

Expected: zero failures and exit code 0.

- [ ] **Step 3: Start the production server and export with real OC assets**

Start `npm start`, submit `test/fixtures/tone-silence.wav`, and save the response as `outputs/oc-lipsync-sample.webm`.

- [ ] **Step 4: Verify the delivered sample**

Use ffprobe and decoded RGBA corner inspection to confirm:

- 1080×1920;
- 30 fps;
- duration approximately 2 seconds;
- VP9 video and Opus audio;
- transparent corner alpha is 0;
- OC alternates open/closed according to the fixture cues and remains bottom-center.

- [ ] **Step 5: Commit the handoff**

Commit `README.md` and any test-backed scoped fixes. Do not commit generated `outputs/*.webm` or temporary frames.

Commit message: `docs: add local OC lip-sync workflow`.
