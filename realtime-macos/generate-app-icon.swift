import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("usage: generate-app-icon <frame-0.png> <output.png>\n", stderr)
    exit(2)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    fputs("Unable to load PAPAlu frame 0\n", stderr)
    exit(1)
}

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: 1024,
    pixelsHigh: 1024,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Unable to create icon bitmap\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()

NSColor.white.setFill()
NSBezierPath(
    roundedRect: NSRect(x: 48, y: 48, width: 928, height: 928),
    xRadius: 220,
    yRadius: 220
).fill()

sourceImage.draw(
    in: NSRect(x: 152, y: 112, width: 720, height: 780),
    from: NSRect(x: 0, y: 0, width: 192, height: 208),
    operation: .sourceOver,
    fraction: 1,
    respectFlipped: false,
    hints: [.interpolation: NSImageInterpolation.high]
)

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to encode icon PNG\n", stderr)
    exit(1)
}

try png.write(to: outputURL, options: .atomic)
