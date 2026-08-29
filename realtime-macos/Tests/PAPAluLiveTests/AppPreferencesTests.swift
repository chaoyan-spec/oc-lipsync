import AppKit

#if SWIFT_PACKAGE
@testable import PAPAluLive
#endif

func testPreferencesRoundTripSelectionPositionAndScale() throws {
    let suite = "LiveCharacterTests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suite) else {
        throw TestFailure(description: "could not create isolated defaults")
    }
    defer { defaults.removePersistentDomain(forName: suite) }
    let preferences = AppPreferences(defaults: defaults)
    preferences.selectedCharacterID = .papalu
    preferences.windowOrigin = NSPoint(x: 120, y: 240)
    preferences.windowScaleFactor = 1.4

    let restored = AppPreferences(defaults: defaults)
    try expectEqual(restored.selectedCharacterID, .papalu, "selection")
    try expectEqual(restored.windowOrigin, NSPoint(x: 120, y: 240), "origin")
    try expectEqual(restored.windowScaleFactor, 1.4, "scale")
}

func testPreferencesDefaultToCatMeme() throws {
    let suite = "LiveCharacterTests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suite) else {
        throw TestFailure(description: "could not create isolated defaults")
    }
    defer { defaults.removePersistentDomain(forName: suite) }
    try expectEqual(
        AppPreferences(defaults: defaults).selectedCharacterID,
        .catMeme,
        "default cat"
    )
}

let appPreferencesTests: [(String, () throws -> Void)] = [
    (
        "preferences round trip selection position and scale",
        testPreferencesRoundTripSelectionPositionAndScale
    ),
    ("preferences default to cat", testPreferencesDefaultToCatMeme),
]
