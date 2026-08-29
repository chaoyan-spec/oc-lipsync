# 通用悬浮说话角色 V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把现有 PAPAlu 固定 8 帧实时工具升级为默认内置猫咪、保留 PAPAlu、支持单个闭嘴/张嘴自定义角色的通用原生 macOS 悬浮说话角色 App。

**Architecture:** 用能力驱动的 `CharacterDefinition` 和 `CharacterRuntime` 取代固定 8 帧约定；内置猫咪、PAPAlu 和自定义两图角色都生成同一种 Runtime 输入。麦克风、窗口、QuickTime 捕获链路保持独立，自定义素材经本地验证后保存到 Application Support，选择、缩放和位置保存到 UserDefaults。

**Tech Stack:** Swift 5、AppKit、AVFoundation、QuartzCore、Foundation、原生文件系统与 UserDefaults；不增加第三方依赖，不联网。

## Global Constraints

- 支持 macOS 13 及以上，保持当前 Swift + AppKit + AVFoundation 架构。
- 当前猫咪是默认角色和视觉回归基线；不得明显改变其 talking 节奏、idle、思考云或麦克风响应。
- PAPAlu 正式 8 帧继续复用 `public/papalu-talking/frames/`，不得重新生成或修改。
- V1 用户导入仅支持一个自定义槽位和两张 PNG；复杂角色包导入不实现。
- Runtime 不得依赖固定 8 帧、固定帧编号或角色名称。
- 没有 blink、settle 或 thought cloud 的角色必须安全降级。
- 自定义图片只在本机处理，不保存音频、不上传、不联网。
- 原离线 Lip Sync 网页及其测试不得受影响。
- 每项行为变化必须先写失败测试，再写最小实现。

---

## 文件结构

### 新增源码

- `realtime-macos/Sources/PAPAluLive/CharacterDefinition.swift`：角色能力、帧步骤、内置角色配置。
- `realtime-macos/Sources/PAPAluLive/CharacterAssets.swift`：从资源目录加载角色图片并验证引用完整性。
- `realtime-macos/Sources/PAPAluLive/CharacterRuntime.swift`：根据 idle/talking 与角色能力选择当前图片步骤。
- `realtime-macos/Sources/PAPAluLive/CharacterWindow.swift`：通用透明窗口和动画计时器。
- `realtime-macos/Sources/PAPAluLive/CharacterImagePreparer.swift`：两图读取、alpha 检查、共同画布标准化。
- `realtime-macos/Sources/PAPAluLive/CustomCharacterStore.swift`：单个自定义角色保存与恢复。
- `realtime-macos/Sources/PAPAluLive/AppPreferences.swift`：角色选择、窗口位置和缩放持久化。
- `realtime-macos/Sources/PAPAluLive/CharacterSettingsController.swift`：两图导入、提示和麦克风预览面板。

### 新增测试

- `realtime-macos/Tests/PAPAluLiveTests/CharacterDefinitionTests.swift`
- `realtime-macos/Tests/PAPAluLiveTests/CharacterRuntimeTests.swift`
- `realtime-macos/Tests/PAPAluLiveTests/CharacterImagePreparerTests.swift`
- `realtime-macos/Tests/PAPAluLiveTests/CustomCharacterStoreTests.swift`
- `realtime-macos/Tests/PAPAluLiveTests/AppPreferencesTests.swift`
- `realtime-macos/Tests/verify-character-resources.sh`

### 新增正式资源

- `realtime-macos/Resources/Characters/CatMeme/idle.png`
- `realtime-macos/Resources/Characters/CatMeme/talking.png`

### 修改或替换

- `realtime-macos/Sources/PAPAluLive/AppDelegate.swift`
- `realtime-macos/Sources/PAPAluLive/MouthGate.swift`
- `realtime-macos/Sources/PAPAluLive/IdleAnimationPlan.swift`
- 删除 `realtime-macos/Sources/PAPAluLive/PAPAluWindow.swift`，由 `CharacterWindow.swift` 取代。
- `realtime-macos/Tests/PAPAluLiveTests/AppShellCompileTests.swift`
- `realtime-macos/Tests/PAPAluLiveTests/MouthGateTests.swift`
- `realtime-macos/Tests/PAPAluLiveTests/IdleAnimationPlanTests.swift`
- `realtime-macos/Tests/PAPAluLiveTests/main.swift`
- `realtime-macos/run-tests.sh`
- `realtime-macos/build-app.sh`
- `realtime-macos/Resources/Info.plist`
- `realtime-macos/Package.swift`
- `README.md`

---

### Task 1: 建立能力驱动的 Character 数据模型

**Files:**
- Create: `realtime-macos/Sources/PAPAluLive/CharacterDefinition.swift`
- Create: `realtime-macos/Tests/PAPAluLiveTests/CharacterDefinitionTests.swift`
- Modify: `realtime-macos/Tests/PAPAluLiveTests/main.swift`
- Modify: `realtime-macos/run-tests.sh`

**Interfaces:**
- Produces: `CharacterID`、`CharacterFrameStep`、`IdleMotionConfiguration`、`CharacterDefinition`。
- Later tasks consume: `CharacterDefinition.catMeme`、`.papalu` 和 `CharacterDefinition.custom(...)`。

- [ ] **Step 1: 写失败测试，证明模型不依赖固定 8 帧**

