import AppKit
#if SWIFT_PACKAGE
@testable import PAPAluLive
#endif

func verifyAppShellContractsCompile() {
    let _: MicrophoneMonitor.Type = MicrophoneMonitor.self
    let _: PAPAluWindow.Type = PAPAluWindow.self
    let _: AppDelegate.Type = AppDelegate.self
    let _: WindowScale.Type = WindowScale.self
    let _: CameraMonitor.Type = CameraMonitor.self
}

func verifyDisplayStatesCompile(on window: PAPAluWindow) {
    window.setDisplayState(.idle)
    window.setDisplayState(.talking)
    window.setDisplayState(.teaching)
}

func verifyCameraUsesCloseRangeHandSamples() {
    _ = CameraMonitor { (_: HandPoseSample) in }
}

func verifyIdlePlanInjectionCompiles(resourceDirectory: URL) throws {
    _ = try PAPAluWindow(
        resourceDirectory: resourceDirectory,
        idlePlan: IdleAnimationPlan()
    )
}

func verifyWindowScaleActionsCompile(on window: PAPAluWindow) {
    window.increaseScale()
    window.decreaseScale()
    window.resetScale()
}
