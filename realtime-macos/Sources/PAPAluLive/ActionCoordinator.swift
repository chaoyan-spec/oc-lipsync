enum PAPAluBaseState: Equatable {
    case idle
    case talking
}

enum PAPAluDisplayState: Equatable {
    case idle
    case talking
    case teaching
}

struct ActionCoordinator {
    static let defaultTeachingDuration = 0.8

    private let teachingDuration: Double
    private var baseState = PAPAluBaseState.idle
    private var teachingUntil: Double?

    init(teachingDuration: Double = Self.defaultTeachingDuration) {
        precondition(teachingDuration > 0)
        self.teachingDuration = teachingDuration
    }

    mutating func updateBaseState(_ state: PAPAluBaseState) {
        baseState = state
    }

    mutating func triggerTeaching(at timestamp: Double) -> PAPAluDisplayState {
        teachingUntil = timestamp + teachingDuration
        return .teaching
    }

    mutating func displayState(at timestamp: Double) -> PAPAluDisplayState {
        if let teachingUntil, timestamp < teachingUntil {
            return .teaching
        }

        teachingUntil = nil
        switch baseState {
        case .idle:
            return .idle
        case .talking:
            return .talking
        }
    }
}
