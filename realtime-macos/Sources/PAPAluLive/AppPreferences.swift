import AppKit

final class AppPreferences {
    private enum Key {
        static let selectedCharacterID = "selectedCharacterID"
        static let windowOrigin = "windowOrigin"
        static let windowScaleFactor = "windowScaleFactor"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedCharacterID: CharacterID {
        get {
            let value = defaults.string(forKey: Key.selectedCharacterID) ?? ""
            return CharacterID(rawValue: value) ?? .catMeme
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.selectedCharacterID)
        }
    }

    var windowScaleFactor: Double {
        get {
            guard defaults.object(forKey: Key.windowScaleFactor) != nil else {
                return 1
            }
            return defaults.double(forKey: Key.windowScaleFactor)
        }
        set {
            defaults.set(newValue, forKey: Key.windowScaleFactor)
        }
    }

    var windowOrigin: NSPoint? {
        get {
            guard let value = defaults.string(forKey: Key.windowOrigin) else {
                return nil
            }
            return NSPointFromString(value)
        }
        set {
            if let newValue {
                defaults.set(NSStringFromPoint(newValue), forKey: Key.windowOrigin)
            } else {
                defaults.removeObject(forKey: Key.windowOrigin)
            }
        }
    }
}
