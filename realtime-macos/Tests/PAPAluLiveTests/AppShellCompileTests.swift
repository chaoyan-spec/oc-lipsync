import AppKit
#if SWIFT_PACKAGE
@testable import PAPAluLive
#endif

func verifyAppShellContractsCompile() {
    let _: MicrophoneMonitor.Type = MicrophoneMonitor.self
    let _: CharacterWindow.Type = CharacterWindow.self
    let _: CharacterRuntime.Type = CharacterRuntime.self
    let _: AppDelegate.Type = AppDelegate.self
    let _: WindowScale.Type = WindowScale.self
    let _: ThoughtCloudView.Type = ThoughtCloudView.self
}

func verifyDisplayStatesCompile(on window: CharacterWindow) {
    window.setDisplayState(.idle)
    window.setDisplayState(.talking)
}

func verifyCharacterSwitchCompiles(
    on window: CharacterWindow,
    assets: CharacterAssets
) {
    window.setCharacter(assets, currentState: .talking)
    window.setDisplayState(.idle)
    window.setContextMenu(NSMenu())
}

func verifyWindowScaleActionsCompile(on window: CharacterWindow) {
    window.increaseScale()
    window.decreaseScale()
    window.resetScale()
}

func verifySettingsControllerCompiles(
    preparer: CharacterImagePreparer,
    store: CustomCharacterStore
) {
    let controller = CharacterSettingsController(
        preparer: preparer,
        store: store
    )
    controller.updateMouthState(.idle)
    controller.onCharacterSaved = { _ in }
}
