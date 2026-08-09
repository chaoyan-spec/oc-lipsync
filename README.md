# OC 口播机

把 MP3、WAV 或 M4A 口播音频转换成带透明背景的 OC 对嘴 WebM。所有文件都只在本机处理，不会上传。

## 开始使用

1. 双击 `启动OC口播机.command`；也可以在终端进入本目录后运行 `npm start`。
2. 浏览器通常会自动打开。如果没有，请打开终端中显示的本地地址（默认是 <http://127.0.0.1:4173>）。
3. 导入 MP3、WAV 或 M4A 音频。
4. 预览效果，并按需要调整灵敏度、最短张嘴时间和 OC 大小三个控制项。
5. 点击导出 WebM，再把下载的视频导入剪辑软件继续制作。

不需要运行 `npm install`。电脑需要已经安装 FFmpeg 和 ffprobe：程序会优先使用 `/opt/homebrew/bin/ffmpeg` 与 `/opt/homebrew/bin/ffprobe`；如果这两个路径不可执行，则从 `PATH` 中查找。

使用结束后，回到启动程序的终端窗口，按 `Control-C` 停止本地服务。
