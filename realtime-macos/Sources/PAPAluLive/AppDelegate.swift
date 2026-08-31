import AppKit
import Foundation

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: CharacterWindow?
    private var microphoneMonitor: MicrophoneMonitor?
    private var settingsController: CharacterSettingsController?
    private var mouthGate = MouthGate()
    private var lastMicrophoneState = MouthState.idle
    private var renderedState: CharacterDisplayState?
    private var selectedCharacterID = CharacterID.catMeme
    private var catalog: [CharacterID: CharacterAssets] = [:]
    private let preferences = AppPreferences()
    private let customStore = CustomCharacterStore()
    private let imagePreparer = CharacterImagePreparer()
    private let menuItemFactory = CharacterMenuItemFactory()
    private var didShowError = false

    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.setActivationPolicy(.regular)
        application.delegate = delegate
        installMainMenu(on: application, target: delegate)

        withExtendedLifetime(delegate) {
            application.run()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try loadCharacterCatalog()
            selectedCharacterID = preferences.selectedCharacterID
            if catalog[selectedCharacterID] == nil {
                selectedCharacterID = .catMeme
                preferences.selectedCharacterID = .catMeme
            }
            guard let assets = catalog[selectedCharacterID] else {
                throw CharacterAssetError.missingRequiredImage
            }

            let window = CharacterWindow(assets: assets)
            self.window = window
            window.applyScaleFactor(preferences.windowScaleFactor)
            if let origin = preferences.windowOrigin {
                window.restoreOrigin(origin)
            }
            window.onPlacementChanged = { [weak self] origin, scale in
                self?.preferences.windowOrigin = origin
                self?.preferences.windowScaleFactor = scale
            }
            rebuildCharacterMenu()
            render(.idle)
            window.orderFrontRegardless()
        } catch {
            showError(error.localizedDescription)
            NSApp.terminate(nil)
            return
        }

        let settingsController = CharacterSettingsController(
            preparer: imagePreparer,
            store: customStore
        )
        settingsController.onCharacterSaved = { [weak self] assets in
            self?.catalog[.custom] = assets
            self?.selectCharacter(.custom)
        }
        self.settingsController = settingsController

        let monitor = MicrophoneMonitor { [weak self] rms, duration in
            guard let self else { return }
            let state = self.mouthGate.update(rms: rms, duration: duration)
            guard state != self.lastMicrophoneState else { return }
            self.lastMicrophoneState = state

            DispatchQueue.main.async { [weak self] in
                self?.handleMicrophoneState(state)
            }
        }
        microphoneMonitor = monitor
        monitor.requestAccessAndStart { [weak self] result in
            if case .failure(let error) = result {
                self?.showError(error.localizedDescription)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        microphoneMonitor?.stop()
    }

    @objc private func increaseScale() {
        window?.increaseScale()
    }

    @objc private func decreaseScale() {
        window?.decreaseScale()
    }

    @objc private func resetScale() {
        window?.resetScale()
    }

    @objc private func selectBundledCharacter(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let id = CharacterID(rawValue: rawValue) else { return }
        selectCharacter(id)
    }

    @objc private func selectCustom() {
        selectCharacter(.custom)
    }

    @objc private func openCustomSettings() {
        settingsController?.updateMouthState(lastMicrophoneState)
        settingsController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsController?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func deleteCustomCharacter() {
        guard catalog[.custom] != nil else { return }

        let alert = NSAlert()
        alert.messageText = "删除自定义角色？"
        alert.informativeText = "只会删除 App 保存的闭嘴、张嘴副本，不会删除你最初选择的图片。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try customStore.delete()
            catalog.removeValue(forKey: .custom)
            if selectedCharacterID == .custom {
                selectCharacter(.catMeme)
            } else {
                rebuildCharacterMenu()
            }
        } catch {
            showError("无法删除自定义角色：\(error.localizedDescription)")
        }
    }

    private func loadCharacterCatalog() throws {
        guard let resourceURL = Bundle.main.resourceURL else {
            throw CharacterAssetError.unreadableImage
        }
        let characters = resourceURL.appendingPathComponent(
            "Characters",
            isDirectory: true
        )
        for bundled in CharacterDefinition.bundledCharacters {
            catalog[bundled.definition.id] = try CharacterAssets.load(
                definition: bundled.definition,
                directory: characters.appendingPathComponent(
                    bundled.resourceDirectoryName,
                    isDirectory: true
                )
            )
        }
        if let custom = try? customStore.load() {
            catalog[.custom] = custom
        }
    }

    private func selectCharacter(_ id: CharacterID) {
        guard let assets = catalog[id] else {
            if id == .custom {
                openCustomSettings()
            }
            return
        }
        selectedCharacterID = id
        preferences.selectedCharacterID = id
        renderedState = lastMicrophoneState == .talking ? .talking : .idle
        window?.setCharacter(
            assets,
            currentState: renderedState ?? .idle
        )
        rebuildCharacterMenu()
    }

    private func rebuildCharacterMenu() {
        let menu = NSMenu(title: "选择角色")
        for bundled in CharacterDefinition.bundledCharacters {
            guard let assets = catalog[bundled.definition.id] else { continue }
            let item = menuItemFactory.makeItem(
                for: assets,
                selectedCharacterID: selectedCharacterID
            )
            item.action = #selector(selectBundledCharacter(_:))
            item.target = self
            menu.addItem(item)
        }
        addCharacterItem(
            title: "自定义角色",
            id: .custom,
            action: #selector(selectCustom),
            to: menu
        )
        menu.addItem(.separator())
        let settingsItem = menu.addItem(
            withTitle: "设置自定义角色…",
            action: #selector(openCustomSettings),
            keyEquivalent: ""
        )
        settingsItem.target = self
        let deleteItem = menu.addItem(
            withTitle: "删除自定义角色…",
            action: #selector(deleteCustomCharacter),
            keyEquivalent: ""
        )
        deleteItem.target = self
        deleteItem.isEnabled = catalog[.custom] != nil
        window?.setContextMenu(menu)
    }

    private func addCharacterItem(
        title: String,
        id: CharacterID,
        action: Selector,
        to menu: NSMenu
    ) {
        let item = menu.addItem(
            withTitle: title,
            action: action,
            keyEquivalent: ""
        )
        item.target = self
        item.state = selectedCharacterID == id ? .on : .off
    }

    private func showError(_ message: String) {
        guard !didShowError else { return }
        didShowError = true

        let presentAlert = {
            let alert = NSAlert()
            alert.messageText = "悬浮说话角色遇到问题"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "知道了")
            alert.runModal()
        }

        if Thread.isMainThread {
            presentAlert()
        } else {
            DispatchQueue.main.async(execute: presentAlert)
        }
    }

    private func handleMicrophoneState(_ state: MouthState) {
        settingsController?.updateMouthState(state)
        render(state == .talking ? .talking : .idle)
    }

    private func render(_ state: CharacterDisplayState) {
        guard state != renderedState else { return }
        renderedState = state
        window?.setDisplayState(state)
    }

    private static func installMainMenu(
        on application: NSApplication,
        target: AppDelegate
    ) {
        let mainMenu = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu()

        let increaseItem = applicationMenu.addItem(
            withTitle: "放大角色",
            action: #selector(increaseScale),
            keyEquivalent: "+"
        )
        increaseItem.target = target

        let decreaseItem = applicationMenu.addItem(
            withTitle: "缩小角色",
            action: #selector(decreaseScale),
            keyEquivalent: "-"
        )
        decreaseItem.target = target

        let resetItem = applicationMenu.addItem(
            withTitle: "恢复默认大小",
            action: #selector(resetScale),
            keyEquivalent: "0"
        )
        resetItem.target = target

        applicationMenu.addItem(.separator())
        let quitItem = applicationMenu.addItem(
            withTitle: "退出悬浮说话角色",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = application
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)
        application.mainMenu = mainMenu
    }
}
