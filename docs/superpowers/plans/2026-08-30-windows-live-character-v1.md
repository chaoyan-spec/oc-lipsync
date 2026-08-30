# Windows Live Character V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Windows 10/11 x64 WPF version of the validated live character tool that uses the default microphone to drive the existing PAPAlu and cat assets through talking and idle states, and publish a self-contained Windows acceptance ZIP.

**Architecture:** Keep `realtime-macos/` unchanged and add an independent `realtime-windows/` solution. A platform-neutral .NET core library owns MouthGate and animation state; the WPF project owns transparent-window rendering, WASAPI microphone capture, local settings, custom PNG preparation, and Windows publishing. Existing PNGs remain the single source assets and are linked into the Windows build.

**Tech Stack:** C# 14, .NET 10 LTS, WPF, NAudio.Wasapi 3.0.1, System.Text.Json, PowerShell publishing scripts.

## Global Constraints

- Keep the existing macOS app and offline web Lip Sync tool behavior unchanged.
- Target `net10.0-windows10.0.19041.0`, publish `win-x64`, and set `EnableWindowsTargeting=true` for Mac-side compilation.
- Windows 11 is the supported target; Windows 10 22H2 x64 is best-effort compatibility verified on a real machine.
- Use one transparent, borderless, draggable, topmost character window with a taskbar icon and normal exit command.
- Use the default Windows microphone only; do not add a device picker.
- Audio remains memory-only: no WAV creation, upload, network service, speech recognition, or transcription.
- Preserve current default MouthGate constants exactly: open `0.012`, close `0.010`, EMA `0.35`, release delay `0.60s`.
- Reuse all approved PNG assets; do not generate or redraw characters.
- Keep V1 single-character; do not include the multi-cat experiment, camera, gesture detection, or auto-update.
- Do not enable trimming for the first self-contained WPF publish.

---

### Task 1: Add the cross-platform core project and port MouthGate

**Files:**
- Create: `realtime-windows/PAPAluLive.Core/PAPAluLive.Core.csproj`
- Create: `realtime-windows/PAPAluLive.Core/MouthGate.cs`
- Create: `realtime-windows/PAPAluLive.Core.Tests/PAPAluLive.Core.Tests.csproj`
- Create: `realtime-windows/PAPAluLive.Core.Tests/Program.cs`

**Interfaces:**
- Produces: `MouthGateConfiguration.Default`, `MouthGate.Update(double rms, double duration)`, and `MouthState` for the WPF audio pipeline.
- Consumes: no earlier task.

- [ ] **Step 0: Bootstrap a turn-local .NET 10 SDK without modifying the Mac system**

```bash
curl -fsSL https://dot.net/v1/dotnet-install.sh \
  -o /private/tmp/papalu-dotnet-install.sh
bash /private/tmp/papalu-dotnet-install.sh \
  --channel 10.0 \
  --install-dir /private/tmp/papalu-dotnet
PAPALU_DOTNET=/private/tmp/papalu-dotnet
"$PAPALU_DOTNET/dotnet" --version
```

Expected: a `10.0.x` SDK version. Do not install a global SDK or commit the temporary toolchain.

- [ ] **Step 1: Create the projects and write a failing MouthGate test runner**

```xml
<!-- realtime-windows/PAPAluLive.Core/PAPAluLive.Core.csproj -->
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
  </PropertyGroup>
</Project>
```

```xml
<!-- realtime-windows/PAPAluLive.Core.Tests/PAPAluLive.Core.Tests.csproj -->
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
  </PropertyGroup>
  <ItemGroup>
    <ProjectReference Include="../PAPAluLive.Core/PAPAluLive.Core.csproj" />
  </ItemGroup>
</Project>
```

```csharp
// realtime-windows/PAPAluLive.Core.Tests/Program.cs
using PAPAluLive.Core;

var failures = new List<string>();

void Check(string name, bool condition)
{
    if (!condition) failures.Add(name);
}

var gate = new MouthGate();
Check("quiet stays idle", gate.Update(0.001, 0.02) == MouthState.Idle);
Check("loud sample opens immediately", gate.Update(0.03, 0.02) == MouthState.Talking);

for (var index = 0; index < 20; index++)
    gate.Update(0.0, 0.02);
Check("short pause remains talking", gate.State == MouthState.Talking);

for (var index = 0; index < 20; index++)
    gate.Update(0.0, 0.02);
Check("release delay closes", gate.State == MouthState.Idle);

if (failures.Count > 0)
{
    Console.Error.WriteLine(string.Join(Environment.NewLine, failures));
    return 1;
}

Console.WriteLine("PAPAluLive.Core tests passed");
return 0;
```

