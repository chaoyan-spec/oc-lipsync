# 自定义角色待机效果对齐 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让自定义两图角色在安静时复用内置猫咪的轻微飘动与思考云，并在讲话时立即回到现有快速口型。

**Architecture:** 保留现有 `CharacterWindow` 的通用待机调度，不新增自定义角色专属分支。只通过 `CharacterDefinition.custom` 声明它拥有思考云能力；飘动继续复用已存在的 `.gentle` 配置。

**Tech Stack:** Swift 5、AppKit、QuartzCore、现有自定义测试运行器。

## Global Constraints

- 不生成或修改角色素材。
- 不改变待机飘动幅度、思考云样式、麦克风门限或 8 fps 两图口型节奏。
- 不新增设置 UI、眨眼或其他动作。

---

### Task 1: 对齐自定义角色待机能力

**Files:**
- Modify: `realtime-macos/Tests/PAPAluLiveTests/CharacterDefinitionTests.swift`
- Modify: `realtime-macos/Sources/PAPAluLive/CharacterDefinition.swift`

**Interfaces:**
- Consumes: `CharacterDefinition.custom(name:)`、`IdleMotionConfiguration.gentle`、`CharacterWindow.scheduleThoughtCloud(generation:)`。
- Produces: 自定义角色的 `thoughtCloudEnabled == true`，现有窗口自动根据该能力显示和隐藏思考云。

- [ ] **Step 1: 写失败测试**

```swift
let custom = CharacterDefinition.custom(name: "我的角色")
try expectEqual(custom.idleMotion, .gentle, "custom idle motion")
try expectEqual(custom.thoughtCloudEnabled, true, "custom cloud")
```

- [ ] **Step 2: 运行测试并确认失败**

Run: `./realtime-macos/run-tests.sh`

Expected: `FAIL: custom cloud: expected true, got false`

- [ ] **Step 3: 最小实现**

在 `CharacterDefinition.custom(name:)` 中保持：

```swift
idleMotion: .gentle,
```

并修改：

```swift
thoughtCloudEnabled: true,
```

- [ ] **Step 4: 完整验证**

Run: `./realtime-macos/run-tests.sh`

Expected: 41 tests pass；应用外壳、摄像头移除、资源和设置面板契约全部通过。

- [ ] **Step 5: 构建和启动预览**

Run: `./realtime-macos/build-app.sh`

Expected: 生成 `outputs/悬浮说话角色.app`。关闭旧实例并启动该 App，确认自定义角色安静时飘动和出现思考云、讲话时立即隐藏思考云并开合嘴。
