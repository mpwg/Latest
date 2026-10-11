import Foundation
import AppKit
import Testing
import LatestProcess
import LatestTrust
@testable import LatestCore
@testable import LatestPlatform

@Suite("Audit regression contracts") struct CoreTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["LATEST_HEADLESS_BROKER_BOUNDARY"] != nil,
                   "Requires a private development-signed Latest bundle and explicitly controlled mutations."))
    @MainActor func realBrokerBoundaryWithoutGUIAutomation() async throws {
        let environment = ProcessInfo.processInfo.environment
        let mode = try #require(environment["LATEST_HEADLESS_BROKER_BOUNDARY"])
        try #require(["valid", "mas", "verifier", "pin", "wrong-id", "adhoc", "symlink", "unavailable", "cancelled"].contains(mode))
        let path = try #require(environment["LATEST_HEADLESS_BROKER_APP"])
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent(".build/native-install-tests/evidence/headless-broker-boundary")
        try #require(path.hasPrefix(root.path + "/"))
        let appURL = URL(fileURLWithPath: path)
        let client = BrokerClient()
        let claim = AppStoreClaim(storeID: UInt64(Int64.max), bundleID: "io.github.mpwg.Latest.NativeFixture.NotAStoreApp",
                                  path: "/Applications/Latest Native Broker Fixture.app")
        try #require(!FileManager.default.fileExists(atPath: claim.path))
        if mode == "valid" {
            let configuration = try BrokerConfiguration.load(appURL: appURL)
            try configuration.verifyBundledTools(appURL: appURL)
            #expect(configuration.team == "PZV43D6HWT")
        } else if mode == "unavailable" {
            for _ in 0..<2 {
                let start = ContinuousClock.now
                do { try await client.update(claim, appURL: appURL); Issue.record("Unavailable broker unexpectedly accepted a request.") }
                catch LatestFailure.process(let reason) { print("Observed native unavailable broker error: \(reason)") }
                #expect(start.duration(to: .now) < .seconds(10))
                #expect(client.activeConnectionCount == 0)
            }
        } else if mode == "cancelled" {
            let request = Task { @MainActor in try await client.update(claim, appURL: appURL) }
            request.cancel()
            do { try await request.value; Issue.record("Pre-cancelled request unexpectedly opened a connection.") }
            catch is CancellationError { }
            #expect(client.activeConnectionCount == 0)
        } else {
            do { try await client.update(claim, appURL: appURL); Issue.record("Altered signed bundle/tool was accepted.") }
            catch LatestFailure.rejected(let reason) { print("Observed native signed boundary rejection: \(reason)") }
            #expect(client.activeConnectionCount == 0)
        }
        #expect(client.activeConnectionCount == 0)
    }
    @Test @MainActor func malformedBrokerRequestsNeverOpenAConnection() async throws {
        let client = BrokerClient()
        for claim in [AppStoreClaim(storeID: 0, bundleID: "fixture", path: "/Applications/Fixture.app"),
                      .init(storeID: 1, bundleID: "bad\nidentifier", path: "/Applications/Fixture.app"),
                      .init(storeID: 1, bundleID: "fixture", path: "/Applications/../tmp/Fixture.app"),
                      .init(storeID: 1, bundleID: "fixture", path: "/Applications/Subfolder/Fixture.app")] {
            do { try await client.update(claim, appURL: URL(fileURLWithPath: "/nonexistent-fixture.app")); Issue.record("Malformed request was accepted.") }
            catch LatestFailure.rejected(let reason) {
                #expect(reason == "The App Store update request is invalid or targets a nonstandard location.")
            }
            #expect(client.activeConnectionCount == 0)
        }
    }
    @Test(arguments: ["1.2", "1.2.0", "2026.2.19", "٣.١", "1.0rc1", "", "🚀"])
    func equalityIsReflexive(_ string: String) {
        let value = AppVersion(display: string)
        #expect(value == value)
        #expect(Set([value, value]).count == 1)
    }
    @Test func comparisonIsSymmetric() {
        let values = [AppVersion(display: "1.2"), .init(display: "1.2.0.1"), .init(display: "2", build: "2"), .init(display: "3", build: "1")]
        for a in values { for b in values {
            if a.compare(to: b) == .older { #expect(b.compare(to: a) == .newer) }
            if a.compare(to: b, policy: .build) == .older { #expect(b.compare(to: a, policy: .build) == .newer) }
        } }
    }
    @Test func maliciousBrokerClaimsAreRejected() throws {
        let valid = AppStoreClaim(storeID: 123, bundleID: "org.example.Test", path: "/Applications/Test.app")
        try BrokerPolicy.validate(valid, installed: [valid], outdatedIDs: [123])
        for claim in [AppStoreClaim(storeID: 0, bundleID: valid.bundleID, path: valid.path),
                      .init(storeID: 123, bundleID: "--bad;command", path: valid.path),
                      .init(storeID: 123, bundleID: valid.bundleID, path: "/Applications/../Test.app"),
                      .init(storeID: 123, bundleID: valid.bundleID, path: "/tmp/Test.app")] {
            #expect(throws: LatestFailure.self) { try BrokerPolicy.validate(claim, installed: [claim], outdatedIDs: [123]) }
        }
        #expect(throws: LatestFailure.self) { try BrokerPolicy.validate(valid, installed: [valid, valid], outdatedIDs: [123]) }
    }
    @Test func lateResultsAreRejected() async {
        let app = AppSnapshot(url: URL(fileURLWithPath: "/Applications/Test.app"), bundleID: "org.example.Test", name: "Test", version: .init(display: "1"))
        let ledger = ScanLedger()
        let old = await ledger.begin(apps: [app]); _ = await ledger.begin(apps: [])
        #expect(await ledger.accept(.init(app: app), generation: old) == false)
    }
    @Test func duplicateReplyIsIgnored() async throws {
        let gate = CompletionGate<Int>()
        #expect(await gate.finish(.success(1)))
        #expect(await gate.finish(.success(2)) == false)
        #expect(try await gate.wait() == 1)
    }
    @Test func caskSchemaDriftIsContained() throws {
        let data = Data(#"{"casks":[{"token":"valid","version":"1","artifacts":[]},{"token":"empty-os","version":"2","artifacts":[],"depends_on":{"macos":{">=":[""]}}}]}"#.utf8)
        #expect(try Metadata.casks(data).count == 2)
    }
    @Test func structuredProcessOutputRemainsSeparateFromDiagnostics() async throws {
        let runner = CommandRunner()
        let program = "import sys; sys.stderr.write('Diagnostic warning\\n'); sys.stdout.write('{\"ok\":true}'); sys.stderr.write('Follow-up warning\\n')"
        let result = try await runner.run(executable: URL(fileURLWithPath: "/usr/bin/python3"),
            arguments: ["-c", program], environment: CommandRunner.userEnvironment())
        #expect(result.exitCode == 0)
        let value = try JSONDecoder().decode([String: Bool].self, from: result.output)
        #expect(value["ok"] == true)
        #expect(result.stderrText.contains("Diagnostic warning"))
        #expect(result.text.contains("Follow-up warning"))
        let flood = "import sys,time; sys.stderr.write('x'*8192); sys.stderr.flush(); time.sleep(60)"
        do {
            _ = try await runner.run(executable: URL(fileURLWithPath: "/usr/bin/python3"), arguments: ["-c", flood],
                environment: CommandRunner.userEnvironment(), timeout: .seconds(5), maximumBytes: 1024)
            Issue.record("An oversized diagnostic stream was accepted.")
        } catch let error as LatestFailure {
            #expect(error == .process("The process output exceeds the size limit."))
        }
    }
    @Test func packageCannotWriteOutsideSelectedApp() {
        let claim = AppStoreClaim(storeID: 123, bundleID: "org.example.Test", path: "/Applications/Test.app")
        #expect(throws: LatestFailure.self) {
            try PackagePolicy.validate(bundleIDs: [claim.bundleID], installLocations: ["/Applications"], payloadPaths: ["../Library/evil"], containsScripts: false, claim: claim)
        }
    }
    @MainActor @Test func sparkleCancellationAndLateCallbacks() {
        let app = AppSnapshot(url: URL(fileURLWithPath: "/tmp/Fixture.app"), bundleID: "org.example.Fixture", name: "Fixture", version: .init(display: "1"))
        var events: [UpdateEvent] = []
        var cancellations = 0
        let session = SparkleSession(app: app, channel: .stable, installing: true) { events.append($0) }
        session.showDownloadInitiated { cancellations += 1 }
        session.showDownloadDidReceiveExpectedContentLength(100)
        session.showDownloadDidReceiveData(ofLength: 20)
        session.cancel(); session.cancel()
        #expect(cancellations == 1)
        #expect(events.last?.progress == 0.2)
        let count = events.count
        session.showDownloadDidReceiveData(ofLength: 50)
        session.showDownloadDidStartExtractingUpdate()
        session.showInstallingUpdate(withApplicationTerminated: true, retryTerminatingApplication: {})
        session.showUpdaterError(LatestFailure.timeout, acknowledgement: {})
        session.showUpdateInstalledAndRelaunched(false, acknowledgement: {})
        #expect(events.count == count)
        session.showDownloadInitiated { cancellations += 1 }
        #expect(cancellations == 2)
    }
    @MainActor @Test func sparkleHandoffRejectsCancellation() {
        let app = AppSnapshot(url: URL(fileURLWithPath: "/tmp/Fixture.app"), bundleID: "org.example.Fixture", name: "Fixture", version: .init(display: "1"))
        var events: [UpdateEvent] = []
        var cancellations = 0
        let session = SparkleSession(app: app, channel: .stable, installing: true) { events.append($0) }
        session.showDownloadInitiated { cancellations += 1 }
        session.showDownloadDidStartExtractingUpdate()
        session.cancel()
        session.showInstallingUpdate(withApplicationTerminated: true, retryTerminatingApplication: {})
        #expect(cancellations == 0)
        #expect(events.map(\.phase) == [.downloading, .installing, .installing])
        session.showUpdateInstalledAndRelaunched(false, acknowledgement: {})
        let count = events.count
        session.showDownloadDidReceiveData(ofLength: 100)
        #expect(events.count == count)
    }
    @Test func completedJobCannotAffectRetry() async throws {
        let app = AppInstanceID(url: URL(fileURLWithPath: "/tmp/Fixture.app"))
        let ledger = JobLedger()
        let old = try await ledger.start(app)
        #expect(await ledger.accept(.init(.cancelled), app: app, token: old))
        #expect(await ledger.accept(.init(.failed), app: app, token: old) == false)
        let retry = try await ledger.start(app)
        #expect(await ledger.accept(.init(.installing), app: app, token: old) == false)
        #expect(await ledger.accept(.init(.downloading), app: app, token: retry))
        #expect(await ledger.event(for: app)?.phase == .downloading)
    }
    @Test func providerDeclaredMajorRequiresConsentAndNeverBulk() throws {
        let app = AppSnapshot(url: URL(fileURLWithPath: "/tmp/Major.app"), bundleID: "org.example.Major", name: "Major", version: .init(display: "1.0", build: "1"))
        let minor = UpdateCandidate(app: app, source: .sparkle, version: .init(display: "1.1", build: "2"), action: .sparkle(URL(string: "https://example.org/feed")!), authoritative: true)
        let declared = UpdateCandidate(app: app, source: .sparkle, version: minor.version, action: minor.action, authoritative: true, explicitMajorUpgrade: true)
        #expect(minor.isMajorUpgrade == false)
        #expect(Presentation.bulkEligible(minor, status: .available))
        #expect(declared.isMajorUpgrade)
        #expect(Presentation.bulkEligible(declared, status: .available) == false)
        let legacy = try JSONDecoder().decode(UpdateCandidate.self, from: JSONEncoder().encode(minor))
        #expect(legacy.explicitMajorUpgrade == nil)
        #expect(legacy.isMajorUpgrade == false)
    }
}

@testable import LatestApplication

private actor ApplicationTestRuntime: ApplicationRuntime {
    enum Installation { case immediate, downloadGate, handoffGate, failure }
    var apps: [AppSnapshot]
    var candidates: [AppInstanceID: UpdateCandidate]
    var validated: [AppInstanceID] = []
    var installed: [AppInstanceID] = []
    var installation: Installation = .immediate
    var rejectValidation = false
    var rejectVerification = false
    let started = CompletionGate<AppInstanceID>()
    let release = CompletionGate<Void>()
    let checkStarted = CompletionGate<Void>()
    let releaseCheck = CompletionGate<Void>()
    var holdChecks = false
    var savedCallback: (@MainActor @Sendable (UpdateEvent) -> Void)?
    init(_ candidates: [UpdateCandidate]) {
        self.apps = candidates.map(\.app)
        self.candidates = Dictionary(candidates.map { ($0.app.id, $0) }, uniquingKeysWith: { a, _ in a })
    }
    func configure(installation: Installation = .immediate, rejectValidation: Bool = false, rejectVerification: Bool = false) {
        self.installation = installation; self.rejectValidation = rejectValidation; self.rejectVerification = rejectVerification
    }
    func setApps(_ apps: [AppSnapshot]) { self.apps = apps }
    func setCandidate(_ candidate: UpdateCandidate) { candidates[candidate.app.id] = candidate }
    func holdProviderCheck() { holdChecks = true }
    func scan(_ directories: [DirectoryPreference]) -> ApplicationInventory { .init(apps: apps) }
    func check(_ app: AppSnapshot, context: CheckContext) async -> AppRecord {
        let candidate = candidates[app.id]
        if holdChecks {
            await checkStarted.finish(.success(()))
            // Deliberately ignore cancellation: a stale provider reply must still be rejected.
            _ = try? await releaseCheck.wait()
        }
        return Resolution.record(app, candidate: candidate, preferences: context.preferences,
            operatingSystem: .init(majorVersion: 27, minorVersion: 0, patchVersion: 1), architecture: .arm64)
    }
    func validate(_ app: AppSnapshot) throws -> AppSnapshot {
        validated.append(app.id)
        guard !rejectValidation else { throw LatestFailure.rejected("Selected instance changed.") }
        return app
    }
    func install(_ candidate: UpdateCandidate, context: CheckContext,
                 event: @escaping @MainActor @Sendable (UpdateEvent) -> Void) async throws {
        let obsoleteCallback = savedCallback
        installed.append(candidate.app.id); savedCallback = event
        await event(.init(installation == .handoffGate ? .installing : .downloading, progress: 0.25))
        if installed.count > 1 { await obsoleteCallback?(.init(.failed, message: "Obsolete job callback during retry")) }
        await started.finish(.success(candidate.app.id))
        if installation == .failure { throw LatestFailure.process("Controlled install failure.") }
        if installation == .downloadGate || installation == .handoffGate {
            try await withTaskCancellationHandler { try await release.wait() }
                onCancel: { Task { await self.release.finish(.failure(.cancelled)) } }
        }
        let previous = candidate.app
        let updated = AppSnapshot(url: previous.id.url, bundleID: previous.bundleID, name: previous.name,
            version: candidate.version, architectures: previous.architectures, fingerprint: "installed")
        apps = apps.map { $0.id == updated.id ? updated : $0 }
        candidates[updated.id] = UpdateCandidate(app: updated, source: candidate.source, version: candidate.version,
            action: candidate.action, authoritative: true)
    }
    func verify(_ candidate: UpdateCandidate, context: CheckContext) throws {
        if rejectVerification { throw LatestFailure.process("Installed version does not match.") }
    }
    func lateFailure() async { await savedCallback?(.init(.failed, message: "Late obsolete callback")) }
    func releaseNotes(_ url: URL) -> String { "<script>bad()</script><p>Remote notes</p>" }
    func enableBroker() -> Bool { true }
}

@MainActor @Suite("Headless application workflows") struct ApplicationTests {
    private func candidate(_ name: String = "A", path: String? = nil, major: Bool = false,
                           source: UpdateSource = .sparkle, action: UpdateAction? = nil) -> UpdateCandidate {
        let app = AppSnapshot(url: URL(fileURLWithPath: path ?? "/tmp/Latest-headless/\(name).app"),
            bundleID: "org.example.\(name)", name: name, version: .init(display: "1.0", build: "1"), architectures: [.arm64], fingerprint: "original")
        return .init(app: app, source: source, version: .init(display: major ? "2.0" : "1.1", build: "2"),
            action: action ?? .sparkle(URL(string: "https://example.invalid/feed")!), authoritative: true,
            releaseNotes: "<script>bad()</script><p>Safe notes</p>")
    }
    private func session(_ runtime: ApplicationTestRuntime, root: URL? = nil,
                         legacy: [String: PreferenceValue] = [:]) async -> ApplicationSession {
        let root = root ?? FileManager.default.temporaryDirectory.appendingPathComponent("Latest-headless-" + UUID().uuidString)
        let session = ApplicationSession(runtime: runtime, preferencesURL: root.appendingPathComponent("preferences.json"),
            diagnosticURL: root.appendingPathComponent("diagnostics.log"), legacy: legacy, monitoringInterval: nil)
        await session.start(); await session.waitForScan()
        return session
    }
    @Test func selectionFilteringNotesAndExactInstance() async {
        let a = candidate("Twin", path: "/tmp/Latest-headless/A/Twin.app")
        let b = candidate("Twin", path: "/tmp/Latest-headless/B/Twin.app")
        let runtime = ApplicationTestRuntime([b, a]); let app = await session(runtime)
        #expect(app.visibleRows.map(\.id) == [a.app.id, b.app.id])
        app.selectedID = b.app.id
        #expect(app.selectedRow?.id == b.app.id)
        #expect(app.notes.contains("Safe notes")); #expect(!app.notes.contains("bad()"))
        app.query = "not-present"; #expect(app.visibleRows.isEmpty)
        app.query = "Twin"; app.sourceFilter = .homebrew; #expect(app.visibleRows.isEmpty)
        app.sourceFilter = .sparkle; #expect(app.visibleRows.count == 2)
        app.requestUpdate(b.app.id); await app.waitForUpdates()
        #expect(await runtime.installed == [b.app.id])
        #expect(app.rows.first { $0.id == a.app.id }?.record.app.version == a.app.version)
        #expect(app.selectedRow?.record.status == .current)
    }
    @Test func majorCancellationConsentAndStaleConsent() async {
        let major = candidate(major: true); let runtime = ApplicationTestRuntime([major]); let app = await session(runtime)
        app.requestUpdate(major.app.id); #expect(app.confirmingMajor); #expect(app.activeUpdates == 0)
        app.cancelMajor(); #expect(!app.confirmingMajor); #expect(await runtime.installed.isEmpty)
        app.requestUpdate(major.app.id)
        let changed = UpdateCandidate(app: major.app, source: .sparkle, version: .init(display: "3.0", build: "3"), action: major.action, authoritative: true)
        await runtime.setCandidate(changed); app.refresh(); await app.waitForScan(); app.confirmMajor()
        #expect(await runtime.installed.isEmpty)
        app.requestUpdate(major.app.id); app.confirmMajor(); await app.waitForUpdates()
        #expect(await runtime.installed == [major.app.id]); #expect(!app.confirmingMajor)
    }
    @Test func bulkExcludesMajorExternalIgnoredSkippedAndIncompatible() async {
        let a = candidate("A"), b = candidate("B", source: .homebrew, action: .homebrew("fixture"))
        let major = candidate("Major", major: true), external = candidate("External", action: .external(URL(string: "https://example.invalid")!))
        let ignored = candidate("Ignored"), skipped = candidate("Skipped")
        let mismatch = candidate("Mismatch")
        let incompatible = UpdateCandidate(app: mismatch.app, source: .sparkle, version: mismatch.version, action: mismatch.action, authoritative: true, architectures: [.x86_64])
        let runtime = ApplicationTestRuntime([a,b,major,external,ignored,skipped,incompatible]); let app = await session(runtime)
        app.ignore(ignored.app.id); await app.waitForScan(); app.skip(skipped.app.id); await app.waitForScan()
        app.updateAll(); app.updateAll(); await app.waitForUpdates()
        #expect(Set(await runtime.installed) == [a.app.id, b.app.id]); #expect(app.canQuit)
    }
    @Test func preflightRejectionNeverInvokesInstaller() async {
        let a = candidate(); let runtime = ApplicationTestRuntime([a]); await runtime.configure(rejectValidation: true)
        let app = await session(runtime); app.requestUpdate(a.app.id); await app.waitForUpdates()
        #expect(await runtime.installed.isEmpty); #expect(app.showingError)
        #expect(app.rows.first?.event?.phase == .failed)
        #expect((try? String(contentsOf: app.diagnosticURL, encoding: .utf8))?.contains("Selected instance changed") == true)
    }
    @Test func failureAndRetryUseOneJobAndIgnoreLateCallback() async {
        let a = candidate(); let runtime = ApplicationTestRuntime([a]); await runtime.configure(installation: .failure)
        let app = await session(runtime); app.requestUpdate(a.app.id); app.requestUpdate(a.app.id)
        #expect(app.activeUpdates == 1); #expect(!app.canQuit)
        await app.waitForUpdates(); #expect(app.rows.first?.event?.phase == .failed)
        await runtime.configure(); app.requestUpdate(a.app.id); await app.waitForUpdates()
        await runtime.lateFailure()
        #expect(await runtime.installed == [a.app.id,a.app.id]); #expect(app.rows.first?.event?.phase == .succeeded)
        #expect(app.rows.first?.record.status == .current); #expect(app.canQuit)
    }
    @Test func downloadCancellationThenRetry() async throws {
        let a = candidate(); let runtime = ApplicationTestRuntime([a]); await runtime.configure(installation: .downloadGate)
        let app = await session(runtime); app.requestUpdate(a.app.id)
        _ = try await runtime.started.wait(); #expect(app.canCancel(a.app.id))
        app.cancel(a.app.id); await app.waitForUpdates()
        #expect(app.rows.first?.event?.phase == .cancelled); #expect(!app.showingError)
        await runtime.configure(); app.requestUpdate(a.app.id); await app.waitForUpdates()
        #expect(app.rows.first?.record.status == .current)
    }
    @Test func installerHandoffDisablesCancellationAndQuit() async throws {
        let a = candidate(); let runtime = ApplicationTestRuntime([a]); await runtime.configure(installation: .handoffGate)
        let app = await session(runtime); app.requestUpdate(a.app.id); _ = try await runtime.started.wait()
        #expect(!app.canCancel(a.app.id)); #expect(!app.canQuit)
        app.cancel(a.app.id); #expect(app.activeUpdates == 1)
        await runtime.release.finish(.success(())); await app.waitForUpdates()
        #expect(app.rows.first?.event?.phase == .succeeded); #expect(app.canQuit)
    }
    @Test func successfulProcessCannotBypassInstalledVerification() async {
        let a = candidate(); let runtime = ApplicationTestRuntime([a]); await runtime.configure(rejectVerification: true)
        let app = await session(runtime); app.requestUpdate(a.app.id); await app.waitForUpdates()
        #expect(app.rows.first?.event?.phase == .failed); #expect(app.showingError)
    }
    @Test func newerScanRejectsLateProviderAndClearsSelection() async throws {
        let a = candidate(); let runtime = ApplicationTestRuntime([a]); let app = await session(runtime)
        app.selectedID = a.app.id; await runtime.holdProviderCheck(); app.refresh()
        try await runtime.checkStarted.wait(); #expect(!app.canUpdate(a.app.id))
        app.requestUpdate(a.app.id); #expect(await runtime.installed.isEmpty)
        await runtime.setApps([]); app.refresh(); await app.waitForScan()
        await runtime.releaseCheck.finish(.success(()))
        #expect(app.rows.isEmpty); #expect(app.selectedRow == nil); #expect(app.notes.isEmpty); #expect(!app.scanning)
    }
    @Test func preferencesMigrationSerialSaveAndRestart() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Latest-restart-" + UUID().uuidString)
        let a = candidate(); let runtime = ApplicationTestRuntime([a])
        let app = await session(runtime, root: root, legacy: ["IgnoredAppsKey": .strings([a.app.bundleID]), "ShowUnsupportedUpdatesKey": .bool(false)])
        #expect(app.preferences.ignoredBundleIDs == [a.app.bundleID]); #expect(!app.preferences.showUnknown)
        app.ignore(a.app.id); await app.waitForScan(); app.skip(a.app.id); await app.waitForScan()
        app.preferences.channels[a.app.id.path] = .beta; app.preferences.fontScale = 1.6
        for index in 0..<30 { app.query = String(index); app.preferences.sortBySource = index % 2 == 0 }
        app.addDirectory(root); app.addDirectory(root); await app.waitForScan(); await app.flushPreferences()
        let restarted = await session(runtime, root: root, legacy: ["IgnoredAppsKey": .strings([a.app.bundleID])])
        #expect(restarted.preferences == app.preferences); #expect(restarted.preferences.ignoredBundleIDs.isEmpty)
        #expect(restarted.preferences.skippedVersions[a.app.id.path] == a.id)
        #expect(restarted.preferences.directories.filter { $0.path == root.path }.count == 1)
        #expect(restarted.rows.first?.record.status == .skipped)
    }
    @Test func directPreferenceCommandsRefreshEligibilityWithoutViewHooks() async {
        let a = candidate(); let runtime = ApplicationTestRuntime([a]); let app = await session(runtime)
        app.preferences.ignoredBundleIDs.insert(a.app.bundleID)
        #expect(app.scanning); #expect(!app.canUpdate(a.app.id))
        await app.waitForScan(); #expect(app.rows.first?.record.status == .ignored)
        app.preferences.ignoredBundleIDs.remove(a.app.bundleID); await app.waitForScan()
        app.preferences.skippedVersions[a.app.id.path] = a.id
        #expect(!app.canUpdate(a.app.id)); await app.waitForScan()
        #expect(app.rows.first?.record.status == .skipped)
        app.preferences.skippedVersions.removeValue(forKey: a.app.id.path); await app.waitForScan()
        #expect(app.canUpdate(a.app.id)); #expect(await runtime.installed.isEmpty)
    }
    @Test func externalUpdaterIsAnEffectWithoutInstallation() async {
        let url = URL(string: "https://example.invalid/update")!
        let a = candidate(action: .external(url)); let runtime = ApplicationTestRuntime([a]); let app = await session(runtime)
        app.requestUpdate(a.app.id)
        #expect(app.externalURL == url); #expect(await runtime.installed.isEmpty); #expect(app.canQuit)
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["LATEST_HEADLESS_NATIVE_SPARKLE"] != nil,
                   "Requires explicitly prepared disposable signed apps and localhost HTTPS."))
    func realSparkleRuntimeWithoutGUIAutomation() async throws {
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = repository.appendingPathComponent(".build/native-install-tests")
        let appURL = root.appendingPathComponent("applications/Latest Sparkle Fixture.app")
        let expected = ProcessInfo.processInfo.environment["LATEST_HEADLESS_NATIVE_SPARKLE"]
        try #require(expected == "succeeded" || expected == "failed" || expected == "checked")
        let before = try #require(AppInventory.snapshot(at: appURL))
        try #require(before.bundleID == "io.github.mpwg.Latest.NativeFixture.Sparkle")
        try #require(before.signatureTeam != nil)
        if expected != "checked" { try #require(before.version.display == "1.0.0") }
        let state = root.appendingPathComponent("preferences/headless")
        let preferencesURL = state.appendingPathComponent("preferences.json")
        let preferences = Preferences(directories: [.init(path: root.appendingPathComponent("applications").path)])
        if expected != "checked" { try await PreferencesStore(url: preferencesURL).save(preferences) }
        let runtime = LiveApplicationRuntime(cacheDirectory: state.appendingPathComponent("Cache"),
            homebrewExecutable: root.appendingPathComponent("homebrew/bin/brew"))
        let app = ApplicationSession(runtime: runtime, preferencesURL: preferencesURL,
            diagnosticURL: state.appendingPathComponent("diagnostics.log"), monitoringInterval: nil,
            jobJournal: state.appendingPathComponent("job-events.jsonl"))
        await app.start(); await app.waitForScan()
        let row = try #require(app.rows.first { $0.id == before.id })
        print("Native checked status: \(row.record.status), reason: \(row.record.reason ?? "none")")
        if expected == "checked" {
            let version = try #require(ProcessInfo.processInfo.environment["LATEST_HEADLESS_NATIVE_EXPECTED_VERSION"])
            #expect(row.record.app.version.display == version)
            #expect(row.record.status == (version == "1.1.0" ? .current : .available))
            #expect(app.activeUpdates == 0); #expect(app.canQuit)
            return
        }
        try #require(row.record.status == .available)
        app.selectedID = before.id
        app.requestUpdate(before.id); await app.waitForUpdates(); await app.flushPreferences()
        #expect(row.event?.phase.rawValue == expected)
        #expect(row.record.app.version.display == (expected == "succeeded" ? "1.1.0" : "1.0.0"))
        #expect(app.canQuit)

    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LATEST_HEADLESS_COMPATIBILITY"] != nil,
                   "Requires explicitly prepared signed compatibility targets and localhost HTTPS."))
    func realSparkleCompatibilityWithoutGUIAutomation() async throws {
        let environment = ProcessInfo.processInfo.environment
        let mode = try #require(environment["LATEST_HEADLESS_COMPATIBILITY"])
        try #require(["architecture", "minimum-os", "incomparable", "build-policy"].contains(mode))
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent(".build/native-install-tests")
        let selected = root.appendingPathComponent("applications/Latest Sparkle Fixture.app")
        let before = try #require(AppInventory.snapshot(at: selected))
        try #require(before.bundleID == "io.github.mpwg.Latest.NativeFixture.Sparkle" && before.signatureTeam != nil)
        let state = root.appendingPathComponent("preferences/headless-compatibility")
        let preferencesURL = state.appendingPathComponent("preferences.json")
        if environment["LATEST_HEADLESS_COMPATIBILITY_RESTART"] == nil {
            try await PreferencesStore(url: preferencesURL).save(.init(directories: [.init(path: root.appendingPathComponent("applications").path)]))
        }
        let runtime = LiveApplicationRuntime(cacheDirectory: state.appendingPathComponent("Cache"),
            homebrewExecutable: root.appendingPathComponent("homebrew/bin/brew"))
        let app = ApplicationSession(runtime: runtime, preferencesURL: preferencesURL,
            diagnosticURL: state.appendingPathComponent("diagnostics.log"), monitoringInterval: nil,
            jobJournal: state.appendingPathComponent("job-events.jsonl"))
        await app.start(); await app.waitForScan()
        let row = try #require(app.rows.first { $0.id == before.id })
        app.selectedID = before.id
        print("Real compatibility \(mode): \(row.record.status), \(row.record.reason ?? "none")")
        if mode == "build-policy" {
            if environment["LATEST_HEADLESS_COMPATIBILITY_RESTART"] == nil {
                try #require(row.record.status == .available && app.canUpdate(before.id))
                #expect(row.record.candidate?.version.display == "0.9.0")
                #expect(row.record.candidate?.version.build == "2")
                app.requestUpdate(before.id); await app.waitForUpdates()
                #expect(row.event?.phase == .succeeded)
            } else { #expect(row.event == nil) }
            #expect(row.record.app.version.display == "0.9.0" && row.record.app.version.build == "2")
            #expect(row.record.status == .current)
        } else {
            let reason = mode == "architecture" ? "This Sparkle update targets a different architecture or insecure URL. Use the app's own updater."
                : mode == "minimum-os" ? "The update requires a newer operating system." : "The versions cannot be compared reliably."
            #expect(row.record.status == (mode == "minimum-os" ? .incompatible : .unknown))
            #expect(row.record.reason == reason)
            #expect(!app.canUpdate(before.id))
            app.requestUpdate(before.id); await app.waitForUpdates()
            #expect(row.event == nil)
            #expect(AppInventory.snapshot(at: selected)?.fingerprint == before.fingerprint)
        }
        #expect(app.activeUpdates == 0 && app.canQuit)
        await app.flushPreferences()
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LATEST_HEADLESS_NATIVE_HOMEBREW"] != nil,
                   "Requires explicitly prepared isolated Homebrew and signed disposable apps."))
    func realHomebrewRuntimeWithoutGUIAutomation() async throws {
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = repository.appendingPathComponent(".build/native-install-tests")
        let mode = try #require(ProcessInfo.processInfo.environment["LATEST_HEADLESS_NATIVE_HOMEBREW"])
        try #require(["valid", "loss", "swap", "catalogue", "retry", "checked"].contains(mode))
        let unmanaged = mode == "catalogue" || ProcessInfo.processInfo.environment["LATEST_HEADLESS_NATIVE_HOMEBREW_TARGET"] == "unmanaged"
        let appURL = root.appendingPathComponent(unmanaged
            ? "applications/Unmanaged/Latest Homebrew Fixture.app" : "applications/Latest Homebrew Fixture.app")
        let before = try #require(AppInventory.snapshot(at: appURL))
        try #require(before.bundleID == "io.github.mpwg.Latest.NativeFixture.Homebrew" && before.signatureTeam != nil)
        if mode != "checked" { try #require(before.version.display == "1.0.0") }
        let state = root.appendingPathComponent("preferences/headless-homebrew")
        let preferencesURL = state.appendingPathComponent("preferences.json")
        var preferences = Preferences(directories: [.init(path: root.appendingPathComponent("applications").path)])
        preferences.showCatalogueHints = mode == "catalogue"
        if mode != "checked" { try await PreferencesStore(url: preferencesURL).save(preferences) }
        let catalogueURL = ProcessInfo.processInfo.environment["LATEST_HEADLESS_NATIVE_CATALOGUE"].flatMap(URL.init(string:))
        let runtime = LiveApplicationRuntime(cacheDirectory: state.appendingPathComponent("Cache"),
            homebrewExecutable: root.appendingPathComponent("homebrew/bin/brew"), catalogueURL: catalogueURL)
        let app = ApplicationSession(runtime: runtime, preferencesURL: preferencesURL,
            diagnosticURL: state.appendingPathComponent("diagnostics.log"), monitoringInterval: nil,
            jobJournal: state.appendingPathComponent("job-events.jsonl"))
        await app.start(); await app.waitForScan()
        let row = try #require(app.rows.first { $0.id == before.id })
        print("Real Homebrew mode \(mode), checked status \(row.record.status), reason \(row.record.reason ?? "none")")
        app.selectedID = before.id
        if mode == "checked" {
            let version = try #require(ProcessInfo.processInfo.environment["LATEST_HEADLESS_NATIVE_EXPECTED_VERSION"])
            #expect(row.record.app.version.display == version)
            let status = try #require(ProcessInfo.processInfo.environment["LATEST_HEADLESS_NATIVE_EXPECTED_STATUS"])
            #expect(row.record.status.rawValue == status)
            #expect(app.activeUpdates == 0); #expect(app.canQuit)
            return
        }
        if mode == "catalogue" {
            #expect(row.record.candidate?.source == .catalogue)
            #expect(row.record.status == .unknown)
            #expect(row.record.candidate?.authoritative == false)
            app.sourceFilter = .catalogue
            #expect(app.visibleRows.contains { $0.id == before.id })
            #expect(!app.canUpdate(before.id)); app.requestUpdate(before.id)
            #expect(app.activeUpdates == 0); #expect(row.event == nil)
            return
        }
        try #require(row.record.status == .available && row.record.candidate?.source == .homebrew)
        if mode == "loss" || mode == "swap" {
            try await nativeHomebrewCheckpoint(mode, root: root)
            let changed = try #require(AppInventory.snapshot(at: appURL))
            if mode == "loss" { try #require(changed.fingerprint == before.fingerprint) }
            else { try #require(changed.fingerprint != before.fingerprint) }
        }
        app.requestUpdate(before.id); app.requestUpdate(before.id)
        #expect(app.activeUpdates == 1); #expect(!app.canQuit)
        await app.waitForUpdates(); await app.flushPreferences()
        if mode == "valid" {
            #expect(row.event?.phase == .succeeded)
            #expect(row.record.app.version.display == "1.1.0")
            #expect(row.record.status == .current)
        } else {
            try #require(row.event?.phase == .failed)
            #expect(app.showingError)
            if mode == "loss" { #expect(row.record.status == .unknown) }
            if mode == "swap" { #expect(app.errorMessage.contains("selected app changed")) }
            if mode == "retry" {
                #expect(row.record.app.version.display == "1.0.0")
                #expect(app.errorMessage.lowercased().contains("checksum") || app.errorMessage.contains("SHA256 mismatch"))
                #expect(app.errorMessage.contains(String(repeating: "0", count: 64)))
                print("Actual failed upgrade: \(app.errorMessage)")
                try await nativeHomebrewCheckpoint("retry", root: root)
                app.showingError = false; app.refresh(); await app.waitForScan()
                try #require(app.canUpdate(before.id))
                app.requestUpdate(before.id); await app.waitForUpdates()
                #expect(row.event?.phase == .succeeded)
                #expect(row.record.app.version.display == "1.1.0")
                #expect(row.record.status == .current)
            }
        }
        #expect(app.canQuit)
    }

    private func nativeHomebrewCheckpoint(_ phase: String, root: URL) async throws {
        let directory = root.appendingPathComponent("evidence/headless-homebrew/coordination")
        let ready = directory.appendingPathComponent(phase + "-ready")
        let released = directory.appendingPathComponent(phase + "-released")
        try Data("Actual production session reached the native checkpoint.\n".utf8).write(to: ready, options: .atomic)
        let deadline = ContinuousClock.now.advanced(by: .seconds(60))
        while !FileManager.default.fileExists(atPath: released.path) && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        try #require(FileManager.default.fileExists(atPath: released.path), "The real external fixture operation did not complete.")
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LATEST_HEADLESS_SPARKLE_LIFECYCLE"] != nil,
                   "Requires explicitly prepared signed fixtures and controlled HTTPS gates."))
    func realSparkleLifecycleWithoutGUIAutomation() async throws {
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = repository.appendingPathComponent(".build/native-install-tests")
        let mode = try #require(ProcessInfo.processInfo.environment["LATEST_HEADLESS_SPARKLE_LIFECYCLE"])
        try #require(["cancellation", "download-error", "handoff", "checked"].contains(mode))
        let selected = root.appendingPathComponent("applications/Latest Sparkle Fixture.app")
        let before = try #require(AppInventory.snapshot(at: selected))
        try #require(before.bundleID == "io.github.mpwg.Latest.NativeFixture.Sparkle" && before.signatureTeam != nil)
        if mode != "checked" { try #require(before.version.display == "1.0.0") }
        let state = root.appendingPathComponent("preferences/headless-lifecycle")
        let preferencesURL = state.appendingPathComponent("preferences.json")
        if mode != "checked" {
            try await PreferencesStore(url: preferencesURL).save(.init(directories: [.init(path: root.appendingPathComponent("applications").path)]))
        }
        let runtime = LiveApplicationRuntime(cacheDirectory: state.appendingPathComponent("Cache"),
            homebrewExecutable: root.appendingPathComponent("homebrew/bin/brew"))
        let app = ApplicationSession(runtime: runtime, preferencesURL: preferencesURL,
            diagnosticURL: state.appendingPathComponent("diagnostics.log"), monitoringInterval: nil,
            jobJournal: state.appendingPathComponent("job-events.jsonl"))
        await app.start(); await app.waitForScan()
        let row = try #require(app.rows.first { $0.id == before.id })
        if mode == "checked" {
            #expect(row.record.app.version.display == "1.1.0"); #expect(row.record.status == .current)
            #expect(app.activeUpdates == 0); #expect(app.canQuit); return
        }
        try #require(row.record.status == .available)
        app.selectedID = before.id
        if mode == "handoff" {
            let pid = try #require(ProcessInfo.processInfo.environment["LATEST_HEADLESS_HANDOFF_PID"].flatMap(Int32.init))
            try await waitForNativeState { NSRunningApplication(processIdentifier: pid)?.bundleURL.map { AppInstanceID(url: $0) } == before.id }
            try await sparkleLifecycleCheckpoint("fixture-ready", root: root)
        }
        app.requestUpdate(before.id)
        if mode == "cancellation" {
            try await waitForNativeState { row.event?.phase == .downloading && app.canCancel(before.id) &&
                FileManager.default.fileExists(atPath: root.appendingPathComponent("evidence/headless-lifecycle/coordination/download-started-ready").path) }
            #expect(!app.canQuit)
            app.cancel(before.id); app.cancel(before.id)
            await app.waitForUpdates()
            try #require(row.event?.phase == .cancelled)
            #expect(!app.showingError); #expect(row.record.app.version.display == "1.0.0")
            try await sparkleLifecycleCheckpoint("cancellation", root: root)
        } else if mode == "download-error" {
            await app.waitForUpdates()
            try #require(row.event?.phase == .failed)
            #expect(app.showingError); #expect(row.record.app.version.display == "1.0.0")
            try await sparkleLifecycleCheckpoint("download-error", root: root)
            app.showingError = false
        } else {
            try await waitForNativeState { row.event?.phase == .installing }
            #expect(!app.canCancel(before.id)); #expect(!app.canQuit)
            app.cancel(before.id)
            #expect(app.activeUpdates == 1)
            try await sparkleLifecycleCheckpoint("handoff", root: root)
        }
        if mode != "handoff" {
            app.refresh(); await app.waitForScan()
            try #require(app.canUpdate(before.id))
            app.requestUpdate(before.id)
        }
        await app.waitForUpdates(); await app.flushPreferences()
        #expect(row.event?.phase == .succeeded)
        #expect(row.record.app.version.display == "1.1.0")
        #expect(row.record.status == .current); #expect(app.canQuit)
    }

    private func waitForNativeState(_ condition: @MainActor () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(60))
        while !condition() && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(50)) }
        try #require(condition(), "The actual native lifecycle did not reach the required state.")
    }

    private func sparkleLifecycleCheckpoint(_ phase: String, root: URL) async throws {
        let coordination = root.appendingPathComponent("evidence/headless-lifecycle/coordination")
        try Data("Actual shared session reached its native lifecycle checkpoint.\n".utf8)
            .write(to: coordination.appendingPathComponent(phase + "-ready"), options: .atomic)
        try await waitForNativeState { FileManager.default.fileExists(atPath: coordination.appendingPathComponent(phase + "-released").path) }
    }

}
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

/// Only discovery is scoped; real CFPreferences reading and JSON migration are unchanged.
private struct MigrationInventoryRuntime: ApplicationRuntime {
    let profile: URL
    func scan(_ directories: [DirectoryPreference]) async -> ApplicationInventory {
        let inventory = AppInventory.collect(directories.filter { $0.path.hasPrefix(profile.path + "/") })
        return .init(apps: inventory.apps, warnings: inventory.warnings)
    }
    func check(_ app: AppSnapshot, context: CheckContext) async -> AppRecord { .init(app: app) }
    func validate(_ expected: AppSnapshot) async throws -> AppSnapshot { throw LatestFailure.rejected("Migration acceptance cannot install apps.") }
    func install(_ candidate: UpdateCandidate, context: CheckContext,
                 event: @escaping @MainActor @Sendable (UpdateEvent) -> Void) async throws { throw LatestFailure.rejected("Migration acceptance cannot install apps.") }
    func verify(_ candidate: UpdateCandidate, context: CheckContext) async throws { throw LatestFailure.rejected("Migration acceptance cannot install apps.") }
    func releaseNotes(_ url: URL) async throws -> String { "" }
    func enableBroker() async throws -> Bool { throw LatestFailure.rejected("Migration acceptance cannot register a broker.") }
}

@Suite("Actual CFPreferences migration through the shared core") @MainActor
struct NativeMigrationTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["LATEST_HEADLESS_MIGRATION_PHASE"] != nil,
                   "Requires an explicitly isolated real macOS preferences domain and private profile."))
    func realLegacyMigrationWithoutGUIAutomation() async throws {
        let environment = ProcessInfo.processInfo.environment
        let phase = try #require(environment["LATEST_HEADLESS_MIGRATION_PHASE"])
        try #require(["migrated", "edited", "restarted", "malformed", "malformed-restart"].contains(phase))
        let domain = try #require(environment["LATEST_HEADLESS_MIGRATION_DOMAIN"])
        try #require(domain.hasPrefix("io.github.mpwg.Latest.NativeMigration.Headless."))
        let path = try #require(environment["LATEST_HEADLESS_MIGRATION_PROFILE"])
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent(".build/native-install-tests/evidence/headless-migration")
        try #require(path.hasPrefix(root.path + "/"))
        let profile = URL(fileURLWithPath: path)
        let support = profile.appendingPathComponent("Library/Application Support/io.github.mpwg.Latest")
        let legacy = LegacyPreferences.read(domain: domain)
        let app = ApplicationSession(runtime: MigrationInventoryRuntime(profile: profile),
            preferencesURL: support.appendingPathComponent("preferences.json"),
            diagnosticURL: support.appendingPathComponent("diagnostics.log"), legacy: legacy,
            monitoringInterval: nil, jobJournal: support.appendingPathComponent("job-events.jsonl"))
        await app.start(); await app.waitForScan()
        let migrated = profile.appendingPathComponent("Ältere Apps").path
        if phase == "malformed" || phase == "malformed-restart" {
            #expect(Set(legacy.keys) == ["directoryPaths"])
            #expect(app.preferences == Preferences())
            #expect(app.rows.isEmpty)
        } else {
            #expect(app.preferences.directories.filter { $0.path == migrated }.count == 1)
            #expect(!app.preferences.directories.contains { $0.path == "relative" || $0.path.hasSuffix("Should Not Migrate") })
            #expect(app.preferences.ignoredBundleIDs == ["io.github.mpwg.Latest.LegacyIgnored"])
            #expect(app.rows.count == 1 && app.rows.first?.record.app.signatureTeam != nil)
            if phase == "migrated" || phase == "edited" {
                try #require(!app.preferences.showCurrent && app.preferences.showIgnored && !app.preferences.showUnknown)
                #expect(app.visibleRows.isEmpty)
            }
            if phase == "edited" {
                app.preferences.showCurrent = true; app.preferences.showIgnored = false
                app.preferences.showUnknown = true; app.preferences.sortBySource = true
                app.preferences.fontScale = 1.4
            }
            if phase == "restarted" {
                if case .strings(let paths) = legacy["directoryPaths"] { #expect(paths == [profile.appendingPathComponent("Should Not Migrate").path]) }
                else { Issue.record("The actual changed legacy domain was not read.") }
                #expect(app.preferences.showCurrent && !app.preferences.showIgnored && app.preferences.showUnknown)
                #expect(app.preferences.sortBySource && app.preferences.fontScale == 1.4)
                #expect(app.visibleRows.count == 1)
            }
        }
        await app.flushPreferences()
        #expect(app.activeUpdates == 0 && app.canQuit && !app.showingError)
    }
}

