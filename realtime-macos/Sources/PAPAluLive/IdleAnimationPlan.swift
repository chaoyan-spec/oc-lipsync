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

struct IdleAnimationPlan {
    let configuration: IdleMotionConfiguration

    init(configuration: IdleMotionConfiguration = .gentle) {
        self.configuration = configuration
    }

    func swayStep(
        direction: IdleSwayDirection,
        durationRandomUnit: Double,
        holdRandomUnit: Double
    ) -> IdleSwayStep {
        let sign = direction == .left ? -1.0 : 1.0
        return IdleSwayStep(
            horizontalOffset: sign * configuration.horizontalOffset,
            rotationDegrees: sign * configuration.rotationDegrees,
            duration: map(durationRandomUnit, into: configuration.durationRange),
            holdDuration: map(holdRandomUnit, into: configuration.holdRange)
        )
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
