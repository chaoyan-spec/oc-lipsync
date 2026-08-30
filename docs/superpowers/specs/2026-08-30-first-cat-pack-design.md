# 第一期推荐猫角色包设计

## 目标

在不改变现有麦克风、动画 Runtime、悬浮窗口和 QuickTime 录屏链路的前提下，把已经在候选看板中确认的三只猫加入内置角色：

- Huh 猫
- Happy 猫
- 抱头尖叫猫

现有猫 Meme（Pop Cat）和 PAPAlu 保持原样，不重新制作、不调整动画参数。

## 素材方案

每只新猫只提供两张正式 PNG：

- `idle.png`：闭嘴状态
- `talking.png`：张嘴状态

两张图必须使用完全相同的透明画布、人物大小、人物中心和底部基线。除嘴部外，不主动改变眼睛、耳朵、毛色、姿势、肢体、模糊质感和 meme 原有身份特征。原图中没有合适嘴型时，只做局部嘴部编辑；不重画成另一只“相似的猫”。

素材完成后生成一张并排 QA 预览，检查透明背景、主体完整、闭嘴/张嘴差异和高速切换时的位移跳动。来源图片仅用于本地原型；公开分发前仍需单独核对版权和授权。

## App 接入

`CharacterDefinition` 增加三个稳定的 `CharacterID` 和对应两图配置。内置角色列表从一组声明式配置加载，核心 Runtime 不增加任何猫咪专属判断。

右键角色菜单继续采用已确认的方案 B：每个内置角色显示名称和闭嘴缩略图。缩略图是独立绘制的副本，不修改 Runtime 正在使用的原始 `NSImage` 尺寸。自定义角色入口保持原有行为。

菜单顺序为：

1. 猫 Meme
2. Huh 猫
3. Happy 猫
4. 抱头尖叫猫
5. PAPAlu
6. 自定义角色

## 文件范围

新增：

- `realtime-macos/Resources/Characters/HuhCat/{idle,talking}.png`
- `realtime-macos/Resources/Characters/HappyCat/{idle,talking}.png`
- `realtime-macos/Resources/Characters/ScreamingCat/{idle,talking}.png`
- 一期素材 QA 预览与来源说明

修改：

- `CharacterDefinition.swift`
- `AppDelegate.swift`
- `build-app.sh`
- 内置角色资源测试和 Swift 定义测试
- `README.md`

## 验收标准

- 三只新猫都能从带缩略图的右键菜单直接切换。
- 讲话时显示张嘴图，安静时显示闭嘴图并保留现有轻微 idle 和思考云。
- 两帧切换无明显整体跳动，主体没有被裁掉，背景真实透明。
- Pop Cat、PAPAlu、自定义角色、麦克风响应和离线网页测试不回归。
- 构建出的 `.app` 包含全部角色资源，且仍然不联网、不保存录音。

## 本期不做

- 多帧猫动画、眨眼帧、动作帧或新状态机
- 猫咪商店、下载、联网更新或账号系统
- AI 自动批量导入任意网络图片
- 版权授权自动判断
- 妙脆角猫及第二期候选
