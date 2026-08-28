import AppKit
import QuartzCore

enum PAPAluDisplayState: Equatable {
    case idle
    case talking
}

enum PAPAluWindowError: LocalizedError {
    case resourceDirectoryMissing
    case frameMissing(Int)

    var errorDescription: String? {
        switch self {
        case .resourceDirectoryMissing:
            return "PAPAlu 动画资源目录不存在。"
        case .frameMissing(let frame):
            return "PAPAlu 动画第 \(frame) 帧缺失。"
        }
    }
}

private final class DraggableImageView: NSImageView {
    override var mouseDownCanMoveWindow: Bool { true }
}

private final class DraggableContainerView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
}

final class PAPAluWindow: NSPanel {
    struct Configuration {
        static let defaultSize = NSSize(width: 288, height: 312)
        static let talkingFrames = [2, 1, 3, 4, 6, 3]
        static let talkingFramesPerSecond = 8.0
    }

    private let frames: [NSImage]
    private let idlePlan: IdleAnimationPlan
    private let thoughtCloudPlan: ThoughtCloudPlan
    private let containerView = DraggableContainerView()
    private let characterView = DraggableImageView()
    private let thoughtCloudView: ThoughtCloudView
    private var animationTimer: Timer?
    private var idleBlinkTimer: Timer?
    private var idleSequenceTimer: Timer?
    private var idleSwayTimer: Timer?
    private var thoughtCloudDelayTimer: Timer?
    private var thoughtCloudDotTimer: Timer?
    private var thoughtCloudDotIndex = 0
    private var idleGeneration = 0
    private var talkingFrameIndex = 0
    private var displayState: PAPAluDisplayState?
    private var windowScale = WindowScale()

