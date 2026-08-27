#if SWIFT_PACKAGE
@testable import PAPAluLive
#endif

func testWindowScaleStartsAtDefaultAndMovesByOneStep() throws {
    var scale = WindowScale()
    try expectEqual(scale.factor, 1.0, "scale must start at default")

    scale.increase()
    try expectEqual(scale.factor, 1.1, "increase must add one step")

    scale.decrease()
    try expectEqual(scale.factor, 1.0, "decrease must subtract one step")
}

func testWindowScaleClampsToMinimumAndMaximum() throws {
    var scale = WindowScale()

    for _ in 0..<30 { scale.decrease() }
    try expectEqual(scale.factor, 0.5, "scale must stop at minimum")

    for _ in 0..<30 { scale.increase() }
    try expectEqual(scale.factor, 2.0, "scale must stop at maximum")
}

func testWindowScaleResetsToDefault() throws {
    var scale = WindowScale()
    scale.increase()
    scale.increase()
    scale.reset()

    try expectEqual(scale.factor, 1.0, "reset must restore default")
}

let windowScaleTests: [(String, () throws -> Void)] = [
    ("window scale steps from default", testWindowScaleStartsAtDefaultAndMovesByOneStep),
    ("window scale clamps to bounds", testWindowScaleClampsToMinimumAndMaximum),
    ("window scale resets", testWindowScaleResetsToDefault),
]
