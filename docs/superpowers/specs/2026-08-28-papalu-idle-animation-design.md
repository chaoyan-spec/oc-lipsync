# PAPAlu Idle Animation V1.x Design

## Goal

Validate one product hypothesis: when PAPAlu is not speaking, a restrained,
irregular idle animation using only the approved eight talking frames makes the
character feel continuously present instead of becoming a static sticker.

## Scope

Keep the existing microphone talking/idle detection, camera wave detection,
`teaching` temporary action, window scaling, and offline Lip Sync tool intact.
Add only idle visual scheduling and a short talking-to-idle visual transition.

Do not add assets, gestures, settings, layers, skeletons, semantic detection,
speech recognition, or any other animation state.

## Approved Assets

- Frame `0`: primary closed-mouth resting pose.
- Frame `7`: secondary closed-mouth pose with a slight body/hair variation.
- Frame `5`: existing approved blink pose; display only briefly because its
  mouth is slightly parted.
- Frames `3` and `1`: small-mouth talking poses used only for the visual
  talking-to-idle close-down transition.
- Frames `2`, `4`, and `6` remain part of the existing talking animation and
  are not added to the idle loop.

No image is generated, edited, duplicated, or replaced.

## Visual State Priority

1. `teaching` temporary action
2. `talking`
3. animated `idle`

The existing `ActionCoordinator` remains responsible for choosing the display
state. The window owns only the animation appropriate to that selected state.

## Idle Rhythm

Idle is event-based rather than a permanent fixed GIF loop.

- Most idle time displays frame `0`.
- A breath event occurs after a random delay from `2.8` to `4.8` seconds:
  frame `0` -> frame `7` -> frame `0`, lasting approximately `500` to `650ms`.
- A blink event occurs after a random delay from `5.5` to `9.0` seconds:
  frame `0` -> frame `5` -> frame `7` -> frame `0`; frame `5` is visible for
  approximately `100` to `120ms`.
- Breath and blink events never overlap. If their deadlines collide, blink has
  priority and the breath is rescheduled.
- All timing constants and frame sequences live in one configuration rather
  than being scattered through UI code.

## State Transitions

### Talking to idle

When the microphone base state changes from talking to idle, the window plays:

`3 -> 1 -> 7 -> 0`

The complete close-down lasts approximately `280` to `320ms`. It is a visual
settling transition only; it does not change `MouthGate` timing or state.

### Idle to talking

Talking has immediate priority. As soon as `MouthGate` reports talking, all
idle timers and any close-down transition are cancelled before the first
talking frame is displayed. Idle must add no audio-response delay.

### Teaching coordination

A wave from idle or talking still enters `teaching` immediately. Entering
`teaching` cancels idle and talking timers. After `0.8` seconds, the existing
coordinator reads the current microphone base state:

- currently talking -> resume talking
- currently quiet -> enter animated idle

It must not restore a cached state from before the wave.

## Architecture

Add a small pure `IdleAnimationPlan` component containing frame sequences,
timing ranges, and deterministic interval mapping for tests. `PAPAluWindow`
uses this plan to schedule one-shot timers on the main run loop. A generation
token or equivalent cancellation guard prevents stale timer callbacks from
changing images after the display state has moved to talking or teaching.

`MouthGate`, `WaveDetector`, and camera capture logic are not changed.

## Testing

Add deterministic tests for:

- idle planning includes closed-mouth breathing variation instead of only
  permanent frame `0`
- breath and blink delays remain inside their approved random ranges
- blink uses frame `5` briefly and returns to a closed frame
- talking-to-idle uses the approved close-down sequence and duration
- state priority still returns from teaching to the current talking or idle
  base state
- existing MouthGate and WaveDetector tests remain unchanged and pass
- the existing offline Lip Sync build and test suite remain unchanged and pass

The app-shell compile test continues to cover the AppKit integration. Final
manual validation checks immediate idle-to-talking interruption, restrained
idle motion, wave/teaching return behavior, QuickTime capture, and CPU impact.

## Acceptance Criteria

- Ten seconds of silence show occasional subtle breathing and an irregular
  blink rather than a permanently static frame.
- Stopping speech produces a short visual close-down before idle.
- Starting speech interrupts idle immediately with no perceptible new delay.
- Wave detection and teaching behavior remain unchanged.
- No new PAPAlu asset is created or modified.
- No camera action or product feature outside idle is added.
- Package size is effectively unchanged and idle adds no meaningful sustained
  CPU load.