- [ ] **Step 2: Run the test runner and verify the missing type failure**

Run:

```bash
PAPALU_DOTNET=/private/tmp/papalu-dotnet
"$PAPALU_DOTNET/dotnet" run --project realtime-windows/PAPAluLive.Core.Tests
```

Expected: compile failure because `MouthGate` and `MouthState` do not exist.

- [ ] **Step 3: Implement the exact Mac MouthGate behavior in C#**

```csharp
// realtime-windows/PAPAluLive.Core/MouthGate.cs
namespace PAPAluLive.Core;

public enum MouthState { Idle, Talking }

public sealed record MouthGateConfiguration(
    double OpenThreshold,
    double CloseThreshold,
    double SmoothingFactor,
    double ReleaseDelay)
{
    public static MouthGateConfiguration Default { get; } =
        new(0.012, 0.010, 0.35, 0.60);

    public void Validate()
    {
        if (OpenThreshold <= CloseThreshold || CloseThreshold < 0 ||
            SmoothingFactor is < 0 or > 1 || ReleaseDelay < 0)
            throw new ArgumentOutOfRangeException(nameof(MouthGateConfiguration));
    }
}

public sealed class MouthGate
{
    private readonly MouthGateConfiguration configuration;
    private double smoothedRms;
    private bool hasSample;
    private double quietDuration;

    public MouthState State { get; private set; } = MouthState.Idle;

    public MouthGate(MouthGateConfiguration? configuration = null)
    {
        this.configuration = configuration ?? MouthGateConfiguration.Default;
        this.configuration.Validate();
    }

    public MouthState Update(double rms, double duration)
    {
        var sample = double.IsFinite(rms) ? Math.Max(0, rms) : 0;
        var elapsed = double.IsFinite(duration) ? Math.Max(0, duration) : 0;

        if (hasSample)
            smoothedRms = configuration.SmoothingFactor * sample +
                (1 - configuration.SmoothingFactor) * smoothedRms;
        else
        {
            smoothedRms = sample;
            hasSample = true;
        }

        if (State == MouthState.Idle && sample >= configuration.OpenThreshold)
        {
            State = MouthState.Talking;
            quietDuration = 0;
        }
        else if (State == MouthState.Talking)
        {
            if (smoothedRms < configuration.CloseThreshold)
            {
                quietDuration += elapsed;
                if (quietDuration >= configuration.ReleaseDelay)
                {
                    State = MouthState.Idle;
                    quietDuration = 0;
                }
            }
            else
                quietDuration = 0;
        }

        return State;
    }
}
```

- [ ] **Step 4: Run the core tests**

Run the command from Step 2.

Expected: `PAPAluLive.Core tests passed`.

- [ ] **Step 5: Commit the core gate**

```bash
git add realtime-windows/PAPAluLive.Core realtime-windows/PAPAluLive.Core.Tests
git commit -m "feat(windows): port microphone mouth gate"
```

---

### Task 2: Port character definitions, runtime, idle plan, cloud plan, and scale

**Files:**
- Create: `realtime-windows/PAPAluLive.Core/CharacterDefinition.cs`
- Create: `realtime-windows/PAPAluLive.Core/CharacterRuntime.cs`
- Create: `realtime-windows/PAPAluLive.Core/IdleAnimationPlan.cs`
- Create: `realtime-windows/PAPAluLive.Core/ThoughtCloudPlan.cs`
- Create: `realtime-windows/PAPAluLive.Core/WindowScale.cs`
- Modify: `realtime-windows/PAPAluLive.Core.Tests/Program.cs`

**Interfaces:**
- Produces: `CharacterDefinition`, `CharacterRuntime`, `IdleAnimationPlan`, `ThoughtCloudPlan`, and `WindowScale` used by WPF rendering.
- Consumes: `MouthState` from Task 1 only at the application boundary; the core runtime uses `CharacterDisplayState`.

- [ ] **Step 1: Add failing tests for exact character order and runtime behavior**

Append assertions that require:

