import Darwin

do {
    let tests = mouthGateTests
        + windowScaleTests
        + idleAnimationPlanTests
        + thoughtCloudPlanTests
        + characterDefinitionTests
        + characterRuntimeTests
    for (name, test) in tests {
        try test()
        print("PASS: \(name)")
    }
    print("\(tests.count) tests passed")
} catch {
    print("FAIL: \(error)")
    exit(EXIT_FAILURE)
}
