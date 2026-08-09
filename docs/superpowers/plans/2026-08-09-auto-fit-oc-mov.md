# Auto-Fit OC MOV Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the transparent Jianying MOV canvas automatically follow the shared visible bounds of the open- and closed-mouth OC images, with an approximately 320px maximum side and 8px transparent padding.

**Architecture:** `server/export-video.js` will inspect each PNG with FFprobe and FFmpeg's Alpha `bbox` filter, merge the two bounds, calculate an even auto-fit output size, and feed those values into the existing MOV filter graph. The HTTP request and browser export flow stay unchanged; only static UI copy and documentation stop promising a fixed resolution.

**Tech Stack:** Node.js built-ins and `node:test`, FFmpeg/ffprobe, browser JavaScript modules, QuickTime Animation (`qtrle`) with `argb`, AAC; no third-party npm dependencies.

## Global Constraints

- Detect every source pixel whose Alpha value is greater than zero with `alphaextract,bbox=min_val=1`.
- Require the open- and closed-mouth PNGs to have the same source canvas dimensions.
- Use the union of both visible bounds so changing mouth state never changes framing.
- Scale visible content down only, with a maximum content side of 304px; never enlarge a smaller OC.
- For downscaled content, round each calculated dimension to the nearest positive even number. For unscaled small content, floor each dimension to a positive even number so it is never enlarged. Add 8px transparent padding on every side, keeping the final longest side at or below 320px.
- The current 622×711 bounds downscale to 266×304; adding 8px on every side produces exactly 282×320.
- Preserve MOV, `qtrle`, `argb`, 15fps, one AAC 96kbps stream, filename `<audio-base>-OC口播.mov`, and response type `video/quicktime`.
- Preserve MP3/WAV/M4A input, cue timing, preview behavior, streamed upload, temporary-file cleanup, loopback-only server, and persistent visible save link.
- Fail export when either image is unreadable or fully transparent, or when source canvas dimensions differ.
- Do not add OC upload, manual crop/scale/output controls, a 9:16 canvas, a WebM path, or npm dependencies.

---

### Task 1: Alpha Bounds and Auto-Fit Geometry

**Files:**
- Modify: `server/export-video.js`
- Modify: `server/export-video.test.js`

**Interfaces:**
- Produce `mergeImageBounds(first, second) -> { x, y, width, height, canvasWidth, canvasHeight }`.
- Produce `calculateAutoFitDimensions(bounds, options?) -> { contentWidth, contentHeight, width, height, padding }`.
- Produce `detectImageBounds(imagePath) -> Promise<{ x, y, width, height, canvasWidth, canvasHeight }>`.
- `exportCompactMov` in Task 2 consumes all three helpers.

- [ ] **Step 1: Write failing geometry tests**

Change the test import and add focused cases to `server/export-video.test.js`:

```js
import {
  calculateAutoFitDimensions,
  detectImageBounds,
  exportCompactMov,
  mergeImageBounds,
} from './export-video.js';

it('merges both mouth bounds and preserves their shared canvas', () => {
  assert.deepEqual(
    mergeImageBounds(
      { x: 12, y: 20, width: 100, height: 180, canvasWidth: 500, canvasHeight: 500 },
      { x: 8, y: 24, width: 120, height: 170, canvasWidth: 500, canvasHeight: 500 },
    ),
    { x: 8, y: 20, width: 120, height: 180, canvasWidth: 500, canvasHeight: 500 },
  );
});

it('rejects mouth images with different source canvases', () => {
  assert.throws(() => mergeImageBounds(
    { x: 0, y: 0, width: 20, height: 20, canvasWidth: 100, canvasHeight: 100 },
    { x: 0, y: 0, width: 20, height: 20, canvasWidth: 120, canvasHeight: 100 },
  ), /same canvas dimensions/);
});

it('fits a portrait OC inside 304px and adds 8px padding', () => {
  assert.deepEqual(
    calculateAutoFitDimensions({ width: 622, height: 711 }),
    { contentWidth: 266, contentHeight: 304, width: 282, height: 320, padding: 8 },
  );
});

it('does not enlarge a smaller landscape OC', () => {
  assert.deepEqual(
    calculateAutoFitDimensions({ width: 200, height: 101 }),
    { contentWidth: 200, contentHeight: 100, width: 216, height: 116, padding: 8 },
  );
});

it('detects the current OC alpha bounds instead of using fixed coordinates', async () => {
  assert.deepEqual(
    await detectImageBounds(join(projectRoot, 'public/oc-mouth-closed.png')),
    { x: 213, y: 188, width: 622, height: 711, canvasWidth: 1000, canvasHeight: 1000 },
  );
});
```

