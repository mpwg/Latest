import SwiftUI
import Sparkle
import AppKit

/// AppKit owns the macOS lifecycle; all application content uses SwiftUI views.
@MainActor final class LatestApplicationDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = makeApplicationSession()
    private var mainWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var selfUpdater: SPUStandardUpdaterController?

    override init() {
        super.init()
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        installMenu()
        let controller = NSHostingController(rootView: LatestWindow(model: model, showSettings: { [weak self] in self?.showSettings() }).task { await self.model.start() })
        let window = NSWindow(contentViewController: controller)
        window.title = "Latest"
        window.styleMask.insert(.resizable)
        window.setContentSize(NSSize(width: 1000, height: 650))
        window.contentMinSize = NSSize(width: 800, height: 520)
        window.setFrameAutosaveName("LatestMainWindow")
        if !window.setFrameUsingName("LatestMainWindow") { window.center() }
        window.isReleasedWhenClosed = false
        window.delegate = self
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
        let editItem = NSMenuItem(); menu.addItem(editItem)
        let edit = NSMenu(title: String(localized: "Edit")); editItem.submenu = edit
        edit.addItem(withTitle: String(localized: "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: String(localized: "Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: String(localized: "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.addItem(.separator())
        edit.addItem(withTitle: String(localized: "Search apps"), action: #selector(focusSearch), keyEquivalent: "f").target = self
        let windowItem = NSMenuItem(); menu.addItem(windowItem)
        let windowMenu = NSMenu(title: String(localized: "Window")); windowItem.submenu = windowMenu
        windowMenu.addItem(withTitle: String(localized: "Close Window"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        NSApp.windowsMenu = windowMenu
        NSApp.mainMenu = menu
    }
    @objc private func openSettings() { showSettings() }
    @objc private func refresh() { model.refresh() }
    @objc private func focusSearch() {
        mainWindow?.makeKeyAndOrderFront(nil)
        NotificationCenter.default.post(name: .latestFocusSearch, object: nil)
    }
    @objc private func updateSelf() { selfUpdater?.checkForUpdates(nil) }
    private func showSettings() {
        if let settingsWindow { settingsWindow.makeKeyAndOrderFront(nil); return }
        let window = LatestSettingsWindow(contentViewController: NSHostingController(rootView: LatestSettings(model: model)))
        window.title = String(localized: "Settings…")
        window.styleMask.insert(.resizable)
        window.setContentSize(NSSize(width: 680, height: 560))
        window.contentMinSize = NSSize(width: 560, height: 440)
        window.isReleasedWhenClosed = false
        window.center(); window.makeKeyAndOrderFront(nil)
        settingsWindow = window
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { model.canQuit }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !model.canQuit else { return .terminateNow }
        presentRunningUpdatesAlert()
        return .terminateCancel
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender === mainWindow, !model.canQuit else { return true }
        presentRunningUpdatesAlert()
        return false
    }
    private func presentRunningUpdatesAlert() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Updates Are Running")
        alert.informativeText = String(localized: "Wait for installation to finish before quitting Latest.")
        alert.addButton(withTitle: String(localized: "Keep Latest Open"))
        alert.runModal()
    }
}

/// Escape dismisses the auxiliary settings window through the native responder chain.
@MainActor private final class LatestSettingsWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) { performClose(sender) }
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
