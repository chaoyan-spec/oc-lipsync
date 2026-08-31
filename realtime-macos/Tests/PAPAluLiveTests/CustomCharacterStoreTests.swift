import AppKit

#if SWIFT_PACKAGE
@testable import PAPAluLive
#endif

func testStoreRoundTripsOneCustomCharacter() throws {
    let directory = try makeCharacterTestDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let sourceDirectory = directory.appendingPathComponent("source")
    try FileManager.default.createDirectory(
        at: sourceDirectory,
        withIntermediateDirectories: true
    )
    let idle = try makeCharacterTestPNG(
        in: sourceDirectory,
        name: "idle.png",
        size: NSSize(width: 30, height: 40),
        alpha: true
    )
    let talking = try makeCharacterTestPNG(
        in: sourceDirectory,
        name: "talking.png",
        size: NSSize(width: 30, height: 40),
        alpha: true
    )
    let prepared = try CharacterImagePreparer().prepare(
        idleURL: idle,
        talkingURL: talking
    )
    let store = CustomCharacterStore(
        rootDirectory: directory.appendingPathComponent("stored")
    )

    try store.save(prepared)
    let loaded = try store.load()

    try expectEqual(loaded?.definition.id, .custom, "custom restored")
    try expectEqual(
        Set(loaded?.images.keys.map { $0 } ?? []),
        Set(["idle", "talking"]),
        "stored images"
    )
}

func testEmptyStoreReturnsNil() throws {
    let directory = try makeCharacterTestDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = CustomCharacterStore(rootDirectory: directory)

    try expectEqual(try store.load() == nil, true, "empty custom slot")
}

func testStoreDeletesSavedCharacterAndRepeatedDeleteIsSafe() throws {
    let directory = try makeCharacterTestDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let sourceDirectory = directory.appendingPathComponent("source")
    try FileManager.default.createDirectory(
        at: sourceDirectory,
        withIntermediateDirectories: true
    )
    let idle = try makeCharacterTestPNG(
        in: sourceDirectory,
        name: "idle.png",
        size: NSSize(width: 30, height: 40),
        alpha: true
    )
    let talking = try makeCharacterTestPNG(
        in: sourceDirectory,
        name: "talking.png",
        size: NSSize(width: 30, height: 40),
        alpha: true
    )
    let prepared = try CharacterImagePreparer().prepare(
        idleURL: idle,
        talkingURL: talking
    )
    let store = CustomCharacterStore(
        rootDirectory: directory.appendingPathComponent("stored")
    )

    try store.save(prepared)
    try store.delete()
    try expectEqual(try store.load() == nil, true, "deleted custom slot")
    try store.delete()
    try expectEqual(try store.load() == nil, true, "repeated delete stays empty")
}

let customCharacterStoreTests: [(String, () throws -> Void)] = [
    ("custom character store round trips", testStoreRoundTripsOneCustomCharacter),
    ("empty custom character store returns nil", testEmptyStoreReturnsNil),
    (
        "custom character store deletes saved assets safely",
        testStoreDeletesSavedCharacterAndRepeatedDeleteIsSafe
    ),
]
