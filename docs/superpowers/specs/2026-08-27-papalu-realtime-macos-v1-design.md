# PAPAlu 实时口型工具 V1 设计

## 目标

在保留现有离线网页 Lip Sync 工具的前提下，新增一个轻量原生 macOS 应用。用户打开 PAPAlu 后，通过 QuickTime 录制整个屏幕或指定区域；讲话时 PAPAlu 实时进入 talking，停止讲话约 120ms 后回到 idle。

## 范围

- 使用 Swift、AppKit、AVFoundation，不引入第三方运行时或大型框架。
- 复用 `public/papalu-talking/frames/` 中的正式透明 PNG 帧。
- 麦克风数据只在内存中计算 RMS，不保存、不上传、不联网。
- 原有 Node.js 网页、音频导入、预览和 MOV 导出保持不变。

## 架构

### MouthGate

纯 Swift 状态机，输入每个麦克风缓冲区的 RMS 和持续时间，输出 `idle` 或 `talking`。配置集中包含：

- 开启阈值：0.025
- 关闭阈值：0.015
- EMA 系数：0.35
- release delay：0.12 秒

EMA 平滑后，高于开启阈值立即进入 talking；只有连续低于关闭阈值达到 release delay 才返回 idle。位于两个阈值之间时保持当前状态。

### MicrophoneMonitor

使用 `AVCaptureDevice.authorizationStatus(for: .audio)` 和 `requestAccess(for: .audio)` 管理权限。授权后，使用 `AVAudioEngine.inputNode` 安装 512 帧 tap，实时计算所有输入声道的 RMS 与缓冲区时长，再传给 MouthGate。组件不提供录音、文件或网络接口。

### PAPAluWindow

使用透明、无边框、无阴影的 `NSPanel`，窗口级别为 `.floating`，不在应用失焦时隐藏，并加入所有桌面空间与全屏辅助空间。窗口保持标准共享类型，以便屏幕录制捕获；用户可直接拖动人物移动窗口。

默认显示尺寸为 288×312，即现有 192×208 素材的 1.5 倍。尺寸、talking 帧序列和动画 fps 集中定义。idle 显示第 0 帧；talking 初始以 8 fps 循环 `[1, 2, 3, 4, 6, 3]`。V1 不加入单独眨眼逻辑。

### AppDelegate

负责创建窗口、请求麦克风权限、启动和停止 MicrophoneMonitor，并只在 MouthGate 状态变化时通知主线程切换动画。应用保持普通 Dock 图标并支持 Command-Q。

## 构建与资源

Swift Package 只包含源码和测试。`build-app.sh` 构建 release 可执行文件，创建 `outputs/PAPAlu实时口型.app`，并在打包时从现有 `public/papalu-talking/frames/` 复制 8 帧到应用包。仓库不维护第二套 PAPAlu 图片。

应用 `Info.plist` 包含明确的 `NSMicrophoneUsageDescription`。V1 不签名、不公证、不上架 App Store。

## 错误处理

- 麦克风权限被拒绝或受限：保留闭嘴 PAPAlu，并显示一次明确的系统弹窗，指向系统设置中的麦克风权限。
- 麦克风启动失败：保留闭嘴 PAPAlu，并显示一次错误弹窗。
- 正式帧缺失：启动时显示一次错误并退出，避免呈现空窗口。

## QuickTime 使用边界

README 明确推荐录制整个屏幕，或录制同时包含教程窗口和 PAPAlu 的区域。由于 PAPAlu 是独立窗口，不保证“仅录制单个应用窗口”时被一起捕获。

## 测试与验收

MouthGate 单元测试覆盖：持续安静、明显讲话、短暂静音、超过 release delay、阈值附近稳定。完整验证包含 Swift 测试、Swift release 构建、原 Node.js 测试与构建、应用包结构、资产字节一致性、进程启动、窗口属性与可见性检查。

麦克风权限弹窗、真实讲话反应、拖动和 QuickTime 全屏/区域捕获属于本机交互验收；自动检查不能替代最终 1 分钟真实录制。

## V1 非目标

不做音素级口型、元音识别、语音识别、字幕、音频保存或上传、摄像头、多角色、设置页、菜单栏应用、开机启动、点击穿透、自动更新、签名、公证、App Store、剪映工作流、Electron、Tauri、音频设备选择器或任何与当前录教程链路无关的扩展。
