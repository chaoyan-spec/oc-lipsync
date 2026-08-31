# Unified Desktop Download Entry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the public GitHub Latest Release page the single permanent download entry for both Windows and macOS.

**Architecture:** Keep GitHub Releases as the only distribution surface. Preserve the accepted Windows asset, add a metadata-safe macOS ZIP with a stable filename, and update the existing latest release from Windows-only wording to cross-platform wording.

**Tech Stack:** Existing Swift/AppKit build script, macOS `ditto`, GitHub CLI Releases, GitHub public release redirects.

## Global Constraints

- The single entry remains `https://github.com/chaoyan-spec/oc-lipsync/releases/latest`.
- Stable asset names are exactly `PAPAluLive-win-x64.zip` and `PAPAluLive-macOS.zip`.
- Do not create a website, combined ZIP, installer, signing workflow, updater, or application-code changes.
- Do not replace or modify the already accepted Windows ZIP.

---

### Task 1: Build and Package the macOS App

**Files:**
- Consume: `realtime-macos/build-app.sh`
- Create: `/private/tmp/PAPAluLive-macOS.zip`

**Interfaces:**
- Consumes the current committed macOS source and authoritative bundled character assets.
- Produces one ZIP whose root contains `悬浮说话角色.app` with executable permissions and resources preserved.

- [ ] Run `./realtime-macos/run-tests.sh` and require all 42 tests and shell contracts to pass.
- [ ] Run `./realtime-macos/build-app.sh` and require `outputs/悬浮说话角色.app` to be produced.
- [ ] Package with `/usr/bin/ditto -c -k --sequesterRsrc --keepParent outputs/悬浮说话角色.app /private/tmp/PAPAluLive-macOS.zip`.
- [ ] Verify the ZIP with `unzip -t`, inspect its file list, and record SHA-256 and size.

### Task 2: Update the Existing Cross-platform Release

**Files:**
- Upload: `/private/tmp/PAPAluLive-macOS.zip`
- Modify externally: GitHub Release `v0.1.0`

**Interfaces:**
- Produces a latest release containing both stable asset names and a cross-platform release description.

- [ ] Upload `PAPAluLive-macOS.zip` to `v0.1.0` without replacing the Windows asset.
- [ ] Change the release title to `悬浮说话角色 v0.1.0（Windows / macOS）`.
- [ ] Change release notes to identify each platform package and extraction/startup instructions.
- [ ] Query the latest release API and require both exact asset names to be present.
- [ ] Verify the public Latest Release page and both stable direct-download redirects return success.

### Task 3: Preserve the Distribution Rule in Git History

**Files:**
- Create: `docs/superpowers/specs/2026-08-31-unified-download-entry-design.md`
- Create: `docs/superpowers/plans/2026-08-31-unified-download-entry.md`

**Interfaces:**
- Produces a committed and pushed rule that future releases must retain both stable asset filenames.

- [ ] Commit the implementation plan after validating it contains no placeholders or contradictory filenames.
- [ ] Push the documentation commits to remote `main` without force-pushing.
- [ ] Verify remote `main` points to the new documentation commit.
