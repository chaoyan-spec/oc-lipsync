# PAPAlu 实时版移除摄像头功能设计

## 目标

将 PAPAlu 实时版收敛为只依赖麦克风的轻量录屏角色：讲话时播放 talking，安静时播放左右轻摆和随机眨眼，不再打开摄像头或识别挥手。

## 删除范围

从 `realtime-macos` 中完整移除：

- 摄像头权限请求和拒绝提示。
- `AVCaptureSession` 视频输入及后台画面读取。
- Apple Vision 人脸、手部和人体关键点分析。
- `WaveDetector` 挥手规则、cooldown 和相关测试。
- `teaching` 临时覆盖状态、动作计时与相关状态测试。
- 实时 App 对 `Teaching.png` 的加载、构建检查和打包依赖。
- `NSCameraUsageDescription`。
- 构建脚本中的 Vision framework 链接。

## 保留范围

- 麦克风权限、AVAudioEngine、RMS、EMA、hysteresis 和 120ms release delay。
- talking 快速起嘴和现有说话帧循环。
- idle 左右轻摆、3～5 秒随机眨眼和 talking/idle 过渡。
- 透明悬浮窗口、拖动、缩放、always-on-top 和 QuickTime 录屏链路。
- 离线网页 Lip Sync 工具。
- 公共正式资产 `public/papalu-states/teaching.png`。该文件不再进入实时 `.app`，但不从仓库删除，以免影响文字 Skill 或其他消费者。

## 简化后的状态

实时 App 只保留两种显示状态：

- `idle`
- `talking`

麦克风状态改变时直接渲染对应状态，不再经过临时动作协调器。

## 文件处理

删除：

- `realtime-macos/Sources/PAPAluLive/CameraMonitor.swift`
- `realtime-macos/Sources/PAPAluLive/WaveDetector.swift`
- `realtime-macos/Sources/PAPAluLive/ActionCoordinator.swift`
- `realtime-macos/Tests/PAPAluLiveTests/WaveDetectorTests.swift`
- `realtime-macos/Tests/PAPAluLiveTests/ActionCoordinatorTests.swift`

修改：

- `AppDelegate.swift`：删除摄像头启动、警告和 teaching 触发逻辑。
- `PAPAluWindow.swift`：显示状态只保留 idle/talking，不加载 Teaching 图片。
- `AppShellCompileTests.swift`、`main.swift`、`run-tests.sh`：移除摄像头和临时动作测试依赖。
- `Info.plist`：删除摄像头用途说明。
- `build-app.sh`：不检查、不复制 Teaching 图片，不链接 Vision。
- `README.md`：删除摄像头使用说明，明确应用只请求麦克风。

## 测试与验收

- 新增或调整静态构建契约，确保 AppDelegate、构建脚本和 Info.plist 不再包含摄像头、Vision、WaveDetector 或 CameraMonitor。
- MouthGate、idle、缩放和 AppKit 壳层测试继续通过。
- 离线网页 78 项测试和生产构建继续通过。
- 构建后的 `.app` 不包含 `Teaching.png`，Info.plist 不包含 `NSCameraUsageDescription`。
- 启动后只请求麦克风权限；系统摄像头指示灯不亮。
- 讲话、安静待机、拖动、缩放和 QuickTime 录屏继续正常。

## 不做

- 不删除公共 `teaching.png` 资产。
- 不增加摄像头开关、启动参数或恢复入口。
- 不调整口型、idle 动画或麦克风参数。
- 不修改离线网页工具。