```swift
func testCatMemeUsesTwoUniqueAssetsWithoutFakeEightFrameRequirement() throws {
    let cat = CharacterDefinition.catMeme
    try expectEqual(cat.id, .catMeme, "cat id")
    try expectEqual(cat.idleAssetName, "idle", "cat idle")
    try expectEqual(Set(cat.talkingAssetNames), Set(["idle", "talking"]), "cat assets")
    try expectEqual(cat.blinkSteps.isEmpty, true, "cat has no fake blink")
    try expectEqual(cat.thoughtCloudEnabled, true, "cat keeps thought cloud")
}

func testPapaluOwnsItsLegacySequencesInsteadOfRuntime() throws {
    let papalu = CharacterDefinition.papalu
    try expectEqual(papalu.talkingAssetNames, ["2", "1", "3", "4", "6", "3"], "PAPAlu talking")
    try expectEqual(papalu.blinkSteps.map(\.assetName), ["5", "7", "0"], "PAPAlu blink")
    try expectEqual(papalu.settleSteps.map(\.assetName), ["3", "1", "7", "0"], "PAPAlu settle")
}

func testTwoFrameCustomCharacterHasNoOptionalAnimationRequirements() throws {
    let custom = CharacterDefinition.custom(name: "我的角色")
    try expectEqual(custom.talkingAssetNames, ["talking"], "custom talking")
    try expectEqual(custom.blinkSteps.isEmpty, true, "custom blink")
    try expectEqual(custom.settleSteps.isEmpty, true, "custom settle")
    try expectEqual(custom.thoughtCloudEnabled, false, "custom cloud")
}
```

- [ ] **Step 2: 将测试接入 `main.swift` 和 `run-tests.sh`，运行并确认 RED**

Run: `./realtime-macos/run-tests.sh`

Expected: FAIL，提示 `cannot find 'CharacterDefinition' in scope`。

- [ ] **Step 3: 实现最小模型**

```swift
import AppKit

enum CharacterID: String, Codable, Equatable {
    case catMeme
    case papalu
    case custom
}

struct CharacterFrameStep: Equatable {
    let assetName: String
    let duration: Double
}

struct IdleMotionConfiguration: Equatable {
    let horizontalOffset: Double
    let rotationDegrees: Double
    let durationRange: ClosedRange<Double>
    let holdRange: ClosedRange<Double>

    static let gentle = IdleMotionConfiguration(
        horizontalOffset: 4,
        rotationDegrees: 1,
        durationRange: 0.95...1.15,
        holdRange: 0.08...0.25
    )
}

struct CharacterDefinition: Equatable {
    let id: CharacterID
    let name: String
    let idleAssetName: String
    let talkingAssetNames: [String]
    let talkingFramesPerSecond: Double
    let blinkSteps: [CharacterFrameStep]
    let settleSteps: [CharacterFrameStep]
    let blinkDelayRange: ClosedRange<Double>?
    let idleMotion: IdleMotionConfiguration
    let thoughtCloudEnabled: Bool
    let defaultSize: NSSize

    static let catMeme = CharacterDefinition(
        id: .catMeme,
        name: "猫 Meme",
        idleAssetName: "idle",
        talkingAssetNames: ["talking", "idle", "talking", "idle", "talking", "talking"],
        talkingFramesPerSecond: 8,
        blinkSteps: [],
        settleSteps: [
            CharacterFrameStep(assetName: "talking", duration: 0.08),
            CharacterFrameStep(assetName: "idle", duration: 0.08),
        ],
        blinkDelayRange: nil,
        idleMotion: .gentle,
        thoughtCloudEnabled: true,
        defaultSize: NSSize(width: 288, height: 312)
    )

    static let papalu = CharacterDefinition(
        id: .papalu,
        name: "PAPAlu",
        idleAssetName: "0",
        talkingAssetNames: ["2", "1", "3", "4", "6", "3"],
        talkingFramesPerSecond: 8,
        blinkSteps: [
            CharacterFrameStep(assetName: "5", duration: 0.11),
            CharacterFrameStep(assetName: "7", duration: 0.10),
            CharacterFrameStep(assetName: "0", duration: 0.12),
        ],
        settleSteps: ["3", "1", "7", "0"].map {
            CharacterFrameStep(assetName: $0, duration: 0.08)
        },
        blinkDelayRange: 3...5,
        idleMotion: .gentle,
        thoughtCloudEnabled: true,
        defaultSize: NSSize(width: 288, height: 312)
    )

    static func custom(name: String) -> CharacterDefinition {
        CharacterDefinition(
            id: .custom,
            name: name,
            idleAssetName: "idle",
            talkingAssetNames: ["talking"],
            talkingFramesPerSecond: 1,
            blinkSteps: [],
            settleSteps: [],
            blinkDelayRange: nil,
            idleMotion: .gentle,
            thoughtCloudEnabled: false,
            defaultSize: NSSize(width: 288, height: 312)
        )
    }
}
```

- [ ] **Step 4: 运行测试并确认 GREEN**

Run: `./realtime-macos/run-tests.sh`

Expected: 所有现有测试和 3 个新模型测试通过。

- [ ] **Step 5: 提交**

```bash
git add realtime-macos/Sources/PAPAluLive/CharacterDefinition.swift realtime-macos/Tests/PAPAluLiveTests/CharacterDefinitionTests.swift realtime-macos/Tests/PAPAluLiveTests/main.swift realtime-macos/run-tests.sh
git commit -m "feat: define capability-based live characters"
```

---

### Task 2: 建立 CharacterAssets 与纯状态 Runtime

**Files:**
- Create: `realtime-macos/Sources/PAPAluLive/CharacterAssets.swift`
- Create: `realtime-macos/Sources/PAPAluLive/CharacterRuntime.swift`
- Create: `realtime-macos/Tests/PAPAluLiveTests/CharacterRuntimeTests.swift`
- Modify: `realtime-macos/Tests/PAPAluLiveTests/main.swift`
- Modify: `realtime-macos/run-tests.sh`

**Interfaces:**
- Consumes: `CharacterDefinition`。
- Produces: `CharacterAssets(definition:images:)`、`CharacterRuntime.setState(_:)`、`currentAssetName`、`advanceTalkingFrame()`、`settleSteps`、`blinkSteps`。

- [ ] **Step 1: 写失败测试**

