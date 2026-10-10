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
}
