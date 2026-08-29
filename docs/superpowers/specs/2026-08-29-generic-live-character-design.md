# 通用悬浮说话角色 V1 设计

日期：2026-08-29

## 目标

把当前面向 PAPAlu 的原生 macOS 实时口型工具，最小必要地通用化为一个服务“不想真人出镜”的创作者的轻量悬浮说话角色工具。

V1 必须支持两条真实使用链路：

1. 打开 App，直接选择已验收的内置猫咪，通过麦克风驱动口型并使用 QuickTime 录屏。
2. 导入一张闭嘴 PNG 和一张张嘴 PNG，不修改代码即可得到一个可拖动、可缩放、可被 QuickTime 捕获的自定义说话角色。

Runtime 从本轮开始支持 PAPAlu 级多帧角色能力，但 V1 用户界面只开放两图自定义导入。复杂角色包、ZIP 或 manifest 导入留到后续阶段。

## 当前真实状态审计

### 已经通用的能力

- `MicrophoneMonitor` 只负责 AVFoundation 麦克风采样和 RMS 计算，与角色无关。
- `MouthGate` 只负责 RMS、EMA、hysteresis 和 release delay，与角色图像无关。
- 透明、无边框、浮动、跨桌面空间、QuickTime 可捕获的窗口能力与角色无关。
- 拖动、缩放、窗口层级、Command-Q 与角色无关。
- `ThoughtCloudView` 的绘制逻辑可以复用，但是否启用应由角色配置决定。

### 仍然写死 PAPAlu 的部分

- 核心窗口类型名是 `PAPAluWindow`。
- `PAPAluDisplayState`、错误提示、菜单文案和产品名称仍带有 PAPAlu。
- Runtime 启动时固定读取 `Resources/Frames/0.png...7.png`。
- talking 固定使用 `[2, 1, 3, 4, 6, 3]`。
- blink 固定使用 `[5, 7, 0]`。
- settle 固定使用 `[3, 1, 7, 0]`。
- `build-app.sh` 固定从 `public/papalu-talking/frames/` 复制 8 张图片。
- 默认尺寸和动画节奏由 PAPAlu 当前素材决定，没有角色级覆盖。

### 当前猫咪的接入方式

猫咪目前不是源码级 built-in character。当前预览 App 是复制 PAPAlu App 后，将 8 个资源槽位映射成两张猫图：

- 闭嘴图占用旧的 `0、1、4、5、7` 槽位。
- 张嘴图占用旧的 `2、3、6` 槽位。

这样可以复用 PAPAlu Runtime，但仍然依赖固定 8 帧，是一次有效的产品验证，不是最终通用架构。

猫咪实际只有两张独立素材，没有真正的 blink 帧或额外嘴型。它目前的自然感来自：

- 已验收的开闭嘴播放节奏。
- 程序生成的 idle 位移和轻微旋转。
- idle 思考云。
- 已针对当前环境验证的麦克风门控。

## 方案选择

### 不采用：继续填充固定 8 帧

优点是改动最小，但每个两图角色都必须复制成 8 个假帧，新增角色仍然依赖 PAPAlu 帧编号，无法满足通用化目标。

### 采用：能力驱动的 Character Runtime

每个角色声明自己拥有的素材和行为。Runtime 根据能力播放，不要求固定帧数，也不认识角色名称。

### 本轮不采用：完整角色包插件系统

角色包 manifest、ZIP 导入、多角色库和角色包导出未来可以建立在同一个 Character 模型之上，但本轮不提供相关 UI 和导入器。

## 核心模型

新增轻量 `CharacterDefinition`，概念字段如下：

```swift
struct CharacterDefinition {
    let id: String
    let name: String
    let source: CharacterSource
    let idleImage: CharacterImageReference
    let talkingSequence: [CharacterFrameStep]
    let blinkSequence: [CharacterFrameStep]?
    let settleSequence: [CharacterFrameStep]?
    let talkingFramesPerSecond: Double
    let idleMotion: IdleMotionConfiguration
    let thoughtCloudEnabled: Bool
    let defaultWindowSize: CGSize
}
```

具体实现可以根据 Swift 编译边界微调，但必须保持以下约束：