    init(
        resourceDirectory: URL? = Bundle.main.resourceURL,
        idlePlan: IdleAnimationPlan = IdleAnimationPlan(),
        thoughtCloudPlan: ThoughtCloudPlan = ThoughtCloudPlan()
    ) throws {
        self.idlePlan = idlePlan
        self.thoughtCloudPlan = thoughtCloudPlan
        thoughtCloudView = ThoughtCloudView(plan: thoughtCloudPlan)
        guard let resourceDirectory else {
            throw PAPAluWindowError.resourceDirectoryMissing
        }

        var loadedFrames = [NSImage]()
        for frame in 0..<8 {
            let path = resourceDirectory
                .appendingPathComponent("Frames", isDirectory: true)
                .appendingPathComponent("\(frame).png")
            guard let image = NSImage(contentsOf: path) else {
                throw PAPAluWindowError.frameMissing(frame)
            }
            loadedFrames.append(image)
        }
        frames = loadedFrames

        let size = Configuration.defaultSize
        let origin = Self.defaultOrigin(for: size)
        super.init(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        sharingType = .readOnly
        animationBehavior = .none
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false

        containerView.frame = NSRect(origin: .zero, size: size)
        containerView.autoresizingMask = [.width, .height]

        characterView.frame = containerView.bounds
        characterView.autoresizingMask = [.width, .height]
        characterView.imageAlignment = .alignCenter
        characterView.imageScaling = .scaleProportionallyUpOrDown
        characterView.image = frames[0]
        characterView.wantsLayer = true

        thoughtCloudView.isHidden = true
        thoughtCloudView.alphaValue = 0
        layoutThoughtCloud(for: size)

        containerView.addSubview(characterView)
        containerView.addSubview(thoughtCloudView)
        contentView = containerView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func setDisplayState(_ state: PAPAluDisplayState) {
        guard state != displayState else { return }
        let previousState = displayState
        displayState = state
        cancelAllAnimation()

        switch state {
        case .idle:
            startIdleAnimation(settlingFromTalking: previousState == .talking)
        case .talking:
            talkingFrameIndex = 0
            showTalkingFrame()
            startAnimationTimer()
        }
    }

    func increaseScale() {
        windowScale.increase()
        applyCurrentScale()
    }

    func decreaseScale() {
        windowScale.decrease()
        applyCurrentScale()
    }

    func resetScale() {
        windowScale.reset()
        applyCurrentScale()
    }

    private func applyCurrentScale() {
        let center = NSPoint(x: frame.midX, y: frame.midY)
        let size = NSSize(
            width: Configuration.defaultSize.width * windowScale.factor,
            height: Configuration.defaultSize.height * windowScale.factor
        )
        let origin = NSPoint(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2
        )
        setFrame(NSRect(origin: origin, size: size), display: true, animate: false)
        layoutThoughtCloud(for: size)
    }

    private func startAnimationTimer() {
        animationTimer?.invalidate()
        let timer = Timer(
            timeInterval: 1 / Configuration.talkingFramesPerSecond,
            repeats: true
        ) { [weak self] _ in
            guard let self else { return }
            self.talkingFrameIndex = (
                self.talkingFrameIndex + 1
            ) % Configuration.talkingFrames.count
            self.showTalkingFrame()
        }
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    private func cancelAllAnimation() {
        idleGeneration += 1
        animationTimer?.invalidate()
        animationTimer = nil
        idleBlinkTimer?.invalidate()
        idleBlinkTimer = nil
        idleSequenceTimer?.invalidate()
        idleSequenceTimer = nil
        idleSwayTimer?.invalidate()
        idleSwayTimer = nil
        hideThoughtCloud()
        resetCharacterTransform()
    }

    private func showTalkingFrame() {
        let frame = Configuration.talkingFrames[talkingFrameIndex]
        characterView.image = frames[frame]
    }

    private func startIdleAnimation(settlingFromTalking: Bool) {
        let generation = idleGeneration
        scheduleThoughtCloud(generation: generation)
        let beginEvents: () -> Void = { [weak self] in
            guard let self else { return }
            self.scheduleNextBlink(generation: generation)
            let firstDirection: IdleSwayDirection = Bool.random()
                ? .left
                : .right
            self.runNextSway(
                direction: firstDirection,
                generation: generation
            )
        }

        if settlingFromTalking {
            playIdleSequence(
                idlePlan.configuration.settleSteps,
                generation: generation,
                completion: beginEvents
            )
        } else {
            characterView.image = frames[idlePlan.configuration.baseFrame]
            beginEvents()
        }
    }

    private func scheduleThoughtCloud(generation: Int) {
        thoughtCloudDelayTimer = makeTimer(
            after: thoughtCloudPlan.configuration.appearanceDelay
        ) { [weak self] in
            guard let self,
                  self.displayState == .idle,
                  generation == self.idleGeneration else { return }
            self.showThoughtCloud(generation: generation)
        }
    }

    private func showThoughtCloud(generation: Int) {
        thoughtCloudView.setActiveDotIndex(0)
        thoughtCloudView.alphaValue = 0
        thoughtCloudView.isHidden = false

        NSAnimationContext.runAnimationGroup { context in
            context.duration = thoughtCloudPlan.configuration.fadeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            thoughtCloudView.animator().alphaValue = 1
        }

        let timer = Timer(
            timeInterval: thoughtCloudPlan.configuration.dotStepInterval,
            repeats: true
        ) { [weak self] _ in
            guard let self,
                  self.displayState == .idle,
                  generation == self.idleGeneration else { return }
            self.thoughtCloudDotIndex = self.thoughtCloudPlan.nextDotIndex(
                after: self.thoughtCloudDotIndex
            )
            self.thoughtCloudView.setActiveDotIndex(
                self.thoughtCloudDotIndex
            )
        }
        thoughtCloudDotIndex = 0
        RunLoop.main.add(timer, forMode: .common)
        thoughtCloudDotTimer = timer
    }

    private func hideThoughtCloud() {
        thoughtCloudDelayTimer?.invalidate()
        thoughtCloudDelayTimer = nil
        thoughtCloudDotTimer?.invalidate()
        thoughtCloudDotTimer = nil
        thoughtCloudDotIndex = 0
        thoughtCloudView.layer?.removeAllAnimations()
        thoughtCloudView.alphaValue = 0
        thoughtCloudView.isHidden = true
        thoughtCloudView.setActiveDotIndex(0)
    }

    private func layoutThoughtCloud(for windowSize: NSSize) {
        let frame = thoughtCloudPlan.frame(
            windowWidth: windowSize.width,
            windowHeight: windowSize.height
        )
        thoughtCloudView.frame = NSRect(
            x: frame.x,
            y: frame.y,
            width: frame.width,
            height: frame.height
        )
    }

    private func scheduleNextBlink(generation: Int) {
        guard displayState == .idle, generation == idleGeneration else { return }

        let delay = idlePlan.blinkDelay(
            randomUnit: Double.random(in: 0...1)
        )
        idleBlinkTimer = makeTimer(after: delay) { [weak self] in
            guard let self else { return }
            self.playIdleSequence(
                self.idlePlan.configuration.blinkSteps,
                generation: generation
            ) { [weak self] in
                self?.scheduleNextBlink(generation: generation)
            }
        }
    }

    private func runNextSway(
        direction: IdleSwayDirection,
        generation: Int
    ) {
        guard displayState == .idle, generation == idleGeneration else { return }
        let step = idlePlan.swayStep(
            direction: direction,
            durationRandomUnit: Double.random(in: 0...1),
            holdRandomUnit: Double.random(in: 0...1)
        )
        animateCharacter(to: step)

        idleSwayTimer = makeTimer(
            after: step.duration + step.holdDuration
        ) { [weak self] in
            self?.runNextSway(
                direction: direction == .left ? .right : .left,
                generation: generation
            )
        }
    }

    private func animateCharacter(to step: IdleSwayStep) {
        guard let layer = characterView.layer else { return }
        let radians = CGFloat(step.rotationDegrees * .pi / 180)
        var transform = CATransform3DMakeTranslation(
            CGFloat(step.horizontalOffset),
            0,
            0
        )
        transform = CATransform3DRotate(transform, radians, 0, 0, 1)

        let animation = CABasicAnimation(keyPath: "transform")
        animation.fromValue = layer.presentation()?.transform ?? layer.transform
        animation.toValue = transform
        animation.duration = step.duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = transform
        CATransaction.commit()
        layer.add(animation, forKey: "papaluIdleSway")
    }

    private func resetCharacterTransform() {
        guard let layer = characterView.layer else { return }
        layer.removeAnimation(forKey: "papaluIdleSway")
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = CATransform3DIdentity
        CATransaction.commit()
    }

    private func playIdleSequence(
        _ steps: [IdleFrameStep],
        index: Int = 0,
        generation: Int,
        completion: @escaping () -> Void
    ) {
        guard displayState == .idle, generation == idleGeneration else { return }
        guard index < steps.count else {
            completion()
            return
        }

        let step = steps[index]
        characterView.image = frames[step.frame]
        idleSequenceTimer = makeTimer(after: step.duration) { [weak self] in
            self?.playIdleSequence(
                steps,
                index: index + 1,
                generation: generation,
                completion: completion
            )
        }
    }

    private func makeTimer(
        after delay: Double,
        action: @escaping () -> Void
    ) -> Timer {
        let timer = Timer(
            timeInterval: max(0, delay),
            repeats: false
        ) { _ in
            action()
        }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    private static func defaultOrigin(for size: NSSize) -> NSPoint {
        guard let visibleFrame = NSScreen.main?.visibleFrame else {
            return NSPoint(x: 80, y: 80)
        }
        return NSPoint(
            x: visibleFrame.maxX - size.width - 36,
            y: visibleFrame.minY + 36
        )
    }
}
