import AppKit

enum CharacterID: String, Codable, Equatable, Hashable {
    case catMeme
    case huhCat
    case happyCat
    case screamingCat
    case papalu
    case custom
}

struct BundledCharacterDefinition: Equatable {
    let definition: CharacterDefinition
    let resourceDirectoryName: String
}

struct CharacterFrameStep: Equatable {
    let assetName: String
    let duration: Double
}

struct IdleMotionConfiguration: Equatable {
    let horizontalOffset: Double
    let rotationDegrees: Double
    let durationRange: ClosedRange<Double>
    let holdRange: ClosedRange<Double>

    static let gentle = IdleMotionConfiguration(
        horizontalOffset: 4,
        rotationDegrees: 1,
        durationRange: 0.95...1.15,
        holdRange: 0.08...0.25
    )
}

struct CharacterDefinition: Equatable {
    let id: CharacterID
    let name: String
    let idleAssetName: String
    let talkingAssetNames: [String]
    let talkingFramesPerSecond: Double
    let blinkSteps: [CharacterFrameStep]
    let settleSteps: [CharacterFrameStep]
    let blinkDelayRange: ClosedRange<Double>?
    let idleMotion: IdleMotionConfiguration
    let thoughtCloudEnabled: Bool
    let defaultSize: NSSize

    static let catMeme = twoFrameBuiltIn(
        id: .catMeme,
        name: "猫 Meme"
    )

    static let huhCat = twoFrameBuiltIn(
        id: .huhCat,
        name: "Huh 猫"
    )

    static let happyCat = twoFrameBuiltIn(
        id: .happyCat,
        name: "Happy 猫"
    )

    static let screamingCat = twoFrameBuiltIn(
        id: .screamingCat,
        name: "抱头尖叫猫"
    )

    static let papalu = CharacterDefinition(
        id: .papalu,
        name: "PAPAlu",
        idleAssetName: "0",
        talkingAssetNames: ["2", "1", "3", "4", "6", "3"],
        talkingFramesPerSecond: 8,
        blinkSteps: [
            CharacterFrameStep(assetName: "5", duration: 0.11),
            CharacterFrameStep(assetName: "7", duration: 0.10),
            CharacterFrameStep(assetName: "0", duration: 0.12),
        ],
        settleSteps: ["3", "1", "7", "0"].map {
            CharacterFrameStep(assetName: $0, duration: 0.08)
        },
        blinkDelayRange: 3...5,
        idleMotion: .gentle,
        thoughtCloudEnabled: true,
        defaultSize: NSSize(width: 288, height: 312)
    )

    static func custom(name: String) -> CharacterDefinition {
        CharacterDefinition(
            id: .custom,
            name: name,
            idleAssetName: "idle",
            talkingAssetNames: [
                "talking", "idle", "talking", "idle", "talking", "talking",
            ],
            talkingFramesPerSecond: 8,
            blinkSteps: [],
            settleSteps: [],
            blinkDelayRange: nil,
            idleMotion: .gentle,
            thoughtCloudEnabled: true,
            defaultSize: NSSize(width: 288, height: 312)
        )
    }

    static let bundledCharacters = [
        BundledCharacterDefinition(
            definition: .catMeme,
            resourceDirectoryName: "CatMeme"
        ),
        BundledCharacterDefinition(
            definition: .huhCat,
            resourceDirectoryName: "HuhCat"
        ),
        BundledCharacterDefinition(
            definition: .happyCat,
            resourceDirectoryName: "HappyCat"
        ),
        BundledCharacterDefinition(
            definition: .screamingCat,
            resourceDirectoryName: "ScreamingCat"
        ),
        BundledCharacterDefinition(
            definition: .papalu,
            resourceDirectoryName: "PAPAlu"
        ),
    ]

    private static func twoFrameBuiltIn(
        id: CharacterID,
        name: String
    ) -> CharacterDefinition {
        CharacterDefinition(
            id: id,
            name: name,
            idleAssetName: "idle",
            talkingAssetNames: [
                "talking", "idle", "talking", "idle", "talking", "talking",
            ],
            talkingFramesPerSecond: 8,
            blinkSteps: [],
            settleSteps: [
                CharacterFrameStep(assetName: "talking", duration: 0.08),
                CharacterFrameStep(assetName: "idle", duration: 0.08),
            ],
            blinkDelayRange: nil,
            idleMotion: .gentle,
            thoughtCloudEnabled: true,
            defaultSize: NSSize(width: 288, height: 312)
        )
    }
}
