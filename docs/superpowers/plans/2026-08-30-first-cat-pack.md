# First Cat Pack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Huh Cat, Happy Cat, and Screaming Cat as selectable two-frame built-in characters with menu thumbnails while preserving the current Pop Cat and PAPAlu behavior.

**Architecture:** Keep `CharacterRuntime` unchanged. Add three two-frame `CharacterDefinition` values and make bundled-character loading/menu construction data-driven from one ordered catalog. Prepare two aligned transparent PNGs per cat, package them through the existing build script, and verify both source and bundle contracts.

**Tech Stack:** Swift 5, AppKit, AVFoundation, Bash, PNG assets, built-in image editing.

## Global Constraints

- Reuse the approved candidate identities; do not redesign the cats.
- Every pair is `idle.png` plus `talking.png` on an identical transparent canvas.
- Preserve existing Pop Cat, PAPAlu, custom-character, microphone, window, and QuickTime behavior.
- Keep the app native and offline; add no dependency, network runtime, or large framework.
- Do not add second-phase candidates or multi-frame animation in this version.

---

### Task 1: Define and test the ordered bundled-character catalog

**Files:**
- Modify: `realtime-macos/Tests/PAPAluLiveTests/CharacterDefinitionTests.swift`
- Modify: `realtime-macos/Sources/PAPAluLive/CharacterDefinition.swift`

**Interfaces:**
- Produces: `CharacterID.huhCat`, `.happyCat`, `.screamingCat`
- Produces: `CharacterDefinition.bundledCharacters: [(definition: CharacterDefinition, resourceDirectoryName: String)]`

- [ ] **Step 1: Write a failing test** asserting the ordered IDs, names, resource folders, and two-frame capability of the three new cats.
- [ ] **Step 2: Run** `bash realtime-macos/run-tests.sh` and confirm the definition test fails because the new cases/catalog do not exist.
- [ ] **Step 3: Add the minimal enum cases, a shared two-frame built-in factory, the three definitions, and the ordered bundled catalog.** Keep PAPAlu's existing multi-frame configuration unchanged.
- [ ] **Step 4: Run** `bash realtime-macos/run-tests.sh` and confirm all Swift and shell tests pass up to the still-missing resource contract introduced in Task 2.

### Task 2: Prepare and validate three two-frame image pairs

**Files:**
- Create: `realtime-macos/Resources/Characters/HuhCat/idle.png`
- Create: `realtime-macos/Resources/Characters/HuhCat/talking.png`
- Create: `realtime-macos/Resources/Characters/HappyCat/idle.png`
- Create: `realtime-macos/Resources/Characters/HappyCat/talking.png`
- Create: `realtime-macos/Resources/Characters/ScreamingCat/idle.png`
- Create: `realtime-macos/Resources/Characters/ScreamingCat/talking.png`
- Create: `outputs/first-cat-pack/qa/contact-sheet.png`
- Create: `outputs/first-cat-pack/SOURCES.md`
- Modify: `realtime-macos/Tests/verify-character-resources.sh`

**Interfaces:**
- Consumes: the three resource-directory names from Task 1.
- Produces: six transparent, pair-aligned PNG assets readable by `CharacterAssets.load`.

- [ ] **Step 1: Extend the resource contract first** so it requires all three folders, both filenames, alpha channels, matching dimensions, and non-empty visible bounds.
- [ ] **Step 2: Run** `bash realtime-macos/Tests/verify-character-resources.sh` and confirm it fails on the missing first new asset.
- [ ] **Step 3: Use built-in image editing** to extract each approved cat onto transparency and create only its missing mouth state. Preserve the meme's original identity and visual texture.
- [ ] **Step 4: Normalize each pair to one bottom-centered shared canvas without stretching, then create a contact sheet.**
- [ ] **Step 5: Run the resource contract and visually inspect the contact sheet** for complete silhouettes, transparency, mouth-state readability, and registration stability.

### Task 3: Load all bundled characters and render thumbnail menu items

**Files:**
- Modify: `realtime-macos/Tests/PAPAluLiveTests/AppShellCompileTests.swift`
- Modify: `realtime-macos/Sources/PAPAluLive/AppDelegate.swift`

**Interfaces:**
- Consumes: `CharacterDefinition.bundledCharacters` and loaded idle images.
- Produces: a data-driven right-click menu whose built-in items carry `CharacterID.rawValue` in `representedObject` and a 28-point thumbnail image.

- [ ] **Step 1: Add failing app-shell/source contract checks** for generic bundled loading, generic menu selection, and thumbnail assignment rather than three new hard-coded selectors.
- [ ] **Step 2: Run** `bash realtime-macos/run-tests.sh` and confirm the new contract fails.
- [ ] **Step 3: Replace hard-coded built-in loading/menu actions with the ordered bundled catalog.** Keep custom settings behavior unchanged.
- [ ] **Step 4: Draw each idle thumbnail into a new `NSImage` with proportional fit and set it on the menu item.** Never resize the Runtime's source image object.
- [ ] **Step 5: Run** `bash realtime-macos/run-tests.sh` and confirm all real-time tests and shell contracts pass.

### Task 4: Package, document, and verify the app

**Files:**
- Modify: `realtime-macos/build-app.sh`
- Modify: `realtime-macos/Tests/verify-app-icon.sh`
- Modify: `README.md`

**Interfaces:**
- Consumes: all bundled-character directories.
- Produces: `outputs/悬浮说话角色.app` containing five built-in characters plus the custom slot.

- [ ] **Step 1: Extend the bundle contract first** to require every new `idle.png` and `talking.png` in `Contents/Resources/Characters`.
- [ ] **Step 2: Run the bundle contract/build** and confirm it fails before the build script copies the new folders.
- [ ] **Step 3: Make `build-app.sh` validate and copy the ordered resource folders without changing signing or the existing output path.**
- [ ] **Step 4: Update README** with the first-batch names, thumbnail selection, and local-prototype rights reminder.
- [ ] **Step 5: Run** `npm test`, `bash realtime-macos/run-tests.sh`, and `bash realtime-macos/build-app.sh`; inspect the built bundle and record size.
- [ ] **Step 6: Launch the built app for a live microphone/selection check** and leave it open for user preview after automated verification passes.
