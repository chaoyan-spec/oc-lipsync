#if SWIFT_PACKAGE
@testable import PAPAluLive
#endif

func testTeachingReturnsToCurrentTalkingState() throws {
    var coordinator = ActionCoordinator(teachingDuration: 0.8)
    coordinator.updateBaseState(.idle)

    try expectEqual(
        coordinator.triggerTeaching(at: 1.0),
        .teaching,
        "wave must show teaching"
    )

    coordinator.updateBaseState(.talking)
    try expectEqual(
        coordinator.displayState(at: 1.81),
        .talking,
        "expired action must use current talking state"
    )
}

func testTeachingReturnsToCurrentIdleState() throws {
    var coordinator = ActionCoordinator(teachingDuration: 0.8)
    coordinator.updateBaseState(.talking)
    _ = coordinator.triggerTeaching(at: 1.0)

    coordinator.updateBaseState(.idle)
    try expectEqual(
        coordinator.displayState(at: 1.81),
        .idle,
        "expired action must use current idle state"
    )
}

let actionCoordinatorTests: [(String, () throws -> Void)] = [
    ("teaching returns to current talking", testTeachingReturnsToCurrentTalkingState),
    ("teaching returns to current idle", testTeachingReturnsToCurrentIdleState),
]
