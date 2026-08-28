#if SWIFT_PACKAGE
@testable import PAPAluLive
#endif

struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

func expectEqual<T: Equatable>(
    _ actual: T,
    _ expected: T,
    _ message: String
) throws {
    guard actual == expected else {
        throw TestFailure(description: "\(message): expected \(expected), got \(actual)")
    }
}

private let step = 0.01

func testDefaultGateUsesApprovedMidSentenceProtection() throws {
    let configuration = MouthGateConfiguration.default

    try expectEqual(configuration.openThreshold, 0.020, "default open threshold")
    try expectEqual(configuration.closeThreshold, 0.015, "default close threshold")
    try expectEqual(configuration.smoothingFactor, 0.35, "default smoothing")
    try expectEqual(configuration.releaseDelay, 0.30, "default release delay")
}

func testSilenceKeepsTheMouthIdle() throws {
    var gate = MouthGate()

    for _ in 0..<100 {
        try expectEqual(
            gate.update(rms: 0.003, duration: step),
            .idle,
            "silence must stay idle"
        )
    }
}

func testClearSpeechEntersTalkingImmediately() throws {
    var gate = MouthGate()

    try expectEqual(
        gate.update(rms: 0.10, duration: step),
        .talking,
        "clear speech must enter talking"
    )
}

func testClearSpeechAfterSilenceEntersTalkingOnFirstBuffer() throws {
    var gate = MouthGate()

    for _ in 0..<100 {
        try expectEqual(
            gate.update(rms: 0.003, duration: step),
            .idle,
            "silence must stay idle before speech"
        )
    }

    try expectEqual(
        gate.update(rms: 0.03, duration: step),
        .talking,
        "first clear speech buffer after silence must open the mouth"
    )
}

func testShortSilenceDoesNotCloseTheMouth() throws {
    var gate = MouthGate()
    try expectEqual(gate.update(rms: 0.10, duration: step), .talking, "speech attack")

    for _ in 0..<8 {
        try expectEqual(
            gate.update(rms: 0, duration: step),
            .talking,
            "short silence must remain talking"
        )
    }
}

func testNaturalMidSentencePauseDoesNotCloseTheMouth() throws {
    var gate = MouthGate()
    try expectEqual(gate.update(rms: 0.10, duration: step), .talking, "speech attack")

    for _ in 0..<20 {
        try expectEqual(
            gate.update(rms: 0, duration: step),
            .talking,
            "a 200ms phrase gap must remain talking"
        )
    }
}

func testSoftSpeechCanRestartAfterSilence() throws {
    var gate = MouthGate()

    try expectEqual(
        gate.update(rms: 0.020, duration: step),
        .talking,
        "soft but intentional speech must open the mouth"
    )
}

func testSubThresholdBackgroundNoiseStaysIdle() throws {
    var gate = MouthGate()

    for _ in 0..<100 {
        try expectEqual(
            gate.update(rms: 0.019, duration: step),
            .idle,
            "background sound below the open threshold must stay idle"
        )
    }
}

func testSilencePastNewReleaseDelayReturnsToIdle() throws {
    var gate = MouthGate()
    try expectEqual(gate.update(rms: 0.10, duration: step), .talking, "speech attack")

    var state = MouthState.talking
    for _ in 0..<50 {
        state = gate.update(rms: 0, duration: step)
    }

    try expectEqual(state, .idle, "sustained silence must still return to idle")
}

func testSilencePastReleaseDelayReturnsToIdle() throws {
    var gate = MouthGate()
    try expectEqual(gate.update(rms: 0.10, duration: step), .talking, "speech attack")

    var state = MouthState.talking
    for _ in 0..<40 {
        state = gate.update(rms: 0, duration: step)
    }

    try expectEqual(state, .idle, "long silence must return to idle")
}

func testHysteresisPreventsThresholdChatter() throws {
    let configuration = MouthGateConfiguration(
        openThreshold: 0.025,
        closeThreshold: 0.015,
        smoothingFactor: 1,
        releaseDelay: 0.12
    )
    var gate = MouthGate(configuration: configuration)

    for rms in [0.024, 0.016, 0.023, 0.017, 0.024] {
        try expectEqual(
            gate.update(rms: rms, duration: 0.03),
            .idle,
            "sub-open noise must stay idle"
        )
    }

    try expectEqual(
        gate.update(rms: 0.04, duration: 0.03),
        .talking,
        "speech must open the mouth"
    )

    for rms in [0.020, 0.014, 0.020, 0.014, 0.020, 0.014] {
        try expectEqual(
            gate.update(rms: rms, duration: 0.03),
            .talking,
            "threshold noise must not chatter"
        )
    }
}

let mouthGateTests: [(String, () throws -> Void)] = [
    (
        "default gate protects mid-sentence speech",
        testDefaultGateUsesApprovedMidSentenceProtection
    ),
    ("silence keeps idle", testSilenceKeepsTheMouthIdle),
    ("speech enters talking", testClearSpeechEntersTalkingImmediately),
    (
        "speech after silence enters talking on first buffer",
        testClearSpeechAfterSilenceEntersTalkingOnFirstBuffer
    ),
    ("short silence stays talking", testShortSilenceDoesNotCloseTheMouth),
    (
        "natural mid-sentence pause stays talking",
        testNaturalMidSentencePauseDoesNotCloseTheMouth
    ),
    ("soft speech restarts talking", testSoftSpeechCanRestartAfterSilence),
    ("sub-threshold noise stays idle", testSubThresholdBackgroundNoiseStaysIdle),
    (
        "new release delay still returns idle",
        testSilencePastNewReleaseDelayReturnsToIdle
    ),
    ("release returns idle", testSilencePastReleaseDelayReturnsToIdle),
    ("hysteresis prevents chatter", testHysteresisPreventsThresholdChatter),
]
