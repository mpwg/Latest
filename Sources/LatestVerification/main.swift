import Foundation
import LatestCore
import LatestProcess
import LatestPlatform

@main struct Verification {
    static func main() async {
        do { try await run() }
        catch { FileHandle.standardError.write(Data(("Verification failed: \(error)\n").utf8)); exit(1) }
    }
    static func run() async throws {
        var count = 0
        func check(_ condition: Bool, _ name: String) throws {
            guard condition else { throw LatestFailure.rejected("FAIL: \(name)") }
            count += 1; print("PASS: \(name)")
        }
        let a = AppVersion(display: "1.2"), b = AppVersion(display: "1.2.0")
        try check(a.compare(to: b) == .same, "Trailing zero comparison")
        try check(Set([a, a]).count == 1, "Structural equality and hashing")
        try check(AppVersion(display: nil) == AppVersion(display: nil), "Empty value equality is reflexive")
        try check(a.compare(to: .init(display: "1.2.0.1")) == .older, "Interior zero is significant")
        let c = AppVersion(display: "2", build: "2"), d = AppVersion(display: "3", build: "1")
        try check(c.compare(to: d) == .older && d.compare(to: c) == .newer, "Symmetric display policy")
        try check(c.compare(to: d, policy: .build) == .newer && d.compare(to: c, policy: .build) == .older, "Symmetric build policy")
        try check(AppVersion(display: "2026.2.15").compare(to: .init(display: "2026.2.19")) == .older, "Calendar versions")
        try check(AppVersion(display: "1.0rc1").compare(to: .init(display: "1.0")) == .older, "Release candidate precedes stable")
        try check(AppVersion(display: "٣.١").compare(to: .init(display: "3.2")) == .older, "Unicode digits")
        try check(AppVersion(display: String(repeating: "9", count: 100)).compare(to: .init(display: "2")) == .newer, "Large numeric components")
        try check(AppVersion(display: "🚀").compare(to: a) == .unknown, "Invalid versions are unknown")
        let app = AppSnapshot(url: URL(fileURLWithPath: "/Applications/Test.app"), bundleID: "org.example.Test", name: "Test", version: a, fingerprint: "one")
        let candidate = UpdateCandidate(app: app, source: .catalogue, version: .init(display: "2"), action: .homebrew("test"), authoritative: false)
        try check(Resolution.record(app, candidate: candidate, preferences: .init(), operatingSystem: .init(majorVersion: 27, minorVersion: 0, patchVersion: 0), architecture: .arm64).status == .unknown, "Catalogue cannot authorize installation")
        try check(!Resolution.supports(minimum: "", current: .init(majorVersion: 27, minorVersion: 0, patchVersion: 0)), "Empty minimum OS is rejected")
        let scan = ScanLedger()
        let first = await scan.begin(apps: [app]); let second = await scan.begin(apps: [app])
        try check(await scan.accept(.init(app: app), generation: first) == false, "Late scan results rejected")
        try check(await scan.accept(.init(app: app), generation: second), "Current scan results accepted")
        let jobs = JobLedger(); let token = try await jobs.start(app.id)
        try check(await jobs.accept(.init(.installing), app: app.id, token: token), "Job advances")
        try check(await jobs.accept(.init(.downloading), app: app.id, token: token) == false, "Late download progress rejected")
        try check(await jobs.accept(.init(.succeeded), app: app.id, token: token), "Job completes")
        try check(await jobs.accept(.init(.failed), app: app.id, token: token) == false, "Exactly one terminal state")
        let claim = AppStoreClaim(storeID: 123, bundleID: app.bundleID, path: app.id.path)
        try BrokerPolicy.validate(claim, installed: [claim], outdatedIDs: [123])
        try check(try BrokerPolicy.arguments(for: claim) == ["update", "123"], "Fixed numeric mas request")
        do { try BrokerPolicy.validate(claim, installed: [claim, claim], outdatedIDs: [123]); throw LatestFailure.process("Duplicate accepted") }
        catch LatestFailure.rejected { try check(true, "Duplicate App Store instances rejected") }
        do { _ = try BrokerPolicy.arguments(for: .init(storeID: 0, bundleID: "x", path: app.id.path)); throw LatestFailure.process("Zero accepted") }
        catch LatestFailure.rejected { try check(true, "Empty/all-app mas request unreachable") }
        try check(SafeText.releaseNotes("<script>evil()</script><p>Safe</p>") == "Safe", "Release notes rendered without scripts")
        let caskData = Data(#"{"casks":[{"token":"valid","version":"2","installed":"1","artifacts":[{"app":["Test.app"]}],"depends_on":{"macos":{">=":["14"]}}},{"token":"empty-os","version":"2","artifacts":[{"app":["Other.app"]}],"depends_on":{"macos":{">=":[""]}}},{"token":"--bad","version":"2"}]}"#.utf8)
        let casks = try Metadata.casks(caskData)
        try check(casks.count == 2 && casks.first?.minimumOS == "14" && casks.last?.minimumOS == nil, "Invalid cask entries cannot discard valid neighbours")
        try check(try Metadata.outdatedCaskTokens(Data(#"{"casks":[{"name":"test","current_version":"2","installed_versions":["1"]}]}"#.utf8)) == ["test"], "Actual Homebrew outdated JSON schema")
        try check(!Metadata.validToken("test;echo unsafe") && !Metadata.validToken("--force") && Metadata.validToken("test@2"), "Cask argument validation")
        let installedJSON = Data(#"{"adamID":123,"bundleID":"org.example.Test","path":"/Applications/Test.app","version":"1"}"#.utf8)
        try check(try MasMetadata.installed(installedJSON) == [claim], "Pinned mas normalized installation JSON")
        try check(try MasMetadata.outdated(Data(#"{"adamID":123,"newVersion":"2"}"#.utf8)) == [123], "Pinned mas normalized outdated JSON")
        try check(MachO.architectures(Data([0xcf,0xfa,0xed,0xfe,0x0c,0,0,1])) == [.arm64], "Native Mach-O architecture")
        try check(MachO.architectures(Data([1,2])) == [], "Truncated Mach-O header")
        let runner = CommandRunner()
        let quoted = try await runner.run(executable: URL(fileURLWithPath: "/usr/bin/printf"), arguments: ["%s", "Robert's app;$(echo unsafe)"], environment: CommandRunner.userEnvironment())
        try check(quoted.exitCode == 0 && quoted.text == "Robert's app;$(echo unsafe)", "Arguments never enter a shell")
        do {
            _ = try await runner.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["10"], environment: CommandRunner.userEnvironment(), timeout: .milliseconds(30))
            throw LatestFailure.process("Timeout not enforced")
        } catch LatestFailure.timeout { try check(true, "Process timeout kills owned group") }
        do {
            _ = try await runner.run(executable: URL(fileURLWithPath: "/usr/bin/yes"), arguments: [], environment: CommandRunner.userEnvironment(), maximumBytes: 100)
            throw LatestFailure.rejected("Output bound not enforced")
        } catch LatestFailure.process { try check(true, "Process output is bounded and drained without deadlock") }
        let cancelled = Task { try await runner.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["10"], environment: CommandRunner.userEnvironment()) }
        try await Task.sleep(for: .milliseconds(40)); cancelled.cancel()
        do { _ = try await cancelled.value; throw LatestFailure.process("Cancellation ignored") }
        catch is CancellationError { try check(true, "Process cancellation reaps the child") }
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/verification-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = root.appendingPathComponent("Test.app/Contents")
        try FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: true)
        let plist: [String: String] = ["CFBundleIdentifier": "org.example.Test", "CFBundleName": "Test", "CFBundleShortVersionString": "1", "CFBundleVersion": "1"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: fixture.appendingPathComponent("Info.plist"))
        let inventory = AppInventory.collect([.init(path: root.path)])
        try check(inventory.apps.count == 1 && inventory.apps.first?.version.display == "1", "Inventory reads Info.plist without loading foreign code")
        var updated = plist; updated["CFBundleShortVersionString"] = "2"
        try PropertyListSerialization.data(fromPropertyList: updated, format: .xml, options: 0).write(to: fixture.appendingPathComponent("Info.plist"))
        try check(AppInventory.collect([.init(path: root.path)]).apps.first?.version.display == "2", "Inventory bypasses stale Bundle caches")
        try check(AppInventory.collect([.init(path: root.path, enabled: false)]).apps.isEmpty, "Disabled directories are excluded")
        try check(!AppInventory.collect([.init(path: root.appendingPathComponent("missing").path)]).warnings.isEmpty, "Missing directory is recoverable")
        let store = PreferencesStore(url: root.appendingPathComponent("preferences.json"))
        var preferences = try await store.load(legacy: ["IgnoredAppsKey": .strings(["org.example.Test"]), "directoryPaths": .strings([root.path])])
        try check(preferences.ignoredBundleIDs.contains("org.example.Test") && preferences.directories.contains(where: { $0.path == root.path }), "Legacy preferences migrate")
        preferences.showCurrent = false; try await store.save(preferences)
        let persisted = try await store.load(legacy: ["IgnoredAppsKey": .strings([])])
        try check(persisted == preferences, "Migration runs once and settings persist")
        do { _ = try Metadata.exclusions(Data("not a plist".utf8)); throw LatestFailure.process("Invalid plist accepted") }
        catch LatestFailure.process(let message) { throw LatestFailure.process(message) }
        catch { try check(true, "Invalid exclusion response is recoverable") }
        let http = BoundedHTTPClient(cacheDirectory: root.appendingPathComponent("cache"))
        do { _ = try await http.fetch(URL(string: "http://example.invalid")!); throw LatestFailure.process("HTTP accepted") }
        catch LatestFailure.rejected { try check(true, "HTTP rejected before network access") }
        print("Verified \(count) core invariants.")
    }
}
