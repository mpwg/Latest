import AppKit
import Foundation
import Observation
import LatestCore
import LatestPlatform

@MainActor @Observable final class AppRow: Identifiable {
    let id: AppInstanceID
    var record: AppRecord
    var event: UpdateEvent?
    let icon: NSImage
    init(record: AppRecord) {
        id = record.id; self.record = record
        icon = NSWorkspace.shared.icon(forFile: record.id.path)
    }
}

@MainActor @Observable final class AppModel {
    var rows: [AppRow] = []
    var visibleRows: [AppRow] = []
    var selectedID: AppInstanceID? { didSet { selectedRow = rows.first { $0.id == selectedID } } }
    var selectedRow: AppRow?
    var query = "" { didSet { filter() } }
    var sourceFilter: UpdateSource? { didSet { filter() } }
    var preferences = Preferences()
    var scanning = false
    var checked = 0
    var total = 0
    var errorMessage = ""
    var showingError = false
    var pendingMajor: UpdateCandidate?
    var confirmingMajor = false
    var warnings: [String] = []
    var loadingNotes = false
    var notes = ""
    var notesToken = UUID()
    var needsBrokerApproval = false
    var activeUpdates: Int { rows.filter { $0.event != nil && $0.event?.isTerminal == false }.count }
    @ObservationIgnored var showSettingsHandler: () -> Void = {}
    let diagnosticURL: URL
    private let store: PreferencesStore
    private let inventory = AppInventory()
    private let scanLedger = ScanLedger()
    private let jobLedger = JobLedger()
    private let brew: HomebrewProvider
    private let appStore: AppStoreProvider
    private let sparkle = SparkleProvider()
    private let broker = BrokerClient()
    private let http: BoundedHTTPClient
    private let catalogue: CatalogueProvider
    private var scanTask: Task<Void, Never>?
    private var monitoringTask: Task<Void, Never>?
    private var jobs: [AppInstanceID: Task<Void, Never>] = [:]
    private var generation: UInt64 = 0
    private var started = false
    private var fingerprints = Set<String>()
    private let uiTesting: Bool

