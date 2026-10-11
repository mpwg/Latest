import Foundation
import Observation
import LatestCore

/// One Store workflow owns the broker until installed-result verification finishes.
@MainActor private final class StoreUpdateQueue {
    struct Permit { let id: UUID; let waited: Bool }
    private var owner: UUID?
    private var waiters: [(UUID, CheckedContinuation<Permit, any Error>)] = []
    func acquire() async throws -> Permit {
        try Task.checkCancellation()
        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if Task.isCancelled { continuation.resume(throwing: CancellationError()) }
                else if owner == nil { owner = id; continuation.resume(returning: Permit(id: id, waited: false)) }
                else { waiters.append((id, continuation)) }
            }
        } onCancel: { Task { @MainActor in self.cancelWaiting(id) } }
    }
    private func cancelWaiting(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.0 == id }) else { return }
        waiters.remove(at: index).1.resume(throwing: CancellationError())
    }
    func release(_ permit: Permit) {
        guard owner == permit.id else { return }
        if waiters.isEmpty { owner = nil }
        else {
            let next = waiters.removeFirst(); owner = next.0
            next.1.resume(returning: Permit(id: next.0, waited: true))
        }
    }
}

@MainActor @Observable public final class ApplicationRow: Identifiable {
    public let id: AppInstanceID
    public internal(set) var record: AppRecord
    public internal(set) var event: UpdateEvent?
    public init(record: AppRecord) {
        id = record.id; self.record = record
    }
}

@MainActor @Observable public final class ApplicationSession {
    public private(set) var rows: [ApplicationRow] = []
    public private(set) var visibleRows: [ApplicationRow] = []
    public var selectedID: AppInstanceID? { didSet { selectedRow = rows.first { $0.id == selectedID }; selectNotes() } }
    public private(set) var selectedRow: ApplicationRow?
    public var query = "" { didSet { filter() } }
    public var sourceFilter: UpdateSource? { didSet { filter() } }
    public var preferences = Preferences() { didSet {
        guard preferencesLoaded, preferences != oldValue else { return }
        save()
        if preferences.directories != oldValue.directories || preferences.channels != oldValue.channels ||
           preferences.ignoredBundleIDs != oldValue.ignoredBundleIDs || preferences.skippedVersions != oldValue.skippedVersions ||
           preferences.showCatalogueHints != oldValue.showCatalogueHints { refresh() }
    } }
    public private(set) var scanning = false
    public private(set) var checked = 0
    public private(set) var total = 0
    public private(set) var errorMessage = ""
    public var showingError = false
    public private(set) var pendingMajor: UpdateCandidate?
    public var confirmingMajor = false
    public private(set) var warnings: [String] = []
    public private(set) var loadingNotes = false
    public private(set) var notes = ""
    private var notesToken = UUID()
    public private(set) var needsBrokerApproval = false
    public var activeUpdates: Int { jobs.count }
    public var hasBulkUpdates: Bool {
        rows.contains { row in
            !isUpdating(row.id) && row.record.candidate.map { Presentation.bulkEligible($0, status: row.record.status) } == true
        }
    }
    public func isUpdating(_ id: AppInstanceID) -> Bool { jobs[id] != nil }
    public var externalURL: URL?
    public let diagnosticURL: URL
    private let store: PreferencesStore
    private let scanLedger = ScanLedger()
    private var jobLedger = JobState()
    private let storeQueue = StoreUpdateQueue()
    private let runtime: any ApplicationRuntime
    private let monitoringInterval: Duration?
    private let fixtureRecords: (@MainActor @Sendable (Preferences) -> [AppRecord])?
    private let legacy: [String: PreferenceValue]
    private let nativeJobJournal: URL?
    private var scanTask: Task<Void, Never>?
    private var monitoringTask: Task<Void, Never>?
    private var notesTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var jobs: [AppInstanceID: Task<Void, Never>] = [:]
    private var generation: UInt64 = 0
    private var started = false
    private var preferencesLoaded = false
    private var fingerprints = Set<String>()

    public init(runtime: any ApplicationRuntime, preferencesURL: URL, diagnosticURL: URL,
                legacy: [String: PreferenceValue] = [:], monitoringInterval: Duration? = .seconds(5),
                jobJournal: URL? = nil,
                fixtureRecords: (@MainActor @Sendable (Preferences) -> [AppRecord])? = nil) {
        self.runtime = runtime; store = PreferencesStore(url: preferencesURL)
        self.diagnosticURL = diagnosticURL; self.legacy = legacy
        self.monitoringInterval = monitoringInterval; nativeJobJournal = jobJournal
        self.fixtureRecords = fixtureRecords
    }
    isolated deinit { scanTask?.cancel(); monitoringTask?.cancel(); notesTask?.cancel() }

