import AppKit
import Foundation
import LatestCore
import LatestApplication
import LatestPlatform

typealias AppModel = ApplicationSession
typealias AppRow = ApplicationRow

extension ApplicationRow {
    var icon: NSImage { NSWorkspace.shared.icon(forFile: id.path) }
}

/// Composition root only: native launch configuration and platform dependencies.
@MainActor func makeApplicationSession() -> ApplicationSession {
    let arguments = ProcessInfo.processInfo.arguments
    func argument(_ name: String) -> String? {
        arguments.firstIndex(of: name).flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }
    }
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? FileManager.default.temporaryDirectory
    #if DEBUG
    let uiTesting = arguments.contains("--ui-testing")
    let nativeRoot = argument("--native-install-test-directory").map { URL(fileURLWithPath: $0) }
    let catalogueURL = argument("--native-install-test-catalogue-url").flatMap(URL.init(string:))
    let domain = argument("--native-migration-test-domain").flatMap {
        $0.hasPrefix("io.github.mpwg.Latest.NativeMigration.") ? $0 : nil
    } ?? "com.max-langer.Latest"
    let monitoringInterval: Duration? = nativeRoot != nil && arguments.contains("--native-install-test-hold-scans") ? nil : .seconds(5)
    let fixture = FixtureInventory()
    let fixtureRecords: (@MainActor @Sendable (Preferences) -> [AppRecord])? = uiTesting ? { @MainActor @Sendable in fixture.records($0) } : nil
    #else
    let nativeRoot: URL? = nil
    let catalogueURL: URL? = nil
    let domain = "com.max-langer.Latest"
    let monitoringInterval: Duration? = .seconds(5)
    let fixtureRecords: (@MainActor @Sendable (Preferences) -> [AppRecord])? = nil
    #endif
    #if DEBUG
    let testRoot = argument("--ui-test-directory").map { URL(fileURLWithPath: $0) }
    let root = nativeRoot?.appendingPathComponent("preferences/l03") ?? (uiTesting
        ? testRoot ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/ui-test-state")
        : support.appendingPathComponent("io.github.mpwg.Latest"))
    #else
    let root = support.appendingPathComponent("io.github.mpwg.Latest")
    #endif
    let runtime = LiveApplicationRuntime(cacheDirectory: root.appendingPathComponent("Cache"),
        homebrewExecutable: nativeRoot?.appendingPathComponent("homebrew/bin/brew"),
        masURL: Bundle.main.url(forResource: "mas", withExtension: nil), catalogueURL: catalogueURL)
    return ApplicationSession(runtime: runtime, preferencesURL: root.appendingPathComponent("preferences.json"),
        diagnosticURL: root.appendingPathComponent("diagnostics.log"), legacy: LegacyPreferences.read(domain: domain),
        monitoringInterval: monitoringInterval,
        jobJournal: nativeRoot?.appendingPathComponent("preferences/l03/job-events.jsonl"), fixtureRecords: fixtureRecords)
}

@MainActor final class FixtureInventory {
    private var fixtureOrderReversed = false
    #if DEBUG
    func records(_ preferences: Preferences) -> [AppRecord] {
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-matrix") {
            return matrixRecords()
        }
        let app = AppSnapshot(url: URL(fileURLWithPath: "/Applications/Latest Test.app"), bundleID: "org.example.test", name: "Latest Test", version: .init(display: "1"))
        let candidate = UpdateCandidate(app: app, source: .sparkle, version: .init(display: "2"), action: .external(URL(string: "https://example.invalid")!), authoritative: true, releaseNotes: "Controlled release notes fixture.")
        let status: AppStatus = preferences.ignoredBundleIDs.contains(app.bundleID) ? .ignored : preferences.skippedVersions[app.id.path] == candidate.id ? .skipped : .external
        return [.init(app: app, candidate: candidate, status: status)]
    }
    private func matrixRecords() -> [AppRecord] {
        // Read-only inventory for native view acceptance; no live provider/install claim.
        let fixtures: [(String, String, String, UpdateSource, AppStatus)] = [
            ("Alpha", "/Applications/Alpha.app", "org.example.alpha", .homebrew, .available),
            ("Beta", "/Applications/Beta.app", "org.example.beta", .catalogue, .external),
            ("Mystery", "/Applications/Mystery.app", "org.example.mystery", .unknown, .unknown),
            ("Twin", "/Applications/A/Twin.app", "org.example.twin", .sparkle, .available),
            ("Twin", "/Applications/B/Twin.app", "org.example.twin", .sparkle, .current),
            ("Zebra", "/Applications/Zebra.app", "org.example.zebra", .appStore, .current),
            ("Ignored", "/Applications/Ignored.app", "org.example.ignored", .homebrew, .ignored),
            ("Skipped", "/Applications/Skipped.app", "org.example.skipped", .sparkle, .skipped),
            ("Incompatible", "/Applications/Incompatible.app", "org.example.incompatible", .sparkle, .incompatible)
        ]
        fixtureOrderReversed.toggle()
        let ordered = fixtureOrderReversed ? Array(fixtures.reversed()) : fixtures
        return ordered.map { name, path, bundleID, source, status in
            let app = AppSnapshot(url: URL(fileURLWithPath: path), bundleID: bundleID, name: name, version: .init(display: "1"))
            let candidate: UpdateCandidate? = source == .unknown ? nil : .init(app: app, source: source, version: .init(display: status == .current ? "1" : "1.1"), action: .none, authoritative: source != .catalogue)
            return .init(app: app, candidate: candidate, status: status)
        }
    }
    #endif
}