- [ ] **Step 2: Run the focused test and verify RED**

Run: `node --test server/export-video.test.js`

Expected: FAIL because `mergeImageBounds`, `calculateAutoFitDimensions`, and `detectImageBounds` are not exported.

- [ ] **Step 3: Implement the geometry helpers**

Add these constants and pure helpers near the executable constants in `server/export-video.js`:

```js
const MAX_CONTENT_SIDE = 304;
const OUTPUT_PADDING = 8;

function floorPositiveEven(value) {
  return Math.max(2, Math.floor(value / 2) * 2);
}

function roundPositiveEven(value) {
  return Math.max(2, Math.round(value / 2) * 2);
}

export function mergeImageBounds(first, second) {
  if (
    first.canvasWidth !== second.canvasWidth
    || first.canvasHeight !== second.canvasHeight
  ) throw new Error('Mouth images must use the same canvas dimensions.');

  const x = Math.min(first.x, second.x);
  const y = Math.min(first.y, second.y);
  const right = Math.max(first.x + first.width, second.x + second.width);
  const bottom = Math.max(first.y + first.height, second.y + second.height);
  return {
    x,
    y,
    width: right - x,
    height: bottom - y,
    canvasWidth: first.canvasWidth,
    canvasHeight: first.canvasHeight,
  };
}

export function calculateAutoFitDimensions(bounds) {
  if (bounds.width < 2 || bounds.height < 2) {
    throw new Error('Mouth image bounds must be at least 2 pixels wide and high.');
  }

  const scale = Math.min(1, MAX_CONTENT_SIDE / Math.max(bounds.width, bounds.height));
  const roundToEven = scale < 1 ? roundPositiveEven : floorPositiveEven;
  const contentWidth = roundToEven(bounds.width * scale);
  const contentHeight = roundToEven(bounds.height * scale);
  return {
    contentWidth,
    contentHeight,
    width: contentWidth + OUTPUT_PADDING * 2,
    height: contentHeight + OUTPUT_PADDING * 2,
    padding: OUTPUT_PADDING,
  };
}
```

Implement Alpha-bound detection using the already resolved FFmpeg and FFprobe executables:

```js
export async function detectImageBounds(imagePath) {
  const [{ stdout }, { stderr }] = await Promise.all([
    execFileAsync(FFPROBE_PATH, [
      '-v', 'error',
      '-select_streams', 'v:0',
      '-show_entries', 'stream=width,height',
      '-of', 'json',
      imagePath,
    ]),
    execFileAsync(FFMPEG_PATH, [
      '-hide_banner', '-loglevel', 'info',
      '-i', imagePath,
      '-vf', 'alphaextract,bbox=min_val=1',
      '-frames:v', '1',
      '-f', 'null',
      '-',
    ]),
  ]);
  const video = JSON.parse(stdout).streams?.[0];
  const match = stderr.match(/x1:(\d+) x2:(\d+) y1:(\d+) y2:(\d+) w:(\d+) h:(\d+)/);
  if (!video || !match) throw new Error('Mouth image has no visible pixels.');
  return {
    x: Number(match[1]),
    y: Number(match[3]),
    width: Number(match[5]),
    height: Number(match[6]),
    canvasWidth: video.width,
    canvasHeight: video.height,
  };
}
```

- [ ] **Step 4: Run the focused test and verify GREEN**

Run: `node --test server/export-video.test.js`

Expected: all geometry tests and the pre-existing real encoder test PASS.

- [ ] **Step 5: Commit Task 1**

```bash
git add server/export-video.js server/export-video.test.js
git commit -m "feat: detect OC alpha bounds"
```

---

### Task 2: Dynamic Transparent MOV Encoder

**Files:**
- Modify: `server/export-video.js`
- Modify: `server/export-video.test.js`

**Interfaces:**
- Consume `detectImageBounds`, `mergeImageBounds`, and `calculateAutoFitDimensions` from Task 1.
- Preserve `exportCompactMov({ audioPath, mouthCues, closedMouthPath, openMouthPath, temporaryRoot? })`.
- Return `{ path, width, height, fps: 15, hasAudio: true, pixelFormat }`, where `width` and `height` are computed per OC.

- [ ] **Step 1: Change the integration test to require dynamic output**

Rename the existing test and replace fixed-size assertions:

