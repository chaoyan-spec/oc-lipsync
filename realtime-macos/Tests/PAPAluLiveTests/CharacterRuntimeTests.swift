import AppKit

#if SWIFT_PACKAGE
@testable import PAPAluLive
#endif

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

func testCharacterAssetsRejectMissingRequiredImage() throws {
    do {
        _ = try CharacterAssets(
            definition: .custom(name: "不完整角色"),
            images: ["idle": NSImage(size: NSSize(width: 1, height: 1))]
        )
        throw TestFailure(description: "missing talking image should be rejected")
    } catch CharacterAssetError.missingRequiredImage {
        return
    }
}

let characterRuntimeTests: [(String, () throws -> Void)] = [
    ("runtime handles one talking frame", testRuntimeHandlesSingleTalkingFrame),
    ("runtime handles multi-frame talking", testRuntimeHandlesMultiFrameTalkingSequence),
    (
        "character changes use current microphone state",
        testRuntimeReturnsToCurrentStateWhenCharacterChanges
    ),
    ("character assets reject missing images", testCharacterAssetsRejectMissingRequiredImage),
]
