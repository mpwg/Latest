import SwiftUI
import Sparkle
import AppKit

@MainActor final class LatestApplicationDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { model.activeUpdates == 0 }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model.activeUpdates > 0 else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = String(localized: "Updates Are Running")
        alert.informativeText = String(localized: "Wait for installation to finish before quitting Latest.")
        alert.addButton(withTitle: String(localized: "Keep Latest Open"))
        alert.runModal()
        return .terminateCancel
    }
}

@main @MainActor struct LatestApplication: App {
    @NSApplicationDelegateAdaptor(LatestApplicationDelegate.self) private var delegate
    private let selfUpdater: SPUStandardUpdaterController?
    init() {
        if let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String, !key.isEmpty {
            selfUpdater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        } else { selfUpdater = nil }
    }
    var body: some Scene {
        WindowGroup("Latest") {
            LatestWindow(model: delegate.model).frame(minWidth: 900, minHeight: 550)
                .task { await delegate.model.start() }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Latest Updates…") { selfUpdater?.checkForUpdates(nil) }.disabled(selfUpdater == nil)
            }
            CommandGroup(after: .newItem) {
                Button("Check for Updates") { delegate.model.refresh() }.keyboardShortcut("r").disabled(delegate.model.scanning)
            }
        }
        Settings { LatestSettings(model: delegate.model) }
    }
}