```csharp
var catalog = CharacterDefinition.BundledCharacters;
Check("character order", catalog.Select(item => item.Id).SequenceEqual(new[]
{
    CharacterId.CatMeme,
    CharacterId.HuhCat,
    CharacterId.HappyCat,
    CharacterId.ScreamingCat,
    CharacterId.Papalu,
}));

var runtime = new CharacterRuntime(CharacterDefinition.Papalu);
runtime.SetState(CharacterDisplayState.Talking);
Check("talking starts on frame 2", runtime.CurrentAssetName == "2");
runtime.AdvanceTalkingFrame();
Check("talking advances to frame 1", runtime.CurrentAssetName == "1");

var scale = new WindowScale(9);
Check("scale clamps maximum", scale.Factor == 2.0);
scale.Reset();
Check("scale resets", scale.Factor == 1.0);

var cloud = new ThoughtCloudPlan();
Check("cloud wraps dot index", cloud.NextDotIndex(2) == 0);
```

- [ ] **Step 2: Run tests and verify the new types are missing**

Run:

```bash
PAPALU_DOTNET=/private/tmp/papalu-dotnet
"$PAPALU_DOTNET/dotnet" run --project realtime-windows/PAPAluLive.Core.Tests
```

Expected: compile failure naming `CharacterDefinition` first.

- [ ] **Step 3: Implement immutable definitions with the existing frame data**

Use these exact values:

```csharp
public enum CharacterId { CatMeme, HuhCat, HappyCat, ScreamingCat, Papalu, Custom }
public enum CharacterDisplayState { Idle, Talking }
public sealed record FrameStep(string AssetName, TimeSpan Duration);
public sealed record CharacterSize(double Width, double Height);
public sealed record IdleMotionConfiguration(
    double HorizontalOffset,
    double RotationDegrees,
    double MinimumDuration,
    double MaximumDuration,
    double MinimumHold,
    double MaximumHold);
```

`CharacterDefinition.Papalu` must use talking frames `2,1,3,4,6,3`, FPS `8`, blink steps `5/0.11s`, `7/0.10s`, `0/0.12s`, settle steps `3,1,7,0` at `0.08s`, blink delay `3...5s`, cloud enabled, and size `288×312`.

Each two-frame cat must use talking sequence `talking,idle,talking,idle,talking,talking`, FPS `8`, settle `talking/0.08s` then `idle/0.08s`, no blink frames, cloud enabled, and size `288×312`.

- [ ] **Step 4: Implement runtime and deterministic plan calculations**

`CharacterRuntime.SetState(Talking)` resets its talking index to zero. `AdvanceTalkingFrame()` wraps over the active definition. `IdleAnimationPlan.GetStep(direction, durationUnit, holdUnit)` clamps random units to `0...1` and maps them into `0.95...1.15s` and `0.08...0.25s`. `WindowScale` clamps to `0.5...2.0` in `0.1` steps. `ThoughtCloudPlan` copies the Mac normalized frame and alpha constants.

- [ ] **Step 5: Run all core tests and commit**

Expected: `PAPAluLive.Core tests passed`.

```bash
git add realtime-windows/PAPAluLive.Core realtime-windows/PAPAluLive.Core.Tests
git commit -m "feat(windows): port character animation runtime"
```

---

### Task 3: Add the transparent WPF shell and bundled character assets

**Files:**
- Create: `realtime-windows/PAPAluLive.Windows/PAPAluLive.Windows.csproj`
- Create: `realtime-windows/PAPAluLive.Windows/App.xaml`
- Create: `realtime-windows/PAPAluLive.Windows/App.xaml.cs`
- Create: `realtime-windows/PAPAluLive.Windows/MainWindow.xaml`
- Create: `realtime-windows/PAPAluLive.Windows/MainWindow.xaml.cs`
- Create: `realtime-windows/PAPAluLive.Windows/Characters/CharacterAssets.cs`
- Create: `realtime-windows/PAPAluLive.Windows/Characters/CharacterCatalog.cs`
- Create: `realtime-windows/Tests/verify-wpf-shell.sh`

**Interfaces:**
- Consumes: `CharacterDefinition` and `CharacterRuntime` from Tasks 1-2; linked PNG resources from existing Mac/public directories.
- Produces: a compilable WPF executable with one transparent, draggable, topmost character window and resource-loaded PNGs.

- [ ] **Step 1: Write a failing shell contract**

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
XAML="$ROOT/realtime-windows/PAPAluLive.Windows/MainWindow.xaml"
PROJECT="$ROOT/realtime-windows/PAPAluLive.Windows/PAPAluLive.Windows.csproj"

