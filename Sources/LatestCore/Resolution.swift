import Foundation

public enum Resolution {
    public static func record(_ app: AppSnapshot, candidate: UpdateCandidate?, preferences: Preferences,
                              operatingSystem: OperatingSystemVersion, architecture: Architecture) -> AppRecord {
        guard let candidate else { return .init(app: app, status: .unknown) }
        if preferences.ignoredBundleIDs.contains(app.bundleID) { return .init(app: app, candidate: candidate, status: .ignored) }
        if preferences.skippedVersions[app.id.path] == candidate.id { return .init(app: app, candidate: candidate, status: .skipped) }
        if candidate.channel == .beta && preferences.channels[app.id.path, default: .stable] == .stable {
            return .init(app: app, candidate: candidate, status: .unknown, reason: "This update belongs to the beta channel.")
        }
        if let minimum = candidate.minimumOS, !supports(minimum: minimum, current: operatingSystem) {
            return .init(app: app, candidate: candidate, status: .incompatible, reason: "The update requires a newer operating system.")
        }
        if !candidate.architectures.isEmpty && !candidate.architectures.contains(architecture) {
            return .init(app: app, candidate: candidate, status: .incompatible, reason: "The update does not support this Mac's architecture.")
        }
        if !candidate.authoritative {
            return .init(app: app, candidate: candidate, status: .unknown, reason: "Catalogue metadata is informational; installation ownership is not established.")
        }
        switch candidate.comparison {
        case .same, .newer: return .init(app: app, candidate: candidate, status: .current)
        case .unknown: return .init(app: app, candidate: candidate, status: .unknown, reason: "The versions cannot be compared reliably.")
        case .older:
            switch candidate.action {
            case .none: return .init(app: app, candidate: candidate, status: .unknown)
            case .external: return .init(app: app, candidate: candidate, status: .external)
            default: return .init(app: app, candidate: candidate, status: .available)
            }
        }
    }

    public static func supports(minimum: String, current: OperatingSystemVersion) -> Bool {
        let parts = minimum.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty, parts.count <= 3,
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              let major = Int(parts[0]) else { return false }
        let minor = parts.count > 1 ? Int(parts[1]) : 0
        let patch = parts.count > 2 ? Int(parts[2]) : 0
        guard let minor, let patch else { return false }
        let a = [current.majorVersion, current.minorVersion, current.patchVersion], b = [major, minor, patch]
        return !a.lexicographicallyPrecedes(b)
    }
}

public actor ScanLedger {
    private var generation: UInt64 = 0
    private var records: [AppInstanceID: AppRecord] = [:]
    public init() {}
    public func begin(apps: [AppSnapshot]) -> UInt64 {
        generation &+= 1
        records = Dictionary(apps.map { ($0.id, AppRecord(app: $0)) }, uniquingKeysWith: { first, _ in first })
        return generation
    }
    @discardableResult public func accept(_ record: AppRecord, generation token: UInt64) -> Bool {
        guard token == generation, let current = records[record.id], current.app.fingerprint == record.app.fingerprint else { return false }
        records[record.id] = record
        return true
    }
    public func snapshot() -> [AppRecord] { records.values.sorted { $0.id.path < $1.id.path } }
}

public enum JobPhase: String, Codable, Sendable { case queued, checking, downloading, installing, verifying, succeeded, failed, cancelled }
public struct UpdateEvent: Equatable, Sendable {
    public let phase: JobPhase
    public let progress: Double?
    public let message: String?
    public init(_ phase: JobPhase, progress: Double? = nil, message: String? = nil) {
        self.phase = phase; self.progress = progress.flatMap { $0.isFinite ? min(1, max(0, $0)) : nil }; self.message = message
    }
    public var isTerminal: Bool { [.succeeded, .failed, .cancelled].contains(phase) }
}

public actor JobLedger {
    private var jobs: [AppInstanceID: (UUID, UpdateEvent)] = [:]
    public init() {}
    public func start(_ app: AppInstanceID) throws -> UUID {
        if let old = jobs[app], !old.1.isTerminal { throw LatestFailure.rejected("An update is already running for this app.") }
        let token = UUID(); jobs[app] = (token, .init(.queued)); return token
    }
    @discardableResult public func accept(_ event: UpdateEvent, app: AppInstanceID, token: UUID) -> Bool {
        guard let old = jobs[app], old.0 == token, !old.1.isTerminal else { return false }
        let phases: [JobPhase] = [.queued, .checking, .downloading, .installing, .verifying]
        if !event.isTerminal, let before = phases.firstIndex(of: old.1.phase), let after = phases.firstIndex(of: event.phase), after < before { return false }
        jobs[app] = (token, event); return true
    }
    public func event(for app: AppInstanceID) -> UpdateEvent? { jobs[app]?.1 }
}