```swift
func testRuntimeHandlesSingleTalkingFrame() throws {
    var runtime = CharacterRuntime(definition: .custom(name: "两图角色"))
    runtime.setState(.talking)
    try expectEqual(runtime.currentAssetName, "talking", "single frame talking")
    runtime.advanceTalkingFrame()
    try expectEqual(runtime.currentAssetName, "talking", "single frame loops")
}

func testRuntimeHandlesMultiFrameTalkingSequence() throws {
    var runtime = CharacterRuntime(definition: .papalu)
    runtime.setState(.talking)
    try expectEqual(runtime.currentAssetName, "2", "first frame")
    runtime.advanceTalkingFrame()
    try expectEqual(runtime.currentAssetName, "1", "second frame")
}

func testRuntimeReturnsToCurrentStateWhenCharacterChanges() throws {
    var runtime = CharacterRuntime(definition: .papalu)
    runtime.setState(.talking)
    runtime.setCharacter(.catMeme, currentState: .idle)
    try expectEqual(runtime.state, .idle, "current microphone state wins")
    try expectEqual(runtime.currentAssetName, "idle", "new character idle")
}
```

- [ ] **Step 2: 运行测试并确认 RED**

Run: `./realtime-macos/run-tests.sh`

Expected: FAIL，提示 `CharacterRuntime` 不存在。

- [ ] **Step 3: 实现纯状态 Runtime 和资源容器**

```swift
enum CharacterDisplayState: Equatable {
    case idle
    case talking
}

struct CharacterRuntime {
    private(set) var definition: CharacterDefinition
    private(set) var state: CharacterDisplayState = .idle
    private var talkingIndex = 0

    var currentAssetName: String {
        switch state {
        case .idle: return definition.idleAssetName
        case .talking: return definition.talkingAssetNames[talkingIndex]
        }
    }

    init(definition: CharacterDefinition) {
        precondition(!definition.talkingAssetNames.isEmpty)
        self.definition = definition
    }

    mutating func setState(_ state: CharacterDisplayState) {
        self.state = state
        if state == .talking { talkingIndex = 0 }
    }

    mutating func advanceTalkingFrame() {
        guard state == .talking else { return }
        talkingIndex = (talkingIndex + 1) % definition.talkingAssetNames.count
    }

    mutating func setCharacter(
        _ definition: CharacterDefinition,
        currentState: CharacterDisplayState
    ) {
        self.definition = definition
        talkingIndex = 0
        setState(currentState)
    }
}
```

`CharacterAssets` 必须验证 idle、talking、blink 和 settle 引用的所有 key 都存在：

```swift
enum CharacterAssetError: LocalizedError {
    case missingRequiredImage
    case unreadableImage

    var errorDescription: String? {
        switch self {
        case .missingRequiredImage: return "角色缺少必要图片。"
        case .unreadableImage: return "角色图片无法读取。"
        }
    }
}

struct CharacterAssets {
    let definition: CharacterDefinition
    let images: [String: NSImage]

    init(definition: CharacterDefinition, images: [String: NSImage]) throws {
        let required = Set(
            [definition.idleAssetName]
            + definition.talkingAssetNames
            + definition.blinkSteps.map(\.assetName)
            + definition.settleSteps.map(\.assetName)
        )
        guard required.isSubset(of: Set(images.keys)) else {
            throw CharacterAssetError.missingRequiredImage
        }
        self.definition = definition
        self.images = images
    }

    static func load(
        definition: CharacterDefinition,
        directory: URL
    ) throws -> CharacterAssets {
        let names = Set(
            [definition.idleAssetName]
            + definition.talkingAssetNames
            + definition.blinkSteps.map(\.assetName)
            + definition.settleSteps.map(\.assetName)
        )
        var images: [String: NSImage] = [:]
        for name in names {
            let url = directory.appendingPathComponent("\(name).png")
            guard let image = NSImage(contentsOf: url) else {
                throw CharacterAssetError.unreadableImage
            }
            images[name] = image
        }
        return try CharacterAssets(definition: definition, images: images)
    }
}
```

- [ ] **Step 4: 运行测试并确认 GREEN**

Run: `./realtime-macos/run-tests.sh`

Expected: Runtime 可处理 1 帧和多帧 talking，所有测试通过。

- [ ] **Step 5: 提交**

```bash
git add realtime-macos/Sources/PAPAluLive/CharacterAssets.swift realtime-macos/Sources/PAPAluLive/CharacterRuntime.swift realtime-macos/Tests/PAPAluLiveTests/CharacterRuntimeTests.swift realtime-macos/Tests/PAPAluLiveTests/main.swift realtime-macos/run-tests.sh
git commit -m "feat: add generic character runtime"
```

---

### Task 3: 将窗口从固定帧迁移到 Character Runtime

**Files:**
- Create: `realtime-macos/Sources/PAPAluLive/CharacterWindow.swift`
- Delete: `realtime-macos/Sources/PAPAluLive/PAPAluWindow.swift`
- Modify: `realtime-macos/Sources/PAPAluLive/AppDelegate.swift`
- Modify: `realtime-macos/Sources/PAPAluLive/IdleAnimationPlan.swift`
- Modify: `realtime-macos/Tests/PAPAluLiveTests/IdleAnimationPlanTests.swift`
- Modify: `realtime-macos/Tests/PAPAluLiveTests/AppShellCompileTests.swift`
- Modify: `realtime-macos/run-tests.sh`

**Interfaces:**
- Consumes: `CharacterAssets`、`CharacterRuntime`、`ThoughtCloudPlan`、`WindowScale`。
- Produces: `CharacterWindow.setDisplayState(_:)`、`setCharacter(_:currentState:)`、`setContextMenu(_:)`、缩放和窗口恢复 API。

- [ ] **Step 1: 改写编译契约测试并确认 RED**

