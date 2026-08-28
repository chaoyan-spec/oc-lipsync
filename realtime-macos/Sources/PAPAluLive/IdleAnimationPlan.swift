struct IdleFrameStep: Equatable {
    let frame: Int
    let duration: Double
}

enum IdleSwayDirection: Equatable {
    case left
    case right
}

struct IdleSwayStep: Equatable {
    let horizontalOffset: Double
    let rotationDegrees: Double
    let duration: Double
    let holdDuration: Double
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
        swayHorizontalOffset: 4,
        swayRotationDegrees: 1,
        swayDurationRange: 0.95...1.15,
        swayHoldRange: 0.08...0.25,
        breathDelayRange: 2.8...4.8,
        blinkDelayRange: 5.5...9.0
    )

    let baseFrame: Int
    let breathSteps: [IdleFrameStep]
    let blinkSteps: [IdleFrameStep]
    let settleSteps: [IdleFrameStep]
    let swayHorizontalOffset: Double
    let swayRotationDegrees: Double
    let swayDurationRange: ClosedRange<Double>
    let swayHoldRange: ClosedRange<Double>
    let breathDelayRange: ClosedRange<Double>
    let blinkDelayRange: ClosedRange<Double>
}

struct IdleAnimationPlan {
    let configuration: IdleAnimationConfiguration

    init(configuration: IdleAnimationConfiguration = .default) {
        self.configuration = configuration
    }

    func swayStep(
        direction: IdleSwayDirection,
        durationRandomUnit: Double,
        holdRandomUnit: Double
    ) -> IdleSwayStep {
        let sign = direction == .left ? -1.0 : 1.0
        return IdleSwayStep(
            horizontalOffset: sign * configuration.swayHorizontalOffset,
            rotationDegrees: sign * configuration.swayRotationDegrees,
            duration: map(
                durationRandomUnit,
                into: configuration.swayDurationRange
            ),
            holdDuration: map(
                holdRandomUnit,
                into: configuration.swayHoldRange
            )
        )
    }

    func blinkDelay(randomUnit: Double) -> Double {
        map(randomUnit, into: configuration.blinkDelayRange)
    }

    func breathDelay(randomUnit: Double) -> Double {
        map(randomUnit, into: configuration.breathDelayRange)
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
