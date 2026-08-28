import AppKit

final class ThoughtCloudView: NSView {
    private let plan: ThoughtCloudPlan
    private var activeDotIndex = 0

    init(plan: ThoughtCloudPlan) {
        self.plan = plan
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func setActiveDotIndex(_ index: Int) {
        activeDotIndex = max(0, index) % 3
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard bounds.width > 0, bounds.height > 0 else { return }

        let white = NSColor(calibratedWhite: 0.98, alpha: 0.98)
        let purple = NSColor(
            calibratedRed: 0.20,
            green: 0.16,
            blue: 0.34,
            alpha: 1
        )
        let lineWidth = max(1.2, bounds.width / 55)

        drawTail(fill: white, stroke: purple, lineWidth: lineWidth)

        let cloud = cloudPath()
        white.setFill()
        cloud.fill()
        purple.setStroke()
        cloud.lineWidth = lineWidth
        cloud.stroke()

        let alphas = plan.dotAlphas(activeIndex: activeDotIndex)
        let radius = bounds.width * 0.043
        let centerY = bounds.height * 0.55
        let centers = [0.45, 0.62, 0.79]

        for (index, centerX) in centers.enumerated() {
            purple.withAlphaComponent(alphas[index]).setFill()
            let dot = NSBezierPath(ovalIn: NSRect(
                x: bounds.width * centerX - radius,
                y: centerY - radius,
                width: radius * 2,
                height: radius * 2
            ))
            dot.fill()
        }
    }

    private func drawTail(
        fill: NSColor,
        stroke: NSColor,
        lineWidth: CGFloat
    ) {
        let tailRects = [
            NSRect(
                x: bounds.width * 0.06,
                y: bounds.height * 0.10,
                width: bounds.width * 0.11,
                height: bounds.width * 0.11
            ),
            NSRect(
                x: bounds.width * 0.15,
                y: bounds.height * 0.23,
                width: bounds.width * 0.16,
                height: bounds.width * 0.16
            ),
        ]

        for rect in tailRects {
            let bubble = NSBezierPath(ovalIn: rect)
            fill.setFill()
            bubble.fill()
            stroke.setStroke()
            bubble.lineWidth = lineWidth
            bubble.stroke()
        }
    }

    private func cloudPath() -> NSBezierPath {
        let width = bounds.width
        let height = bounds.height
        let path = NSBezierPath()

        path.move(to: NSPoint(x: width * 0.20, y: height * 0.40))
        path.curve(
            to: NSPoint(x: width * 0.38, y: height * 0.73),
            controlPoint1: NSPoint(x: width * 0.11, y: height * 0.50),
            controlPoint2: NSPoint(x: width * 0.19, y: height * 0.72)
        )
        path.curve(
            to: NSPoint(x: width * 0.65, y: height * 0.86),
            controlPoint1: NSPoint(x: width * 0.40, y: height * 0.96),
            controlPoint2: NSPoint(x: width * 0.57, y: height * 1.00)
        )
        path.curve(
            to: NSPoint(x: width * 0.91, y: height * 0.66),
            controlPoint1: NSPoint(x: width * 0.80, y: height * 0.99),
            controlPoint2: NSPoint(x: width * 0.96, y: height * 0.86)
        )
        path.curve(
            to: NSPoint(x: width * 0.79, y: height * 0.38),
            controlPoint1: NSPoint(x: width * 1.00, y: height * 0.55),
            controlPoint2: NSPoint(x: width * 0.93, y: height * 0.37)
        )
        path.curve(
            to: NSPoint(x: width * 0.44, y: height * 0.31),
            controlPoint1: NSPoint(x: width * 0.72, y: height * 0.17),
            controlPoint2: NSPoint(x: width * 0.51, y: height * 0.17)
        )
        path.curve(
            to: NSPoint(x: width * 0.20, y: height * 0.40),
            controlPoint1: NSPoint(x: width * 0.32, y: height * 0.22),
            controlPoint2: NSPoint(x: width * 0.21, y: height * 0.27)
        )
        path.close()
        return path
    }
}
