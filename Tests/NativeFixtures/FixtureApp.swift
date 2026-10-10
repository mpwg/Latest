import AppKit
import Foundation

/// A disposable app with real bundle metadata; it never updates another app.
@main @MainActor enum FixtureApp {
    static func main() throws {
        let bundle = Bundle.main
        let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Latest Fixture"
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        if CommandLine.arguments.contains("--fixture-metadata") {
            let value = ["bundleID": bundle.bundleIdentifier ?? "", "version": version,
                         "path": bundle.bundleURL.path]
            print(String(decoding: try JSONSerialization.data(withJSONObject: value, options: .sortedKeys), as: UTF8.self))
            return
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let menu = NSMenu()
        let item = NSMenuItem()
        menu.addItem(item)
        item.submenu = NSMenu(title: name)
        item.submenu?.addItem(withTitle: "Quit Fixture", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        app.mainMenu = menu
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 200),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = name
        let label = NSTextField(labelWithString: "\(name)\nVersion \(version)\nDisposable native installation fixture")
        label.frame = NSRect(x: 24, y: 40, width: 432, height: 120)
        label.font = .systemFont(ofSize: 20)
        window.contentView?.addSubview(label)
        window.center()
        window.makeKeyAndOrderFront(nil)
        app.activate()
        withExtendedLifetime(window) { app.run() }
    }
}
