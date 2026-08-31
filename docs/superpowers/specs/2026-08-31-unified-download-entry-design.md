# Unified Desktop Download Entry Design

## Goal

Provide one permanent public download entry for both Windows and macOS builds of 悬浮说话角色.

## Entry

Use the GitHub Latest Release page as the single user-facing entry:

`https://github.com/chaoyan-spec/oc-lipsync/releases/latest`

The page remains stable while release tags change.

## Assets

Every latest release must contain these stable asset names:

- `PAPAluLive-win-x64.zip`
- `PAPAluLive-macOS.zip`

The current accepted Windows package remains unchanged. The latest accepted macOS App is packaged with `ditto` so the `.app` bundle structure, executable permissions, and macOS resource metadata are preserved.

## Release Presentation

Rename the current release title from Windows-only wording to a cross-platform title. The release notes clearly list the Windows and macOS downloads, explain that each package must be fully extracted before launch, and retain the existing product capability summary.

## Verification

- Verify the macOS ZIP contains one complete `悬浮说话角色.app` bundle.
- Verify both assets are present on the latest release with the exact stable names.
- Verify the public Latest Release page resolves without authentication.
- Keep platform-specific direct links available, while presenting only the release page as the primary entry.

## Non-goals

- No separate download website.
- No automatic operating-system detection.
- No combined cross-platform ZIP.
- No signing, notarization, installer, updater, or changes to application code.
