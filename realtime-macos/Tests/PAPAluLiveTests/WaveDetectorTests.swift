#if SWIFT_PACKAGE
@testable import PAPAluLive
#endif

private func pose(
    time: Double,
    wristX: Double,
    wristY: Double = 0.72,
    confidence: Double = 0.95
) -> BodyPoseSample {
    BodyPoseSample(
        timestamp: time,
        leftShoulder: PosePoint(x: 0.40, y: 0.60, confidence: confidence),
        rightShoulder: PosePoint(x: 0.60, y: 0.60, confidence: confidence),
        leftElbow: PosePoint(x: 0.34, y: 0.66, confidence: confidence),
        rightElbow: nil,
        leftWrist: PosePoint(x: wristX, y: wristY, confidence: confidence),
        rightWrist: nil
    )
}

private func rightPose(
    time: Double,
    wristX: Double,
    wristY: Double = 0.72,
    confidence: Double = 0.95
) -> BodyPoseSample {
    BodyPoseSample(
        timestamp: time,
        leftShoulder: PosePoint(x: 0.40, y: 0.60, confidence: confidence),
        rightShoulder: PosePoint(x: 0.60, y: 0.60, confidence: confidence),
        leftElbow: nil,
        rightElbow: PosePoint(x: 0.66, y: 0.66, confidence: confidence),
        leftWrist: nil,
        rightWrist: PosePoint(x: wristX, y: wristY, confidence: confidence)
    )
}

private func feed(
    _ detector: inout WaveDetector,
    xs: [Double],
    startTime: Double = 0,
    step: Double = 0.1,
    wristY: Double = 0.72,
    confidence: Double = 0.95
) -> [Bool] {
    xs.enumerated().map { index, x in
        detector.update(
            pose(
                time: startTime + Double(index) * step,
                wristX: x,
                wristY: wristY,
                confidence: confidence
            )
        )
    }
}

private func handPose(
    time: Double,
    x: Double = 0.95,
    y: Double,
    confidence: Double = 0.95
) -> HandPoseSample {
    HandPoseSample(
        timestamp: time,
        palm: PosePoint(x: x, y: y, confidence: confidence),
        faceBounds: NormalizedRect(x: 0.46, y: 0.02, width: 0.44, height: 0.58)
    )
}

private func feedHand(
    _ detector: inout WaveDetector,
    ys: [Double],
    startTime: Double = 0,
    step: Double = 0.1
) -> [Bool] {
    ys.enumerated().map { index, y in
        detector.update(
            handPose(time: startTime + Double(index) * step, y: y)
        )
    }
}

func testStationaryWristDoesNotTriggerWave() throws {
    var detector = WaveDetector()
    let results = feed(&detector, xs: Array(repeating: 0.25, count: 12))
    try expectEqual(results.contains(true), false, "stationary wrist must not trigger")
}

func testSmallWristMovementDoesNotTriggerWave() throws {
    var detector = WaveDetector()
    let results = feed(&detector, xs: [0.25, 0.27, 0.24, 0.28, 0.25, 0.27])
    try expectEqual(results.contains(true), false, "small movement must not trigger")
}

func testLowWristDoesNotTriggerWave() throws {
    var detector = WaveDetector()
    let results = feed(
        &detector,
        xs: [0.18, 0.34, 0.50, 0.32, 0.16],
        wristY: 0.42
    )
    try expectEqual(results.contains(true), false, "wrist below shoulder must not trigger")
}

func testClearWaveTriggersOnce() throws {
    var detector = WaveDetector()
    let results = feed(&detector, xs: [0.18, 0.30, 0.46, 0.34, 0.18])
    try expectEqual(results.filter { $0 }.count, 1, "clear out-and-back wave must trigger once")
}

func testGradualClearWaveTriggers() throws {
    var detector = WaveDetector()
    let results = feed(
        &detector,
        xs: [
            0.18, 0.22, 0.26, 0.30, 0.34, 0.38, 0.42, 0.46,
            0.42, 0.38, 0.34, 0.30, 0.26, 0.22, 0.18,
        ],
        step: 0.06
    )
    try expectEqual(
        results.filter { $0 }.count,
        1,
        "gradual visible wave must trigger once"
    )
}

func testRightHandWaveTriggers() throws {
    var detector = WaveDetector()
    let xs = [0.82, 0.70, 0.54, 0.66, 0.82]
    let results = xs.enumerated().map { index, x in
        detector.update(
            rightPose(time: Double(index) * 0.1, wristX: x)
        )
    }
    try expectEqual(results.filter { $0 }.count, 1, "right hand wave must trigger")
}