```swift
func verifyAppShellContractsCompile() {
    let _: CharacterWindow.Type = CharacterWindow.self
    let _: CharacterRuntime.Type = CharacterRuntime.self
}

func verifyCharacterSwitchCompiles(
    on window: CharacterWindow,
    assets: CharacterAssets
) {
    window.setCharacter(assets, currentState: .talking)
    window.setDisplayState(.idle)
    window.setContextMenu(NSMenu())
}
```

Run: `./realtime-macos/run-tests.sh`

Expected: FAIL，`CharacterWindow` 不存在。

- [ ] **Step 2: 将 idle 计划改为只负责程序微动**

`IdleAnimationPlan` 从角色定义读取 `IdleMotionConfiguration`，不再拥有 base、blink 或 settle 帧编号：

```swift
struct IdleAnimationPlan {
    let configuration: IdleMotionConfiguration

    init(configuration: IdleMotionConfiguration = .gentle) {
        self.configuration = configuration
    }

    func swayStep(
        direction: IdleSwayDirection,
        durationRandomUnit: Double,
        holdRandomUnit: Double
    ) -> IdleSwayStep {
        let sign = direction == .left ? -1.0 : 1.0
        return IdleSwayStep(
            horizontalOffset: sign * configuration.horizontalOffset,
            rotationDegrees: sign * configuration.rotationDegrees,
            duration: map(durationRandomUnit, into: configuration.durationRange),
            holdDuration: map(holdRandomUnit, into: configuration.holdRange)
        )
    }
}
```

- [ ] **Step 3: 实现 `CharacterWindow`**

迁移现有透明窗口、拖动、缩放、idle sway、思考云和计时器。关键变化必须是：

```swift
final class CharacterWindow: NSPanel {
    private var assets: CharacterAssets
    private var runtime: CharacterRuntime

    func setCharacter(
        _ assets: CharacterAssets,
        currentState: CharacterDisplayState
    ) {
        cancelAllAnimation()
        self.assets = assets
        runtime.setCharacter(assets.definition, currentState: currentState)
        applyDefaultAspectRatioWithoutMovingWindowCenter()
        renderCurrentState()
    }

    private func showAsset(named name: String) {
        characterView.image = assets.images[name]
    }

    private func scheduleNextBlink(generation: Int) {
        guard let range = assets.definition.blinkDelayRange,
              !assets.definition.blinkSteps.isEmpty else { return }
        idleBlinkTimer = makeTimer(after: Double.random(in: range)) { [weak self] in
            guard let self,
                  self.runtime.state == .idle,
                  generation == self.idleGeneration else { return }
            self.playFrameSequence(
                self.assets.definition.blinkSteps,
                generation: generation
            ) { [weak self] in
                self?.scheduleNextBlink(generation: generation)
            }
        }
    }

    private func scheduleThoughtCloud(generation: Int) {
        guard assets.definition.thoughtCloudEnabled else { return }
        thoughtCloudDelayTimer = makeTimer(
            after: thoughtCloudPlan.configuration.appearanceDelay
        ) { [weak self] in
            guard let self,
                  self.runtime.state == .idle,
                  generation == self.idleGeneration else { return }
            self.showThoughtCloud(generation: generation)
        }
    }
}
```

初始化器必须逐项保留旧窗口的 `isOpaque = false`、`.clear` 背景、`hasShadow = false`、`.floating`、跨空间、QuickTime `sharingType = .readOnly`、拖动容器和缩放行为；只把输入从 `resourceDirectory` 改为已验证的 `CharacterAssets`，并用 `assets.definition.defaultSize` 代替固定尺寸。`showThoughtCloud`、`hideThoughtCloud`、`layoutThoughtCloud`、`animateCharacter`、`resetCharacterTransform` 和 `makeTimer` 的现有方法体原样迁移，动画 key 从 `papaluIdleSway` 改成 `characterIdleSway`。

所有旧的 `frames[Int]`、固定 `[2,1,3,4,6,3]`、blink 和 settle index 必须从窗口中删除。

`AppDelegate.applicationDidFinishLaunching` 同步迁移到通用窗口接口。此任务只要求编译，正式资源在 Task 4 打包：

```swift
let directory = Bundle.main.resourceURL!
    .appendingPathComponent("Characters/PAPAlu", isDirectory: true)
let assets = try CharacterAssets.load(
    definition: .papalu,
    directory: directory
)
let window = CharacterWindow(assets: assets)
self.window = window
window.setDisplayState(.idle)
window.orderFrontRegardless()
```

- [ ] **Step 4: 运行测试并搜索固定帧残留**

Run:

```bash
./realtime-macos/run-tests.sh
rg -n '0\.\.<8|talkingFrames|frames\[|\[2, 1, 3, 4, 6, 3\]' realtime-macos/Sources/PAPAluLive/CharacterWindow.swift
```

Expected: 测试通过；`rg` 无固定帧匹配。

- [ ] **Step 5: 提交**

```bash
git add realtime-macos/Sources/PAPAluLive/CharacterWindow.swift realtime-macos/Sources/PAPAluLive/AppDelegate.swift realtime-macos/Sources/PAPAluLive/IdleAnimationPlan.swift realtime-macos/Tests/PAPAluLiveTests/IdleAnimationPlanTests.swift realtime-macos/Tests/PAPAluLiveTests/AppShellCompileTests.swift realtime-macos/run-tests.sh
git rm realtime-macos/Sources/PAPAluLive/PAPAluWindow.swift
git commit -m "refactor: drive the live window from character capabilities"
```

---

### Task 4: 正式接入猫咪和 PAPAlu 资源

**Files:**
- Create: `realtime-macos/Resources/Characters/CatMeme/idle.png`
- Create: `realtime-macos/Resources/Characters/CatMeme/talking.png`
- Create: `realtime-macos/Tests/verify-character-resources.sh`
- Modify: `realtime-macos/build-app.sh`
- Modify: `realtime-macos/run-tests.sh`

