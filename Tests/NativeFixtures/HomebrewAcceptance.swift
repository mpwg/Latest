import AppKit
import Foundation
import SwiftUI
import LatestCore
import LatestPlatform

@MainActor final class HomebrewAcceptanceDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var model: AppModel?
    private let root: URL
    init(root: URL) { self.root = root }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            do { try await verify(); exit(0) }
            catch { FileHandle.standardError.write(Data("Native Homebrew acceptance failed: \(error)\n".utf8)); exit(1) }
        }
    }

    private func verify() async throws {
        let app = root.appendingPathComponent("applications/Latest Homebrew Fixture.app")
        let state = root.appendingPathComponent("preferences/l03")
        let evidence = root.appendingPathComponent("evidence/l03")
        try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
        let preferences = Preferences(directories: [.init(path: app.deletingLastPathComponent().path)])
        try await PreferencesStore(url: state.appendingPathComponent("preferences.json")).save(preferences)
        let instance = AppModel(preferencesDirectory: state, homebrewExecutable: root.appendingPathComponent("homebrew/bin/brew"))
        model = instance
        let content = NSHostingController(rootView: LatestWindow(model: instance))
        let window = NSWindow(contentViewController: content)
        window.title = "Latest — native Homebrew acceptance"
        window.setContentSize(NSSize(width: 1000, height: 650))
        window.center(); window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate()
        await instance.start()
        try await waitUntil { !instance.scanning && instance.rows.contains { $0.id == AppInstanceID(url: app) && $0.record.candidate != nil } }
        guard let row = instance.rows.first(where: { $0.id == AppInstanceID(url: app) }),
              row.record.status == .available, row.record.app.version.display == "1.0.0",
              row.record.candidate?.source == .homebrew else {
            throw LatestFailure.rejected("The real baseline cask was not resolved as an available Homebrew update.")
        }
        instance.selectedID = row.id
        try await Task.sleep(for: .milliseconds(300))
        try capture(window, to: evidence.appendingPathComponent("before.png"))
        let before = row.record.app
        instance.requestUpdate(row)
        try await waitUntil { row.event?.isTerminal == true }
        guard row.event?.phase == .succeeded, let installed = AppInventory.snapshot(at: app),
              installed.bundleID == before.bundleID, installed.version.display == "1.1.0",
              installed.architectures == before.architectures else {
            throw LatestFailure.process("The real update did not succeed with the expected installed identity/version/architecture: \(row.event?.message ?? instance.errorMessage)")
        }
        try await waitUntil { !instance.scanning && instance.rows.first { $0.id == row.id }?.record.status == .current }
        try await Task.sleep(for: .milliseconds(300))
        try capture(window, to: evidence.appendingPathComponent("after.png"))
        let result = ["before": before.version.description, "after": installed.version.description,
                      "bundleID": installed.bundleID, "path": installed.id.path,
                      "terminalPhase": row.event?.phase.rawValue ?? "", "postScanStatus": "current",
                      "provider": "real HomebrewProvider via production AppModel",
                      "hostArchitecture": installed.architectures.map(\.rawValue).sorted().joined(separator: ",")]
        try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            .write(to: evidence.appendingPathComponent("result.json"), options: .atomic)
        print("Native Homebrew acceptance passed: 1.0.0 → 1.1.0; installed bundle verified before success; native UI rescanned to current.")
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(90))
        while !condition() {
            guard ContinuousClock.now < deadline else { throw LatestFailure.timeout }
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    private func capture(_ window: NSWindow, to path: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-l", String(window.windowNumber), path.path]
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0, FileManager.default.fileExists(atPath: path.path) else {
            throw LatestFailure.process("Could not capture the native acceptance window.")
        }
    }
}

@main @MainActor enum HomebrewAcceptance {
    static func main() {
        guard CommandLine.arguments.count == 2 else { exit(2) }
        let app = NSApplication.shared
        let delegate = HomebrewAcceptanceDelegate(root: URL(fileURLWithPath: CommandLine.arguments[1]))
        app.setActivationPolicy(.regular); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
