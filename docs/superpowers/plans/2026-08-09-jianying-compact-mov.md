# Jianying Compact MOV Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the large transparent WebM export with the user-verified 320×366, 15 fps transparent Animation MOV that imports into Jianying at about 3.7 MB per 13.43 seconds.

**Architecture:** The server will crop the shared opaque character bounds from both 1000×1000 mouth PNGs, scale the result to 320×366, encode `qtrle` with `argb`, and mux AAC audio into MOV. The browser request will carry only filename and mouth cues; the UI will remove canvas scale controls and expose one Jianying-specific MOV download flow.

**Tech Stack:** Browser JavaScript modules, Node.js HTTP server and built-in tests, FFmpeg/ffprobe, QuickTime Animation (`qtrle`), AAC; no third-party npm dependencies.

## Global Constraints

- Output must be MOV, `qtrle`, `argb`, 320×366, 15 fps, with one AAC 96 kbps audio stream.
- Top-left decoded RGBA pixel must be `0 0 0 0`.
- Crop source PNGs at `622:711:213:188` before scaling to 320×366.
- Filename must be `<audio-base>-OC口播.mov` and response type must be `video/quicktime`.
- Do not send or validate character scale in the export request.
- Preserve MP3, WAV, M4A input, cue timing, streaming upload, cleanup, loopback binding, and visible save-link behavior.
- Do not retain a second WebM export path or add npm dependencies.

---

### Task 1: Compact Transparent MOV Encoder

**Files:**
- Modify: `server/export-video.js`
- Modify: `server/export-video.test.js`

**Interfaces:**
- Replace `exportTransparentWebm(input)` with `exportCompactMov(input)`.
- Consume `{ audioPath, mouthCues, closedMouthPath, openMouthPath, temporaryRoot? }`.
- Return `{ path, width: 320, height: 366, fps: 15, hasAudio: true, pixelFormat }`.

- [ ] **Step 1: Change the real encoder test to the approved MOV contract**

Rename the test and import, remove `characterScale`, and assert:

```js
import { exportCompactMov } from './export-video.js';

it('exports a verified transparent 320x366 Animation MOV with AAC audio', {
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
    { width: 320, height: 366, fps: 15, hasAudio: true },
  );
  assert.equal(video.codec_name, 'qtrle');
  assert.equal(video.width, 320);
  assert.equal(video.height, 366);
  assert.equal(video.avg_frame_rate, '15/1');
  assert.equal(video.pix_fmt, 'argb');
  assert.equal(audio.length, 1);
  assert.equal(audio[0].codec_name, 'aac');
});
```

Decode the top-left pixel without the VP9-specific decoder option and keep `assert.equal(corner[3], 0)`.

- [ ] **Step 2: Run the encoder test and verify RED**

Run: `node --test server/export-video.test.js`

Expected: FAIL because `exportCompactMov` is not exported and the current encoder produces VP9 WebM.

- [ ] **Step 3: Implement the minimal MOV encoder**

In `server/export-video.js`:

```js
export class ExportError extends Error {
  constructor(cause) {
    super('Could not export transparent MOV.', { cause });
    this.name = 'ExportError';
  }
}

export async function exportCompactMov({
  audioPath,
  mouthCues,
  closedMouthPath,
  openMouthPath,
  temporaryRoot = tmpdir(),
}) {
  // existing temporary directory and ffconcat lifecycle
  const outputPath = join(exportDirectory, 'transparent.mov');
  await execFileAsync(FFMPEG_PATH, [
    '-hide_banner', '-loglevel', 'error', '-y',
    '-f', 'concat', '-safe', '0', '-i', manifestPath,
    '-i', audioPath,
    '-filter_complex',
    '[0:v]crop=622:711:213:188,scale=320:366:flags=lanczos,fps=15,format=argb[video]',
    '-map', '[video]',
    '-map', '1:a:0',
    '-t', duration.toFixed(6),
    '-r', '15',
    '-c:v', 'qtrle',
    '-pix_fmt', 'argb',
    '-c:a', 'aac',
    '-b:a', '96k',
    '-movflags', '+faststart',
    outputPath,
  ], { maxBuffer: 10 * 1024 * 1024 });
}
```

