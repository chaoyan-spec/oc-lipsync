# PAPAlu App Icon and Installation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a recognizable PAPAlu macOS icon from the approved frame 0, wire it into the app bundle, and install the app at `/Applications/PAPAlu 实时口型.app`.

**Architecture:** A small Swift/AppKit generator draws the complete approved PAPAlu frame on a white rounded-square background and emits a 1024px PNG. A shell wrapper creates the required iconset and `AppIcon.icns`; the existing app builder packages that ICNS and the plist declares it. A shell contract test verifies the assets and built bundle before installation.

**Tech Stack:** Swift 5, AppKit, `sips`, `iconutil`, Bash, macOS App Bundle metadata.

## Global Constraints

- The only character source is `public/papalu-talking/frames/0.png`.
- Do not redraw or modify PAPAlu's face, hair, clothes, or proportions.
- Keep bundle identifier `com.chaoyan.papalu-live`.
- Do not change microphone, mouth gate, idle, thought cloud, or floating-window behavior.
- Install only to `/Applications/PAPAlu 实时口型.app`.
- Do not add an installer, auto-update system, signing, or notarization.

---

### Task 1: Generate, package, install, and verify the PAPAlu app icon

**Files:**
- Create: `realtime-macos/generate-app-icon.swift`
- Create: `realtime-macos/generate-app-icon.sh`
- Create: `realtime-macos/Resources/AppIcon-1024.png`
- Create: `realtime-macos/Resources/AppIcon.icns`
- Create: `realtime-macos/Tests/verify-app-icon.sh`
- Modify: `realtime-macos/Resources/Info.plist`
- Modify: `realtime-macos/build-app.sh`
- Modify: `realtime-macos/run-tests.sh`
- Modify: `README.md`

**Interfaces:**
- Consumes: approved PNG at `public/papalu-talking/frames/0.png`.
- Produces: `AppIcon-1024.png`, `AppIcon.icns`, and a built app whose `CFBundleIconFile` is `AppIcon.icns`.

- [ ] **Step 1: Write the failing icon bundle contract test**

Create `realtime-macos/Tests/verify-app-icon.sh` to assert that the master PNG is 1024×1024, `AppIcon.icns` can be expanded by `iconutil`, the plist declares `AppIcon.icns`, and a built app contains `Contents/Resources/AppIcon.icns`.

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REALTIME_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$REALTIME_DIR/.." && pwd)"
MASTER_ICON="$REALTIME_DIR/Resources/AppIcon-1024.png"
ICNS_ICON="$REALTIME_DIR/Resources/AppIcon.icns"
APP_ICON="$REPO_ROOT/outputs/PAPAlu实时口型.app/Contents/Resources/AppIcon.icns"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/papalu-icon-test.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT

[[ -f "$MASTER_ICON" ]]
[[ "$(sips -g pixelWidth "$MASTER_ICON" | awk '/pixelWidth/ {print $2}')" == "1024" ]]
[[ "$(sips -g pixelHeight "$MASTER_ICON" | awk '/pixelHeight/ {print $2}')" == "1024" ]]
[[ -f "$ICNS_ICON" ]]
iconutil -c iconset "$ICNS_ICON" -o "$TEMP_DIR/AppIcon.iconset"
[[ -f "$TEMP_DIR/AppIcon.iconset/icon_512x512@2x.png" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$REALTIME_DIR/Resources/Info.plist")" == "AppIcon.icns" ]]
[[ -f "$APP_ICON" ]]
cmp -s "$ICNS_ICON" "$APP_ICON"

echo "PAPAlu app icon contract passed"
```

- [ ] **Step 2: Run the contract test and verify RED**

Run: `bash realtime-macos/Tests/verify-app-icon.sh`

Expected: FAIL because `Resources/AppIcon-1024.png` and `Resources/AppIcon.icns` do not exist.

- [ ] **Step 3: Add the minimal reproducible icon generator**

Create `generate-app-icon.swift` using AppKit. It must load the first frame, create a 1024×1024 transparent bitmap, draw a white rounded rectangle, and draw the complete source rectangle `(0, 0, 192, 208)` into destination rectangle `(152, 112, 720, 780)` without changing the character artwork.

```swift
import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("usage: generate-app-icon <frame-0.png> <output.png>\n", stderr)
    exit(2)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    fputs("Unable to load PAPAlu frame 0\n", stderr)
    exit(1)
}
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: 1024,
    pixelsHigh: 1024,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Unable to create icon bitmap\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()