- `talkingSequence` 至少有一帧，可以引用同一张图多次以表达节奏，但不制造磁盘上的假帧。
- blink 和 settle 都是可选能力。
- 没有 blink 时不调度眨眼，不报错。
- 没有 settle 时从 talking 直接显示 idle。
- 思考云不是 idle 的固定组成，而是角色级能力。
- Runtime 不包含 PAPAlu 或猫咪的资源路径和帧编号。
- 后续复杂角色包可以直接生成同一种 `CharacterDefinition`。

## Runtime 与状态

基础视觉状态仍保持最小：

- `idle`
- `talking`

状态优先级和麦克风数据流不变：

`AVAudioEngine → RMS → MouthGate → idle/talking → CharacterRuntime → CharacterWindow`

`CharacterRuntime` 负责：

- 根据当前角色选择正确的 idle 图。
- 按角色自己的 talking sequence 和 FPS 播放。
- 在支持时播放 blink 和 settle。
- 在不支持时安全降级。
- 切换角色时立即使用当前实时麦克风状态重新渲染，而不是恢复旧的缓存状态。

`CharacterWindow` 负责：

- 展示 Runtime 当前选择的图像。
- 透明悬浮、拖动和缩放。
- 角色级 idle motion。
- 角色允许时显示思考云。
- 提供右键角色选择入口。

为了减少无意义改名，不要求同时重命名所有历史文件；但核心新类型不得再使用 PAPAlu 命名。现有 `PAPAluWindow.swift` 可以在本轮有目的地迁移为 `CharacterWindow.swift`。

## 内置角色

### 猫咪

猫咪是首次启动时的默认角色，也是本轮视觉回归基线。

配置：

- idle：闭嘴图。
- talking：复用当前验收通过的开嘴、闭嘴节奏。
- blink：无。
- settle：使用现有两图能够表达的最短开嘴到闭嘴序列，不添加第三种嘴型。
- idle motion：保留当前轻微位移和旋转。
- thought cloud：启用，保持当前验收效果。
- 麦克风响应：不得比当前猫咪预览明显变慢。

猫咪素材进入正式 `realtime-macos/Resources/Characters/CatMeme/`，不再依赖输出目录中的临时替换资源。

### PAPAlu

PAPAlu 保留为第二个内置角色：

- idle、talking、blink、settle 继续使用现有正式 8 帧。
- 当前序列和节奏迁移到 PAPAlu 的角色配置。
- 不重新生成或修改 PAPAlu 图片。

PAPAlu 证明 Runtime 可以处理丰富多帧角色；猫咪和自定义角色证明 Runtime 可以处理两帧角色。

## 两图自定义角色

V1 只保存一个 custom character slot。

用户提供：

1. 闭嘴 PNG。
2. 张嘴 PNG。

默认配置：

- idle：闭嘴图。
- talking：张嘴图。
- blink：无。
- settle：无，talking 结束后直接闭嘴。
- idle motion：使用克制的通用微动。
- thought cloud：关闭。
- talking motion：允许极轻的程序位移，但不改变图片内容。

V1 不生成嘴型、不抠图、不调用网络、不修改用户原图。

## 图片验证与标准化

导入时必须检查：

- 两张文件是否能被 `NSImage` 读取。
- 像素宽高是否有效。
- 图像是否包含可见像素。
- 是否存在有效 alpha 通道。
- 两张图片画布是否一致。

处理原则：

- 无法读取或没有可见内容：阻止保存并明确提示。
- 没有透明背景：允许继续，但提示录屏中会保留图片背景。
- 画布尺寸一致：原样复制。
- 画布尺寸不同：在不缩放、不裁切、不改变内容的前提下，放入同一个透明画布，按底部居中对齐。新画布使用两张图所需的最大宽高。

标准化后的副本写入 App 的 Application Support；用户原文件不修改。

## 最小角色界面

右键悬浮角色显示：

- 内置猫咪
- PAPAlu
- 自定义角色
- 设置自定义角色……

当前角色显示勾选状态。

“设置自定义角色……”打开轻量原生面板，包含：

- 闭嘴图片选择按钮和缩略图。
- 张嘴图片选择按钮和缩略图。
- 图片检查结果与透明背景提示。
- 麦克风实时预览区域。
- “使用这个角色”按钮。

