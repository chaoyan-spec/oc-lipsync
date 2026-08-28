#if SWIFT_PACKAGE
@testable import PAPAluLive
#endif

func testIdleUsesApprovedExistingFrames() throws {
    let configuration = IdleAnimationConfiguration.default

    try expectEqual(configuration.baseFrame, 0, "idle base frame")
    try expectEqual(
        configuration.breathSteps.map(\.frame),
        [7, 0],
        "breath must use closed-mouth frames"
    )
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

func testRandomDelayMappingStaysInApprovedRanges() throws {
    let plan = IdleAnimationPlan()

    try expectEqual(plan.breathDelay(randomUnit: 0), 2.8, "minimum breath delay")
    try expectEqual(plan.breathDelay(randomUnit: 1), 4.8, "maximum breath delay")
    try expectEqual(plan.blinkDelay(randomUnit: 0), 5.5, "minimum blink delay")
    try expectEqual(plan.blinkDelay(randomUnit: 1), 9.0, "maximum blink delay")
}

func testRandomDelayMappingClampsInvalidInputs() throws {
    let plan = IdleAnimationPlan()

    try expectEqual(plan.breathDelay(randomUnit: -4), 2.8, "negative random unit")
    try expectEqual(plan.breathDelay(randomUnit: 4), 4.8, "large random unit")
    try expectEqual(plan.blinkDelay(randomUnit: .nan), 5.5, "non-finite random unit")
}

func testBlinkWinsWhenItsDeadlineIsSoonerOrEqual() throws {
    let plan = IdleAnimationPlan()

    try expectEqual(
        plan.nextEvent(breathDelay: 3.2, blinkDelay: 1.4),
        .blink(after: 1.4),
        "earlier blink must win"
    )
    try expectEqual(
        plan.nextEvent(breathDelay: 2.0, blinkDelay: 2.0),
        .blink(after: 2.0),
        "blink must win a tie"
    )
    try expectEqual(
        plan.nextEvent(breathDelay: 1.2, blinkDelay: 4.0),
        .breath(after: 1.2),
        "earlier breath must win"
    )
}

func testIdleEventDurationsStayRestrained() throws {
    let configuration = IdleAnimationConfiguration.default
    let breathDuration = configuration.breathSteps.reduce(0) { $0 + $1.duration }
    let blinkDuration = configuration.blinkSteps.reduce(0) { $0 + $1.duration }
    let settleDuration = configuration.settleSteps.reduce(0) { $0 + $1.duration }

    try expectEqual(breathDuration, 0.56, "breath duration")
    try expectEqual(blinkDuration, 0.33, "blink duration")
    try expectEqual(settleDuration, 0.32, "settle duration")
}

let idleAnimationPlanTests: [(String, () throws -> Void)] = [
    ("idle uses approved existing frames", testIdleUsesApprovedExistingFrames),
    ("idle random delays stay in range", testRandomDelayMappingStaysInApprovedRanges),
    ("idle random delays clamp invalid inputs", testRandomDelayMappingClampsInvalidInputs),
    ("blink wins an earlier or tied deadline", testBlinkWinsWhenItsDeadlineIsSoonerOrEqual),
    ("idle event durations stay restrained", testIdleEventDurationsStayRestrained),
]