@Suite("Native major consent and scoped bulk installation") @MainActor
struct NativeMajorBulkTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["LATEST_HEADLESS_MAJOR_BULK"] != nil,
                   "Requires disposable signed apps and controlled real HTTPS scans/downloads."))
    func realMajorBulkWithoutGUIAutomation() async throws {
        let environment = ProcessInfo.processInfo.environment
        let mode = try #require(environment["LATEST_HEADLESS_MAJOR_BULK"])
        try #require(["major", "provider-major", "changed-major", "bulk"].contains(mode))
        let restart = environment["LATEST_HEADLESS_MAJOR_BULK_RESTART"] != nil
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent(".build/native-install-tests")
        let evidence = root.appendingPathComponent("evidence/headless-major-bulk")
        let state = root.appendingPathComponent("preferences/headless-major-bulk")
        let selected = root.appendingPathComponent("applications/Latest Sparkle Fixture.app")
        let before = try #require(AppInventory.snapshot(at: selected))
        try #require(before.bundleID == "io.github.mpwg.Latest.NativeFixture.Sparkle" && before.signatureTeam != nil)
        let runtime = LiveApplicationRuntime(cacheDirectory: state.appendingPathComponent("Cache"),
            homebrewExecutable: root.appendingPathComponent("homebrew/bin/brew"))
        let app = ApplicationSession(runtime: runtime, preferencesURL: state.appendingPathComponent("preferences.json"),
            diagnosticURL: state.appendingPathComponent("diagnostics.log"), monitoringInterval: nil,
            jobJournal: state.appendingPathComponent("job-events.jsonl"))
        await app.start()
        if mode == "bulk" && !restart {
            try await wait {
                app.scanning && app.rows.first { $0.id == before.id }?.record.candidate != nil &&
                FileManager.default.fileExists(atPath: evidence.appendingPathComponent("bulk/scan-requested").path)
            }
            #expect(!app.canUpdate(before.id)); app.requestUpdate(before.id); app.updateAll()
            #expect(app.activeUpdates == 0 && app.canQuit)
            try await checkpoint("SCAN", evidence: evidence)
        }
        await app.waitForScan()
        let row = try #require(app.rows.first { $0.id == before.id })
        app.selectedID = before.id
        if restart {
            let version = mode == "major" ? "2.0.0" : mode == "changed-major" ? "1.0.0" : "1.1.0"
            #expect(row.record.app.version.display == version)
            #expect(row.record.status == (mode == "changed-major" ? .available : .current))
            if mode == "changed-major" { #expect(row.record.candidate?.isMajorUpgrade == true) }
            if mode == "bulk" {
                let minor = try #require(app.rows.first { $0.record.app.bundleID == "io.github.mpwg.Latest.NativeFixture.L17.minor" })
                #expect(minor.record.app.version.display == "1.1.0" && minor.record.status == .current)
                try verifyExcluded(app)
            }
            #expect(app.rows.allSatisfy { $0.event == nil }); #expect(app.activeUpdates == 0 && app.canQuit)
            return
        }
        try #require(before.version.display == "1.0.0" && app.canUpdate(before.id))
        switch mode {
        case "major", "provider-major":
            try #require(row.record.candidate?.isMajorUpgrade == true)
            app.updateAll(); await app.waitForUpdates()
            #expect(app.activeUpdates == 0 && row.event == nil)
            app.requestUpdate(before.id)
            #expect(app.confirmingMajor && app.pendingMajor?.app.id == before.id)
            #expect(app.activeUpdates == 0 && app.canQuit)
            app.cancelMajor(); app.confirmMajor()
            #expect(!app.confirmingMajor && app.pendingMajor == nil && row.event == nil)
            try await checkpoint("CANCEL_MAJOR", evidence: evidence)
            #expect(AppInventory.snapshot(at: selected)?.fingerprint == before.fingerprint)
            app.requestUpdate(before.id); app.confirmMajor(); app.confirmMajor()
            await app.waitForUpdates()
            #expect(row.event?.phase == .succeeded && row.record.status == .current)
            #expect(row.record.app.version.display == (mode == "major" ? "2.0.0" : "1.1.0"))
        case "changed-major":
            try #require(row.record.candidate?.isMajorUpgrade == false)
            try await checkpoint("CHANGED_MAJOR", evidence: evidence)
            app.requestUpdate(before.id); await app.waitForUpdates()
            #expect(row.event?.phase == .failed && app.showingError)
            #expect(app.errorMessage == "The Sparkle update's major-upgrade requirement changed. Check for updates again.")
            #expect(AppInventory.snapshot(at: selected)?.fingerprint == before.fingerprint)
        case "bulk":
            let minor = try #require(app.rows.first { $0.record.app.bundleID == "io.github.mpwg.Latest.NativeFixture.L17.minor" })
            try verifyExcluded(app)
            try #require(app.canUpdate(minor.id) && app.hasBulkUpdates)
            app.updateAll(); app.updateAll(); app.requestUpdate(before.id)
            try await wait { app.activeUpdates == 2 && row.event?.phase == .downloading && minor.event?.phase == .downloading }
            #expect(!app.canQuit && !app.canUpdate(before.id) && !app.hasBulkUpdates)
            #expect(app.rows.filter { $0.event != nil }.count == 2)
            try await checkpoint("BULK", evidence: evidence)
            await app.waitForUpdates()
            for updated in [row, minor] {
                #expect(updated.event?.phase == .succeeded && updated.record.status == .current)
                #expect(updated.record.app.version.display == "1.1.0" && updated.record.app.version.build == "2")
            }
            try verifyExcluded(app)
        default: Issue.record("Unexpected native major/bulk mode.")
        }
        #expect(app.activeUpdates == 0 && app.canQuit && !app.confirmingMajor)
        await app.flushPreferences()
    }
    private func verifyExcluded(_ app: ApplicationSession) throws {
        for (key, status) in [("major", AppStatus.available), ("declared-major", .available), ("ignored", .ignored),
                              ("skipped", .skipped), ("incompatible", .incompatible), ("current", .current), ("unknown", .unknown)] {
            let row = try #require(app.rows.first { $0.record.app.bundleID == "io.github.mpwg.Latest.NativeFixture.L17." + key })
            #expect(row.record.status == status && row.record.app.version.display == "1.0.0")
            #expect(row.event == nil)
            if key == "major" || key == "declared-major" { #expect(row.record.candidate?.isMajorUpgrade == true) }
        }
    }
    private func wait(_ condition: @MainActor () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(60))
        while !condition() && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(50)) }
        try #require(condition(), "The actual shared-session major/bulk state did not reach its checkpoint.")
    }
    private func checkpoint(_ name: String, evidence: URL) async throws {
        try Data("Actual shared session reached its major/bulk checkpoint.\n".utf8)
            .write(to: evidence.appendingPathComponent(name + "-requested"), options: .atomic)
        FileHandle.standardOutput.write(Data(("L17_READY_" + name + "\n").utf8))
        try await wait { FileManager.default.fileExists(atPath: evidence.appendingPathComponent(name + "-ready").path) }
    }
}

