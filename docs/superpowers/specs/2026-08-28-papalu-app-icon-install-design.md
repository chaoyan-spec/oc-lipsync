# PAPAlu App 图标与安装设计

## 目标

让 PAPAlu 实时口型工具在 macOS 中拥有容易辨认的正式图标，并安装到系统“应用程序”文件夹。用户以后可以从“应用程序”、启动台或 Spotlight 搜索并启动，不再依赖项目目录中的深层路径。

## 图标设计

- 唯一角色来源为现有正式素材 `public/papalu-talking/frames/0.png`。
- 完整使用第 0 帧中的 PAPAlu 全身，保持原画、五官、发型、服装和比例不变。
- 使用白色圆角方形底板，并在人物四周保留稳定留白。
- 不使用 AI 重画，不生成相似角色，不修改 PAPAlu 形象。
- 输出标准 macOS `AppIcon.icns`，包含系统需要的多档分辨率。

## 工程接入

- 在 `realtime-macos/Resources/` 中保存图标源文件和生成后的 `AppIcon.icns`。
- 在 `Info.plist` 中通过 `CFBundleIconFile` 声明应用图标。
- 更新 `build-app.sh`，构建时将 `AppIcon.icns` 复制到 App Bundle 的 `Contents/Resources/`。
- 保持现有 bundle identifier `com.chaoyan.papalu-live`，不改变实时口型、idle 动画、思考云或窗口行为。

## 安装位置

- 构建完成后安装到 `/Applications/PAPAlu 实时口型.app`。
- 如果目标位置已有同名版本，只替换这个明确的 App，不触碰其他应用或项目文件。
- 安装后从 `/Applications` 启动并检查 Dock 图标、Spotlight 搜索结果和透明悬浮窗口。

## 验证

- `Info.plist` 校验通过。
- `.icns` 能被 macOS 正确读取，Dock 和 Finder 显示 PAPAlu 图标。
- `/Applications/PAPAlu 实时口型.app` 能正常启动。
- 麦克风权限、实时嘴型、idle 动画和思考云保持原有行为。
- 原有自动测试继续通过。

## 不做

- 不重画 PAPAlu。
- 不修改角色动画素材。
- 不制作设置页、安装器、自动更新或签名公证流程。
- 不改变应用名称、bundle identifier 或现有功能。
