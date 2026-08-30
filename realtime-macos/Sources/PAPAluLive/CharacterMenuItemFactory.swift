import AppKit

struct CharacterMenuItemFactory {
    private let thumbnailSize = NSSize(width: 28, height: 28)

    func makeItem(
        for assets: CharacterAssets,
        selectedCharacterID: CharacterID
    ) -> NSMenuItem {
        let item = NSMenuItem(title: assets.definition.name, action: nil, keyEquivalent: "")
        item.representedObject = assets.definition.id.rawValue
        item.state = selectedCharacterID == assets.definition.id ? .on : .off
        item.image = makeThumbnail(
            from: assets.images[assets.definition.idleAssetName]
        )
        return item
    }

    private func makeThumbnail(from source: NSImage?) -> NSImage? {
        guard let source, source.size.width > 0, source.size.height > 0 else {
            return nil
        }
        let thumbnail = NSImage(size: thumbnailSize)
        let scale = min(
            thumbnailSize.width / source.size.width,
            thumbnailSize.height / source.size.height
        )
        let targetSize = NSSize(
            width: source.size.width * scale,
            height: source.size.height * scale
        )
        let target = NSRect(
            x: (thumbnailSize.width - targetSize.width) / 2,
            y: (thumbnailSize.height - targetSize.height) / 2,
            width: targetSize.width,
            height: targetSize.height
        )

        thumbnail.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(in: target)
        thumbnail.unlockFocus()
        return thumbnail
    }
}
