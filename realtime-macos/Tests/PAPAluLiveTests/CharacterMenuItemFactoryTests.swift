import AppKit

#if SWIFT_PACKAGE
@testable import PAPAluLive
#endif

func testBundledMenuItemShowsIdentitySelectionAndThumbnail() throws {
    let source = NSImage(size: NSSize(width: 100, height: 200))
    let assets = try CharacterAssets(
        definition: .huhCat,
        images: ["idle": source, "talking": source]
    )

    let item = CharacterMenuItemFactory().makeItem(
        for: assets,
        selectedCharacterID: .huhCat
    )

    try expectEqual(item.title, "Huh 猫", "menu title")
    try expectEqual(item.representedObject as? String, "huhCat", "menu id")
    try expectEqual(item.state, .on, "selected state")
    try expectEqual(item.image?.size, NSSize(width: 28, height: 28), "thumbnail")
    try expectEqual(source.size, NSSize(width: 100, height: 200), "source untouched")
}

func testBundledMenuItemIsOffWhenAnotherCharacterIsSelected() throws {
    let source = NSImage(size: NSSize(width: 40, height: 40))
    let assets = try CharacterAssets(
        definition: .happyCat,
        images: ["idle": source, "talking": source]
    )
    let item = CharacterMenuItemFactory().makeItem(
        for: assets,
        selectedCharacterID: .catMeme
    )

    try expectEqual(item.state, .off, "unselected state")
}

let characterMenuItemFactoryTests: [(String, () throws -> Void)] = [
    (
        "bundled menu item shows identity selection and thumbnail",
        testBundledMenuItemShowsIdentitySelectionAndThumbnail
    ),
    (
        "bundled menu item is off when another character is selected",
        testBundledMenuItemIsOffWhenAnotherCharacterIsSelected
    ),
]
