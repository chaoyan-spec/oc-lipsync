#if SWIFT_PACKAGE
@testable import PAPAluLive
#endif

private func expectClose(
    _ actual: Double,
    _ expected: Double,
    _ message: String
) throws {
    guard abs(actual - expected) < 0.000_001 else {
        throw TestFailure(
            description: "\(message): expected \(expected), got \(actual)"
        )
    }
}

func testThoughtCloudUsesApprovedTiming() throws {
    let configuration = ThoughtCloudConfiguration.default

    try expectEqual(configuration.appearanceDelay, 0.5, "appearance delay")
    try expectEqual(configuration.fadeDuration, 0.18, "fade duration")
    try expectEqual(configuration.dotStepInterval, 0.3, "dot step interval")
}

func testThoughtCloudDotsAdvanceInOrder() throws {
    let plan = ThoughtCloudPlan()

    try expectEqual(plan.nextDotIndex(after: 0), 1, "first dot advances to second")
    try expectEqual(plan.nextDotIndex(after: 1), 2, "second dot advances to third")
    try expectEqual(plan.nextDotIndex(after: 2), 0, "third dot wraps to first")
}

func testThoughtCloudHighlightsOnlyTheActiveDot() throws {
    let plan = ThoughtCloudPlan()

    try expectEqual(
        plan.dotAlphas(activeIndex: 1),
        [0.35, 1.0, 0.35],
        "only the current dot should be fully visible"
    )
}

func testThoughtCloudLayoutScalesWithTheWindow() throws {
    let plan = ThoughtCloudPlan()
    let natural = plan.frame(windowWidth: 288, windowHeight: 312)
    let doubled = plan.frame(windowWidth: 576, windowHeight: 624)

    try expectClose(natural.x, 172.8, "natural x")
    try expectClose(natural.y, 240.24, "natural y")
    try expectClose(natural.width, 86.4, "natural width")
    try expectClose(natural.height, 56.16, "natural height")
    try expectClose(doubled.x, natural.x * 2, "scaled x")
    try expectClose(doubled.y, natural.y * 2, "scaled y")
    try expectClose(doubled.width, natural.width * 2, "scaled width")
    try expectClose(doubled.height, natural.height * 2, "scaled height")
}

let thoughtCloudPlanTests: [(String, () throws -> Void)] = [
    ("thought cloud uses approved timing", testThoughtCloudUsesApprovedTiming),
    ("thought cloud dots advance in order", testThoughtCloudDotsAdvanceInOrder),
    ("thought cloud highlights one dot", testThoughtCloudHighlightsOnlyTheActiveDot),
    ("thought cloud layout scales", testThoughtCloudLayoutScalesWithTheWindow),
]
