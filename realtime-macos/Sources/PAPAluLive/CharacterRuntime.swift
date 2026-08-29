enum CharacterDisplayState: Equatable {
    case idle
    case talking
}

struct CharacterRuntime {
    private(set) var definition: CharacterDefinition
    private(set) var state: CharacterDisplayState = .idle
    private var talkingIndex = 0

    var currentAssetName: String {
        switch state {
        case .idle:
            return definition.idleAssetName
        case .talking:
            return definition.talkingAssetNames[talkingIndex]
        }
    }

    init(definition: CharacterDefinition) {
        precondition(!definition.talkingAssetNames.isEmpty)
        self.definition = definition
    }

    mutating func setState(_ state: CharacterDisplayState) {
        self.state = state
        if state == .talking {
            talkingIndex = 0
        }
    }

    mutating func advanceTalkingFrame() {
        guard state == .talking else { return }
        talkingIndex = (talkingIndex + 1) % definition.talkingAssetNames.count
    }

    mutating func setCharacter(
        _ definition: CharacterDefinition,
        currentState: CharacterDisplayState
    ) {
        self.definition = definition
        talkingIndex = 0
        setState(currentState)
    }
}
