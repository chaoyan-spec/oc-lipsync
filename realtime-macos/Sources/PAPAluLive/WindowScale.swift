struct WindowScale {
    private static let minimum = 0.5
    private static let maximum = 2.0
    private static let defaultFactor = 1.0
    private static let step = 0.1

    private(set) var factor = Self.defaultFactor

    mutating func increase() {
        factor = min(Self.maximum, rounded(factor + Self.step))
    }

    mutating func decrease() {
        factor = max(Self.minimum, rounded(factor - Self.step))
    }

    mutating func reset() {
        factor = Self.defaultFactor
    }

    private func rounded(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
}