    public func start() async {
        guard !started else { return }
        started = true
        do {
            preferences = try await store.load(legacy: legacy)
        } catch { fail(error) }
        preferencesLoaded = true
        refresh()
        guard fixtureRecords == nil, let monitoringInterval else { return }
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: monitoringInterval) } catch { return }
                guard let self, !self.scanning, self.activeUpdates == 0 else { continue }
                let result = await self.runtime.scan(self.preferences.directories)
                let next = Set(result.apps.map { "\($0.id.path)|\($0.fingerprint)" })
                if next != self.fingerprints || result.warnings != self.warnings { self.refresh() }
            }
        }
    }
    public func refresh() {
        if let fixtureRecords {
            rows = fixtureRecords(preferences).map(ApplicationRow.init(record:))
            selectedRow = rows.first { $0.id == selectedID }; filter(); selectNotes(); return
        }
        generation &+= 1
        let token = generation
        scanTask?.cancel()
        scanning = true; checked = 0; total = 0
        scanTask = Task { await scan(token: token) }
    }
    private func scan(token: UInt64) async {
        guard generation == token, !Task.isCancelled else { return }
        scanning = true; checked = 0
        defer { if generation == token { scanning = false } }
        let result = await runtime.scan(preferences.directories)
        guard generation == token, !Task.isCancelled else { return }
        warnings = result.warnings
        fingerprints = Set(result.apps.map { "\($0.id.path)|\($0.fingerprint)" })
        total = result.apps.count
        let ledgerToken = await scanLedger.begin(apps: result.apps)
        guard generation == token, !Task.isCancelled else { return }
        let previous = Dictionary(rows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        rows = result.apps.map { app in
            let row = previous[app.id] ?? ApplicationRow(record: .init(app: app))
            row.record = .init(app: app); return row
        }
        selectedRow = rows.first { $0.id == selectedID }; filter(); selectNotes()
        let context = CheckContext(apps: result.apps, preferences: preferences)
        let runtime = runtime
        await withTaskGroup(of: AppRecord.self) { group in
            var iterator = result.apps.makeIterator()
            for _ in 0..<8 { if let app = iterator.next() { group.addTask { await runtime.check(app, context: context) } } }
            while let record = await group.next() {
                if generation == token, !Task.isCancelled, await scanLedger.accept(record, generation: ledgerToken),
                   generation == token, !Task.isCancelled {
                    rows.first { $0.id == record.id }?.record = record
                    checked += 1; filter()
                    if selectedID == record.id { selectNotes() }
                }
                if Task.isCancelled { group.cancelAll(); break }
                if let app = iterator.next() { group.addTask { await runtime.check(app, context: context) } }
            }
        }
    }
    public func filter() {
        let matches = Presentation.visible(rows.map { $0.record }, query: query, source: sourceFilter, preferences: preferences)
        let mapping = Dictionary(rows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        visibleRows = matches.compactMap { mapping[$0.id] }
    }

    public func save() {
        filter()
        let value = preferences
        let previous = saveTask
        saveTask = Task { await previous?.value; do { try await store.save(value) } catch { fail(error) } }
    }
    public func ignore(_ id: AppInstanceID) {
        guard let row = rows.first(where: { $0.id == id }) else { return }
        if preferences.ignoredBundleIDs.contains(row.record.app.bundleID) { preferences.ignoredBundleIDs.remove(row.record.app.bundleID) }
        else { preferences.ignoredBundleIDs.insert(row.record.app.bundleID) }
    }
    public func skip(_ id: AppInstanceID) {
        guard let candidate = rows.first(where: { $0.id == id })?.record.candidate else { return }
        preferences.skippedVersions[id.path] = candidate.id
    }
    public func clearSkip(_ id: AppInstanceID) { preferences.skippedVersions.removeValue(forKey: id.path) }
    public func canUpdate(_ id: AppInstanceID) -> Bool {
        guard let row = rows.first(where: { $0.id == id }) else { return false }
        return !scanning && !isUpdating(id) && [.available, .external].contains(row.record.status) && row.record.candidate != nil
    }
    public func canCancel(_ id: AppInstanceID) -> Bool {
        guard isUpdating(id), let event = rows.first(where: { $0.id == id })?.event else { return false }
        return !event.isTerminal && event.phase != .installing && event.phase != .verifying
    }
    public var canQuit: Bool { jobs.isEmpty }
    public func waitForScan() async { await scanTask?.value }
    public func waitForUpdates() async { while let job = jobs.values.first { await job.value }; await waitForScan() }
    public func flushPreferences() async { await saveTask?.value }
    public func stopMonitoring() { monitoringTask?.cancel(); monitoringTask = nil }

    public func requestUpdate(_ id: AppInstanceID) {
        guard canUpdate(id), let row = rows.first(where: { $0.id == id }),
              let candidate = row.record.candidate else { return }
        if case .external(let url) = candidate.action { externalURL = url; return }
        if candidate.isMajorUpgrade { pendingMajor = candidate; confirmingMajor = true }
        else { perform(candidate) }
    }
    public func confirmMajor() {
        defer { pendingMajor = nil; confirmingMajor = false }
        guard let pendingMajor, canUpdate(pendingMajor.app.id),
              rows.first(where: { $0.id == pendingMajor.app.id })?.record.candidate == pendingMajor else { return }
        perform(pendingMajor)
    }
    public func cancelMajor() { pendingMajor = nil; confirmingMajor = false }
    public func updateAll() {
        guard !scanning, activeUpdates == 0 else { return }
        for row in rows where row.record.candidate.map({ Presentation.bulkEligible($0, status: row.record.status) }) == true { requestUpdate(row.id) }
    }
    public func cancel(_ id: AppInstanceID) {
        guard canCancel(id) else { return }
        jobs[id]?.cancel()
    }
    private func perform(_ candidate: UpdateCandidate) {
        guard jobs[candidate.app.id] == nil else { return }
        rows.first { $0.id == candidate.app.id }?.event = .init(.queued)
        jobs[candidate.app.id] = Task {
            var jobToken: UUID?
            var storePermit: StoreUpdateQueue.Permit?
            defer { if let storePermit { storeQueue.release(storePermit) } }
            do {
                let token = try jobLedger.start(candidate.app.id); jobToken = token
                try Task.checkCancellation()
                if case .appStore = candidate.action { storePermit = try await storeQueue.acquire() }
                try Task.checkCancellation()
                _ = try await runtime.validate(candidate.app)
                try Task.checkCancellation()
                if storePermit?.waited == true {
                    let context = CheckContext(apps: rows.map { $0.record.app }, preferences: preferences)
                    let fresh = await runtime.check(candidate.app, context: context)
                    try Task.checkCancellation()
                    guard fresh.status == .available, let offer = fresh.candidate, offer.authoritative,
                          offer.id == candidate.id, offer.action == candidate.action,
                          offer.app.fingerprint == candidate.app.fingerprint,
                          offer.isMajorUpgrade == candidate.isMajorUpgrade, offer.channel == candidate.channel else {
                        throw LatestFailure.rejected("The queued App Store update changed. Check for updates again.")
                    }
                }
                accept(.init(.checking), candidate: candidate, token: token)
                let context = CheckContext(apps: rows.map { $0.record.app }, preferences: preferences)
                try await runtime.install(candidate, context: context) { event in
                    self.accept(event, candidate: candidate, token: token)
                }
                accept(.init(.verifying), candidate: candidate, token: token)
                try await runtime.verify(candidate, context: context)
                accept(.init(.succeeded), candidate: candidate, token: token)
            } catch {
                let cancelled = error is CancellationError || Task.isCancelled || (error as? LatestFailure) == .cancelled
                if let jobToken { accept(.init(cancelled ? .cancelled : .failed, message: error.localizedDescription), candidate: candidate, token: jobToken) }
                if !cancelled { fail(error) }
            }
            jobs.removeValue(forKey: candidate.app.id)
            refresh()
        }
    }
    private func accept(_ event: UpdateEvent, candidate: UpdateCandidate, token: UUID) {
        if jobLedger.accept(event, app: candidate.app.id, token: token) {
            rows.first { $0.id == candidate.app.id }?.event = event
            if let nativeJobJournal {
                do {
                    let entry = ["job": token.uuidString, "path": candidate.app.id.path, "phase": event.phase.rawValue,
                                 "time": Date().ISO8601Format()]
                    var data = try JSONSerialization.data(withJSONObject: entry, options: .sortedKeys)
                    data.append(10)
                    if !FileManager.default.fileExists(atPath: nativeJobJournal.path) {
                        try data.write(to: nativeJobJournal, options: .atomic)
                    } else {
                        let file = try FileHandle(forWritingTo: nativeJobJournal)
                        defer { try? file.close() }
                        try file.seekToEnd(); try file.write(contentsOf: data)
                    }
                } catch { /* Optional native evidence must not change an install outcome. */ }
            }
        }
    }
    public func selectNotes() {
        notesTask?.cancel()
        let token = UUID(); notesToken = token; notes = ""; loadingNotes = false
        guard let candidate = selectedRow?.record.candidate else { return }
        if let value = candidate.releaseNotes { notes = SafeText.releaseNotes(value); return }
        guard let url = candidate.releaseNotesURL, url.scheme == "https" else { return }
        loadingNotes = true
        notesTask = Task {
            defer { if notesToken == token { loadingNotes = false } }
            do {
                let value = try await runtime.releaseNotes(url)
                if notesToken == token { notes = SafeText.releaseNotes(value) }
            } catch { if notesToken == token { notes = error.localizedDescription } }
        }
    }
    public func enableBroker() {
        Task { do { needsBrokerApproval = try await runtime.enableBroker() } catch { fail(error) } }
    }
    public func addDirectory(_ url: URL) {
        let path = url.resolvingSymlinksInPath().path
        if !preferences.directories.contains(where: { $0.path == path }) { preferences.directories.append(.init(path: path)) }
    }
    public func fail(_ error: Error) {
        errorMessage = error.localizedDescription; showingError = true
        do {
            try FileManager.default.createDirectory(at: diagnosticURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            var text = (try? String(contentsOf: diagnosticURL, encoding: .utf8)) ?? ""
            text = String(text.suffix(200_000)) + "\n\(Date().ISO8601Format()) \(error.localizedDescription)\n"
            try Data(text.utf8).write(to: diagnosticURL, options: .atomic)
        } catch { /* Diagnostic failure must not hide the original error. */ }
    }
}