grep -q 'AllowsTransparency="True"' "$XAML"
grep -q 'WindowStyle="None"' "$XAML"
grep -q 'Background="Transparent"' "$XAML"
grep -q 'Topmost="True"' "$XAML"
grep -q '<TargetFramework>net10.0-windows10.0.19041.0</TargetFramework>' "$PROJECT"
grep -q '<EnableWindowsTargeting>true</EnableWindowsTargeting>' "$PROJECT"
echo "WPF shell contract passed"
```

- [ ] **Step 2: Run it and verify failure because the WPF project is absent**

Run: `bash realtime-windows/Tests/verify-wpf-shell.sh`

Expected: non-zero exit for missing `MainWindow.xaml`.

- [ ] **Step 3: Create the WPF project with exact publishing properties**

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>WinExe</OutputType>
    <TargetFramework>net10.0-windows10.0.19041.0</TargetFramework>
    <SupportedOSPlatformVersion>10.0.19041.0</SupportedOSPlatformVersion>
    <UseWPF>true</UseWPF>
    <EnableWindowsTargeting>true</EnableWindowsTargeting>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <RuntimeIdentifier>win-x64</RuntimeIdentifier>
    <SelfContained>true</SelfContained>
    <PublishSingleFile>true</PublishSingleFile>
    <EnableCompressionInSingleFile>true</EnableCompressionInSingleFile>
    <IncludeNativeLibrariesForSelfExtract>true</IncludeNativeLibrariesForSelfExtract>
    <PublishTrimmed>false</PublishTrimmed>
  </PropertyGroup>
  <ItemGroup>
    <ProjectReference Include="../PAPAluLive.Core/PAPAluLive.Core.csproj" />
    <PackageReference Include="NAudio.Wasapi" Version="3.0.1" />
  </ItemGroup>
</Project>
```

Link the four cat pairs and PAPAlu frames as WPF `Resource` items with stable paths under `Resources/Characters/<name>/` rather than copying or moving the source files.

- [ ] **Step 4: Implement the shell and catalog loader**

`MainWindow.xaml` must set the five window properties checked by the contract, `ResizeMode="NoResize"`, `ShowInTaskbar="True"`, and contain a transparent `Grid` with an `Image x:Name="CharacterImage"`. `MainWindow.OnMouseLeftButtonDown` must call `DragMove()` only when the left button is pressed.

`CharacterAssets.LoadBundled(CharacterDefinition)` must create frozen `BitmapImage` instances from pack URIs. `CharacterCatalog.LoadBundled()` returns all five definitions and throws a localized startup error if any required resource is absent.

- [ ] **Step 5: Run contract and cross-target build**

```bash
bash realtime-windows/Tests/verify-wpf-shell.sh
PAPALU_DOTNET=/private/tmp/papalu-dotnet
"$PAPALU_DOTNET/dotnet" build realtime-windows/PAPAluLive.Windows -c Release
```

Expected: `WPF shell contract passed` and `Build succeeded`.

- [ ] **Step 6: Commit the shell**

```bash
git add realtime-windows/PAPAluLive.Windows realtime-windows/Tests/verify-wpf-shell.sh
git commit -m "feat(windows): add transparent WPF character shell"
```

---

### Task 4: Add PCM RMS analysis and WASAPI microphone monitoring

**Files:**
- Create: `realtime-windows/PAPAluLive.Core/PcmRmsCalculator.cs`
- Modify: `realtime-windows/PAPAluLive.Core.Tests/Program.cs`
- Create: `realtime-windows/PAPAluLive.Windows/Audio/MicrophoneMonitor.cs`
- Modify: `realtime-windows/PAPAluLive.Windows/App.xaml.cs`
- Modify: `realtime-windows/PAPAluLive.Windows/MainWindow.xaml.cs`

**Interfaces:**
- Produces: `PcmRmsCalculator.Calculate(...)` and `MicrophoneMonitor.SampleAvailable` events.
- Consumes: NAudio `WasapiCapture.DataAvailable`, `MouthGate.Update`, and `MainWindow.SetDisplayState`.

- [ ] **Step 1: Add failing RMS tests for float32 and PCM16**

