import AppKit
#if SWIFT_PACKAGE
@testable import PAPAluLive
#endif

func verifyAppShellContractsCompile() {
    let _: MicrophoneMonitor.Type = MicrophoneMonitor.self
    let _: PAPAluWindow.Type = PAPAluWindow.self
    let _: AppDelegate.Type = AppDelegate.self
    let _: WindowScale.Type = WindowScale.self
}

func verifyWindowScaleActionsCompile(on window: PAPAluWindow) {
    window.increaseScale()
    window.decreaseScale()
    window.resetScale()
}
