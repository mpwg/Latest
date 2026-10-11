import Foundation
import Testing
import LatestCore
import LatestApplication
import LatestPlatform

@Suite("Native preferences through the shared session") @MainActor
struct NativePreferencesTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["LATEST_HEADLESS_PREFERENCES_PHASE"] != nil,
                   "Requires explicitly prepared signed disposable apps and localhost HTTPS."))
    func realPreferencesWithoutGUIAutomation() async throws {
        let phase = try #require(ProcessInfo.processInfo.environment["LATEST_HEADLESS_PREFERENCES_PHASE"])
        try #require(["ignore", "ignored-restart", "skip-restart", "new", "new-restart",
                      "beta", "beta-restart", "stable", "stable-restart"].contains(phase))
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent(".build/native-install-tests")
        let selected = root.appendingPathComponent("applications/Latest Sparkle Fixture.app")
        let secondary = root.appendingPathComponent("applications/Secondary/Latest Sparkle Fixture.app")
        let before = try #require(AppInventory.snapshot(at: selected))
        let other = try #require(AppInventory.snapshot(at: secondary))
        try #require(before.bundleID == "io.github.mpwg.Latest.NativeFixture.Sparkle" && before.signatureTeam != nil)
        try #require(other.bundleID == before.bundleID && other.signatureTeam == before.signatureTeam)
        try #require(before.version.display == "1.0.0" && other.version.display == "1.0.0")
        let state = root.appendingPathComponent("preferences/headless-preferences")
        let preferencesURL = state.appendingPathComponent("preferences.json")
        if phase == "ignore" || phase == "beta" {
            var preferences = Preferences(directories: [.init(path: root.appendingPathComponent("applications").path)])
            preferences.showIgnored = true
            try await PreferencesStore(url: preferencesURL).save(preferences)
        }
        let runtime = LiveApplicationRuntime(cacheDirectory: state.appendingPathComponent("Cache"),
            homebrewExecutable: root.appendingPathComponent("homebrew/bin/brew"))
        let app = ApplicationSession(runtime: runtime, preferencesURL: preferencesURL,
            diagnosticURL: state.appendingPathComponent("diagnostics.log"), monitoringInterval: nil,
            jobJournal: state.appendingPathComponent("job-events.jsonl"))
        await app.start(); await app.waitForScan()
        let row = try #require(app.rows.first { $0.id == before.id })
        let otherRow = try #require(app.rows.first { $0.id == other.id })
        app.selectedID = before.id
        let skippedID = before.id.path + "|sparkle|1.1.0 (2)"
        switch phase {
        case "ignore":
            try #require(app.canUpdate(before.id) && app.canUpdate(other.id))
            app.ignore(before.id); await app.waitForScan()
            #expect(row.record.status == .ignored && otherRow.record.status == .ignored)
            #expect(!app.canUpdate(before.id) && !app.canUpdate(other.id))
            app.requestUpdate(before.id)
            app.preferences.showIgnored = false
            #expect(!app.visibleRows.contains { $0.id == before.id || $0.id == other.id })
            app.preferences.showIgnored = true
        case "ignored-restart":
            try #require(row.record.status == .ignored && otherRow.record.status == .ignored)
            #expect(app.preferences.ignoredBundleIDs == [before.bundleID])
            app.requestUpdate(before.id)
            app.ignore(before.id); await app.waitForScan()
            try #require(app.canUpdate(before.id) && app.canUpdate(other.id))
            app.skip(before.id); await app.waitForScan()
            #expect(row.record.status == .skipped && !app.canUpdate(before.id))
            #expect(otherRow.record.status == .available && app.canUpdate(other.id))
        case "skip-restart":
            try #require(row.record.status == .skipped && otherRow.record.status == .available)
            #expect(app.preferences.skippedVersions == [before.id.path: skippedID])
            #expect(!app.canUpdate(before.id) && app.canUpdate(other.id))
            app.requestUpdate(before.id)
            app.clearSkip(before.id); await app.waitForScan()
            try #require(app.canUpdate(before.id))
            app.skip(before.id); await app.waitForScan()
            #expect(row.record.status == .skipped && otherRow.record.status == .available)
        case "new", "new-restart":
            #expect(app.preferences.skippedVersions == [before.id.path: skippedID])
            #expect(row.record.candidate?.version.display == "1.2.0")
            #expect(otherRow.record.candidate?.version.display == "1.2.0")
            #expect(app.canUpdate(before.id) && app.canUpdate(other.id))
            #expect(row.record.status == .available && otherRow.record.status == .available)
        case "beta":
            try #require(row.record.candidate?.version.display == "1.1.0")
            app.preferences.channels[before.id.path] = .beta; await app.waitForScan()
            #expect(row.record.candidate?.version.display == "1.2.0")
            #expect(otherRow.record.candidate?.version.display == "1.1.0")
            #expect(app.preferences.channels == [before.id.path: .beta])
        case "beta-restart", "stable":
            try #require(row.record.candidate?.version.display == "1.2.0")
            #expect(otherRow.record.candidate?.version.display == "1.1.0")
            #expect(app.preferences.channels == [before.id.path: .beta])
            app.refresh(); await app.waitForScan()
            #expect(row.record.candidate?.version.display == "1.2.0")
            if phase == "stable" {
                app.preferences.channels[before.id.path] = .stable; await app.waitForScan()
                #expect(row.record.candidate?.version.display == "1.1.0")
                #expect(otherRow.record.candidate?.version.display == "1.1.0")
            }
        case "stable-restart":
            #expect(app.preferences.channels == [before.id.path: .stable])
            #expect(row.record.candidate?.version.display == "1.1.0")
            #expect(otherRow.record.candidate?.version.display == "1.1.0")
        default: Issue.record("Unexpected native preferences phase.")
        }
        await app.waitForUpdates(); await app.flushPreferences()
        #expect(row.event == nil && otherRow.event == nil)
        #expect(app.activeUpdates == 0 && app.canQuit && !app.showingError)
        #expect(AppInventory.snapshot(at: selected)?.fingerprint == before.fingerprint)
        #expect(AppInventory.snapshot(at: secondary)?.fingerprint == other.fingerprint)
        print("Actual native preferences phase \(phase) verified and persisted.")
    }
}
