# Windows Live Character V1 Acceptance

## Status

**Awaiting real Windows acceptance.** The Windows x64 executable has been cross-built and packaged on macOS, but transparency, WASAPI input, DPI behavior, OBS capture, and the Windows-only smoke-test executable must be run on a real Windows machine before this branch is considered release-accepted.

## Acceptance artifact

- Archive: `outputs/windows/悬浮说话角色-win-x64.zip`
- Archive SHA-256: `412480ecc13f856c80e9e2757937fe4f25822524e370525b576c071f77f428aa`
- Archive contents: `PAPAluLive.Windows.exe`, `README-Windows.md`
- Target: Windows 11 x64; Windows 10 22H2 x64 best-effort compatibility
- Signing: unsigned local acceptance build

## Mac-side evidence completed

- Windows core checks: 23 passed.
- WPF application and Windows smoke-test projects: cross-target build succeeded with 0 warnings and 0 errors.
- WPF shell contract: passed.
- Self-contained executable: PE32+ Windows GUI x86-64, approximately 75 MB.
- Package contract checked: executable present and non-empty; no WAV, M4A, MP3, camera, or webcam assets.
- Existing macOS realtime tests and contracts: 41 passed.
- Existing offline web Lip Sync tests: 78 passed.

## Real Windows environment

- [ ] Windows edition and build:
- [ ] CPU architecture is x64:
- [ ] Display scaling / DPI:
- [ ] Default microphone:
- [ ] SmartScreen shown: yes / no
- [ ] Extracted size:
- [ ] Startup time:

## Real Windows checks

### Application shell

- [ ] ZIP extracts and `PAPAluLive.Windows.exe` launches without installing .NET.
- [ ] Window background is transparent, with no title bar, border, or shadow.
- [ ] Character remains above ordinary application windows.
- [ ] Left-drag moves the character.
- [ ] Right-click menu shows five built-ins, custom import, scaling, and exit.
- [ ] Scale and position survive restart.
- [ ] A saved position from a disconnected monitor is clamped back on-screen.
- [ ] Application icon appears in the taskbar.

### Characters and animation

- [ ] All five built-in characters display and switch without stale frames or crashes.
- [ ] PAPAlu talking, settle, idle sway, blink, and thought cloud are visible.
- [ ] Two-frame cats open during speech and return to idle after speech.
- [ ] Importing closed/open PNGs creates a usable custom character.
- [ ] Cancelling either PNG picker does not alter the current custom character.

### Microphone

- [ ] Speaking opens the mouth quickly.
- [ ] One minute of continuous speech does not fall into idle mid-sentence.
- [ ] Natural short pauses do not cause rapid chatter.
- [ ] Roughly 600 ms of silence returns to idle.
- [ ] Disabling microphone access shows one clear message and leaves the character idle.
- [ ] No audio file is created in the app folder or `%LOCALAPPDATA%\PAPAluLive`.

### Recording

- [ ] OBS Display Capture records the tutorial screen and the floating character.
- [ ] OBS microphone input records the user's voice.
- [ ] No camera window appears.
- [ ] One-minute recording has no visible animation freeze or serious CPU spike.

## Windows source verification

On a Windows development checkout with .NET 10 SDK installed, run:

```powershell
.\realtime-windows\build-windows.ps1
```

Pass criteria: core tests pass, Windows image/store/settings smoke tests pass, package contract passes, and a fresh archive is produced.

## Acceptance result

- [ ] Passed
- [ ] Blocked

Observed blockers and focused fixes should be recorded below before marking Passed.