**Interfaces:**
- Consumes: 已验收猫图 `.worktrees/oc-lipsync/outputs/cat-meme-preview/assets/mouth-closed.png` 和 `mouth-open.png`，现有 PAPAlu `public/papalu-talking/frames/`。
- Produces: App bundle `Contents/Resources/Characters/CatMeme/` 与 `Characters/PAPAlu/`。

- [ ] **Step 1: 先写资源契约测试并确认 RED**

```bash
#!/bin/bash
set -euo pipefail
REALTIME_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$REALTIME_DIR/.." && pwd)"

for asset in idle talking; do
  file="$REALTIME_DIR/Resources/Characters/CatMeme/$asset.png"
  [[ -f "$file" ]]
  [[ "$(sips -g hasAlpha "$file" | awk '/hasAlpha/ {print $2}')" == "yes" ]]
done

for frame in 0 1 2 3 4 5 6 7; do
  [[ -f "$REPO_ROOT/public/papalu-talking/frames/$frame.png" ]]
done
```

Run: `./realtime-macos/Tests/verify-character-resources.sh`

Expected: FAIL，猫咪正式资源不存在。

- [ ] **Step 2: 复制已验收猫咪透明 PNG 到正式资源目录**

```bash
mkdir -p realtime-macos/Resources/Characters/CatMeme
cp outputs/cat-meme-preview/assets/mouth-closed.png realtime-macos/Resources/Characters/CatMeme/idle.png
cp outputs/cat-meme-preview/assets/mouth-open.png realtime-macos/Resources/Characters/CatMeme/talking.png
```

- [ ] **Step 3: 修改构建脚本**

构建脚本输出新的 `outputs/悬浮说话角色.app`，并复制：

```bash
CAT_DIR="$SCRIPT_DIR/Resources/Characters/CatMeme"
PAPALU_DIR="$REPO_ROOT/public/papalu-talking/frames"
CHARACTER_RESOURCES="$CONTENTS/Resources/Characters"

mkdir -p "$CHARACTER_RESOURCES/CatMeme" "$CHARACTER_RESOURCES/PAPAlu"
cp "$CAT_DIR/idle.png" "$CHARACTER_RESOURCES/CatMeme/idle.png"
cp "$CAT_DIR/talking.png" "$CHARACTER_RESOURCES/CatMeme/talking.png"
for frame in 0 1 2 3 4 5 6 7; do
  cp "$PAPALU_DIR/$frame.png" "$CHARACTER_RESOURCES/PAPAlu/$frame.png"
done
```

保留旧 `outputs/PAPAlu实时口型.app`，不要由新构建脚本删除或覆盖。

- [ ] **Step 4: 运行资源与完整测试**

Run:

```bash
./realtime-macos/Tests/verify-character-resources.sh
./realtime-macos/run-tests.sh
```

Expected: 资源契约和全部测试通过。

- [ ] **Step 5: 提交**

```bash
git add realtime-macos/Resources/Characters/CatMeme realtime-macos/Tests/verify-character-resources.sh realtime-macos/build-app.sh realtime-macos/run-tests.sh
git commit -m "feat: add built-in cat and PAPAlu resources"
```

---

### Task 5: 修复通用麦克风门控的底噪释放

**Files:**
- Modify: `realtime-macos/Sources/PAPAluLive/MouthGate.swift`
- Modify: `realtime-macos/Tests/PAPAluLiveTests/MouthGateTests.swift`

**Interfaces:**
- Produces: 集中的 `MouthGateConfiguration.default`，默认 `open 0.012 / close 0.010 / EMA 0.35 / release 0.60`。

- [ ] **Step 1: 写已捕获底噪回归测试**

```swift
func testCapturedNoiseFloorReturnsToIdleAfterSpeech() throws {
    var gate = MouthGate()
    try expectEqual(gate.update(rms: 0.05, duration: step), .talking, "speech")

    var state = MouthState.talking
    for _ in 0..<200 {
        state = gate.update(rms: 0.008, duration: step)
    }

    try expectEqual(state, .idle, "0.008 RMS noise floor must release talking")
}
```

- [ ] **Step 2: 运行并确认 RED**

Run: `./realtime-macos/run-tests.sh`

Expected: FAIL，状态仍是 `talking`。

- [ ] **Step 3: 仅修改集中关闭阈值**

```swift
static let `default` = MouthGateConfiguration(
    openThreshold: 0.012,
    closeThreshold: 0.010,
    smoothingFactor: 0.35,
    releaseDelay: 0.60
)
```

- [ ] **Step 4: 运行全部 MouthGate 回归测试**

Run: `./realtime-macos/run-tests.sh`

Expected: 新底噪测试和连续讲话、句间停顿、软语音、hysteresis 测试全部通过。

- [ ] **Step 5: 提交**

```bash
git add realtime-macos/Sources/PAPAluLive/MouthGate.swift realtime-macos/Tests/PAPAluLiveTests/MouthGateTests.swift
git commit -m "fix: release talking state above the measured noise floor"
```

---

### Task 6: 两图验证、标准化与单个自定义角色存储

**Files:**
- Create: `realtime-macos/Sources/PAPAluLive/CharacterImagePreparer.swift`
- Create: `realtime-macos/Sources/PAPAluLive/CustomCharacterStore.swift`
- Create: `realtime-macos/Tests/PAPAluLiveTests/CharacterImagePreparerTests.swift`
- Create: `realtime-macos/Tests/PAPAluLiveTests/CustomCharacterStoreTests.swift`
- Modify: `realtime-macos/Tests/PAPAluLiveTests/main.swift`
- Modify: `realtime-macos/run-tests.sh`

**Interfaces:**
- Produces: `PreparedCharacterImages`、`CharacterImagePreparer.prepare(idleURL:talkingURL:)`、`CustomCharacterStore.save(_:)`、`load()`。
- Later tasks consume: 已标准化的 `idle.png`、`talking.png` 和 `.custom` definition/assets。

- [ ] **Step 1: 写失败测试**

