import Foundation
import LatestCore

@main struct Verification {
    static func main() async throws {
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
        print("Verified \(count) core invariants.")
    }
}