Update `inspectExport` to require `qtrle`, 320×366, `15/1`, `argb`, and one `aac` stream. Update `verifyTransparentCorner` to decode MOV normally. Preserve manifest removal and recursive failure cleanup.

- [ ] **Step 4: Run encoder test and verify GREEN**

Run: `node --test server/export-video.test.js`

Expected: PASS with a real MOV; temporary export directory contains only `transparent.mov`.

- [ ] **Step 5: Commit Task 1**

```bash
git add server/export-video.js server/export-video.test.js
git commit -m "feat: export compact transparent MOV"
```

---

### Task 2: MOV API, Download, and UI

**Files:**
- Modify: `server/index.js`
- Modify: `server/index.test.js`
- Modify: `public/lib/export-client.js`
- Modify: `public/app.js`
- Modify: `public/index.html`
- Modify: `public/lib/ui-state.js`
- Modify: `src/export-client.test.js`
- Modify: `src/app-export-state.test.js`
- Modify: `src/ui-state.test.js`
- Modify: `src/launcher.test.js`
- Modify: `README.md`

**Interfaces:**
- API metadata becomes `{ filename: string, cues: MouthCue[] }`.
- `/api/export` responds with `video/quicktime` and `-OC口播.mov`.
- `createExportController.getExportInput()` returns `{ file, cues }`.

- [ ] **Step 1: Write failing server response and metadata tests**

In `server/index.test.js`, remove `scale` from `validMetadata`, delete the scale rejection test, and change the attachment test to require:

```js
assert.match(response.headers.get('content-type'), /^video\/quicktime\b/);
assert.match(
  response.headers.get('content-disposition'),
  /filename\*=UTF-8''a%27b%28c%29%2A-OC%E5%8F%A3%E6%92%AD\.mov/,
);
assert.equal('characterScale' in receivedInput, false);
assert.deepEqual(receivedInput.mouthCues, validMetadata.cues);
```

Make fake exporters write `transparent.mov`. Run:

```bash
node --test server/index.test.js
```

Expected: FAIL because the server still requires scale and responds with WebM headers.

- [ ] **Step 2: Write failing client and UI tests**

Update `src/export-client.test.js` so `makeInput()` has only `file` and `cues`, decoded request metadata omits `scale`, and success requires:

```js
assert.deepEqual(decoded.metadata, { filename: '访谈.WAV', cues: input.cues });
assert.equal(downloadLink.textContent, '导出完成，点击保存 MOV');
assert.equal(downloadLink.download, '访谈-OC口播.mov');
assert.equal(button.textContent, '导出剪映透明 MOV');
```

Delete the obsolete scale-normalization test and change retained-result error copy from WebM to MOV.

Update UI/static tests to assert that `character-scale` is absent, the button says `导出剪映透明 MOV`, the link says `导出完成，点击保存 MOV`, and the stage label includes `320 × 366`.

Run:

```bash
node --test src/export-client.test.js src/app-export-state.test.js src/ui-state.test.js src/launcher.test.js
```

Expected: FAIL against the current WebM copy, scale metadata, and scale control.

- [ ] **Step 3: Implement the server MOV response contract**

In `server/index.js`:

```js
import { exportCompactMov } from './export-video.js';

function validateMetadata(metadata) {
  if (typeof metadata.filename !== 'string' || !isSupportedAudio(metadata.filename)) {
    throw new ExportRequestError('Unsupported audio extension.', 'UNSUPPORTED_AUDIO');
  }
  if (!hasValidCues(metadata.cues)) {
    throw new ExportRequestError('Invalid export settings.');
  }
  return metadata;
}
```

Remove `hasValidScale`, do not pass `characterScale`, default `exportVideo` to `exportCompactMov`, and return:

```js
const downloadName = `${safeDownloadBase(metadata.filename)}-OC口播.mov`;
response.writeHead(200, {
  'Content-Type': 'video/quicktime',
  'Content-Length': outputMetadata.size,
  'Content-Disposition': contentDisposition(downloadName),
  'X-Content-Type-Options': 'nosniff',
});
```

