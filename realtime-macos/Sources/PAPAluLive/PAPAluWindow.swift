import AppKit

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

final class PAPAluWindow: NSPanel {
    struct Configuration {
        static let defaultSize = NSSize(width: 288, height: 312)
        static let talkingFrames = [1, 2, 3, 4, 6, 3]
        static let talkingFramesPerSecond = 8.0
    }

    private let frames: [NSImage]
    private let characterView = DraggableImageView()
    private var animationTimer: Timer?
    private var talkingFrameIndex = 0
    private var isTalking = false
    private var windowScale = WindowScale()

    init(resourceDirectory: URL? = Bundle.main.resourceURL) throws {
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

        characterView.frame = NSRect(origin: .zero, size: size)
        characterView.autoresizingMask = [.width, .height]
        characterView.imageAlignment = .alignCenter
        characterView.imageScaling = .scaleProportionallyUpOrDown
        characterView.image = frames[0]
        contentView = characterView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func setTalking(_ talking: Bool) {
        guard talking != isTalking else { return }
        isTalking = talking

        if talking {
            talkingFrameIndex = 0
            showTalkingFrame()
            startAnimationTimer()
        } else {
            animationTimer?.invalidate()
            animationTimer = nil
            characterView.image = frames[0]
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

    private func showTalkingFrame() {
        let frame = Configuration.talkingFrames[talkingFrameIndex]
        characterView.image = frames[frame]
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
