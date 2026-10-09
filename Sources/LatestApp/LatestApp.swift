import SwiftUI
import Sparkle
import AppKit

/// AppKit owns the macOS lifecycle; all application content uses SwiftUI views.
@MainActor final class LatestApplicationDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var mainWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var selfUpdater: SPUStandardUpdaterController?

    override init() {
        super.init()
        model.showSettingsHandler = { [weak self] in self?.showSettings() }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        installMenu()
        let controller = NSHostingController(rootView: LatestWindow(model: model).task { await self.model.start() })
        let window = NSWindow(contentViewController: controller)
        window.title = "Latest"
        window.styleMask.insert(.resizable)
        window.setContentSize(NSSize(width: 1000, height: 650))
        window.setFrameAutosaveName("LatestMainWindow")
        if !window.setFrameUsingName("LatestMainWindow") { window.center() }
        window.isReleasedWhenClosed = false
        mainWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        if let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String, !key.isEmpty {
            selfUpdater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        }
    }
    private func installMenu() {
        let menu = NSMenu()
        let application = NSMenuItem(); menu.addItem(application)
        let appMenu = NSMenu(title: "Latest"); application.submenu = appMenu
        let about = appMenu.addItem(withTitle: String(localized: "About Latest"), action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        about.target = NSApp
        appMenu.addItem(.separator())
        let settings = appMenu.addItem(withTitle: String(localized: "Settings…"), action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        let check = appMenu.addItem(withTitle: String(localized: "Check for Updates"), action: #selector(refresh), keyEquivalent: "r")
        check.target = self
        let selfCheck = appMenu.addItem(withTitle: String(localized: "Check for Latest Updates…"), action: #selector(updateSelf), keyEquivalent: "")
        selfCheck.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: String(localized: "Quit Latest"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q").target = NSApp
        NSApp.mainMenu = menu
    }
    @objc private func openSettings() { showSettings() }
    @objc private func refresh() { model.refresh() }
    @objc private func updateSelf() { selfUpdater?.checkForUpdates(nil) }
    private func showSettings() {
        if let settingsWindow { settingsWindow.makeKeyAndOrderFront(nil); return }
        let window = NSWindow(contentViewController: NSHostingController(rootView: LatestSettings(model: model)))
        window.title = String(localized: "Settings…")
        window.isReleasedWhenClosed = false
        window.center(); window.makeKeyAndOrderFront(nil)
        settingsWindow = window
    }
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

@main @MainActor enum LatestApplication {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = LatestApplicationDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
