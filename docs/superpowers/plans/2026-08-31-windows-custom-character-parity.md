# Windows Custom Character Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sync the accepted Mac custom-character cadence, idle effects, and deletion behavior to the Windows WPF build.

**Architecture:** Keep the existing WPF design. Put animation behavior in `CharacterDefinition.Custom`, App-copy deletion in `CustomCharacterStore`, menu state in `CharacterMenuBuilder`, and user-facing coordination in `MainWindow`.

**Tech Stack:** C# 13, .NET 10, WPF, existing PAPAluLive Core and Windows smoke-test projects.

## Global Constraints

- Preserve all bundled character behavior.
- Delete only `%LocalAppData%\PAPAluLive\CustomCharacter`; never delete source PNGs.
- If deletion fails, keep the current in-memory character unchanged.
- Preserve the corrected top thought-cloud layout and full thumbnail rendering.
- Do not add dependencies or unrelated UI.

---

### Task 1: Lock Custom Animation Parity with Core Tests

**Files:**
- Modify: `realtime-windows/PAPAluLive.Core.Tests/Program.cs`
- Modify: `realtime-windows/PAPAluLive.Core/CharacterDefinition.cs`

**Interfaces:**
- Consumes: `CharacterDefinition.Custom()` and `CharacterRuntime`.
- Produces: a custom definition with `TalkingAssetNames = ["talking", "idle", "talking", "idle", "talking", "talking"]`, `TalkingFramesPerSecond = 8`, gentle idle motion, and thought cloud enabled.

- [ ] Add failing core checks for cadence, frame progression, gentle idle motion, and thought cloud.
- [ ] Run the core test executable and confirm those checks fail.
- [ ] Change only `CharacterDefinition.Custom()` to match the accepted two-frame behavior.
- [ ] Run the core tests and confirm every check passes.

### Task 2: Add Safe Custom-Asset Deletion

**Files:**
- Modify: `realtime-windows/PAPAluLive.Windows.SmokeTests/Program.cs`
- Modify: `realtime-windows/PAPAluLive.Windows/Characters/CustomCharacterStore.cs`

**Interfaces:**
- Produces: `public void Delete()` that recursively removes only the store's managed custom-character directory and is safe when called again.

- [ ] Add smoke checks that imported assets disappear after `Delete()` and a repeated delete stays safe.
- [ ] Cross-build the smoke project and confirm compilation fails because `Delete()` is missing.
- [ ] Add the minimal idempotent `Delete()` implementation.
- [ ] Cross-build the smoke project successfully.

### Task 3: Wire Delete into the WPF Menu

**Files:**
- Modify: `realtime-windows/Tests/verify-wpf-shell.sh`
- Modify: `realtime-windows/PAPAluLive.Windows/Presentation/CharacterMenuBuilder.cs`
- Modify: `realtime-windows/PAPAluLive.Windows/MainWindow.xaml.cs`

**Interfaces:**
- `CharacterMenuBuilder` consumes a new `Action deleteCustom` callback.
- `SetCustomAvailable` synchronizes both the custom selection item and delete item's enabled state.
- `MainWindow.DeleteCustomCharacter()` confirms, deletes, clears memory, and falls back to Cat Meme if needed.

- [ ] Add shell-contract checks for the menu text, enabled-state update, and handler wiring.
- [ ] Run the shell contract and confirm it fails.
- [ ] Add the delete menu item and enabled-state synchronization.
- [ ] Add the confirmation and fallback handler in `MainWindow`.
- [ ] Run the shell contract and cross-build the WPF smoke project successfully.

### Task 4: Package and Verify the Windows Build

**Files:**
- Create: `outputs/windows/悬浮说话角色-win-x64-20260831-sync1.zip`

**Interfaces:**
- Produces: a self-contained Windows 10/11 x64 ZIP containing the executable and Windows README.

- [ ] Run core tests, WPF shell contract, and the Windows smoke-project cross-build.
- [ ] Publish `PAPAluLive.Windows.csproj` for `win-x64` as a self-contained single-file executable.
- [ ] Add `README-Windows.md`, create the ZIP, and verify the archive.
- [ ] Record archive size, SHA-256, and real-Windows acceptance steps.
