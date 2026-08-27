import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: PAPAluWindow?
    private var microphoneMonitor: MicrophoneMonitor?
    private var mouthGate = MouthGate()
    private var renderedState = MouthState.idle
    private var didShowError = false

    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.setActivationPolicy(.regular)
        application.delegate = delegate
        installMainMenu(on: application)

        withExtendedLifetime(delegate) {
            application.run()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let window = try PAPAluWindow()
            self.window = window
            window.orderFrontRegardless()
        } catch {
            showError(error.localizedDescription)
            NSApp.terminate(nil)
            return
        }

        let monitor = MicrophoneMonitor { [weak self] rms, duration in
            guard let self else { return }
            let state = self.mouthGate.update(rms: rms, duration: duration)
            guard state != self.renderedState else { return }
            self.renderedState = state

            DispatchQueue.main.async { [weak self] in
                self?.window?.setTalking(state == .talking)
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

    private static func installMainMenu(on application: NSApplication) {
        let mainMenu = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu()
        applicationMenu.addItem(
            withTitle: "退出 PAPAlu 实时口型",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)
        application.mainMenu = mainMenu
    }
}