NSColor.white.setFill()
NSBezierPath(
    roundedRect: NSRect(x: 48, y: 48, width: 928, height: 928),
    xRadius: 220,
    yRadius: 220
).fill()
sourceImage.draw(
    in: NSRect(x: 152, y: 112, width: 720, height: 780),
    from: NSRect(x: 0, y: 0, width: 192, height: 208),
    operation: .sourceOver,
    fraction: 1,
    respectFlipped: false,
    hints: [.interpolation: NSImageInterpolation.high]
)
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to encode icon PNG\n", stderr)
    exit(1)
}
try png.write(to: outputURL, options: .atomic)
```

Create `generate-app-icon.sh` to compile the Swift generator into a temporary executable, write `Resources/AppIcon-1024.png`, generate the ten standard iconset PNG entries with `sips`, and convert the iconset to `Resources/AppIcon.icns` with `iconutil`.

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_FRAME="$REPO_ROOT/public/papalu-talking/frames/0.png"
MASTER_ICON="$SCRIPT_DIR/Resources/AppIcon-1024.png"
ICNS_ICON="$SCRIPT_DIR/Resources/AppIcon.icns"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/papalu-icon-build.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT

xcrun swiftc -framework AppKit "$SCRIPT_DIR/generate-app-icon.swift" -o "$TEMP_DIR/generate-app-icon"
"$TEMP_DIR/generate-app-icon" "$SOURCE_FRAME" "$MASTER_ICON"

ICONSET="$TEMP_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"
for entry in \
    '16 icon_16x16.png' \
    '32 icon_16x16@2x.png' \
    '32 icon_32x32.png' \
    '64 icon_32x32@2x.png' \
    '128 icon_128x128.png' \
    '256 icon_128x128@2x.png' \
    '256 icon_256x256.png' \
    '512 icon_256x256@2x.png' \
    '512 icon_512x512.png' \
    '1024 icon_512x512@2x.png'; do
    size="${entry%% *}"
    name="${entry#* }"
    sips -z "$size" "$size" "$MASTER_ICON" --out "$ICONSET/$name" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$ICNS_ICON"
```

Run: `bash realtime-macos/generate-app-icon.sh`

Expected: both icon resources are created, `AppIcon-1024.png` is 1024×1024, and `AppIcon.icns` is readable by `iconutil`.

- [ ] **Step 4: Wire the icon into the app bundle**

Add to `realtime-macos/Resources/Info.plist`:

```xml
<key>CFBundleIconFile</key>
<string>AppIcon.icns</string>
```

Update `build-app.sh` to fail when `Resources/AppIcon.icns` is missing and copy it to `Contents/Resources/AppIcon.icns` before the staged app is moved into `outputs/`.

```bash
ICON_FILE="$SCRIPT_DIR/Resources/AppIcon.icns"
if [[ ! -f "$ICON_FILE" ]]; then
  echo "Missing PAPAlu app icon: $ICON_FILE" >&2
  exit 1
fi
# After copying Info.plist:
cp "$ICON_FILE" "$CONTENTS/Resources/AppIcon.icns"
```

Append the icon contract test to `run-tests.sh` after the app-shell and camera-removal checks.

```bash
"$SCRIPT_DIR/Tests/verify-app-icon.sh"
```

- [ ] **Step 5: Build and verify GREEN**

Run:

```bash
cd realtime-macos
./build-app.sh
cd ..
./realtime-macos/run-tests.sh
```

Expected: all Swift tests pass, app-shell compilation passes, camera-removal verification passes, and `PAPAlu app icon contract passed` is printed.

- [ ] **Step 6: Update the user-facing launch instructions**

Update `README.md` to state that the installed app lives at `/Applications/PAPAlu 实时口型.app`, can be launched via Spotlight or Launchpad, and can be closed by right-clicking its Dock icon and choosing Quit or focusing PAPAlu and pressing Command-Q.

```markdown
安装后，PAPAlu 位于 `/Applications/PAPAlu 实时口型.app`。可以在 Spotlight 或启动台搜索“PAPAlu 实时口型”启动。关闭时可右键 Dock 中的 PAPAlu 图标选择“退出”，或先聚焦 PAPAlu 再按 `Command-Q`。
```

- [ ] **Step 7: Install only the named app and smoke-test it**

Stop the running `PAPAluLive` process, copy the verified bundle to `/Applications/PAPAlu 实时口型.app` with `ditto`, launch that installed bundle, and verify:

```bash
/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' '/Applications/PAPAlu 实时口型.app/Contents/Info.plist'
test -f '/Applications/PAPAlu 实时口型.app/Contents/Resources/AppIcon.icns'
pgrep -x PAPAluLive
```

Expected: plist prints `AppIcon.icns`, the icon exists, and `PAPAluLive` has a running PID.

- [ ] **Step 8: Commit the implementation**

```bash
git add README.md realtime-macos
git commit -m "feat: add PAPAlu app icon and installation"
```
