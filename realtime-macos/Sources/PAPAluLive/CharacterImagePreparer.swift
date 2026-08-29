import AppKit

enum CharacterImagePreparationError: LocalizedError {
    case unreadableImage
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            return "角色图片无法读取，请选择 PNG 文件。"
        case .renderFailed:
            return "角色图片无法完成标准化处理。"
        }
    }
}

struct PreparedCharacterImages {
    let idlePNG: Data
    let talkingPNG: Data
    let canvasSize: NSSize
    let warnings: [String]
}

final class CharacterImagePreparer {
    func prepare(
        idleURL: URL,
        talkingURL: URL
    ) throws -> PreparedCharacterImages {
        let idle = try loadBitmap(from: idleURL)
        let talking = try loadBitmap(from: talkingURL)
        let canvas = NSSize(
            width: max(idle.pixelsWide, talking.pixelsWide),
            height: max(idle.pixelsHigh, talking.pixelsHigh)
        )
        let warnings = [idle, talking].allSatisfy(\.hasAlpha)
            ? []
            : ["图片没有透明背景，录屏时会保留原背景。"]

        return PreparedCharacterImages(
            idlePNG: try renderBottomCentered(idle, canvas: canvas),
            talkingPNG: try renderBottomCentered(talking, canvas: canvas),
            canvasSize: canvas,
            warnings: warnings
        )
    }

    private func loadBitmap(from url: URL) throws -> NSBitmapImageRep {
        guard let data = try? Data(contentsOf: url),
              let bitmap = NSBitmapImageRep(data: data),
              bitmap.pixelsWide > 0,
              bitmap.pixelsHigh > 0 else {
            throw CharacterImagePreparationError.unreadableImage
        }
        return bitmap
    }

    private func renderBottomCentered(
        _ source: NSBitmapImageRep,
        canvas: NSSize
    ) throws -> Data {
        let width = Int(canvas.width)
        let height = Int(canvas.height)
        guard let output = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: output) else {
            throw CharacterImagePreparationError.renderFailed
        }

        let image = NSImage(
            size: NSSize(width: source.pixelsWide, height: source.pixelsHigh)
        )
        image.addRepresentation(source)
        let target = NSRect(
            x: (canvas.width - CGFloat(source.pixelsWide)) / 2,
            y: 0,
            width: CGFloat(source.pixelsWide),
            height: CGFloat(source.pixelsHigh)
        )

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .none
        image.draw(
            in: target,
            from: NSRect(
                x: 0,
                y: 0,
                width: CGFloat(source.pixelsWide),
                height: CGFloat(source.pixelsHigh)
            ),
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: false,
            hints: nil
        )
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        guard let data = output.representation(using: .png, properties: [:]) else {
            throw CharacterImagePreparationError.renderFailed
        }
        return data
    }
}