```csharp
var floatSamples = new[] { 0.5f, -0.5f, 0.5f, -0.5f };
var floatBytes = new byte[floatSamples.Length * sizeof(float)];
Buffer.BlockCopy(floatSamples, 0, floatBytes, 0, floatBytes.Length);
var floatResult = PcmRmsCalculator.Calculate(
    floatBytes, new AudioFormat(48000, 1, 32, AudioEncoding.IeeeFloat));
Check("float rms", Math.Abs(floatResult.Rms - 0.5) < 0.0001);
Check("float duration", Math.Abs(floatResult.Duration - 4.0 / 48000) < 0.000001);

var pcmSamples = new short[] { 16384, -16384 };
var pcmBytes = new byte[pcmSamples.Length * sizeof(short)];
Buffer.BlockCopy(pcmSamples, 0, pcmBytes, 0, pcmBytes.Length);
var pcmResult = PcmRmsCalculator.Calculate(
    pcmBytes, new AudioFormat(16000, 1, 16, AudioEncoding.Pcm));
Check("pcm16 rms", Math.Abs(pcmResult.Rms - 0.5) < 0.001);
```

- [ ] **Step 2: Run tests and verify `PcmRmsCalculator` is missing**

Run the core test command. Expected: compile failure.

- [ ] **Step 3: Implement format-safe RMS calculation**

Define:

```csharp
public enum AudioEncoding { Pcm, IeeeFloat }
public readonly record struct AudioFormat(
    int SampleRate, int Channels, int BitsPerSample, AudioEncoding Encoding);
public readonly record struct RmsSample(double Rms, double Duration);
public static class PcmRmsCalculator
{
    public static RmsSample Calculate(ReadOnlySpan<byte> bytes, AudioFormat format);
}
```

Support IEEE float32 and PCM 16/24/32 little-endian. Validate sample rate, channels, bit depth, and complete frames. Normalize signed PCM by `2^(bits-1)`, average squares across all channels, and derive duration from complete frames only.

- [ ] **Step 4: Implement `MicrophoneMonitor` using default shared WASAPI capture**

`MicrophoneMonitor.Start()` creates `WasapiCapture`, maps `WaveFormat` or `WaveFormatExtensible` to `AudioFormat`, subscribes to `DataAvailable`, computes RMS, and raises `SampleAvailable` without retaining the buffer. `Stop()` unsubscribes, stops, and disposes exactly once. `RecordingStopped` reports a localized error once.

Dispatch MouthGate state transitions to WPF with `Application.Current.Dispatcher.BeginInvoke`; never update WPF controls from the NAudio capture thread.

- [ ] **Step 5: Run core tests and WPF build**

Expected: core tests pass and WPF build succeeds with no warnings.

- [ ] **Step 6: Commit audio monitoring**

```bash
git add realtime-windows/PAPAluLive.Core realtime-windows/PAPAluLive.Core.Tests realtime-windows/PAPAluLive.Windows
git commit -m "feat(windows): drive mouth state from WASAPI microphone"
```

---

### Task 5: Implement talking, settle, idle sway, thought cloud, menu, scale, and settings

**Files:**
- Create: `realtime-windows/PAPAluLive.Windows/Presentation/CharacterAnimator.cs`
- Create: `realtime-windows/PAPAluLive.Windows/Presentation/ThoughtCloudControl.cs`
- Create: `realtime-windows/PAPAluLive.Windows/Presentation/CharacterMenuBuilder.cs`
- Create: `realtime-windows/PAPAluLive.Windows/Storage/AppSettingsStore.cs`
- Modify: `realtime-windows/PAPAluLive.Windows/MainWindow.xaml`
- Modify: `realtime-windows/PAPAluLive.Windows/MainWindow.xaml.cs`
- Modify: `realtime-windows/PAPAluLive.Core.Tests/Program.cs`

**Interfaces:**
- Produces: visible parity with Mac talking/idle behavior and persisted selection/placement/scale.
- Consumes: Task 2 plans, Task 3 assets, and Task 4 microphone state.

- [ ] **Step 1: Add failing pure tests for sway mapping, cloud geometry, and setting normalization**

Require exact Mac values: ±4 px and ±1 degree, sway duration `0.95...1.15s`, hold `0.08...0.25s`, cloud frame `(0.525,0.725,0.45,0.27)`, dot alpha `1.0/0.35`, and scale `0.5...2.0`.

- [ ] **Step 2: Implement `CharacterAnimator` with cancellable generations**

Every state or character change increments a generation number and stops all prior `DispatcherTimer` and WPF animations. Talking uses the definition FPS and sequence. Idle optionally plays settle steps, then starts alternating sway, schedules random blink only when blink frames exist, and displays the cloud after `0.5s`. A new talking state cancels idle immediately so mouth opening is never blocked by blink or sway.

