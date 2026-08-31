# 删除自定义角色 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 macOS 右键菜单中安全删除唯一的自定义角色槽位，并在必要时回退到猫 Meme。

**Architecture:** `CustomCharacterStore` 独立负责删除 App 保存的素材目录；`AppDelegate` 负责确认、内存 catalog、当前选择和菜单同步。原始上传文件从未被 Store 接管，因此删除动作只影响 App 的处理副本。

**Tech Stack:** Swift 5、AppKit、Foundation、现有自定义测试运行器。

## Global Constraints

- 只删除 `Application Support/悬浮说话角色/CustomCharacter` 中的 App 副本。
- 删除前必须让用户确认；取消时不改变任何状态。
- 删除失败时保留当前角色和 catalog。
- 当前使用自定义角色时，删除成功后回到猫 Meme。
- 不修改 Windows 版本，不增加多角色槽位或恢复功能。

---

### Task 1: 自定义角色删除链路

**Files:**
- Modify: `realtime-macos/Tests/PAPAluLiveTests/CustomCharacterStoreTests.swift`
- Modify: `realtime-macos/Sources/PAPAluLive/CustomCharacterStore.swift`
- Modify: `realtime-macos/Sources/PAPAluLive/AppDelegate.swift`
- Modify: `realtime-macos/Tests/verify-settings-panel.sh`

**Interfaces:**
- Consumes: `CustomCharacterStore.rootDirectory`、`AppDelegate.catalog`、`selectedCharacterID`、`selectCharacter(_:)`、`rebuildCharacterMenu()`。
- Produces: `CustomCharacterStore.delete() throws` 和右键菜单动作 `deleteCustomCharacter()`。

- [ ] **Step 1: 写存储删除失败测试**

```swift
try store.save(prepared)
try store.delete()
try expectEqual(try store.load() == nil, true, "deleted custom slot")
try store.delete()
try expectEqual(try store.load() == nil, true, "repeated delete stays empty")
```

同时在 `verify-settings-panel.sh` 中要求 `AppDelegate.swift` 包含“删除自定义角色…”和 `#selector(deleteCustomCharacter)`。

- [ ] **Step 2: 运行测试并确认失败**

Run: `./realtime-macos/run-tests.sh`

Expected: Swift 编译失败，提示 `CustomCharacterStore` 没有 `delete`；修正存储测试编译后，契约检查仍因缺少删除菜单而失败。

- [ ] **Step 3: 实现幂等存储删除**

在 `CustomCharacterStore` 中新增：

```swift
func delete() throws {
    let manager = FileManager.default
    guard manager.fileExists(atPath: rootDirectory.path) else { return }
    try manager.removeItem(at: rootDirectory)
}
```

- [ ] **Step 4: 接入确认框和菜单同步**

在 `AppDelegate` 中新增 `@objc private func deleteCustomCharacter()`：

```swift
let alert = NSAlert()
alert.messageText = "删除自定义角色？"
alert.informativeText = "只会删除 App 保存的闭嘴、张嘴副本，不会删除你最初选择的图片。"
alert.alertStyle = .warning
alert.addButton(withTitle: "删除")
alert.addButton(withTitle: "取消")
guard alert.runModal() == .alertFirstButtonReturn else { return }

do {
    try customStore.delete()
    catalog.removeValue(forKey: .custom)
    if selectedCharacterID == .custom {
        selectCharacter(.catMeme)
    } else {
        rebuildCharacterMenu()
    }
} catch {
    showError("无法删除自定义角色：\(error.localizedDescription)")
}
```

在“设置自定义角色…”之后加入“删除自定义角色…”，并设置：

```swift
deleteItem.isEnabled = catalog[.custom] != nil
```

- [ ] **Step 5: 完整验证和预览**

Run: `./realtime-macos/run-tests.sh`

Expected: 42 项测试通过，应用外壳和所有契约检查通过。

Run: `./realtime-macos/build-app.sh`

Expected: 生成签名有效的 `outputs/悬浮说话角色.app`。启动后确认取消不删除、确认删除后回到猫 Meme、菜单项置灰且可以重新上传。