func testCooldownPreventsRepeatedWave() throws {
    var detector = WaveDetector()
    let first = feed(&detector, xs: [0.18, 0.30, 0.46, 0.34, 0.18])
    let second = feed(
        &detector,
        xs: [0.18, 0.30, 0.46, 0.34, 0.18],
        startTime: 0.8
    )

    try expectEqual(first.filter { $0 }.count, 1, "first wave must trigger")
    try expectEqual(second.contains(true), false, "cooldown must suppress repeat")
}

func testWaveCanTriggerAfterCooldown() throws {
    var detector = WaveDetector()
    _ = feed(&detector, xs: [0.18, 0.30, 0.46, 0.34, 0.18])
    let afterCooldown = feed(
        &detector,
        xs: [0.18, 0.30, 0.46, 0.34, 0.18],
        startTime: 3.0
    )

    try expectEqual(
        afterCooldown.filter { $0 }.count,
        1,
        "wave after cooldown must trigger"
    )
}

func testLowConfidencePoseIsIgnored() throws {
    var detector = WaveDetector()
    let results = feed(
        &detector,
        xs: [0.18, 0.30, 0.46, 0.34, 0.18],
        confidence: 0.2
    )
    try expectEqual(results.contains(true), false, "low confidence pose must be ignored")
}

func testHandFallbackDetectsWaveOnDominantAxis() throws {
    var detector = WaveDetector()
    let results = feedHand(&detector, ys: [0.05, 0.14, 0.27, 0.15, 0.05])
    try expectEqual(
        results.filter { $0 }.count,
        1,
        "hand fallback must detect the real camera's dominant-axis wave"
    )
}

func testHandFallbackDoesNotTriggerForStationaryHand() throws {
    var detector = WaveDetector()
    let results = feedHand(&detector, ys: Array(repeating: 0.08, count: 12))
    try expectEqual(results.contains(true), false, "stationary detected hand must not wave")
}

func testHandFallbackDoesNotTriggerForOneWayRaise() throws {
    var detector = WaveDetector()
    let results = feedHand(&detector, ys: [0.05, 0.10, 0.16, 0.22, 0.27])
    try expectEqual(results.contains(true), false, "one-way hand raise must not wave")
}

func testHandFallbackAcceptsModerateConfidenceWrist() throws {
    var detector = WaveDetector()
    let ys = [0.05, 0.14, 0.27, 0.15, 0.05]
    let results = ys.enumerated().map { index, y in
        detector.update(
            handPose(
                time: Double(index) * 0.1,
                y: y,
                confidence: 0.35
            )
        )
    }
    try expectEqual(
        results.filter { $0 }.count,
        1,
        "moderate-confidence wrist tracking must remain usable"
    )
}

func testHandFallbackRejectsVeryLowConfidenceWrist() throws {
    var detector = WaveDetector()
    let ys = [0.05, 0.14, 0.27, 0.15, 0.05]
    let results = ys.enumerated().map { index, y in
        detector.update(
            handPose(
                time: Double(index) * 0.1,
                y: y,
                confidence: 0.2
            )
        )
    }
    try expectEqual(
        results.contains(true),
        false,
        "very-low-confidence wrist tracking must be ignored"
    )
}

func testCooldownIsSharedAcrossBodyAndHandDetection() throws {
    var detector = WaveDetector()
    _ = feed(&detector, xs: [0.18, 0.30, 0.46, 0.34, 0.18])
    let handResults = feedHand(
        &detector,
        ys: [0.05, 0.14, 0.27, 0.15, 0.05],
        startTime: 0.8
    )
    try expectEqual(
        handResults.contains(true),
        false,
        "body and hand routes must share one cooldown"
    )
}

let waveDetectorTests: [(String, () throws -> Void)] = [
    ("stationary wrist does not wave", testStationaryWristDoesNotTriggerWave),
    ("small movement does not wave", testSmallWristMovementDoesNotTriggerWave),
    ("low wrist does not wave", testLowWristDoesNotTriggerWave),
    ("clear wave triggers once", testClearWaveTriggersOnce),
    ("gradual clear wave triggers", testGradualClearWaveTriggers),
    ("right hand wave triggers", testRightHandWaveTriggers),
    ("cooldown suppresses repeat", testCooldownPreventsRepeatedWave),
    ("wave works after cooldown", testWaveCanTriggerAfterCooldown),
    ("low confidence is ignored", testLowConfidencePoseIsIgnored),
    ("hand fallback detects dominant-axis wave", testHandFallbackDetectsWaveOnDominantAxis),
    ("stationary detected hand does not wave", testHandFallbackDoesNotTriggerForStationaryHand),
    ("one-way hand raise does not wave", testHandFallbackDoesNotTriggerForOneWayRaise),
    ("moderate-confidence wrist remains usable", testHandFallbackAcceptsModerateConfidenceWrist),
    ("very-low-confidence wrist is ignored", testHandFallbackRejectsVeryLowConfidenceWrist),
    ("body and hand routes share cooldown", testCooldownIsSharedAcrossBodyAndHandDetection),
]