- [ ] **Step 3: Draw `ThoughtCloudControl` without image assets**

Port the existing white fill, purple outline, two tail circles, cloud Bézier path, and three animated dots into `OnRender(DrawingContext)`. Set `IsHitTestVisible=false`; the cloud must never block dragging or right-click selection.

- [ ] **Step 4: Build the right-click menu and persistence**

The context menu order must be:

1. 猫 Meme
2. Huh 猫
3. Happy 猫
4. 抱头尖叫猫
5. PAPAlu
6. separator
7. 自定义角色
8. 设置自定义角色…
9. separator
10. 放大角色
11. 缩小角色
12. 恢复默认大小
13. 退出

Each built-in item uses a 28×28 idle thumbnail and stores the stable `CharacterId`. `AppSettingsStore` serializes `SelectedCharacterId`, `Left`, `Top`, and `Scale` to `%LOCALAPPDATA%/PAPAluLive/settings.json` using atomic temp-file replacement. Invalid JSON falls back to defaults without deleting the bad file.

- [ ] **Step 5: Run tests and WPF build, then commit**

Expected: core tests pass, shell contract passes, WPF build succeeds.

```bash
git add realtime-windows
git commit -m "feat(windows): add character animation and controls"
```

---

### Task 6: Add custom two-PNG character import and Windows smoke tests

**Files:**
- Create: `realtime-windows/PAPAluLive.Windows/Characters/CharacterImagePreparer.cs`
- Create: `realtime-windows/PAPAluLive.Windows/Characters/CustomCharacterStore.cs`
- Create: `realtime-windows/PAPAluLive.Windows.SmokeTests/PAPAluLive.Windows.SmokeTests.csproj`
- Create: `realtime-windows/PAPAluLive.Windows.SmokeTests/Program.cs`
- Modify: `realtime-windows/PAPAluLive.Windows/MainWindow.xaml.cs`
- Modify: `realtime-windows/PAPAluLive.Windows/Presentation/CharacterMenuBuilder.cs`

**Interfaces:**
- Produces: local `idle.png` and `talking.png` on one bottom-centered transparent canvas plus a Windows-only smoke-test executable.
- Consumes: WPF `BitmapDecoder`, `DrawingVisual`, `RenderTargetBitmap`, and `PngBitmapEncoder`.

- [ ] **Step 1: Write a Windows smoke test that creates mismatched in-memory PNGs**

Create a 100×120 red test bitmap and an 80×140 blue test bitmap, pass them to `CharacterImagePreparer`, and assert both outputs decode to 100×140. Assert the 80-pixel image is horizontally centered and both drawings touch the bottom baseline. Save only under the test temporary directory and delete it in `finally`.

- [ ] **Step 2: Run the smoke test on Windows and verify the preparer is missing**

Run:

```powershell
dotnet run --project realtime-windows/PAPAluLive.Windows.SmokeTests
```

Expected: compile failure naming `CharacterImagePreparer`.

- [ ] **Step 3: Implement image preparation and storage**

Decode PNGs with `BitmapCacheOption.OnLoad`, preserve native pixels without stretching, create a canvas using maximum width and height, draw each source at `x=(canvasWidth-sourceWidth)/2`, `y=canvasHeight-sourceHeight`, and encode PNG with alpha. Return the warning `图片没有透明背景，录屏时会保留原背景。` if either source lacks alpha.

Save atomically to `%LOCALAPPDATA%/PAPAluLive/CustomCharacter/idle.png` and `talking.png`. Never overwrite an existing valid pair until both new outputs are successfully encoded.

- [ ] **Step 4: Connect “设置自定义角色…” to two file pickers**

Open the closed-mouth picker first and the talking picker second, both restricted to `.png`. Cancellation at either step makes no changes. Success immediately loads the custom character using the current live talking/idle state and refreshes the menu checkmark.

- [ ] **Step 5: Run Windows smoke tests and commit**

Expected: `PAPAluLive Windows smoke tests passed`.

```bash
git add realtime-windows
git commit -m "feat(windows): import custom two-frame characters"
```

---

### Task 7: Add self-contained publishing, documentation, and regressions

**Files:**
- Create: `realtime-windows/build-windows.ps1`
- Create: `realtime-windows/verify-windows-package.ps1`
- Create: `realtime-windows/README.md`
- Modify: `.gitignore`
- Modify: `README.md`

