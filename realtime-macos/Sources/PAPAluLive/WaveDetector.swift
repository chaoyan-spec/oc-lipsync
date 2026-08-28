struct PosePoint: Equatable {
    let x: Double
    let y: Double
    let confidence: Double
}

struct BodyPoseSample: Equatable {
    let timestamp: Double
    let leftShoulder: PosePoint?
    let rightShoulder: PosePoint?
    let leftElbow: PosePoint?
    let rightElbow: PosePoint?
    let leftWrist: PosePoint?
    let rightWrist: PosePoint?
}

struct NormalizedRect: Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    var midX: Double { x + width / 2 }
    var midY: Double { y + height / 2 }
}

struct HandPoseSample: Equatable {
    let timestamp: Double
    let palm: PosePoint
    let faceBounds: NormalizedRect
}

struct WaveDetectorConfiguration: Equatable {
    static let `default` = WaveDetectorConfiguration(
        minimumConfidence: 0.5,
        minimumShoulderWidth: 0.08,
        wristHeightTolerance: 0.25,
        timeWindow: 1.0,
        minimumHorizontalAmplitude: 1.0,
        minimumDirectionalStep: 0.15,
        minimumDirectionReversals: 1,
        minimumTotalTravel: 2.0,
        handTimeWindow: 1.2,
        minimumHandAmplitude: 0.3,
        minimumHandDirectionalStep: 0.06,
        minimumHandTotalTravel: 0.55,
        minimumHandConfidence: 0.3,
        cooldown: 2.0
    )

    let minimumConfidence: Double
    let minimumShoulderWidth: Double
    let wristHeightTolerance: Double
    let timeWindow: Double
    let minimumHorizontalAmplitude: Double
    let minimumDirectionalStep: Double
    let minimumDirectionReversals: Int
    let minimumTotalTravel: Double
    let handTimeWindow: Double
    let minimumHandAmplitude: Double
    let minimumHandDirectionalStep: Double
    let minimumHandTotalTravel: Double
    let minimumHandConfidence: Double
    let cooldown: Double
}

struct WaveDetector {
    private struct MovementPoint {
        let timestamp: Double
        let normalizedX: Double
    }

    private struct HandMovementPoint {
        let timestamp: Double
        let normalizedX: Double
        let normalizedY: Double
    }

    private enum Hand {
        case left
        case right
    }

    private let configuration: WaveDetectorConfiguration
    private var leftHistory = [MovementPoint]()
    private var rightHistory = [MovementPoint]()
    private var handHistory = [HandMovementPoint]()
    private var lastTriggerTime: Double?

    init(configuration: WaveDetectorConfiguration = .default) {
        self.configuration = configuration
    }

    mutating func update(_ sample: BodyPoseSample) -> Bool {
        guard sample.timestamp.isFinite else { return false }

        if let lastTriggerTime,
           sample.timestamp - lastTriggerTime < configuration.cooldown {
            return false
        }

        guard let leftShoulder = valid(sample.leftShoulder),
              let rightShoulder = valid(sample.rightShoulder) else {
            return false
        }

        let shoulderWidth = abs(rightShoulder.x - leftShoulder.x)
        guard shoulderWidth >= configuration.minimumShoulderWidth else {
            return false
        }

        updateHistory(
            hand: .left,
            timestamp: sample.timestamp,
            shoulder: leftShoulder,
            elbow: sample.leftElbow,
            wrist: sample.leftWrist,
            shoulderWidth: shoulderWidth
        )
        updateHistory(
            hand: .right,
            timestamp: sample.timestamp,
            shoulder: rightShoulder,
            elbow: sample.rightElbow,
            wrist: sample.rightWrist,
            shoulderWidth: shoulderWidth
        )

        guard isWave(leftHistory) || isWave(rightHistory) else {
            return false
        }

        recordTrigger(at: sample.timestamp)
        return true
    }

    mutating func update(_ sample: HandPoseSample) -> Bool {
        guard sample.timestamp.isFinite,
              cooldownHasExpired(at: sample.timestamp),
              let palm = validHandPoint(sample.palm),
              sample.faceBounds.x.isFinite,
              sample.faceBounds.y.isFinite,
              sample.faceBounds.width.isFinite,
              sample.faceBounds.height.isFinite else {
            return false
        }

        let scale = max(sample.faceBounds.width, sample.faceBounds.height)
        guard scale > 0 else { return false }

        let cutoff = sample.timestamp - configuration.handTimeWindow
        handHistory.removeAll { $0.timestamp < cutoff }
        handHistory.append(
            HandMovementPoint(
                timestamp: sample.timestamp,
                normalizedX: (palm.x - sample.faceBounds.midX) / scale,
                normalizedY: (palm.y - sample.faceBounds.midY) / scale
            )
        )

        guard isHandWave(handHistory) else { return false }
        recordTrigger(at: sample.timestamp)
        return true
    }

