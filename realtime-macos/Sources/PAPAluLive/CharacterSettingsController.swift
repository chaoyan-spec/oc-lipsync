import AppKit
import UniformTypeIdentifiers

final class CharacterSettingsController: NSWindowController {
    var onCharacterSaved: ((CharacterAssets) -> Void)?

    private enum ImageSlot {
        case idle
        case talking
    }

    private let preparer: CharacterImagePreparer
    private let store: CustomCharacterStore
    private let idleThumbnail = NSImageView()
    private let talkingThumbnail = NSImageView()
    private let previewView = NSImageView()
    private let statusLabel = NSTextField(labelWithString: "请选择两张 PNG。")
    private let useButton = NSButton(title: "使用这个角色", target: nil, action: nil)
    private var idleURL: URL?
    private var talkingURL: URL?
    private var prepared: PreparedCharacterImages?
    private var preparedIdleImage: NSImage?
    private var preparedTalkingImage: NSImage?
    private var mouthState: MouthState = .idle

    init(
        preparer: CharacterImagePreparer,
        store: CustomCharacterStore
    ) {
        self.preparer = preparer
        self.store = store
        super.init(window: nil)
        configureWindow()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func updateMouthState(_ state: MouthState) {
        mouthState = state
        refreshPreviewImage()
    }

    private func configureWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 430),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "设置自定义角色"
        panel.isReleasedWhenClosed = false
        panel.center()
        window = panel

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = content

        let explanation = NSTextField(
            wrappingLabelWithString: "选择一张闭嘴 PNG 和一张张嘴 PNG。图片尺寸不同时会自动放到同一个底部居中的画布中。"
        )
        explanation.textColor = .secondaryLabelColor

        configureThumbnail(idleThumbnail)
        configureThumbnail(talkingThumbnail)
        configurePreview()

        let idleButton = NSButton(
            title: "选择闭嘴 PNG…",
            target: self,
            action: #selector(chooseIdleImage)
        )
        let talkingButton = NSButton(
            title: "选择张嘴 PNG…",
            target: self,
            action: #selector(chooseTalkingImage)
        )
        let idleColumn = makeImageColumn(
            title: "安静 / 闭嘴",
            imageView: idleThumbnail,
            button: idleButton
        )
        let talkingColumn = makeImageColumn(
            title: "说话 / 张嘴",
            imageView: talkingThumbnail,
            button: talkingButton
        )
        let sourceRow = NSStackView(views: [idleColumn, talkingColumn])
        sourceRow.orientation = .horizontal
        sourceRow.spacing = 16
        sourceRow.distribution = .fillEqually

        let previewTitle = NSTextField(labelWithString: "实时麦克风预览")
        previewTitle.font = .boldSystemFont(ofSize: 13)
        let previewRow = NSStackView(views: [previewTitle, previewView])
        previewRow.orientation = .vertical
        previewRow.alignment = .centerX
        previewRow.spacing = 6

        statusLabel.maximumNumberOfLines = 2
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.textColor = .secondaryLabelColor

        useButton.target = self
        useButton.action = #selector(useCharacter)
        useButton.keyEquivalent = "\r"
        useButton.isEnabled = false

        let root = NSStackView(views: [
            explanation,
            sourceRow,
            previewRow,
            statusLabel,
            useButton,
        ])
        root.translatesAutoresizingMaskIntoConstraints = false
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 12
        content.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            root.topAnchor.constraint(equalTo: content.topAnchor, constant: 18),
            root.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -18),
            sourceRow.widthAnchor.constraint(equalTo: root.widthAnchor),
            previewRow.widthAnchor.constraint(equalTo: root.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: root.widthAnchor),
            useButton.trailingAnchor.constraint(equalTo: root.trailingAnchor),
        ])
    }

    private func configureThumbnail(_ imageView: NSImageView) {
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        imageView.layer?.cornerRadius = 8
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 120),
            imageView.heightAnchor.constraint(equalToConstant: 100),
        ])
    }

    private func configurePreview() {
        previewView.imageScaling = .scaleProportionallyUpOrDown
        previewView.imageAlignment = .alignCenter
        previewView.wantsLayer = true
        previewView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        previewView.layer?.cornerRadius = 8
        previewView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            previewView.widthAnchor.constraint(equalToConstant: 130),
            previewView.heightAnchor.constraint(equalToConstant: 130),
        ])
    }

    private func makeImageColumn(
        title: String,
        imageView: NSImageView,
        button: NSButton
    ) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.font = .boldSystemFont(ofSize: 13)
        let stack = NSStackView(views: [label, imageView, button])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 7
        return stack
    }

    @objc private func chooseIdleImage() {
        presentOpenPanel(for: .idle)
    }

    @objc private func chooseTalkingImage() {
        presentOpenPanel(for: .talking)
    }

    private func presentOpenPanel(for slot: ImageSlot) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = slot == .idle ? "选择闭嘴 PNG" : "选择张嘴 PNG"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.accept(url: url, for: slot)
        }
    }

    private func accept(url: URL, for slot: ImageSlot) {
        guard let image = NSImage(contentsOf: url) else {
            showInlineError("图片无法读取，请重新选择 PNG。")
            return
        }
        switch slot {
        case .idle:
            idleURL = url
            idleThumbnail.image = image
        case .talking:
            talkingURL = url
            talkingThumbnail.image = image
        }
        prepareWhenReady()
    }

    private func prepareWhenReady() {
        guard let idleURL, let talkingURL else {
            prepared = nil
            useButton.isEnabled = false
            statusLabel.stringValue = "还需要选择另一张 PNG。"
            return
        }
        do {
            let result = try preparer.prepare(
                idleURL: idleURL,
                talkingURL: talkingURL
            )
            prepared = result
            preparedIdleImage = NSImage(data: result.idlePNG)
            preparedTalkingImage = NSImage(data: result.talkingPNG)
            useButton.isEnabled = true
            statusLabel.textColor = result.warnings.isEmpty
                ? .secondaryLabelColor
                : .systemOrange
            statusLabel.stringValue = result.warnings.isEmpty
                ? "准备完成，可以直接使用。"
                : result.warnings.joined(separator: " ")
            refreshPreviewImage()
        } catch {
            prepared = nil
            useButton.isEnabled = false
            showInlineError(error.localizedDescription)
        }
    }

    private func refreshPreviewImage() {
        previewView.image = mouthState == .talking
            ? preparedTalkingImage
            : preparedIdleImage
    }

    @objc private func useCharacter() {
        guard let prepared else { return }
        do {
            try store.save(prepared)
            onCharacterSaved?(try store.loadRequired())
            close()
        } catch {
            showInlineError(error.localizedDescription)
        }
    }

    private func showInlineError(_ message: String) {
        statusLabel.textColor = .systemRed
        statusLabel.stringValue = message
    }
}