```js
it('exports an auto-fit transparent Animation MOV with AAC audio', {
  timeout: 120_000,
}, async () => {
  const result = await exportCompactMov({
    audioPath: join(projectRoot, 'test/fixtures/tone-silence.wav'),
    closedMouthPath: join(projectRoot, 'public/oc-mouth-closed.png'),
    openMouthPath: join(projectRoot, 'public/oc-mouth-open.png'),
    mouthCues,
    temporaryRoot,
  });

  assert.deepEqual(
    { width: result.width, height: result.height, fps: result.fps, hasAudio: result.hasAudio },
    { width: 282, height: 320, fps: 15, hasAudio: true },
  );
  assert.equal(video.codec_name, 'qtrle');
  assert.equal(video.width, 282);
  assert.equal(video.height, 320);
  assert.equal(video.avg_frame_rate, '15/1');
  assert.equal(video.pix_fmt, 'argb');
  assert.equal(audio.length, 1);
  assert.equal(audio[0].codec_name, 'aac');
});
```

Keep the top-left RGBA Alpha assertion at zero. Add a failure case that passes a generated fully transparent PNG for one mouth state and asserts `ExportError` plus recursive cleanup:

```js
await execFileAsync(ffmpegPath, [
  '-hide_banner', '-loglevel', 'error', '-y',
  '-f', 'lavfi', '-i', 'color=black@0.0:s=100x100,format=rgba',
  '-frames:v', '1', transparentPath,
]);
await assert.rejects(exportCompactMov({
  audioPath,
  closedMouthPath: transparentPath,
  openMouthPath,
  mouthCues,
  temporaryRoot,
}), { name: 'ExportError' });
assert.deepEqual(await readdir(temporaryRoot), []);
```

- [ ] **Step 2: Run the encoder test and verify RED**

Run: `node --test server/export-video.test.js`

Expected: FAIL because the encoder still returns 320×366 and still contains the fixed `crop=622:711:213:188,scale=320:366` filter.

- [ ] **Step 3: Wire auto-fit values into the MOV filter graph**

At the start of `exportCompactMov`, before creating the manifest, compute:

```js
const [closedBounds, openBounds] = await Promise.all([
  detectImageBounds(closedMouthPath),
  detectImageBounds(openMouthPath),
]);
const bounds = mergeImageBounds(closedBounds, openBounds);
const dimensions = calculateAutoFitDimensions(bounds);
const filter = [
  `crop=${bounds.width}:${bounds.height}:${bounds.x}:${bounds.y}`,
  `scale=${dimensions.contentWidth}:${dimensions.contentHeight}:flags=lanczos`,
  `pad=${dimensions.width}:${dimensions.height}:${dimensions.padding}:${dimensions.padding}:color=black@0`,
  'fps=15',
  'format=argb',
].join(',');
```

Pass `` `[0:v]${filter}[video]` `` to `-filter_complex`. Change inspection to accept expected dimensions:

```js
async function inspectExport(path, { width, height }) {
  // existing ffprobe call
  if (
    video?.codec_name !== 'qtrle'
    || video.width !== width
    || video.height !== height
    || video.avg_frame_rate !== '15/1'
    || video.pix_fmt !== 'argb'
    || audio.length !== 1
    || audio[0].codec_name !== 'aac'
  ) throw new Error('Encoded stream properties did not match the export contract.');
  return video;
}
```

Return the dynamic values:

```js
const video = await inspectExport(outputPath, dimensions);
return {
  path: outputPath,
  width: dimensions.width,
  height: dimensions.height,
  fps: 15,
  hasAudio: true,
  pixelFormat: video.pix_fmt,
};
```

Keep all existing `try/catch` cleanup and `ExportError` wrapping.

- [ ] **Step 4: Run focused and full tests**

Run: `node --test server/export-video.test.js`

Expected: all encoder, geometry, transparency, and invalid-image tests PASS.

Run: `npm test`

Expected: the complete suite PASS with zero failures.

- [ ] **Step 5: Commit Task 2**

```bash
git add server/export-video.js server/export-video.test.js
git commit -m "feat: auto-fit transparent MOV canvas"
```

---

### Task 3: UI Copy, Real Audio Proof, and Runtime Package

**Files:**
- Modify: `public/index.html`
- Modify: `README.md`
- Modify: `src/app-export-state.test.js`
- Modify: `server/export-video.test.js` only if final media-contract assertions reveal a missing case
- Regenerate ignored artifact: `outputs/田林东路-OC口播.mov`
- Regenerate ignored artifact: `outputs/OC口播机.zip`

