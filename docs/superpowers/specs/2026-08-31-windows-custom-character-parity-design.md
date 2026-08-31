# Windows Custom Character Parity Design

## Goal

Bring the Windows WPF build to feature parity with the Mac custom-character behavior that has already passed acceptance, without changing the existing Windows architecture or bundled-character behavior.

## Scope

- Custom two-frame characters use the same 8 fps speech cadence as bundled two-frame cats: `talking, idle, talking, idle, talking, talking`.
- Custom characters retain the existing gentle idle sway and now show the existing thought cloud while idle.
- The right-click menu gains `删除自定义角色…`.
- Deletion requires confirmation, removes only the App-managed copies under `%LocalAppData%\PAPAluLive\CustomCharacter`, never touches the original imported PNG files, and falls back to Cat Meme if the deleted custom character is active.
- The delete action is disabled when no custom character exists.
- Previously fixed Windows thought-cloud placement and complete 32×32 character thumbnails remain unchanged.

## Approach

Use the existing Windows boundaries directly:

- `CharacterDefinition.Custom()` owns the custom character's animation cadence and idle-effect flags.
- `CustomCharacterStore` owns deletion of the App-managed imported asset directory.
- `CharacterMenuBuilder` owns the delete command and enabled state.
- `MainWindow` owns confirmation, error reporting, active-character fallback, and settings persistence.

This is preferred over introducing a shared cross-platform configuration layer because the latter would turn a small parity update into a broader refactor. Updating only deletion would leave the Windows visual behavior behind Mac, while rebuilding the menu or storage layer would add risk without user benefit.

## Data Flow

When a custom character is selected, microphone state continues to drive the existing runtime. Talking advances through the six-step two-frame sequence at 8 fps. Idle uses the existing gentle whole-image sway and thought cloud.

On deletion, the window asks for confirmation. If confirmed, the store removes its own custom-character directory. The in-memory custom assets are then cleared, the menu entry and delete command are disabled, and an active custom character switches to Cat Meme using the current microphone state. If disk deletion fails, the active state remains unchanged and the user receives an error message.

## Testing

- Core tests verify custom cadence, frame order, idle sway flag, and thought-cloud flag.
- Windows smoke tests verify store deletion and idempotent repeated deletion.
- The WPF shell contract verifies the delete menu, enabled-state synchronization, and deletion handler wiring.
- Cross-build the Windows WPF smoke project on macOS and produce a self-contained `win-x64` package for real Windows acceptance.

## Non-goals

- No new character formats, settings panel, multiple custom characters, recycle bin, undo, cloud animation redesign, or cross-platform refactor.
- No changes to the Mac build in this task.