```swift
func testPreparerRejectsUnreadableInput() throws {
    let preparer = CharacterImagePreparer()
    try expectThrows("unreadable image") {
        _ = try preparer.prepare(
            idleURL: URL(fileURLWithPath: "/missing-idle.png"),
            talkingURL: URL(fileURLWithPath: "/missing-talking.png")
        )
    }
}

func testPreparerBottomCentersDifferentCanvasSizes() throws {
    let idle = try makeTestPNG(size: NSSize(width: 100, height: 200), alpha: true)
    let talking = try makeTestPNG(size: NSSize(width: 160, height: 120), alpha: true)
    let prepared = try CharacterImagePreparer().prepare(idleURL: idle, talkingURL: talking)
    try expectEqual(prepared.canvasSize, NSSize(width: 160, height: 200), "shared canvas")
}

func testStoreRoundTripsOneCustomCharacter() throws {
    let root = try makeTemporaryDirectory()
    let store = CustomCharacterStore(rootDirectory: root)
    try store.save(makePreparedCharacterImages())
    let loaded = try store.load()
    try expectEqual(loaded?.definition.id, .custom, "custom restored")
}
```

- [ ] **Step 2: 运行测试并确认 RED**

Run: `./realtime-macos/run-tests.sh`

Expected: FAIL，preparer 和 store 类型不存在。

- [ ] **Step 3: 实现验证和无损共同画布**

```swift
struct PreparedCharacterImages {
    let idlePNG: Data
    let talkingPNG: Data
    let canvasSize: NSSize
    let warnings: [String]
}

final class CharacterImagePreparer {
    func prepare(idleURL: URL, talkingURL: URL) throws -> PreparedCharacterImages {
        let idle = try loadBitmap(from: idleURL)
        let talking = try loadBitmap(from: talkingURL)
        let canvas = NSSize(
            width: max(idle.pixelsWide, talking.pixelsWide),
            height: max(idle.pixelsHigh, talking.pixelsHigh)
        )
        let warnings = [idle, talking].allSatisfy(\.hasAlpha)
            ? []
            : ["图片没有透明背景，录屏时会保留原背景。"]
        return PreparedCharacterImages(
            idlePNG: try renderBottomCentered(idle, canvas: canvas),
            talkingPNG: try renderBottomCentered(talking, canvas: canvas),
            canvasSize: canvas,
            warnings: warnings
        )
    }
}
```

实现必须使用 `NSBitmapImageRep` 绘制 RGBA PNG；目标 rect 的 x 为 `(canvasWidth - imageWidth) / 2`，y 为 `0`，不得缩放或裁切。

- [ ] **Step 4: 实现 Application Support 单槽存储**

```swift
final class CustomCharacterStore {
    let rootDirectory: URL

    init(rootDirectory: URL = Self.defaultRootDirectory()) {
        self.rootDirectory = rootDirectory
    }

    func save(_ prepared: PreparedCharacterImages) throws {
        try FileManager.default.createDirectory(
            at: rootDirectory,
            withIntermediateDirectories: true
        )
        try prepared.idlePNG.write(to: rootDirectory.appendingPathComponent("idle.png"), options: .atomic)
        try prepared.talkingPNG.write(to: rootDirectory.appendingPathComponent("talking.png"), options: .atomic)
    }

    func load() throws -> CharacterAssets? {
        let idleURL = rootDirectory.appendingPathComponent("idle.png")
        let talkingURL = rootDirectory.appendingPathComponent("talking.png")
        let manager = FileManager.default
        guard manager.fileExists(atPath: idleURL.path),
              manager.fileExists(atPath: talkingURL.path) else { return nil }
        guard let idle = NSImage(contentsOf: idleURL),
              let talking = NSImage(contentsOf: talkingURL) else {
            throw CharacterAssetError.unreadableImage
        }
        return try CharacterAssets(
            definition: .custom(name: "自定义角色"),
            images: ["idle": idle, "talking": talking]
        )
    }

    func loadRequired() throws -> CharacterAssets {
        guard let assets = try load() else {
            throw CharacterAssetError.missingRequiredImage
        }
        return assets
    }
}
```

- [ ] **Step 5: 运行测试并确认 GREEN**

Run: `./realtime-macos/run-tests.sh`

Expected: 无效文件、不同画布、alpha 提示、保存恢复测试全部通过。

- [ ] **Step 6: 提交**

```bash
git add realtime-macos/Sources/PAPAluLive/CharacterImagePreparer.swift realtime-macos/Sources/PAPAluLive/CustomCharacterStore.swift realtime-macos/Tests/PAPAluLiveTests/CharacterImagePreparerTests.swift realtime-macos/Tests/PAPAluLiveTests/CustomCharacterStoreTests.swift realtime-macos/Tests/PAPAluLiveTests/main.swift realtime-macos/run-tests.sh
git commit -m "feat: prepare and persist one custom character"
```

---

### Task 7: 保存角色选择、窗口位置和缩放

**Files:**
- Create: `realtime-macos/Sources/PAPAluLive/AppPreferences.swift`
- Create: `realtime-macos/Tests/PAPAluLiveTests/AppPreferencesTests.swift`
- Modify: `realtime-macos/Sources/PAPAluLive/WindowScale.swift`
- Modify: `realtime-macos/Sources/PAPAluLive/CharacterWindow.swift`
- Modify: `realtime-macos/Tests/PAPAluLiveTests/main.swift`
- Modify: `realtime-macos/run-tests.sh`

**Interfaces:**
- Produces: `AppPreferences.selectedCharacterID`、`windowOrigin`、`windowScaleFactor`。
- CharacterWindow produces: `currentScaleFactor`、`applyScaleFactor(_:)`、`restoreOrigin(_:)`、窗口移动回调。

- [ ] **Step 1: 写失败测试**

