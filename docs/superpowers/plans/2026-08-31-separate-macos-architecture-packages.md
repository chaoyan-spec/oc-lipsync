# Separate macOS Architecture Packages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build, verify, and publish separate Apple Silicon and Intel macOS ZIP files from the same PAPAlu Live source.

**Architecture:** Parameterize the existing native macOS build script with an explicit architecture and architecture-specific output. Add a shell contract before changing production build behavior, then produce and inspect both app bundles before replacing the single ambiguous macOS release asset.

**Tech Stack:** Bash, Swift 5, AppKit, AVFoundation, `lipo`, `ditto`, GitHub Releases.

## Global Constraints

- Stable asset names are exactly `PAPAluLive-macOS-Apple-Silicon.zip` and `PAPAluLive-macOS-Intel.zip`.
- Apple Silicon contains only `arm64`; Intel contains only `x86_64`.
- Keep `PAPAluLive-win-x64.zip` unchanged.
- Keep the permanent entry `https://github.com/chaoyan-spec/oc-lipsync/releases/latest`.
- Do not change application behavior or create a Universal binary.

---

### Task 1: Parameterize the macOS Build

**Files:**
- Create: `realtime-macos/Tests/verify-build-architectures.sh`
- Modify: `realtime-macos/build-app.sh`
- Modify: `realtime-macos/run-tests.sh`

**Interfaces:**
- Consumes one architecture argument: `arm64` or `x86_64`.
- Produces `outputs/macos/Apple-Silicon/悬浮说话角色.app` or `outputs/macos/Intel/悬浮说话角色.app`.

- [ ] Add a shell contract that requires both supported architectures, both target triples, architecture-specific outputs, and rejection of unsupported input.
- [ ] Run the contract and verify it fails because the current script is hardcoded to `arm64`.
- [ ] Add minimal argument validation and map `arm64` to `arm64-apple-macosx13.0` / `Apple-Silicon`, and `x86_64` to `x86_64-apple-macosx13.0` / `Intel`.
- [ ] Add the contract to `run-tests.sh` and verify the full macOS test suite passes.

### Task 2: Build and Inspect Both Packages

**Files:**
- Create: `/private/tmp/PAPAluLive-macOS-Apple-Silicon.zip`
- Create: `/private/tmp/PAPAluLive-macOS-Intel.zip`

**Interfaces:**
- Produces two metadata-safe ZIP archives with the same App bundle name but different executable architectures.

- [ ] Run `./realtime-macos/build-app.sh arm64` and verify `lipo -info` reports `arm64`.
- [ ] Run `./realtime-macos/build-app.sh x86_64` and verify `lipo -info` reports `x86_64`.
- [ ] Package each App with `ditto -c -k --sequesterRsrc --keepParent` using the exact stable filenames.
- [ ] Run `unzip -t`, unpack both archives, re-check the contained executable architecture, and record size and SHA-256.

### Task 3: Update the Public Release

**Files:**
- Modify externally: GitHub Release `v0.1.0`
- Modify: `docs/superpowers/specs/2026-08-31-unified-download-entry-design.md`
- Modify: `docs/superpowers/plans/2026-08-31-unified-download-entry.md`

**Interfaces:**
- The Latest Release page exposes Windows, Apple Silicon macOS, and Intel macOS downloads.

- [ ] Update the existing unified-download documentation to list the two macOS assets.
- [ ] Upload both new macOS ZIPs to `v0.1.0` without replacing the Windows asset.
- [ ] Update release notes with plain-language chip selection guidance.
- [ ] Verify the new assets through the release API and public direct-download URLs.
- [ ] Remove the old `PAPAluLive-macOS.zip` only after both new assets pass public verification.
- [ ] Commit and push the scoped source and documentation changes without adding existing untracked output or planning files.
