import Darwin

do {
    for (name, test) in mouthGateTests {
        try test()
        print("PASS: \(name)")
    }
    print("\(mouthGateTests.count) tests passed")
} catch {
    print("FAIL: \(error)")
    exit(EXIT_FAILURE)
}