- [ ] **Step 4: Implement the browser and UI MOV contract**

In `public/lib/export-client.js`, remove `normalizeScale`, use:

```js
const EXPORT_LABEL = '导出剪映透明 MOV';
const EXPORT_ERROR_WITH_RESULT = '本次导出失败，上次完成的 MOV 仍可保存';
const EXPORT_SUCCESS = '导出完成，点击保存 MOV';

const { file, cues } = getExportInput();
const body = createExportRequestBody({ filename: file.name, cues }, file);
downloadLink.download = `${downloadBase(file.name)}-OC口播.mov`;
```

In `public/app.js`, remove `characterScale` elements, state wiring, listeners, export controls, and export input. In `public/lib/ui-state.js`, remove `characterScale` from initial state.

In `public/index.html`, remove the OC size label/input, change export/link copy, and change the stage label to `320 × 366 · 剪映透明 MOV`.

Update README usage and requirements from WebM to MOV, explicitly stating that placement and scale are adjusted in Jianying.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run:

```bash
node --test server/index.test.js src/export-client.test.js src/app-export-state.test.js src/ui-state.test.js src/launcher.test.js
npm run build
```

Expected: all focused tests PASS and syntax build exits 0.

- [ ] **Step 6: Commit Task 2**

```bash
git add server/index.js server/index.test.js public/lib/export-client.js public/app.js \
  public/index.html public/lib/ui-state.js src/export-client.test.js \
  src/app-export-state.test.js src/ui-state.test.js src/launcher.test.js README.md
git commit -m "feat: make MOV the Jianying download format"
```

---

### Task 3: Real-Audio Release Verification

**Files:**
- Regenerate (ignored): `outputs/oc-lipsync-sample.mov`
- Regenerate (ignored): `outputs/OC口播机.zip`
- Copy deliverables to: `/Users/chaoyan/Documents/Codex/2026-08-08/zhe-s/outputs/`

**Interfaces:**
- Production browser path consumes `田林东路.m4a` and produces a visible `.mov` save link.
- Runtime-only ZIP includes the current source, assets, launcher, and no tests or repository files.

- [ ] **Step 1: Run full automated verification**

```bash
npm test
npm run build
zsh -n '启动OC口播机.command'
git diff --check
```

Expected: zero test failures and all checks exit 0.

- [ ] **Step 2: Verify the exact user audio through the real browser**

Start the local server, load `/Users/chaoyan/Downloads/田林东路.m4a`, play the preview, export, and require:

```text
loaded filename = 田林东路.m4a
duration ≈ 13.46 seconds
preview changes mouth state repeatedly
save link text = 导出完成，点击保存 MOV
download name = 田林东路-OC口播.mov
href starts with blob:
```

- [ ] **Step 3: Verify the resulting media contract**

Use ffprobe and a decoded corner pixel to require:

```text
container = mov
video codec = qtrle
pixel format = argb
dimensions = 320x366
frame rate = 15/1
audio codec = aac
duration ≈ source duration
top-left RGBA = 0 0 0 0
13.43-second user file size target = 3–5 MB
```

- [ ] **Step 4: Rebuild and verify the runtime-only ZIP**

Build a fresh explicit-allowlist archive containing runtime files, including `public/lib/playback-mouth.js`, and excluding `.git`, `.superpowers`, docs, source tests, fixtures, outputs, and scratch files. Run `unzip -t`, extract to a fresh directory, run `npm run build --prefix <fresh-dir>`, start it on a free loopback port, and verify `OC_LIPSYNC_READY` plus page title.

- [ ] **Step 5: Copy verified deliverables and inspect final state**

Copy `OC口播机.zip` and `oc-lipsync-sample.mov` to `/Users/chaoyan/Documents/Codex/2026-08-08/zhe-s/outputs/`. Verify hashes after copying.

```bash
git status --short
git log -5 --oneline
```

Expected: only the pre-existing untracked `findings.md`, `progress.md`, and `task_plan.md` remain.
