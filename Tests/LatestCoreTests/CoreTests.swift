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
