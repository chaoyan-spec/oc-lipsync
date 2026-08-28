enum MouthState: Equatable {
    case idle
    case talking
}

struct MouthGateConfiguration: Equatable {
    static let `default` = MouthGateConfiguration(
        openThreshold: 0.012,
        closeThreshold: 0.006,
        smoothingFactor: 0.35,
        releaseDelay: 0.60
    )

    let openThreshold: Double
    let closeThreshold: Double
    let smoothingFactor: Double
    let releaseDelay: Double

    init(
        openThreshold: Double,
        closeThreshold: Double,
        smoothingFactor: Double,
        releaseDelay: Double
    ) {
        precondition(openThreshold > closeThreshold)
        precondition(closeThreshold >= 0)
        precondition((0...1).contains(smoothingFactor))
        precondition(releaseDelay >= 0)

        self.openThreshold = openThreshold
        self.closeThreshold = closeThreshold
        self.smoothingFactor = smoothingFactor
        self.releaseDelay = releaseDelay
    }
}

struct MouthGate {
    private let configuration: MouthGateConfiguration
    private var smoothedRms = 0.0
    private var hasSample = false
    private var quietDuration = 0.0
    private(set) var state = MouthState.idle

    init(configuration: MouthGateConfiguration = .default) {
        self.configuration = configuration
    }

    mutating func update(rms: Double, duration: Double) -> MouthState {
        let sample = rms.isFinite ? max(0, rms) : 0
        let elapsed = duration.isFinite ? max(0, duration) : 0

        if hasSample {
            let alpha = configuration.smoothingFactor
            smoothedRms = alpha * sample + (1 - alpha) * smoothedRms
        } else {
            smoothedRms = sample
            hasSample = true
        }

        switch state {
        case .idle:
            if sample >= configuration.openThreshold {
                state = .talking
                quietDuration = 0
            }
        case .talking:
            if smoothedRms < configuration.closeThreshold {
                quietDuration += elapsed
                if quietDuration >= configuration.releaseDelay {
                    state = .idle
                    quietDuration = 0
                }
            } else {
                quietDuration = 0
            }
        }

        return state
    }
}
