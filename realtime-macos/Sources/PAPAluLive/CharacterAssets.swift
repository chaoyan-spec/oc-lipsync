import AppKit

enum CharacterAssetError: LocalizedError {
    case missingRequiredImage
    case unreadableImage

    var errorDescription: String? {
        switch self {
        case .missingRequiredImage:
            return "角色缺少必要图片。"
        case .unreadableImage:
            return "角色图片无法读取。"
        }
    }
}

struct CharacterAssets {
    let definition: CharacterDefinition
    let images: [String: NSImage]

    init(definition: CharacterDefinition, images: [String: NSImage]) throws {
        guard Self.requiredNames(for: definition).isSubset(of: Set(images.keys)) else {
            throw CharacterAssetError.missingRequiredImage
        }
        self.definition = definition
        self.images = images
    }

    static func load(
        definition: CharacterDefinition,
        directory: URL
    ) throws -> CharacterAssets {
        var images: [String: NSImage] = [:]
        for name in requiredNames(for: definition) {
            let url = directory.appendingPathComponent("\(name).png")
            guard let image = NSImage(contentsOf: url) else {
                throw CharacterAssetError.unreadableImage
            }
            images[name] = image
        }
        return try CharacterAssets(definition: definition, images: images)
    }

    private static func requiredNames(
        for definition: CharacterDefinition
    ) -> Set<String> {
        Set(
            [definition.idleAssetName]
                + definition.talkingAssetNames
                + definition.blinkSteps.map(\.assetName)
                + definition.settleSteps.map(\.assetName)
        )
    }
}
