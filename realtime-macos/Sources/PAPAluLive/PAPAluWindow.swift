import AppKit
import QuartzCore

enum PAPAluWindowError: LocalizedError {
    case resourceDirectoryMissing
    case frameMissing(Int)
    case teachingImageMissing

    var errorDescription: String? {
        switch self {
        case .resourceDirectoryMissing:
            return "PAPAlu 动画资源目录不存在。"
        case .frameMissing(let frame):
            return "PAPAlu 动画第 \(frame) 帧缺失。"
        case .teachingImageMissing:
            return "PAPAlu teaching 正式素材缺失。"
        }
    }
}

private final class DraggableImageView: NSImageView {
    override var mouseDownCanMoveWindow: Bool { true }
}

final class PAPAluWindow: NSPanel {
    struct Configuration {
        static let defaultSize = NSSize(width: 288, height: 312)
        static let talkingFrames = [2, 1, 3, 4, 6, 3]
        static let talkingFramesPerSecond = 8.0
    }

    private let frames: [NSImage]
    private let teachingImage: NSImage
    private let idlePlan: IdleAnimationPlan
    private let characterView = DraggableImageView()
    private var animationTimer: Timer?
    private var idleBlinkTimer: Timer?
    private var idleSequenceTimer: Timer?
    private var idleSwayTimer: Timer?
    private var idleGeneration = 0
    private var talkingFrameIndex = 0
    private var displayState: PAPAluDisplayState?
    private var windowScale = WindowScale()

    init(
        resourceDirectory: URL? = Bundle.main.resourceURL,
        idlePlan: IdleAnimationPlan = IdleAnimationPlan()
    ) throws {
        self.idlePlan = idlePlan
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

        let teachingPath = resourceDirectory.appendingPathComponent("Teaching.png")
        guard let teachingImage = NSImage(contentsOf: teachingPath) else {
            throw PAPAluWindowError.teachingImageMissing
        }
        self.teachingImage = teachingImage

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

        characterView.frame = NSRect(origin: .zero, size: size)
        characterView.autoresizingMask = [.width, .height]
        characterView.imageAlignment = .alignCenter
        characterView.imageScaling = .scaleProportionallyUpOrDown
        characterView.image = frames[0]
        characterView.wantsLayer = true
        contentView = characterView
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
        case .teaching:
            characterView.image = teachingImage
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
        resetCharacterTransform()
    }

    private func showTalkingFrame() {
        let frame = Configuration.talkingFrames[talkingFrameIndex]
        characterView.image = frames[frame]
    }

    private func startIdleAnimation(settlingFromTalking: Bool) {
        let generation = idleGeneration
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
