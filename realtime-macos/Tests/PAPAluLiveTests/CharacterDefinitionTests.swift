#if SWIFT_PACKAGE
@testable import PAPAluLive
#endif

func testCatMemeUsesTwoUniqueAssetsWithoutFakeEightFrameRequirement() throws {
    let cat = CharacterDefinition.catMeme
    try expectEqual(cat.id, .catMeme, "cat id")
    try expectEqual(cat.idleAssetName, "idle", "cat idle")
    try expectEqual(
        Set(cat.talkingAssetNames),
        Set(["idle", "talking"]),
        "cat assets"
    )
    try expectEqual(cat.blinkSteps.isEmpty, true, "cat has no fake blink")
    try expectEqual(cat.thoughtCloudEnabled, true, "cat keeps thought cloud")
}

func testPapaluOwnsItsLegacySequencesInsteadOfRuntime() throws {
    let papalu = CharacterDefinition.papalu
    try expectEqual(
        papalu.talkingAssetNames,
        ["2", "1", "3", "4", "6", "3"],
        "PAPAlu talking"
    )
    try expectEqual(
        papalu.blinkSteps.map(\.assetName),
        ["5", "7", "0"],
        "PAPAlu blink"
    )
    try expectEqual(
        papalu.settleSteps.map(\.assetName),
        ["3", "1", "7", "0"],
        "PAPAlu settle"
    )
}

func testTwoFrameCustomCharacterHasNoOptionalAnimationRequirements() throws {
    let custom = CharacterDefinition.custom(name: "我的角色")
    try expectEqual(
        custom.talkingAssetNames,
        ["talking", "idle", "talking", "idle", "talking", "talking"],
        "custom talking cadence"
    )
    try expectEqual(custom.talkingFramesPerSecond, 8, "custom talking fps")
    try expectEqual(custom.idleMotion, .gentle, "custom idle motion")
    try expectEqual(custom.blinkSteps.isEmpty, true, "custom blink")
    try expectEqual(custom.settleSteps.isEmpty, true, "custom settle")
    try expectEqual(custom.thoughtCloudEnabled, true, "custom cloud")
}

func testFirstCatPackIsAnOrderedTwoFrameBundledCatalog() throws {
    let bundled = CharacterDefinition.bundledCharacters
    try expectEqual(
        bundled.map(\.definition.id),
        [.catMeme, .huhCat, .happyCat, .screamingCat, .papalu],
        "bundled character order"
    )
    try expectEqual(
        bundled.map(\.resourceDirectoryName),
        ["CatMeme", "HuhCat", "HappyCat", "ScreamingCat", "PAPAlu"],
        "bundled resource directories"
    )

    let newCats = bundled.dropFirst().dropLast().map(\.definition)
    try expectEqual(
        newCats.map(\.name),
        ["Huh 猫", "Happy 猫", "抱头尖叫猫"],
        "first cat pack names"
    )
    for cat in newCats {
        try expectEqual(cat.idleAssetName, "idle", "\(cat.name) idle")
        try expectEqual(
            Set(cat.talkingAssetNames),
            Set(["idle", "talking"]),
            "\(cat.name) mouth assets"
        )
        try expectEqual(cat.blinkSteps.isEmpty, true, "\(cat.name) blink")
        try expectEqual(cat.thoughtCloudEnabled, true, "\(cat.name) cloud")
    }
}

let characterDefinitionTests: [(String, () throws -> Void)] = [
    (
        "cat uses two unique assets without fake frame requirements",
        testCatMemeUsesTwoUniqueAssetsWithoutFakeEightFrameRequirement
    ),
    (
        "PAPAlu owns its legacy animation sequences",
        testPapaluOwnsItsLegacySequencesInsteadOfRuntime
    ),
    (
        "two-frame custom character has no optional requirements",
        testTwoFrameCustomCharacterHasNoOptionalAnimationRequirements
    ),
    (
        "first cat pack is an ordered two-frame bundled catalog",
        testFirstCatPackIsAnOrderedTwoFrameBundledCatalog
    ),
]