```swift
func testPreferencesRoundTripSelectionPositionAndScale() throws {
    let suite = "LiveCharacterTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    let preferences = AppPreferences(defaults: defaults)
    preferences.selectedCharacterID = .papalu
    preferences.windowOrigin = NSPoint(x: 120, y: 240)
    preferences.windowScaleFactor = 1.4

    let restored = AppPreferences(defaults: defaults)
    try expectEqual(restored.selectedCharacterID, .papalu, "selection")
    try expectEqual(restored.windowOrigin, NSPoint(x: 120, y: 240), "origin")
    try expectEqual(restored.windowScaleFactor, 1.4, "scale")
}

func testPreferencesDefaultToCatMeme() throws {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    try expectEqual(AppPreferences(defaults: defaults).selectedCharacterID, .catMeme, "default cat")
}
```

- [ ] **Step 2: 运行并确认 RED**

Run: `./realtime-macos/run-tests.sh`

Expected: FAIL，`AppPreferences` 不存在。

- [ ] **Step 3: 实现最小 UserDefaults 包装**

```swift
final class AppPreferences {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedCharacterID: CharacterID {
        get { CharacterID(rawValue: defaults.string(forKey: "selectedCharacterID") ?? "") ?? .catMeme }
        set { defaults.set(newValue.rawValue, forKey: "selectedCharacterID") }
    }

    var windowScaleFactor: Double {
        get { defaults.object(forKey: "windowScaleFactor") as? Double ?? 1.0 }
        set { defaults.set(newValue, forKey: "windowScaleFactor") }
    }

    var windowOrigin: NSPoint? {
        get {
            guard let value = defaults.string(forKey: "windowOrigin") else { return nil }
            return NSPointFromString(value)
        }
        set { defaults.set(newValue.map(NSStringFromPoint), forKey: "windowOrigin") }
    }
}
```

窗口恢复必须将 origin clamp 到至少一个当前 `NSScreen.visibleFrame`，避免外接屏移除后窗口消失。

- [ ] **Step 4: 运行测试并确认 GREEN**

Run: `./realtime-macos/run-tests.sh`

Expected: 默认猫咪和保存恢复测试全部通过。

- [ ] **Step 5: 提交**

```bash
git add realtime-macos/Sources/PAPAluLive/AppPreferences.swift realtime-macos/Sources/PAPAluLive/WindowScale.swift realtime-macos/Sources/PAPAluLive/CharacterWindow.swift realtime-macos/Tests/PAPAluLiveTests/AppPreferencesTests.swift realtime-macos/Tests/PAPAluLiveTests/main.swift realtime-macos/run-tests.sh
git commit -m "feat: remember character and window placement"
```

---

### Task 8: 增加右键角色菜单和两图设置面板

**Files:**
- Create: `realtime-macos/Sources/PAPAluLive/CharacterSettingsController.swift`
- Modify: `realtime-macos/Sources/PAPAluLive/AppDelegate.swift`
- Modify: `realtime-macos/Sources/PAPAluLive/CharacterWindow.swift`
- Modify: `realtime-macos/Tests/PAPAluLiveTests/AppShellCompileTests.swift`
- Modify: `realtime-macos/run-tests.sh`

**Interfaces:**
- Consumes: built-in `CharacterAssets`、`CustomCharacterStore`、`CharacterImagePreparer`、`AppPreferences`。
- Produces: 右键菜单选择、设置面板、草稿麦克风预览、保存并激活 custom character。

- [ ] **Step 1: 扩充编译契约并确认 RED**

```swift
func verifySettingsControllerCompiles(
    preparer: CharacterImagePreparer,
    store: CustomCharacterStore
) {
    let controller = CharacterSettingsController(preparer: preparer, store: store)
    controller.updateMouthState(.idle)
    controller.onCharacterSaved = { _ in }
}
```

Run: `./realtime-macos/run-tests.sh`

Expected: FAIL，设置控制器接口不存在。

- [ ] **Step 2: 实现原生设置面板**

面板必须包含并只包含以下核心交互：

```swift
final class CharacterSettingsController: NSWindowController {
    var onCharacterSaved: ((CharacterAssets) -> Void)?

    private let preparer: CharacterImagePreparer
    private let store: CustomCharacterStore
    private var prepared: PreparedCharacterImages?
    private var mouthState: MouthState = .idle

    func updateMouthState(_ state: MouthState) {
        mouthState = state
        refreshPreviewImage()
    }

    @objc private func chooseIdleImage() { presentOpenPanel(for: .idle) }
    @objc private func chooseTalkingImage() { presentOpenPanel(for: .talking) }
    @objc private func useCharacter() {
        guard let prepared else { return }
        do {
            try store.save(prepared)
            onCharacterSaved?(try store.loadRequired())
            close()
        } catch {
            showInlineError(error.localizedDescription)
        }
    }
}
```

`NSOpenPanel.allowedContentTypes` 只允许 `.png`。选择任一图片后，只在两张都存在时调用 preparer；错误显示在面板内，不使用崩溃或循环弹窗。无 alpha 只显示警告，不阻止“使用这个角色”。预览图根据 `mouthState` 在已准备的 idle/talking 图之间切换。

- [ ] **Step 3: 在 AppDelegate 建立统一目录和右键菜单**

```swift
private var selectedCharacterID: CharacterID = .catMeme
private var lastMicrophoneState = MouthState.idle

@objc private func selectCatMeme() { selectCharacter(.catMeme) }
@objc private func selectPapalu() { selectCharacter(.papalu) }
@objc private func selectCustom() { selectCharacter(.custom) }
@objc private func openCustomSettings() { settingsController.showWindow(nil) }

private func selectCharacter(_ id: CharacterID) {
    guard let assets = catalog[id] else {
        if id == .custom { openCustomSettings(); return }
        return
    }
    selectedCharacterID = id
    preferences.selectedCharacterID = id
    window?.setCharacter(
        assets,
        currentState: lastMicrophoneState == .talking ? .talking : .idle
    )
    rebuildCharacterMenu()
}
```

