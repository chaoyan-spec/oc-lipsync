import AppKit
import Foundation

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: CharacterWindow?
    private var microphoneMonitor: MicrophoneMonitor?
    private var mouthGate = MouthGate()
    private var lastMicrophoneState = MouthState.idle
    private var renderedState: CharacterDisplayState?
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
            guard let resourceURL = Bundle.main.resourceURL else {
                throw CharacterAssetError.unreadableImage
            }
            let directory = resourceURL
                .appendingPathComponent("Characters", isDirectory: true)
                .appendingPathComponent("CatMeme", isDirectory: true)
            let assets = try CharacterAssets.load(
                definition: .catMeme,
                directory: directory
            )
            let window = CharacterWindow(assets: assets)
            self.window = window
            render(.idle)
            window.orderFrontRegardless()
        } catch {
            showError(error.localizedDescription)
            NSApp.terminate(nil)
            return
        }

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

    private func showError(_ message: String) {
        guard !didShowError else { return }
        didShowError = true

        let presentAlert = {
            let alert = NSAlert()
            alert.messageText = "PAPAlu 实时口型遇到问题"
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
            withTitle: "放大 PAPAlu",
            action: #selector(increaseScale),
            keyEquivalent: "+"
        )
        increaseItem.target = target

        let decreaseItem = applicationMenu.addItem(
            withTitle: "缩小 PAPAlu",
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
            withTitle: "退出 PAPAlu 实时口型",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = application
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)
        application.mainMenu = mainMenu
    }
}
