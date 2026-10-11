import Foundation
import Testing
@testable import LatestCore
@testable import LatestPlatform

@Suite("Audit regression contracts") struct CoreTests {
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
    @Test func externalUpdaterIsAnEffectWithoutInstallation() async {
        let url = URL(string: "https://example.invalid/update")!
        let a = candidate(action: .external(url)); let runtime = ApplicationTestRuntime([a]); let app = await session(runtime)
        app.requestUpdate(a.app.id)
        #expect(app.externalURL == url); #expect(await runtime.installed.isEmpty); #expect(app.canQuit)
    }
}