**Interfaces:**
- Produces: `outputs/windows/悬浮说话角色-win-x64.zip` and an explicit acceptance guide.
- Consumes: the completed WPF project and Windows PowerShell/.NET 10 SDK.

- [ ] **Step 1: Write the package verifier before the publisher**

`verify-windows-package.ps1` takes a publish directory, requires `PAPAluLive.Windows.exe`, rejects `.wav`, `.m4a`, `.mp3`, or camera assets, checks that the executable is non-empty, and prints `Windows package contract passed`.

- [ ] **Step 2: Run it against an empty directory and verify failure**

Expected: non-zero exit with `Missing PAPAluLive.Windows.exe`.

- [ ] **Step 3: Implement deterministic self-contained publishing**

`build-windows.ps1` must:

1. Require .NET SDK 10.
2. Run the core test console.
3. Run the Windows smoke-test console.
4. Publish `PAPAluLive.Windows.csproj` with `-c Release -r win-x64 --self-contained true`.
5. Run `verify-windows-package.ps1`.
6. Zip the publish folder to `outputs/windows/悬浮说话角色-win-x64.zip`.
7. Print the final path and byte size.

- [ ] **Step 4: Document the exact Windows user path**

The Windows README must say:

1. Extract the ZIP.
2. Double-click `PAPAluLive.Windows.exe`.
3. If the mic is idle, enable “允许桌面应用访问麦克风”.
4. Right-click the character to switch, resize, import, or exit.
5. Use OBS “显示器采集”; do not promise Window Capture includes the overlay.
6. Audio is not saved or uploaded.

- [ ] **Step 5: Run all available Mac-side and repository regressions**

```bash
PAPALU_DOTNET=/private/tmp/papalu-dotnet
"$PAPALU_DOTNET/dotnet" run --project realtime-windows/PAPAluLive.Core.Tests
"$PAPALU_DOTNET/dotnet" build realtime-windows/PAPAluLive.Windows -c Release
bash realtime-windows/Tests/verify-wpf-shell.sh
bash realtime-macos/run-tests.sh
npm test
git diff --check
```

Expected: all core tests, Windows build/contracts, 41 macOS tests/contracts, and 78 offline tests pass.

- [ ] **Step 6: Commit packaging and docs**

```bash
git add realtime-windows README.md .gitignore
git commit -m "build(windows): publish live character acceptance package"
```

---

### Task 8: Run real Windows 10/11 acceptance and record results

**Files:**
- Create: `docs/testing/windows-live-character-v1-acceptance.md`
- Modify only the Windows implementation files implicated by observed defects.

**Interfaces:**
- Produces: an evidence-backed Windows V1 acceptance result and any minimal fixes required for the real recording chain.
- Consumes: `outputs/windows/悬浮说话角色-win-x64.zip` from Task 7 and the user's real Windows x64 machine.

- [ ] **Step 1: Transfer and run the acceptance ZIP on the real Windows PC**

Record Windows edition/build, DPI scale, microphone type, archive size, extracted size, startup time, and whether SmartScreen appears.

- [ ] **Step 2: Verify the character behavior**

Check transparent background, no border/shadow, topmost behavior, dragging, scale persistence, all five built-in characters, one custom pair, idle sway, PAPAlu blink, thought cloud, and normal exit.

- [ ] **Step 3: Verify the microphone behavior**

Speak continuously for one minute, include normal syllable pauses, then stay quiet for ten seconds. Pass criteria: fast opening, no mid-sentence false idle, natural release after roughly `0.60s`, no generated audio file, and useful error text when desktop mic permission is disabled.

- [ ] **Step 4: Verify the real recording path**

Record one minute with OBS Display Capture. Pass criteria: tutorial screen, voice, and transparent character are all visible/audible; the hidden camera and any settings dialogs are not present.

- [ ] **Step 5: Fix only acceptance blockers and rerun the smallest affected tests**

Do not add new features. For every blocker, record symptom, cause, changed file, focused test, and re-test result in the acceptance document.

- [ ] **Step 6: Run final full verification and commit acceptance evidence**

Run all commands from Task 7 Step 5 plus `build-windows.ps1` on Windows. Commit only after all automated checks and the real recording chain pass.

```bash
git add docs/testing/windows-live-character-v1-acceptance.md realtime-windows
git commit -m "test(windows): verify live character recording workflow"
```
