import AppKit

#if SWIFT_PACKAGE
@testable import PAPAluLive
#endif

func makeCharacterTestDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    return directory
}

func makeCharacterTestPNG(
    in directory: URL,
    name: String,
    size: NSSize,
    alpha: Bool
) throws -> URL {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width),
        pixelsHigh: Int(size.height),
        bitsPerSample: 8,
        samplesPerPixel: alpha ? 4 : 3,
        hasAlpha: alpha,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let data = bitmap.representation(using: .png, properties: [:]) else {
        throw TestFailure(description: "could not create test PNG")
    }
    let url = directory.appendingPathComponent(name)
    try data.write(to: url)
    return url
}

func testPreparerRejectsUnreadableInput() throws {
    do {
        _ = try CharacterImagePreparer().prepare(
            idleURL: URL(fileURLWithPath: "/missing-idle.png"),
            talkingURL: URL(fileURLWithPath: "/missing-talking.png")
        )
        throw TestFailure(description: "unreadable image should throw")
    } catch CharacterImagePreparationError.unreadableImage {
        return
    }
}

func testPreparerBottomCentersDifferentCanvasSizes() throws {
    let directory = try makeCharacterTestDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let idle = try makeCharacterTestPNG(
        in: directory,
        name: "idle-source.png",
        size: NSSize(width: 100, height: 200),
        alpha: true
    )
    let talking = try makeCharacterTestPNG(
        in: directory,
        name: "talking-source.png",
        size: NSSize(width: 160, height: 120),
        alpha: true
    )

    let prepared = try CharacterImagePreparer().prepare(
        idleURL: idle,
        talkingURL: talking
    )

    try expectEqual(
        prepared.canvasSize,
        NSSize(width: 160, height: 200),
        "shared canvas"
    )
    try expectEqual(prepared.warnings.isEmpty, true, "alpha PNG warning")
}

func testPreparerWarnsWhenInputHasNoAlpha() throws {
    let directory = try makeCharacterTestDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let idle = try makeCharacterTestPNG(
        in: directory,
        name: "idle-rgb.png",
        size: NSSize(width: 20, height: 20),
        alpha: false
    )
    let talking = try makeCharacterTestPNG(
        in: directory,
        name: "talking-rgba.png",
        size: NSSize(width: 20, height: 20),
        alpha: true
    )

    let prepared = try CharacterImagePreparer().prepare(
        idleURL: idle,
        talkingURL: talking
    )
    try expectEqual(prepared.warnings.isEmpty, false, "opaque input warning")
}

let characterImagePreparerTests: [(String, () throws -> Void)] = [
    ("preparer rejects unreadable input", testPreparerRejectsUnreadableInput),
    (
        "preparer uses a bottom-centered shared canvas",
        testPreparerBottomCentersDifferentCanvasSizes
    ),
    ("preparer warns about missing alpha", testPreparerWarnsWhenInputHasNoAlpha),
]
