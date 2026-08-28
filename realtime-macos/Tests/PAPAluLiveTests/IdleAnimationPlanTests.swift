#if SWIFT_PACKAGE
@testable import PAPAluLive
#endif

func testIdleUsesApprovedExistingFrames() throws {
    let configuration = IdleAnimationConfiguration.default

    try expectEqual(configuration.baseFrame, 0, "idle base frame")
    try expectEqual(
        configuration.blinkSteps.map(\.frame),
        [5, 7, 0],
        "blink must use the approved blink and closed frames"
    )
    try expectEqual(
        configuration.settleSteps.map(\.frame),
        [3, 1, 7, 0],
        "talking-to-idle must close the mouth gradually"
    )
}

func testIdleSwayUsesOpposingVisiblePoses() throws {
    let plan = IdleAnimationPlan()
    let left = plan.swayStep(
        direction: .left,
        durationRandomUnit: 0.5,
        holdRandomUnit: 0.5
    )
    let right = plan.swayStep(
        direction: .right,
        durationRandomUnit: 0.5,
        holdRandomUnit: 0.5
    )

    try expectEqual(left.horizontalOffset, -4, "left horizontal offset")
    try expectEqual(left.rotationDegrees, -1, "left rotation")
    try expectEqual(right.horizontalOffset, 4, "right horizontal offset")
    try expectEqual(right.rotationDegrees, 1, "right rotation")
    try expectEqual(left.duration, right.duration, "opposing sway duration")
    try expectEqual(left.holdDuration, right.holdDuration, "opposing sway hold")
}

func testSwayAndBlinkRandomMappingStaysInApprovedRanges() throws {
    let plan = IdleAnimationPlan()

    let minimum = plan.swayStep(
        direction: .left,
        durationRandomUnit: 0,
        holdRandomUnit: 0
    )
    let maximum = plan.swayStep(
        direction: .right,
        durationRandomUnit: 1,
        holdRandomUnit: 1
    )

    try expectEqual(minimum.duration, 0.95, "minimum sway duration")
    try expectEqual(maximum.duration, 1.15, "maximum sway duration")
    try expectEqual(minimum.holdDuration, 0.08, "minimum sway hold")
    try expectEqual(maximum.holdDuration, 0.25, "maximum sway hold")
    try expectEqual(plan.blinkDelay(randomUnit: 0), 3.0, "minimum blink delay")
    try expectEqual(plan.blinkDelay(randomUnit: 1), 5.0, "maximum blink delay")
}

func testRandomDelayMappingClampsInvalidInputs() throws {
    let plan = IdleAnimationPlan()
    let minimum = plan.swayStep(
        direction: .left,
        durationRandomUnit: -4,
        holdRandomUnit: .nan
    )
    let maximum = plan.swayStep(
        direction: .right,
        durationRandomUnit: 4,
        holdRandomUnit: 4
    )

    try expectEqual(minimum.duration, 0.95, "negative sway random unit")
    try expectEqual(minimum.holdDuration, 0.08, "non-finite hold random unit")
    try expectEqual(maximum.duration, 1.15, "large sway random unit")
    try expectEqual(maximum.holdDuration, 0.25, "large hold random unit")
    try expectEqual(plan.blinkDelay(randomUnit: .nan), 3.0, "non-finite random unit")
}

func testIdleEventDurationsStayRestrained() throws {
    let configuration = IdleAnimationConfiguration.default
    let blinkDuration = configuration.blinkSteps.reduce(0) { $0 + $1.duration }
    let settleDuration = configuration.settleSteps.reduce(0) { $0 + $1.duration }

    try expectEqual(blinkDuration, 0.33, "blink duration")
    try expectEqual(settleDuration, 0.32, "settle duration")
}

func testTalkingStartsWithClearlyOpenMouth() throws {
    try expectEqual(
        PAPAluWindow.Configuration.talkingFrames.first,
        2,
        "talking must start with a clearly open mouth"
    )
}

let idleAnimationPlanTests: [(String, () throws -> Void)] = [
    ("idle uses approved existing frames", testIdleUsesApprovedExistingFrames),
    ("idle sway uses opposing visible poses", testIdleSwayUsesOpposingVisiblePoses),
    (
        "idle sway and blink random values stay in range",
        testSwayAndBlinkRandomMappingStaysInApprovedRanges
    ),
    ("idle random delays clamp invalid inputs", testRandomDelayMappingClampsInvalidInputs),
    ("idle event durations stay restrained", testIdleEventDurationsStayRestrained),
    ("talking starts with clearly open mouth", testTalkingStartsWithClearlyOpenMouth),
]
