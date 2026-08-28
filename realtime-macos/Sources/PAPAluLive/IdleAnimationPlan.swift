struct IdleFrameStep: Equatable {
    let frame: Int
    let duration: Double
}

enum IdleScheduledEvent: Equatable {
    case breath(after: Double)
    case blink(after: Double)
}

struct IdleAnimationConfiguration: Equatable {
    static let `default` = IdleAnimationConfiguration(
        baseFrame: 0,
        breathSteps: [
            IdleFrameStep(frame: 7, duration: 0.28),
            IdleFrameStep(frame: 0, duration: 0.28),
        ],
        blinkSteps: [
            IdleFrameStep(frame: 5, duration: 0.11),
            IdleFrameStep(frame: 7, duration: 0.10),
            IdleFrameStep(frame: 0, duration: 0.12),
        ],
        settleSteps: [
            IdleFrameStep(frame: 3, duration: 0.08),
            IdleFrameStep(frame: 1, duration: 0.08),
            IdleFrameStep(frame: 7, duration: 0.08),
            IdleFrameStep(frame: 0, duration: 0.08),
        ],
        breathDelayRange: 2.8...4.8,
        blinkDelayRange: 5.5...9.0
    )

    let baseFrame: Int
    let breathSteps: [IdleFrameStep]
    let blinkSteps: [IdleFrameStep]
    let settleSteps: [IdleFrameStep]
    let breathDelayRange: ClosedRange<Double>
    let blinkDelayRange: ClosedRange<Double>
}

struct IdleAnimationPlan {
    let configuration: IdleAnimationConfiguration

    init(configuration: IdleAnimationConfiguration = .default) {
        self.configuration = configuration
    }

    func breathDelay(randomUnit: Double) -> Double {
        map(randomUnit, into: configuration.breathDelayRange)
    }

    func blinkDelay(randomUnit: Double) -> Double {
        map(randomUnit, into: configuration.blinkDelayRange)
    }

    func nextEvent(
        breathDelay: Double,
        blinkDelay: Double
    ) -> IdleScheduledEvent {
        if blinkDelay <= breathDelay {
            return .blink(after: max(0, blinkDelay))
        }
        return .breath(after: max(0, breathDelay))
    }

    private func map(
        _ randomUnit: Double,
        into range: ClosedRange<Double>
    ) -> Double {
        let finiteUnit = randomUnit.isFinite ? randomUnit : 0
        let clampedUnit = min(1, max(0, finiteUnit))
        return range.lowerBound
            + (range.upperBound - range.lowerBound) * clampedUnit
    }
}