没有完成两张图选择前，自定义角色不可激活。V1 不做商店、角色搜索、拖拽排序或多 custom slot。

## 持久化

使用 `UserDefaults` 保存：

- 当前角色 ID。
- 上次窗口位置。
- 上次缩放比例。

使用 `Application Support` 保存：

- 标准化后的自定义闭嘴图。
- 标准化后的自定义张嘴图。
- 最小自定义角色元数据。

启动恢复顺序：

1. 加载内置角色。
2. 检查自定义角色文件是否完整可读。
3. 恢复上次选择；若资源损坏或丢失，安全回退到内置猫咪。
4. 恢复窗口大小和位置，并确保窗口仍位于当前可用屏幕范围。

不使用数据库、云同步、登录或网络。

## 麦克风配置

音频参数集中到一个通用配置，不再散落 hardcode。

当前默认值使用已捕获的本机数据和猫咪验收结果：

- open threshold：`0.012`
- close threshold：`0.010`
- EMA smoothing：`0.35`
- release delay：`0.60s`

V1 不增加灵敏度滑杆或自动校准。原因是当前阶段尚无不同麦克风和声线的外部样本，过早加入校准可能引入新的误判。该限制记录为外部测试项。

## 产品与代码命名

用户可见开发名称暂定为“悬浮说话角色”，不代表正式品牌名。

核心代码逐步采用通用命名：

- `CharacterDefinition`
- `CharacterRuntime`
- `CharacterWindow`
- `CharacterAnimationPlan`
- `CharacterStore`

不为了统一命名而移动无关文件或重构离线网页工具。

## 测试策略

### Character 模型

- 两帧角色不依赖固定 8 帧。
- 多帧角色可以声明自己的 talking、blink 和 settle。
- 缺少可选能力时正确降级。
- 切换角色后根据当前麦克风状态重新渲染。

### 内置猫咪

- 默认选择猫咪。
- talking 顺序与当前验收版本一致。
- idle 微动和思考云保持启用。
- 无真实 blink 素材时不调度 blink。

### PAPAlu

- 原 8 帧全部可读取。
- talking、blink、settle 序列保持现有值。
- 迁移后不再由 Runtime 写死帧编号。

### 自定义角色

- 两张有效 PNG 可以保存和激活。
- 没有 blink 和 settle 不报错。
- 不同尺寸能够底部居中放入共同透明画布。
- 无 alpha 时给出提示但允许使用。
- 替换图片后 Runtime 刷新。
- 退出后重新启动可以恢复。
- 损坏或缺失文件安全回退到猫咪。

### 音频与回归

- `0.008` RMS 底噪在讲话结束后能够回到 idle。
- 原 MouthGate 连续讲话和句间停顿测试继续通过。
- 原窗口缩放、idle、thought cloud、图标和摄像头移除测试继续通过。
- 原离线网页测试继续通过。
- 构建后的 App 资源包含内置猫咪和 PAPAlu。

### 人工验证

- 内置猫咪：讲话、安静、idle、思考云、拖动、缩放、重启恢复、QuickTime 录屏。
- PAPAlu：多帧 talking、blink、settle 与现有表现对比。
- 自定义角色：导入、预览、讲话、安静、替换素材、重启恢复、QuickTime 录屏。

## 明确不做

- 复杂角色包、ZIP 或 manifest 导入 UI。
- 多个自定义角色槽位。
- AI 抠图、AI 嘴型生成或角色重画。
- 摄像头、Live2D、骨骼、分层人物、音素级口型。
- 账号、云同步、角色市场、内置录屏、视频导出。
- Windows、Mac App Store、自动更新。

## 成功标准

- 当前猫咪的已验收视觉效果和音频响应没有明显退化。
- 用户可以直接选择内置猫咪开始录屏。
- 用户可以导入任意一组有效的闭嘴和张嘴 PNG，不改代码即可生成悬浮说话角色。
- PAPAlu 作为复杂多帧角色运行在同一个 Runtime 上。
- Runtime 不依赖固定 8 帧、PAPAlu 帧编号或角色名称。
- 完成上述 V1 后停止，不继续扩展复杂角色包或其他功能。
