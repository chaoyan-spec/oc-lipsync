# Windows 悬浮说话角色 V1 设计

## 目标

在不重构、不替换现有 macOS 原生版的前提下，新增一套 Windows 10/11 桌面应用，让创作者可以完成同一条已验证链路：

> 打开悬浮角色 → 正常讲话 → 角色实时开闭嘴和待机 → 用 OBS 显示器采集录下教程

Windows V1 只做单角色悬浮口播，不继续多猫实验，不扩展摄像头、动作捕捉或虚拟主播功能。

## 已确认的技术路线

- 语言和 UI：C# + WPF
- 运行时：.NET 10 LTS
- 麦克风：NAudio 的 WASAPI shared-mode capture
- 图像：现有透明 PNG，不重新生成角色
- 状态判断：RMS → EMA smoothing → hysteresis → talking / idle
- 发布：第一阶段 Windows x64 自包含便携包
- 系统范围：Windows 11 正式支持；Windows 10 22H2 x64 尽力兼容并真机测试

不使用 Electron、Tauri、Python、OpenCV、Live2D、WinUI 3 或跨平台 UI 重写。

## 架构边界

仓库新增独立目录 `realtime-windows/`。现有 `realtime-macos/` 和离线网页工具保持原样。

Windows 版分为四层：

1. `Core`：MouthGate、角色状态、动画节奏、缩放规则等无 UI 逻辑。
2. `Audio`：从默认 Windows 麦克风读取 PCM，只计算 RMS，不保存数据。
3. `Presentation`：WPF 透明窗口、PNG 切换、idle 摆动、思考云、右键菜单。
4. `Storage`：本地角色选择、窗口位置、缩放和自定义角色素材。

建议的初始文件结构：

```text
realtime-windows/
  PAPAluLive.Windows.csproj
  App.xaml
  App.xaml.cs
  MainWindow.xaml
  MainWindow.xaml.cs
  Core/
    MouthGate.cs
    CharacterDefinition.cs
    CharacterRuntime.cs
    IdleAnimationPlan.cs
    ThoughtCloudPlan.cs
    WindowScale.cs
  Audio/
    MicrophoneMonitor.cs
  Characters/
    CharacterCatalog.cs
    CharacterAssets.cs
    CustomCharacterStore.cs
  Tests/
  build-windows.ps1
```

## 现有能力复用

直接复用同一套源素材：

- PAPAlu 8 帧
- 猫 Meme、Huh 猫、Happy 猫、抱头尖叫猫闭嘴/张嘴帧
- App 图标和角色缩略图

第一阶段不搬动已有素材目录，Windows 构建脚本从现有正式资源复制，避免影响 Mac 构建。Windows 技术链路验证后，再单独评估是否抽成 `shared/characters/` 和 manifest；这不是 V1 阻塞项。

Swift 代码不能直接被 C# 编译，但以下行为和测试数据按现有实现逐项移植：

- MouthGate 阈值、EMA 和 release delay
- talking 帧序列与 FPS
- talking → idle 收口
- idle 左右轻摆与随机眨眼
- 思考云延迟和点动画
- 角色缩放范围
- PNG 底部居中和相同画布标准化

## 实时音频链路

`WasapiCapture` 以 shared mode 读取系统默认输入设备。每个音频 buffer：

1. 按实际 PCM 格式转换采样值。
2. 计算多声道 RMS。
3. 按 buffer 帧数和采样率计算 duration。
4. 把 RMS 和 duration 送入与 Mac 版一致的 MouthGate。
5. 状态变化时切换 WPF 角色动画。

音频只在内存中分析；不创建 WAV，不保存，不上传，不联网。V1 不提供音频设备选择器，跟随 Windows 默认麦克风。

如果麦克风不可用或系统关闭“允许桌面应用访问麦克风”，角色保持 idle，并显示一次简短故障说明和系统设置路径，不循环弹窗。

## 悬浮窗口

主窗口采用：

- `WindowStyle=None`
- `AllowsTransparency=True`
- `Background=Transparent`
- `Topmost=True`
- 无阴影、无标题栏
- 保留任务栏图标和正常退出入口
- 鼠标按住人物区域调用 `DragMove()`
- 支持 100%、125%、150%、200% DPI

右键菜单显示角色闭嘴缩略图和名称，切换角色时重新读取当前 talking / idle 状态。窗口位置、缩放和所选角色保存在 `%LOCALAPPDATA%/PAPAluLive/`。

## 功能范围

Windows V1 包含：

- 单个透明悬浮角色
- 麦克风实时 talking / idle
- talking 循环、收口、idle 微动、随机眨眼、思考云
- 拖动和放大缩小
- 所有现有内置角色
- 右键缩略图角色选择
- 导入闭嘴 PNG + 张嘴 PNG 的自定义角色
- 本地保存设置
- Windows x64 自包含发布包

Windows V1 不包含：

- 多角色同时运行
- 摄像头、动作检测或表情捕捉
- 音素级口型、语音识别或字幕
- 麦克风设备选择器
- 设置中心、账号、联网、云同步或自动更新
- Windows on Arm 专用构建
- MSIX、商店发布、自动安装器

## 录屏边界

推荐使用 OBS 的“显示器采集”，或其他能够录制整个屏幕/区域的工具。不要承诺 OBS“窗口采集”、Xbox Game Bar 的单应用录制一定包含悬浮角色，因为角色是独立窗口。

Windows App 不主动调用录屏 API，也不与 OBS 集成。

## 发布方式

内部验收包采用 `win-x64` 自包含发布，用户不需要另装 .NET。V1 可先交付 ZIP，解压后双击 EXE。

自包含包会明显大于当前约 7 MB 的 Mac App，预计为几十 MB；以实际 Windows publish 结果为准。V1 不启用高风险 trimming。公开分发前再处理 Authenticode 签名、SmartScreen 信誉和安装器。

## 测试与真机验收

自动测试至少覆盖：

- MouthGate 与 Mac 版相同的输入序列和期望状态
- 安静、讲话、短暂停顿、release delay、阈值抖动
- talking 帧循环、收口和 idle 恢复
- 角色资源完整、PNG 可读取、画布匹配
- 自定义角色标准化和本地保存
- 设置读写、窗口缩放和角色切换
- 禁止生成录音文件的契约检查

真实 Windows x64 电脑验收：

1. Windows 11：透明、置顶、拖动、DPI、麦克风、OBS 显示器采集。
2. Windows 10 22H2：启动、透明窗口、麦克风、OBS 显示器采集，按尽力兼容记录结果。
3. 麦克风权限开启和关闭两种情况。
4. 系统默认麦克风和常见 USB / 蓝牙耳机至少各一次。
5. 连续讲话一分钟不能中途错误进入 idle。

Mac 环境负责源代码、纯逻辑测试和发布脚本；最终透明窗口、麦克风和录屏链路必须由用户的真实 Windows 电脑验收。

## 完成标准

- Mac 原生版和离线网页工具无回归。
- Windows 双击启动后出现一个透明、可拖动、置顶角色。
- 讲话快速进入 talking，连续讲话不错误暂停，安静后自然进入 idle。
- 现有角色形象和动画规则保持一致。
- OBS 显示器采集能录到教程内容、声音和悬浮角色。
- 不保存音频、不上传、不联网。
- 生成可交给普通 Windows x64 用户解压运行的验收包。