    private func valid(_ point: PosePoint?) -> PosePoint? {
        guard let point,
              point.x.isFinite,
              point.y.isFinite,
              point.confidence >= configuration.minimumConfidence else {
            return nil
        }
        return point
    }

    private mutating func updateHistory(
        hand: Hand,
        timestamp: Double,
        shoulder: PosePoint,
        elbow: PosePoint?,
        wrist: PosePoint?,
        shoulderWidth: Double
    ) {
        let cutoff = timestamp - configuration.timeWindow
        switch hand {
        case .left:
            leftHistory.removeAll { $0.timestamp < cutoff }
        case .right:
            rightHistory.removeAll { $0.timestamp < cutoff }
        }

        guard valid(elbow) != nil, let wrist = valid(wrist) else { return }

        let minimumWristY = shoulder.y
            - configuration.wristHeightTolerance * shoulderWidth
        guard wrist.y >= minimumWristY else {
            switch hand {
            case .left:
                leftHistory.removeAll(keepingCapacity: true)
            case .right:
                rightHistory.removeAll(keepingCapacity: true)
            }
            return
        }

        let point = MovementPoint(
            timestamp: timestamp,
            normalizedX: (wrist.x - shoulder.x) / shoulderWidth
        )
        switch hand {
        case .left:
            leftHistory.append(point)
        case .right:
            rightHistory.append(point)
        }
    }

    private func isWave(_ history: [MovementPoint]) -> Bool {
        guard history.count >= 4 else { return false }

        let xs = history.map(\.normalizedX)
        guard let minimum = xs.min(), let maximum = xs.max(),
              maximum - minimum >= configuration.minimumHorizontalAmplitude else {
            return false
        }

        var totalTravel = 0.0
        var previousDirection = 0
        var reversals = 0

        for index in 1..<xs.count {
            let delta = xs[index] - xs[index - 1]
            totalTravel += abs(delta)
            guard abs(delta) >= configuration.minimumDirectionalStep else {
                continue
            }

            let direction = delta > 0 ? 1 : -1
            if previousDirection != 0, direction != previousDirection {
                reversals += 1
            }
            previousDirection = direction
        }

        return totalTravel >= configuration.minimumTotalTravel
            && reversals >= configuration.minimumDirectionReversals
    }

    private func isHandWave(_ history: [HandMovementPoint]) -> Bool {
        guard history.count >= 4 else { return false }

        let xs = history.map(\.normalizedX)
        let ys = history.map(\.normalizedY)
        let xAmplitude = (xs.max() ?? 0) - (xs.min() ?? 0)
        let yAmplitude = (ys.max() ?? 0) - (ys.min() ?? 0)
        let dominantValues = xAmplitude >= yAmplitude ? xs : ys
        let amplitude = max(xAmplitude, yAmplitude)
        guard amplitude >= configuration.minimumHandAmplitude else { return false }

        var totalTravel = 0.0
        var previousDirection = 0
        var reversals = 0
        for index in 1..<dominantValues.count {
            let delta = dominantValues[index] - dominantValues[index - 1]
            totalTravel += abs(delta)
            guard abs(delta) >= configuration.minimumHandDirectionalStep else {
                continue
            }

            let direction = delta > 0 ? 1 : -1
            if previousDirection != 0, direction != previousDirection {
                reversals += 1
            }
            previousDirection = direction
        }

        return totalTravel >= configuration.minimumHandTotalTravel
            && reversals >= configuration.minimumDirectionReversals
    }

    private func cooldownHasExpired(at timestamp: Double) -> Bool {
        guard let lastTriggerTime else { return true }
        return timestamp - lastTriggerTime >= configuration.cooldown
    }

    private func validHandPoint(_ point: PosePoint) -> PosePoint? {
        guard point.x.isFinite,
              point.y.isFinite,
              point.confidence >= configuration.minimumHandConfidence else {
            return nil
        }
        return point
    }

    private mutating func recordTrigger(at timestamp: Double) {
        lastTriggerTime = timestamp
        leftHistory.removeAll(keepingCapacity: true)
        rightHistory.removeAll(keepingCapacity: true)
        handHistory.removeAll(keepingCapacity: true)
    }
}
