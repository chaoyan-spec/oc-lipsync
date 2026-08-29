#if SWIFT_PACKAGE
@testable import PAPAluLive
#endif

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
}

func testTalkingStartsWithClearlyOpenMouth() throws {
    try expectEqual(
        CharacterDefinition.papalu.talkingAssetNames.first,
        "2",
        "talking must start with a clearly open mouth"
    )
}

let idleAnimationPlanTests: [(String, () throws -> Void)] = [
    ("idle sway uses opposing visible poses", testIdleSwayUsesOpposingVisiblePoses),
    (
        "idle sway and blink random values stay in range",
        testSwayAndBlinkRandomMappingStaysInApprovedRanges
    ),
    ("idle random delays clamp invalid inputs", testRandomDelayMappingClampsInvalidInputs),
    ("talking starts with clearly open mouth", testTalkingStartsWithClearlyOpenMouth),
]