    init(preferencesDirectory: URL? = nil, homebrewExecutable: URL? = nil) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        #if DEBUG
        uiTesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        #else
        uiTesting = false
        #endif
        let arguments = ProcessInfo.processInfo.arguments
        let testRoot = arguments.firstIndex(of: "--ui-test-directory").flatMap { $0 + 1 < arguments.count ? URL(fileURLWithPath: arguments[$0+1]) : nil }
        let root = preferencesDirectory ?? (uiTesting ? (testRoot ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/ui-test-state")) : support.appendingPathComponent("io.github.mpwg.Latest"))
        brew = HomebrewProvider(executable: homebrewExecutable)
        store = PreferencesStore(url: root.appendingPathComponent("preferences.json"))
        diagnosticURL = root.appendingPathComponent("diagnostics.log")
        http = BoundedHTTPClient(cacheDirectory: root.appendingPathComponent("Cache"))
        catalogue = CatalogueProvider(http: http)
        let tool = Bundle.main.url(forResource: "mas", withExtension: nil)
        appStore = AppStoreProvider(http: http, masURL: tool)
    }
    isolated deinit { scanTask?.cancel(); monitoringTask?.cancel() }

    func start() async {
        guard !started else { return }
        started = true
        do {
            let legacy = UserDefaults.standard.persistentDomain(forName: "com.max-langer.Latest") ?? [:]
            var values: [String: PreferenceValue] = [:]
            for key in ["directoryPaths", "IgnoredAppsKey"] { if let value = legacy[key] as? [String] { values[key] = .strings(value) } }
            for key in ["ShowInstalledUpdatesKey", "ShowIgnoredUpdatesKey", "ShowUnsupportedUpdatesKey"] { if let value = legacy[key] as? Bool { values[key] = .bool(value) } }
            preferences = try await store.load(legacy: values)
        } catch { fail(error) }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") { installFixtures(); return }
        #endif
        refresh()
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                guard let self, !self.scanning, self.activeUpdates == 0 else { continue }
                let result = await self.inventory.scan(self.preferences.directories)
                let next = Set(result.apps.map { "\($0.id.path)|\($0.fingerprint)" })
                if next != self.fingerprints { self.refresh() }
            }
        }
    }
    func refresh() {
        #if DEBUG
        if uiTesting { installFixtures(); return }
        #endif
        generation &+= 1
        let token = generation
        scanTask?.cancel()
        scanTask = Task { await scan(token: token) }
    }
    private func scan(token: UInt64) async {
        scanning = true; checked = 0
        defer { if generation == token { scanning = false } }
        let result = await inventory.scan(preferences.directories)
        guard generation == token, !Task.isCancelled else { return }
        warnings = result.warnings
        fingerprints = Set(result.apps.map { "\($0.id.path)|\($0.fingerprint)" })
        total = result.apps.count
        let ledgerToken = await scanLedger.begin(apps: result.apps)
        let previous = Dictionary(rows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        rows = result.apps.map { app in
            let row = previous[app.id] ?? AppRow(record: .init(app: app))
            row.record = .init(app: app); return row
        }
        selectedRow = rows.first { $0.id == selectedID }; filter()
        let context = CheckContext(apps: result.apps, preferences: preferences)
        let providers: [any UpdateProvider] = [appStore, brew, sparkle, catalogue]
        await withTaskGroup(of: AppRecord.self) { group in
            var iterator = result.apps.makeIterator()
            for _ in 0..<8 { if let app = iterator.next() { group.addTask { await Self.check(app, providers: providers, context: context) } } }
            while let record = await group.next() {
                if generation == token, !Task.isCancelled, await scanLedger.accept(record, generation: ledgerToken) {
                    rows.first { $0.id == record.id }?.record = record
                    checked += 1; filter()
                }
                if Task.isCancelled { group.cancelAll(); break }
                if let app = iterator.next() { group.addTask { await Self.check(app, providers: providers, context: context) } }
            }
        }
    }
    nonisolated private static func check(_ app: AppSnapshot, providers: [any UpdateProvider], context: CheckContext) async -> AppRecord {
        #if arch(arm64)
        let architecture = Architecture.arm64
        #else
        let architecture = Architecture.x86_64
        #endif
        do {
            for provider in providers {
                try Task.checkCancellation()
                if let candidate = try await provider.check(app, context: context) {
                    return Resolution.record(app, candidate: candidate, preferences: context.preferences,
                                             operatingSystem: ProcessInfo.processInfo.operatingSystemVersion, architecture: architecture)
                }
            }
            return .init(app: app, reason: "No reliable update source is available.")
        } catch { return .init(app: app, reason: error.localizedDescription) }
    }
    func filter() {
        let matches = Presentation.visible(rows.map { $0.record }, query: query, source: sourceFilter, preferences: preferences)
        let mapping = Dictionary(rows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        visibleRows = matches.compactMap { mapping[$0.id] }
    }

    func save() {
        filter()
        let value = preferences
        Task { do { try await store.save(value) } catch { fail(error) } }
    }
    func ignore(_ row: AppRow) {
        if preferences.ignoredBundleIDs.contains(row.record.app.bundleID) { preferences.ignoredBundleIDs.remove(row.record.app.bundleID) }
        else { preferences.ignoredBundleIDs.insert(row.record.app.bundleID) }
        save(); refresh()
    }
    func skip(_ row: AppRow) {
        guard let candidate = row.record.candidate else { return }
        preferences.skippedVersions[row.id.path] = candidate.id; save(); refresh()
    }
    func clearSkip(_ row: AppRow) { preferences.skippedVersions.removeValue(forKey: row.id.path); save(); refresh() }
    func requestUpdate(_ row: AppRow) {
        guard row.record.status == .available || row.record.status == .external, let candidate = row.record.candidate else { return }
        if case .external(let url) = candidate.action { NSWorkspace.shared.open(url); return }
        if candidate.isMajorUpgrade { pendingMajor = candidate; confirmingMajor = true }
        else { perform(candidate) }
    }
    func confirmMajor() { if let pendingMajor { perform(pendingMajor) }; pendingMajor = nil }
    func updateAll() {
        for row in rows where row.record.candidate.map({ Presentation.bulkEligible($0, status: row.record.status) }) == true { requestUpdate(row) }
    }
    func cancel(_ row: AppRow) {
        guard row.event?.phase != .installing && row.event?.phase != .verifying else { return }
        jobs[row.id]?.cancel()
    }
    private func perform(_ candidate: UpdateCandidate) {
        guard jobs[candidate.app.id] == nil else { return }
        rows.first { $0.id == candidate.app.id }?.event = .init(.queued)
        jobs[candidate.app.id] = Task {
            var jobToken: UUID?
            do {
                let token = try await jobLedger.start(candidate.app.id); jobToken = token
                guard let fresh = AppInventory.snapshot(at: candidate.app.id.url), fresh.fingerprint == candidate.app.fingerprint else {
                    throw LatestFailure.rejected("The selected app changed. Check for updates again.")
                }
                await accept(.init(.checking), candidate: candidate, token: token)
                let context = CheckContext(apps: rows.map { $0.record.app }, preferences: preferences)
                switch candidate.action {
                case .homebrew:
                    await accept(.init(.installing), candidate: candidate, token: token)
                    try await brew.upgrade(candidate, context: context)
                case .appStore(let id):
                    await appStore.invalidate()
                    guard let claim = try await appStore.claim(for: fresh), claim.storeID == id else { throw LatestFailure.rejected("The App Store installation is ambiguous.") }
                    await accept(.init(.installing), candidate: candidate, token: token)
                    try await broker.update(claim)
                    await appStore.invalidate()
                case .sparkle:
                    try await sparkle.install(candidate, channel: preferences.channels[candidate.app.id.path, default: .stable]) { event in
                        Task { await self.accept(event, candidate: candidate, token: token) }
                    }
                default: throw LatestFailure.rejected("This update must be performed externally.")
                }
                await accept(.init(.verifying), candidate: candidate, token: token)
                guard let installed = AppInventory.snapshot(at: candidate.app.id.url), installed.bundleID == candidate.app.bundleID else { throw LatestFailure.process("The installed app could not be verified.") }
                if case .homebrew = candidate.action {
                    guard let checked = try await brew.check(installed, context: context), checked.comparison == .same else { throw LatestFailure.process("Homebrew still reports this app as outdated.") }
                } else {
                    let order = installed.version.compare(to: candidate.version, policy: candidate.source == .sparkle ? .build : .display)
                    guard order == .same || order == .newer else { throw LatestFailure.process("The installed version does not match the expected update.") }
                }
                guard candidate.app.architectures.isEmpty || !installed.architectures.isDisjoint(with: candidate.app.architectures) else { throw LatestFailure.process("The installed app architecture changed unexpectedly.") }
                await accept(.init(.succeeded), candidate: candidate, token: token)
            } catch {
                if let jobToken { await accept(.init(error is CancellationError ? .cancelled : .failed, message: error.localizedDescription), candidate: candidate, token: jobToken) }
                if !(error is CancellationError) { fail(error) }
            }
            jobs.removeValue(forKey: candidate.app.id)
            refresh()
        }
    }
    private func accept(_ event: UpdateEvent, candidate: UpdateCandidate, token: UUID) async {
        if await jobLedger.accept(event, app: candidate.app.id, token: token) { rows.first { $0.id == candidate.app.id }?.event = event }
    }
    func selectNotes() {
        let token = UUID(); notesToken = token; notes = ""; loadingNotes = false
        guard let candidate = selectedRow?.record.candidate else { return }
        if let value = candidate.releaseNotes { notes = SafeText.releaseNotes(value); return }
        guard let url = candidate.releaseNotesURL, url.scheme == "https" else { return }
        loadingNotes = true
        Task {
            defer { if notesToken == token { loadingNotes = false } }
            do {
                let response = try await http.fetch(url, maximumBytes: 500_000) { guard String(data: $0, encoding: .utf8) != nil else { throw LatestFailure.network("Unsupported release notes encoding.") } }
                if notesToken == token { notes = SafeText.releaseNotes(String(decoding: response.data, as: UTF8.self)) }
            } catch { if notesToken == token { notes = error.localizedDescription } }
        }
    }
    func enableBroker() {
        do { try BrokerClient.register(); needsBrokerApproval = BrokerClient.status != .enabled }
        catch { fail(error) }
    }
    func addDirectory() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            let path = url.resolvingSymlinksInPath().path
            if !preferences.directories.contains(where: { $0.path == path }) { preferences.directories.append(.init(path: path)); save(); refresh() }
        }
    }
    func fail(_ error: Error) {
        errorMessage = error.localizedDescription; showingError = true
        do {
            try FileManager.default.createDirectory(at: diagnosticURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            var text = (try? String(contentsOf: diagnosticURL, encoding: .utf8)) ?? ""
            text = String(text.suffix(200_000)) + "\n\(Date().ISO8601Format()) \(error.localizedDescription)\n"
            try Data(text.utf8).write(to: diagnosticURL, options: .atomic)
        } catch { /* Diagnostic failure must not hide the original error. */ }
    }
    #if DEBUG
    private func installFixtures() {
        let app = AppSnapshot(url: URL(fileURLWithPath: "/Applications/Latest Test.app"), bundleID: "org.example.test", name: "Latest Test", version: .init(display: "1"))
        let candidate = UpdateCandidate(app: app, source: .sparkle, version: .init(display: "2"), action: .external(URL(string: "https://example.invalid")!), authoritative: true, releaseNotes: "Controlled release notes fixture.")
        let status: AppStatus = preferences.ignoredBundleIDs.contains(app.bundleID) ? .ignored : preferences.skippedVersions[app.id.path] == candidate.id ? .skipped : .external
        rows = [AppRow(record: .init(app: app, candidate: candidate, status: status))]
        selectedRow = rows.first { $0.id == selectedID }; filter()
    }
    #endif
}
