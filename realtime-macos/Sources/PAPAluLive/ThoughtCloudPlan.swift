struct ThoughtCloudFrame: Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct ThoughtCloudConfiguration: Equatable {
    static let `default` = ThoughtCloudConfiguration(
        appearanceDelay: 0.5,
        fadeDuration: 0.18,
        dotStepInterval: 0.3,
        inactiveDotAlpha: 0.35,
        activeDotAlpha: 1.0,
        normalizedFrame: ThoughtCloudFrame(
            x: 0.525,
            y: 0.725,
            width: 0.45,
            height: 0.27
        )
    )

    let appearanceDelay: Double
    let fadeDuration: Double
    let dotStepInterval: Double
    let inactiveDotAlpha: Double
    let activeDotAlpha: Double
    let normalizedFrame: ThoughtCloudFrame
}

struct ThoughtCloudPlan {
    let configuration: ThoughtCloudConfiguration

    init(configuration: ThoughtCloudConfiguration = .default) {
        self.configuration = configuration
    }

    func nextDotIndex(after currentIndex: Int) -> Int {
        (max(0, currentIndex) + 1) % 3
    }

    func dotAlphas(activeIndex: Int) -> [Double] {
        (0..<3).map { index in
            index == activeIndex
                ? configuration.activeDotAlpha
                : configuration.inactiveDotAlpha
        }
    }

    func frame(windowWidth: Double, windowHeight: Double) -> ThoughtCloudFrame {
        let normalized = configuration.normalizedFrame
        return ThoughtCloudFrame(
            x: normalized.x * windowWidth,
            y: normalized.y * windowHeight,
            width: normalized.width * windowWidth,
            height: normalized.height * windowHeight
        )
    }
}
