# PAPAlu RMS-Calibrated Gate Fix Implementation Plan

**Goal:** Keep PAPAlu talking across the low-RMS syllables observed on the user's actual microphone while retaining real idle detection.

**Architecture:** Preserve the existing audio and rendering pipeline. Protect the approved default gate values with unit tests, add one regression sequence copied from the numeric diagnostic trace, then remove all temporary diagnostic logging.

### Task 1: Reproduce the real trace failure

- Update `MouthGateTests.swift` with the approved defaults and the RMS sequence that previously changed to idle at its final sample.
- Verify the old defaults fail the new test.

### Task 2: Apply the calibrated defaults

- Update only `MouthGateConfiguration.default` to `0.012 / 0.006 / 0.60`.
- Update README timing language.
- Verify all native tests pass.

### Task 3: Remove diagnostics and deliver

- Remove environment-controlled RMS logging from `AppDelegate.swift` and `MicrophoneMonitor.swift`.
- Delete `/tmp/papalu-rms-diagnostic.log` after analysis.
- Run native and web regressions, build, synchronize, and launch the formal app.

**Stop condition:** Do not add adaptive thresholds or unrelated animation changes.