**Interfaces:**
- Browser request payload, API route, content type, download filename, and save-link behavior remain unchanged.
- User-facing stage label becomes exactly `自动适应 OC · 剪映透明 MOV`.

- [ ] **Step 1: Write the failing UI copy test**

Update the existing static assertion in `src/app-export-state.test.js`:

```js
test('removes canvas scale and labels the auto-fit Jianying MOV export', async () => {
  const html = await readFile(new URL('../public/index.html', import.meta.url), 'utf8');
  assert.doesNotMatch(html, /id="character-scale"/);
  assert.doesNotMatch(html, /320 × 366/);
  assert.match(html, /自动适应 OC · 剪映透明 MOV/);
  assert.match(html, /导出剪映透明 MOV/);
});
```

- [ ] **Step 2: Run the UI test and verify RED**

Run: `node --test src/app-export-state.test.js`

Expected: FAIL because `public/index.html` still displays `320 × 366 · 剪映透明 MOV`.

- [ ] **Step 3: Update the UI and README**

In `public/index.html`, replace the stage label with:

```html
<span class="stage-label">自动适应 OC · 剪映透明 MOV</span>
```

In `README.md`, replace the fixed output paragraph with:

```markdown
导出文件会自动识别张嘴、闭嘴 OC 的共同透明边界，保持人物比例，最长边约 320px，并在四周保留 8px 透明边距。人物在最终画布中的位置和大小请直接在剪映中调整。
```

- [ ] **Step 4: Run UI tests and commit the user-facing change**

Run: `node --test src/app-export-state.test.js src/launcher.test.js`

Expected: all UI and documentation tests PASS.

```bash
git add public/index.html README.md src/app-export-state.test.js
git commit -m "docs: explain auto-fit MOV output"
```

- [ ] **Step 5: Verify the real M4A through the production export path**

Use `/Users/chaoyan/Downloads/田林东路.m4a` with the existing 30fps energy analysis and mouth timeline, then call the production `exportCompactMov` and copy the result to `outputs/田林东路-OC口播.mov`.

Run FFprobe:

```bash
/opt/homebrew/bin/ffprobe -v error \
  -show_entries format=duration,size:stream=codec_type,codec_name,width,height,avg_frame_rate,pix_fmt,bit_rate \
  -of json outputs/田林东路-OC口播.mov
```

Expected: video `qtrle`, `282x320`, `15/1`, `argb`; one AAC stream near 96kbps; duration about 13.4 seconds. Decode pixel `(0,0)` as RGBA and require `0 0 0 0`.

- [ ] **Step 6: Verify the live browser flow**

Start the current app on an unused loopback port. In the real browser:

1. Confirm `自动适应 OC · 剪映透明 MOV` is visible.
2. Choose `/Users/chaoyan/Downloads/田林东路.m4a` through the file chooser.
3. Confirm duration `00:13` and enabled `导出剪映透明 MOV`.
4. Export and wait for the persistent `导出完成，点击保存 MOV` link.
5. Confirm download name `田林东路-OC口播.mov` and no console warnings/errors.

- [ ] **Step 7: Rebuild and test the runtime-only ZIP**

Create `outputs/OC口播机.zip` from this exact allowlist:

```text
package.json
README.md
启动OC口播机.command
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

Require `unzip -t outputs/OC口播机.zip` to pass. Extract into a fresh temporary directory, run `npm run build`, run `zsh -n 启动OC口播机.command`, start on an unused port, and require `/__oc-lipsync/ready` to return `OC_LIPSYNC_READY`. Confirm the archive contains no `src`, `test`, test files, fixtures, VCS data, planning files, or prior output artifacts.

- [ ] **Step 8: Run final verification**

Run:

```bash
npm test
npm run build
zsh -n 启动OC口播机.command
git diff --check
git status --short
```

Expected: all tests PASS, syntax checks exit zero, no whitespace errors, all source/docs/tests committed, and only the pre-existing untracked `findings.md`, `progress.md`, `task_plan.md` plus ignored regenerated outputs remain.

- [ ] **Step 9: Copy final artifacts to the main project output directory**

Copy and byte-verify:

```text
/Users/chaoyan/Documents/Codex/2026-08-08/zhe-s/outputs/田林东路-OC口播.mov
/Users/chaoyan/Documents/Codex/2026-08-08/zhe-s/outputs/OC口播机.zip
```

Report the final MOV dimensions, byte size, SHA-256, test count, and ZIP SHA-256 to the user.