右键菜单顺序固定为：猫 Meme、PAPAlu、自定义角色、分隔线、设置自定义角色……。当前角色使用 `.on` 标记。没有有效 custom assets 时点击“自定义角色”直接打开设置面板。

- [ ] **Step 4: 保存窗口移动和缩放**

`CharacterWindow` 在 `windowDidMove`、放大、缩小和重置后，通过闭包把 origin 与 scale 写入 `AppPreferences`。启动时先恢复，再显示窗口。

- [ ] **Step 5: 运行编译契约和全部测试**

Run: `./realtime-macos/run-tests.sh`

Expected: 设置面板、右键选择、原窗口和全部纯逻辑测试通过编译。

- [ ] **Step 6: 提交**

```bash
git add realtime-macos/Sources/PAPAluLive/CharacterSettingsController.swift realtime-macos/Sources/PAPAluLive/AppDelegate.swift realtime-macos/Sources/PAPAluLive/CharacterWindow.swift realtime-macos/Tests/PAPAluLiveTests/AppShellCompileTests.swift realtime-macos/run-tests.sh
git commit -m "feat: add character picker and two-image setup"
```

---

### Task 9: 产品命名、构建契约和文档

**Files:**
- Modify: `realtime-macos/Resources/Info.plist`
- Modify: `realtime-macos/Package.swift`
- Modify: `realtime-macos/build-app.sh`
- Modify: `realtime-macos/Tests/verify-app-icon.sh`
- Modify: `README.md`

**Interfaces:**
- Produces: `outputs/悬浮说话角色.app`，默认猫咪，可选择 PAPAlu 或 custom。

- [ ] **Step 1: 先修改构建契约测试并确认 RED**

`verify-app-icon.sh` 的 App 路径改为：

```bash
APP_ICON="$REPO_ROOT/outputs/悬浮说话角色.app/Contents/Resources/AppIcon.icns"
```

新增构建后断言：

```bash
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$REALTIME_DIR/Resources/Info.plist")" == "悬浮说话角色" ]]
[[ -f "$REPO_ROOT/outputs/悬浮说话角色.app/Contents/Resources/Characters/CatMeme/idle.png" ]]
[[ -f "$REPO_ROOT/outputs/悬浮说话角色.app/Contents/Resources/Characters/PAPAlu/0.png" ]]
```

Run: `./realtime-macos/run-tests.sh`

Expected: FAIL，因为新 App 尚未构建、Info.plist 仍是 PAPAlu 名称。

- [ ] **Step 2: 更新用户可见开发名称和隐私说明**

Info.plist：

```xml
<key>CFBundleDisplayName</key>
<string>悬浮说话角色</string>
<key>CFBundleName</key>
<string>悬浮说话角色</string>
<key>CFBundleIdentifier</key>
<string>com.chaoyan.live-character</string>
<key>NSMicrophoneUsageDescription</key>
<string>麦克风音量仅用于实时驱动悬浮角色口型，不会保存或上传录音。</string>
```

新 bundle identifier 会触发一次新的麦克风权限请求，这是预期行为。

- [ ] **Step 3: 更新构建输出和 README**

README 必须说明：

- 猫咪是默认内置角色。
- 右键可选择猫咪、PAPAlu 或设置自定义角色。
- 自定义角色只需要闭嘴和张嘴两张 PNG。
- 无透明背景会原样显示。
- 图片仅保存在本机，不联网。
- QuickTime 应录制整个屏幕或包含角色的区域。
- PAPAlu 旧离线网页使用方式保持不变。

- [ ] **Step 4: 构建并运行所有自动检查**

Run:

```bash
./realtime-macos/build-app.sh
./realtime-macos/run-tests.sh
npm test
```

Expected: 新 App 生成；原生测试、构建契约和离线网页测试全部通过。

- [ ] **Step 5: 提交**

```bash
git add realtime-macos/Resources/Info.plist realtime-macos/Package.swift realtime-macos/build-app.sh realtime-macos/Tests/verify-app-icon.sh README.md
git commit -m "docs: present the generic live character app"
```

---

### Task 10: 本机运行链路与视觉回归验收

**Files:**
- Verify only; do not add features.

**Interfaces:**
- Consumes: `outputs/悬浮说话角色.app`。
- Produces: 最终测试证据、包体大小、已知限制和用户验收步骤。

- [ ] **Step 1: 检查 App bundle**

Run:

```bash
plutil -lint "outputs/悬浮说话角色.app/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "outputs/悬浮说话角色.app"
du -sh "outputs/悬浮说话角色.app"
```

Expected: plist 和签名有效，记录包体。

- [ ] **Step 2: 启动并验收内置猫咪**

Run: `open "outputs/悬浮说话角色.app"`

人工检查：默认猫咪；说话快速开口；安静约 1 秒闭嘴；idle 微动和思考云与已验收预览一致；拖动和 `Command +/-/0` 正常。

- [ ] **Step 3: 验收 PAPAlu**

右键选择 PAPAlu，检查 talking 多帧、随机 blink、settle、idle 和思考云，确认没有明显视觉回归。

- [ ] **Step 4: 验收自定义角色**

右键“设置自定义角色……”；导入一组同尺寸透明 PNG，再导入一组不同尺寸 PNG；确认预览、讲话、安静、替换图片、重启恢复、位置和缩放恢复均正常。

- [ ] **Step 5: 验收 QuickTime**

录制整个屏幕或同时包含教程窗口和角色的区域 1 分钟；确认猫咪、自定义角色和麦克风声音可同时捕获，摄像头画面不出现。

- [ ] **Step 6: 最终回归与停止**

Run:

```bash
./realtime-macos/run-tests.sh
npm test
git status --short
```

Expected: 所有测试通过；仅保留用户原有未跟踪文件；不继续实现角色包、更多猫咪或设置扩展。
