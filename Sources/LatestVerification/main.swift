import Foundation
import LatestCore
import LatestProcess
import LatestPlatform
import LatestContracts
import LatestTrust

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
        try PackagePolicy.validate(bundleIDs: [claim.bundleID], installLocations: ["/Applications"], payloadPaths: ["Test.app", "Test.app/Contents/Info.plist"], containsScripts: false, claim: claim)
        try check(true, "Package policy accepts only the selected application subtree")
        for path in ["Other.app/Contents/a", "../Library/a", "/Library/a", "Test.app/../Other.app"] {
            do {
                try PackagePolicy.validate(bundleIDs: [claim.bundleID], installLocations: ["/Applications"], payloadPaths: [path], containsScripts: false, claim: claim)
                throw LatestFailure.process("Unrelated package path accepted")
            } catch LatestFailure.rejected { try check(true, "Package path rejected: \(path)") }
        }
        do {
            try PackagePolicy.validate(bundleIDs: [claim.bundleID], installLocations: ["/Applications"], payloadPaths: ["Test.app"], containsScripts: true, claim: claim)
            throw LatestFailure.process("Package scripts accepted")
        } catch LatestFailure.rejected { try check(true, "Install scripts cannot reach root execution") }
        let gate = CompletionGate<Int>()
        let completedOnce = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            for index in 0..<32 { group.addTask { await gate.finish(.success(index)) } }
            var accepted = 0; for await value in group { if value { accepted += 1 } }; return accepted
        }
        try check(completedOnce == 1, "Concurrent reply/timeout/cancel races complete exactly once")
        let terminal = try await gate.wait()
        try check(terminal >= 0 && terminal < 32, "Reply received before waiter is preserved")
        let record = AppRecord(app: app, candidate: .init(app: app, source: .homebrew, version: .init(display: "1.3"), action: .homebrew("test"), authoritative: true), status: .available)
        try check(Presentation.visible([record], query: "ORG.EXAMPLE", source: .homebrew, preferences: .init()).count == 1, "Search and source filters")
        try check(Presentation.visible([record], query: "", source: .sparkle, preferences: .init()).isEmpty, "Mismatched source hidden")
        var hidden = Preferences(); hidden.showCurrent = false; hidden.showUnknown = false
        try check(Presentation.visible([.init(app: app, status: .current), .init(app: app, status: .unknown)], query: "", source: nil, preferences: hidden).isEmpty, "Visibility preferences")
        try check(Presentation.bulkEligible(record.candidate!, status: .available), "Bulk accepts verified minor updates")
        try check(!Presentation.bulkEligible(candidate, status: .available), "Bulk rejects catalogue hints and major upgrades")
        var ignored = Preferences(); ignored.ignoredBundleIDs = [app.bundleID]
        let os = OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0)
        try check(Resolution.record(app, candidate: record.candidate, preferences: ignored, operatingSystem: os, architecture: .arm64).status == .ignored, "Ignored apps are never actionable")
        var skipped = Preferences(); skipped.skippedVersions[app.id.path] = record.candidate?.id
        try check(Resolution.record(app, candidate: record.candidate, preferences: skipped, operatingSystem: os, architecture: .arm64).status == .skipped, "Only selected version is skipped")
        let incompatible = UpdateCandidate(app: app, source: .sparkle, version: .init(display: "2"), action: .sparkle(URL(string: "https://fixture.invalid")!), authoritative: true, minimumOS: "28", architectures: [.x86_64])
        try check(Resolution.record(app, candidate: incompatible, preferences: .init(), operatingSystem: os, architecture: .arm64).status == .incompatible, "OS and architecture constraints prevent installation")
        let beta = UpdateCandidate(app: app, source: .sparkle, version: .init(display: "2beta"), action: incompatible.action, authoritative: true, channel: .beta)
        try check(Resolution.record(app, candidate: beta, preferences: .init(), operatingSystem: os, architecture: .arm64).status == .unknown, "Stable channel rejects beta updates")
        let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [HTTPFixture.self]
        let transport = URLSession(configuration: configuration)
        let fixtureHTTP = BoundedHTTPClient(cacheDirectory: root.appendingPathComponent("transport-cache"), testSession: transport)
        let response = try await fixtureHTTP.fetch(URL(string: "https://fixture.invalid/valid")!) { _ = try JSONSerialization.jsonObject(with: $0) }
        try check(!response.stale && response.data.count > 0, "Valid HTTPS response is decoded and cached")
        for endpoint in ["error", "large", "downgrade"] {
            do {
                _ = try await fixtureHTTP.fetch(URL(string: "https://fixture.invalid/\(endpoint)")!, maximumBytes: 100)
                throw LatestFailure.process("Invalid transport response accepted")
            } catch LatestFailure.network { try check(true, "Transport rejects \(endpoint)") }
        }
        do {
            _ = try await fixtureHTTP.fetch(URL(string: "https://fixture.invalid/invalid")!) { _ = try JSONSerialization.jsonObject(with: $0) }
            throw LatestFailure.process("Invalid JSON cached")
        } catch LatestFailure.process(let message) { throw LatestFailure.process(message) }
        catch { try check(true, "Malformed response is never accepted as valid cache data") }
        let offlineConfiguration = URLSessionConfiguration.ephemeral; offlineConfiguration.protocolClasses = [OfflineFixture.self]
        let offline = BoundedHTTPClient(cacheDirectory: root.appendingPathComponent("transport-cache"), testSession: URLSession(configuration: offlineConfiguration))
        let cached = try await offline.fetch(URL(string: "https://fixture.invalid/valid")!) { _ = try JSONSerialization.jsonObject(with: $0) }
        try check(cached.stale && cached.data == response.data, "Offline uses only validated last-known-good data and marks it stale")
        let ownership = OwnedRequest(), cancellationResult = CompletionGate<Bool>()
        let accepted = await ownership.start { _ in
            do { try await Task.sleep(for: .seconds(10)); await cancellationResult.finish(.success(false)) }
            catch { await cancellationResult.finish(.success(true)) }
        }
        try check(accepted, "Broker connection owns its preflight task")
        await ownership.disconnect()
        try check(try await cancellationResult.wait(), "Disconnect cancels owned preflight task")
        let installation = OwnedRequest(), ready = CompletionGate<Bool>(), resultGate = CompletionGate<Bool>()
        _ = await installation.start { owner in
            do {
                try await owner.handOffToInstaller(); await ready.finish(.success(true))
                try await Task.sleep(for: .milliseconds(30)); await resultGate.finish(.success(true))
            } catch { await resultGate.finish(.success(false)) }
        }
        _ = try await ready.wait(); await installation.disconnect()
        try check(try await resultGate.wait(), "Started installation completes safely after client disconnect")
        let seed = Data(repeating: 7, count: 32)
        let publicKey = try ReleaseSigning.publicKey(seed: seed)
        let signature = try ReleaseSigning.signature(data: response.data, seed: seed)
        try check(try ReleaseSigning.verify(data: response.data, signature: signature, publicKey: publicKey), "Ed25519 update signatures verify")
        try check(try !ReleaseSigning.verify(data: response.data + Data([1]), signature: signature, publicKey: publicKey), "Modified update archive signature is rejected")
        let feed = try ReleaseSigning.signedFeed(response.data, seed: seed)
        try check(String(decoding: feed, as: UTF8.self).contains("<!-- sparkle-signatures:\nedSignature: ") && String(decoding: feed, as: UTF8.self).contains("length: \(response.data.count)"), "Signed feed uses Sparkle 2.10 envelope")
        try check(!FeedPolicy.compatible(URL(string: "https://fixture.invalid/x86-64/update.xml")!, with: [.arm64]), "Architecture-specific feed cannot switch ARM to Intel")
        try check(!FeedPolicy.compatible(URL(string: "https://fixture.invalid/arm64/update.zip")!, with: [.x86_64]), "Architecture-specific archive cannot switch Intel to ARM")
        try check(FeedPolicy.compatible(URL(string: "https://fixture.invalid/universal/update.xml")!, with: [.arm64, .x86_64]), "Universal update feed remains supported")
        try check(try Metadata.casks(Data(#"[{"token":"valid","version":"1"},"invalid item"]"#.utf8)).count == 1, "Malformed catalogue neighbour is isolated")
        let olderPreferences = try JSONDecoder().decode(Preferences.self, from: Data(#"{"showCurrent":false}"#.utf8))
        try check(!olderPreferences.showCurrent && !olderPreferences.showCatalogueHints, "New preference fields do not break existing settings")
        let prefix = root.appendingPathComponent("brew-prefix")
        let stagedApp = prefix.appendingPathComponent("Caskroom/test/1/Test.app")
        try FileManager.default.createDirectory(at: stagedApp.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: stagedApp, withDestinationURL: fixture.deletingLastPathComponent())
        let caskJSON = root.appendingPathComponent("brew-info.json")
        try Data(#"{"casks":[{"token":"test","version":"3","installed":"1","auto_updates":false,"artifacts":[{"app":["Test.app"]}]}]}"#.utf8).write(to: caskJSON)
        let fakeBrew = root.appendingPathComponent("brew")
        let script = """
        #!/usr/bin/python3
        import json,sys
        from pathlib import Path
        root=Path(__file__).resolve().parent
        args=sys.argv[1:]
        if args==['--prefix']: print(root/'brew-prefix')
        elif args==['info','--cask','--json=v2','--installed']: print((root/'brew-info.json').read_text())
        elif args==['outdated','--cask','--json=v2','test']: print(json.dumps({'casks':[{'name':'test','current_version':'3','installed_versions':['1']}]}))
        elif args==['upgrade','--cask','--no-ask','test']: (root/'executed-arguments.json').write_text(json.dumps(args))
        else: sys.exit(2)
        """
        try Data(script.utf8).write(to: fakeBrew)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fakeBrew.path)
        let brewProvider = HomebrewProvider(executable: fakeBrew)
        guard let scanned = AppInventory.snapshot(at: fixture.deletingLastPathComponent()) else { throw LatestFailure.process("Fixture disappeared") }
        let brewContext = CheckContext(apps: [scanned], preferences: .init())
        guard let owned = try await brewProvider.check(scanned, context: brewContext) else { throw LatestFailure.process("Managed fixture not recognized") }
        try check(owned.source == .homebrew && owned.authoritative && owned.comparison == .older, "Local cask registration authorizes only its canonical app")
        let unowned = AppSnapshot(url: root.appendingPathComponent("Elsewhere/Test.app"), bundleID: scanned.bundleID, name: scanned.name, version: scanned.version)
        try check(try await brewProvider.check(unowned, context: brewContext) == nil, "Name match without registered installation cannot authorize Homebrew")
        try await brewProvider.upgrade(owned, context: brewContext)
        let recordedArguments = try JSONDecoder().decode([String].self, from: Data(contentsOf: root.appendingPathComponent("executed-arguments.json")))
        try check(recordedArguments == ["upgrade", "--cask", "--no-ask", "test"], "Homebrew upgrades exactly one verified cask")
        do {
            try CodeTrust.verify(URL(fileURLWithPath: "/usr/bin/true"), requirement: ForkIdentity.requirement(identifier: ForkIdentity.tool, team: "26ZJLRV99G"))
            throw LatestFailure.process("Foreign signing identity accepted")
        } catch LatestFailure.rejected { try check(true, "Foreign signed executable fails the fork's designated requirement") }
        do { _ = try ForkIdentity.requirement(identifier: ForkIdentity.application, team: "bad\"team"); throw LatestFailure.process("Malformed team accepted") }
        catch ForkIdentity.IdentityError.unconfigured { try check(true, "Signing requirements cannot be injected") }
        let helper = try await runner.run(executable: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/debug/LatestBroker"), arguments: [], environment: CommandRunner.userEnvironment())
        try check(helper.exitCode != 0, "Broker cannot be launched as an ordinary unprivileged process")
        let verifier = try await runner.run(executable: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/debug/LatestPackageVerifier"), arguments: ["/tmp/invalid.pkg", "123", claim.bundleID, claim.path], environment: CommandRunner.userEnvironment())
        try check(verifier.exitCode != 0, "Package verifier rejects unauthorized direct invocation")
        print("Verified \(count) core invariants.")
    }
}
