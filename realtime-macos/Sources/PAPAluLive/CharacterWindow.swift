import AppKit
import QuartzCore

private final class DraggableImageView: NSImageView {
    override var mouseDownCanMoveWindow: Bool { true }
}

private final class DraggableContainerView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
}

final class CharacterWindow: NSPanel {
    private var assets: CharacterAssets
    private var runtime: CharacterRuntime
    private var idlePlan: IdleAnimationPlan
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
    private var hasRenderedState = false
    private var windowScale = WindowScale()

    init(
        assets: CharacterAssets,
        thoughtCloudPlan: ThoughtCloudPlan = ThoughtCloudPlan()
    ) {
        self.assets = assets
        runtime = CharacterRuntime(definition: assets.definition)
        idlePlan = IdleAnimationPlan(
            configuration: assets.definition.idleMotion
        )
        self.thoughtCloudPlan = thoughtCloudPlan
        thoughtCloudView = ThoughtCloudView(plan: thoughtCloudPlan)

        let size = assets.definition.defaultSize
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
        characterView.wantsLayer = true
        showAsset(named: runtime.currentAssetName)

        thoughtCloudView.isHidden = true
        thoughtCloudView.alphaValue = 0
        layoutThoughtCloud(for: size)

        containerView.addSubview(characterView)
        containerView.addSubview(thoughtCloudView)
        contentView = containerView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func setDisplayState(_ state: CharacterDisplayState) {
        guard !hasRenderedState || state != runtime.state else { return }
        let previousState = runtime.state
        hasRenderedState = true
        runtime.setState(state)
        cancelAllAnimation()

        switch state {
        case .idle:
            startIdleAnimation(settlingFromTalking: previousState == .talking)
        case .talking:
            showAsset(named: runtime.currentAssetName)
            startAnimationTimer()
        }
    }

    func setCharacter(
        _ assets: CharacterAssets,
        currentState: CharacterDisplayState
    ) {
        cancelAllAnimation()
        self.assets = assets
        idlePlan = IdleAnimationPlan(
            configuration: assets.definition.idleMotion
        )
        runtime.setCharacter(assets.definition, currentState: currentState)
        hasRenderedState = true
        applyDefaultAspectRatioWithoutMovingWindowCenter()
        renderCurrentState()
    }

    func setContextMenu(_ menu: NSMenu) {
        containerView.menu = menu
        characterView.menu = menu
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

    private func renderCurrentState() {
        switch runtime.state {
        case .idle:
            startIdleAnimation(settlingFromTalking: false)
        case .talking:
            showAsset(named: runtime.currentAssetName)
            startAnimationTimer()
        }
    }

    private func applyDefaultAspectRatioWithoutMovingWindowCenter() {
        let center = NSPoint(x: frame.midX, y: frame.midY)
        let size = scaledDefaultSize()
        setFrame(
            NSRect(
                x: center.x - size.width / 2,
                y: center.y - size.height / 2,
                width: size.width,
                height: size.height
            ),
            display: true,
            animate: false
        )
        layoutThoughtCloud(for: size)
    }

    private func applyCurrentScale() {
        applyDefaultAspectRatioWithoutMovingWindowCenter()
    }

    private func scaledDefaultSize() -> NSSize {
        NSSize(
            width: assets.definition.defaultSize.width * windowScale.factor,
            height: assets.definition.defaultSize.height * windowScale.factor
        )
    }

    private func startAnimationTimer() {
        animationTimer?.invalidate()
        let frameRate = max(1, assets.definition.talkingFramesPerSecond)
        let timer = Timer(timeInterval: 1 / frameRate, repeats: true) {
            [weak self] _ in
            guard let self else { return }
            self.runtime.advanceTalkingFrame()
            self.showAsset(named: self.runtime.currentAssetName)
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

    private func showAsset(named name: String) {
        characterView.image = assets.images[name]
    }

    private func startIdleAnimation(settlingFromTalking: Bool) {
        let generation = idleGeneration
        scheduleThoughtCloud(generation: generation)

        let beginEvents: () -> Void = { [weak self] in
            guard let self else { return }
            self.scheduleNextBlink(generation: generation)
            let direction: IdleSwayDirection = Bool.random() ? .left : .right
            self.runNextSway(direction: direction, generation: generation)
        }

        let steps = assets.definition.settleSteps
        if settlingFromTalking, !steps.isEmpty {
            playFrameSequence(
                steps,
                generation: generation,
                completion: beginEvents
            )
        } else {
            showAsset(named: assets.definition.idleAssetName)
            beginEvents()
        }
    }

    private func scheduleNextBlink(generation: Int) {
        guard runtime.state == .idle,
              generation == idleGeneration,
              let range = assets.definition.blinkDelayRange,
              !assets.definition.blinkSteps.isEmpty else { return }

        idleBlinkTimer = makeTimer(after: Double.random(in: range)) {
            [weak self] in
            guard let self,
                  self.runtime.state == .idle,
                  generation == self.idleGeneration else { return }
            self.playFrameSequence(
                self.assets.definition.blinkSteps,
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
        guard runtime.state == .idle, generation == idleGeneration else { return }
        let step = idlePlan.swayStep(
            direction: direction,
            durationRandomUnit: Double.random(in: 0...1),
            holdRandomUnit: Double.random(in: 0...1)
        )
        animateCharacter(to: step)
        idleSwayTimer = makeTimer(after: step.duration + step.holdDuration) {
            [weak self] in
            self?.runNextSway(
                direction: direction == .left ? .right : .left,
                generation: generation
            )
        }
    }

    private func playFrameSequence(
        _ steps: [CharacterFrameStep],
        index: Int = 0,
        generation: Int,
        completion: @escaping () -> Void
    ) {
        guard runtime.state == .idle, generation == idleGeneration else { return }
        guard index < steps.count else {
            completion()
            return
        }
        let step = steps[index]
        showAsset(named: step.assetName)
        idleSequenceTimer = makeTimer(after: step.duration) { [weak self] in
            self?.playFrameSequence(
                steps,
                index: index + 1,
                generation: generation,
                completion: completion
            )
        }
    }

    private func scheduleThoughtCloud(generation: Int) {
        guard assets.definition.thoughtCloudEnabled else { return }
        thoughtCloudDelayTimer = makeTimer(
            after: thoughtCloudPlan.configuration.appearanceDelay
        ) { [weak self] in
            guard let self,
                  self.runtime.state == .idle,
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
                  self.runtime.state == .idle,
                  generation == self.idleGeneration else { return }
            self.thoughtCloudDotIndex = self.thoughtCloudPlan.nextDotIndex(
                after: self.thoughtCloudDotIndex
            )
            self.thoughtCloudView.setActiveDotIndex(self.thoughtCloudDotIndex)
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
        let cloudFrame = thoughtCloudPlan.frame(
            windowWidth: windowSize.width,
            windowHeight: windowSize.height
        )
        thoughtCloudView.frame = NSRect(
            x: cloudFrame.x,
            y: cloudFrame.y,
            width: cloudFrame.width,
            height: cloudFrame.height
        )
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
        layer.add(animation, forKey: "characterIdleSway")
    }

    private func resetCharacterTransform() {
        guard let layer = characterView.layer else { return }
        layer.removeAnimation(forKey: "characterIdleSway")
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = CATransform3DIdentity
        CATransaction.commit()
    }

    private func makeTimer(
        after delay: Double,
        action: @escaping () -> Void
    ) -> Timer {
        let timer = Timer(timeInterval: max(0, delay), repeats: false) { _ in
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
