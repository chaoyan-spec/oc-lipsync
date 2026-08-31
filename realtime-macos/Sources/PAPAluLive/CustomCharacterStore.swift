import AppKit

final class CustomCharacterStore {
    let rootDirectory: URL

    init(rootDirectory: URL = CustomCharacterStore.defaultRootDirectory()) {
        self.rootDirectory = rootDirectory
    }

    func save(_ prepared: PreparedCharacterImages) throws {
        try FileManager.default.createDirectory(
            at: rootDirectory,
            withIntermediateDirectories: true
        )
        try prepared.idlePNG.write(
            to: rootDirectory.appendingPathComponent("idle.png"),
            options: .atomic
        )
        try prepared.talkingPNG.write(
            to: rootDirectory.appendingPathComponent("talking.png"),
            options: .atomic
        )
    }

    func load() throws -> CharacterAssets? {
        let idleURL = rootDirectory.appendingPathComponent("idle.png")
        let talkingURL = rootDirectory.appendingPathComponent("talking.png")
        let manager = FileManager.default
        guard manager.fileExists(atPath: idleURL.path),
              manager.fileExists(atPath: talkingURL.path) else {
            return nil
        }
        guard let idle = NSImage(contentsOf: idleURL),
              let talking = NSImage(contentsOf: talkingURL) else {
            throw CharacterAssetError.unreadableImage
        }
        return try CharacterAssets(
            definition: .custom(name: "自定义角色"),
            images: ["idle": idle, "talking": talking]
        )
    }

    func loadRequired() throws -> CharacterAssets {
        guard let assets = try load() else {
            throw CharacterAssetError.missingRequiredImage
        }
        return assets
    }

    func delete() throws {
        let manager = FileManager.default
        guard manager.fileExists(atPath: rootDirectory.path) else { return }
        try manager.removeItem(at: rootDirectory)
    }

    private static func defaultRootDirectory() -> URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        return applicationSupport
            .appendingPathComponent("悬浮说话角色", isDirectory: true)
            .appendingPathComponent("CustomCharacter", isDirectory: true)
    }
}
