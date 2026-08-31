# Separate macOS Architecture Packages Design

## Goal

Publish two clearly named macOS downloads so Apple Silicon and Intel users can select the correct build without downloading an unused architecture.

## Distribution

The GitHub Latest Release page remains the permanent public entry:

`https://github.com/chaoyan-spec/oc-lipsync/releases/latest`

The macOS assets are:

- `PAPAluLive-macOS-Apple-Silicon.zip` containing an `arm64` executable.
- `PAPAluLive-macOS-Intel.zip` containing an `x86_64` executable.

The existing `PAPAluLive-win-x64.zip` remains unchanged. The ambiguous `PAPAluLive-macOS.zip` is removed after both replacement assets are verified.

## Build Design

`realtime-macos/build-app.sh` accepts one explicit architecture argument: `arm64` or `x86_64`. It maps that argument to the matching macOS 13 Swift target and writes to an architecture-specific App output path, preventing the second build from overwriting the first.

Both builds use the same Swift/AppKit/AVFoundation source, character assets, Info.plist, icon, ad-hoc signing, and minimum macOS version. No Universal binary is produced.

## Verification

- A shell contract rejects unsupported architecture values and verifies both supported target triples and output names exist in the build script.
- Existing macOS tests and contracts continue to pass.
- Each built executable is checked with `lipo -info` and `file` before packaging.
- Each ZIP is tested with `unzip -t`, unpacked, and its contained executable architecture is checked again.
- GitHub Release API must show the Windows asset and both exact macOS asset names.
- All three stable direct-download URLs and the Latest Release page must resolve publicly.

## Non-goals

- No Universal 2 package.
- No application behavior changes.
- No installer, signing certificate, notarization, auto-update, or download website.
- No changes to the accepted Windows package.