@Suite("Native directories and real volume recovery") @MainActor
struct NativeDirectoryTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["LATEST_HEADLESS_DIRECTORIES"] != nil,
                   "Requires disposable signed directory fixtures and actual owned test-volume images."))
    func realDirectoriesWithoutGUIAutomation() async throws {
        let environment = ProcessInfo.processInfo.environment
        let mode = try #require(environment["LATEST_HEADLESS_DIRECTORIES"])
        try #require(["actions", "volume", "empty-volume", "stale"].contains(mode))
        let restart = environment["LATEST_HEADLESS_DIRECTORIES_RESTART"] != nil
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent(".build/native-install-tests")
        let evidence = root.appendingPathComponent("evidence/headless-directories")
        let paths = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: evidence.appendingPathComponent("paths.json")))
        let state = root.appendingPathComponent("preferences/headless-directories")
        let runtime = LiveApplicationRuntime(cacheDirectory: state.appendingPathComponent("Cache"),
            homebrewExecutable: root.appendingPathComponent("homebrew/bin/brew"))
        let monitor: Duration? = !restart && (mode == "volume" || mode == "empty-volume") ? .seconds(5) : nil
        let app = ApplicationSession(runtime: runtime, preferencesURL: state.appendingPathComponent("preferences.json"),
            diagnosticURL: state.appendingPathComponent("diagnostics.log"), monitoringInterval: monitor,
            jobJournal: state.appendingPathComponent("job-events.jsonl"))
        defer { app.stopMonitoring() }
        await app.start()
        if restart {
            await app.waitForScan()
            if mode == "actions" {
                let added = try #require(paths["added"])
                #expect(app.rows.map { $0.id.path } == [added + "/Latest L19 Added Fixture.app"])
                #expect(app.preferences.directories.contains { $0.path == added && $0.enabled })
                #expect(!app.preferences.directories.contains { $0.path == paths["initial"] })
                #expect(app.preferences.directories.filter { $0.path != added }.allSatisfy { !$0.enabled })
                try await checkpoint("PERSISTED", evidence: evidence)
            } else if mode == "stale" {
                #expect(app.preferences.directories.isEmpty && app.rows.isEmpty)
            } else {
                #expect(app.rows.count == (mode == "volume" ? 1 : 0))
            }
            #expect(app.warnings.isEmpty && app.activeUpdates == 0 && app.canQuit)
            return
        }
        switch mode {
        case "actions":
            let initial = try #require(paths["initial"]), added = try #require(paths["added"])
            await app.waitForScan()
            #expect(app.rows.map { $0.id.path } == [initial + "/Latest L19 Initial Fixture.app"])
            let index = try #require(app.preferences.directories.firstIndex { $0.path == initial })
            app.preferences.directories[index].enabled = false; await app.waitForScan(); await app.flushPreferences()
            #expect(app.rows.isEmpty && app.visibleRows.isEmpty)
            try await checkpoint("DISABLED", evidence: evidence)
            app.preferences.directories[index].enabled = true; await app.waitForScan()
            app.addDirectory(URL(fileURLWithPath: added)); app.addDirectory(URL(fileURLWithPath: added))
            await app.waitForScan()
            #expect(Set(app.rows.map { $0.id.path }) == [initial + "/Latest L19 Initial Fixture.app", added + "/Latest L19 Added Fixture.app"])
            #expect(app.preferences.directories.filter { $0.path == added }.count == 1)
            app.preferences.directories.removeAll { $0.path == initial }; await app.waitForScan(); await app.flushPreferences()
            #expect(app.rows.map { $0.id.path } == [added + "/Latest L19 Added Fixture.app"])
            #expect(app.preferences.directories.filter { $0.path != added }.allSatisfy { !$0.enabled })
            try await checkpoint("REMOVED", evidence: evidence)
        case "volume", "empty-volume":
            let volume = try #require(paths["volume"])
            await app.waitForScan()
            #expect(app.warnings.isEmpty && app.rows.count == (mode == "volume" ? 1 : 0))
            app.selectedID = app.rows.first?.id
            try await checkpoint("EJECT", evidence: evidence)
            try await wait { !app.scanning && app.rows.isEmpty && app.warnings == ["Cannot read directory: " + volume] }
            #expect(app.selectedRow == nil && app.visibleRows.isEmpty)
            try await checkpoint("REMOUNT", evidence: evidence)
            try await wait { !app.scanning && app.warnings.isEmpty && app.rows.count == (mode == "volume" ? 1 : 0) }
            try await checkpoint("RECOVERED", evidence: evidence)
        case "stale":
            let volume = try #require(paths["volume"])
            try await wait { app.scanning && app.rows.count == 1 &&
                FileManager.default.fileExists(atPath: evidence.appendingPathComponent("stale/request-received").path) }
            let oldID = try #require(app.rows.first?.id)
            app.selectedID = oldID
            var waitingForOldScan = false
            let oldScan = Task { @MainActor in waitingForOldScan = true; await app.waitForScan() }
            try await wait { waitingForOldScan }
            try await checkpoint("HELD", evidence: evidence)
            app.preferences.directories.removeAll { $0.path == volume }
            await app.waitForScan(); await app.flushPreferences()
            #expect(app.rows.isEmpty && app.selectedRow == nil && app.warnings.isEmpty && !app.canUpdate(oldID))
            try await checkpoint("LATE", evidence: evidence)
            await oldScan.value
            #expect(app.rows.isEmpty && app.visibleRows.isEmpty && app.selectedRow == nil && app.warnings.isEmpty)
            try await checkpoint("SUPERSEDED", evidence: evidence)
            app.refresh(); await app.waitForScan()
            #expect(app.preferences.directories.isEmpty && app.rows.isEmpty && app.warnings.isEmpty)
        default: Issue.record("Unexpected native directories mode.")
        }
        #expect(app.activeUpdates == 0 && app.canQuit && !app.showingError)
        #expect(app.rows.allSatisfy { $0.event == nil })
        await app.flushPreferences()
    }
    private func wait(_ condition: @MainActor () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(60))
        while !condition() && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(50)) }
        try #require(condition(), "The actual directory/volume state did not reach its checkpoint.")
    }
    private func checkpoint(_ name: String, evidence: URL) async throws {
        try Data("Actual shared session reached its directory/volume checkpoint.\n".utf8)
            .write(to: evidence.appendingPathComponent(name + "-requested"), options: .atomic)
        try await wait { FileManager.default.fileExists(atPath: evidence.appendingPathComponent(name + "-ready").path) }
    }
}

