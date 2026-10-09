import Foundation

public struct AppInstanceID: Codable, Hashable, Sendable, Identifiable {
    public let path: String
    public var id: String { path }
    public init(url: URL) { path = url.standardizedFileURL.resolvingSymlinksInPath().path }
    public var url: URL { URL(fileURLWithPath: path) }
}

public enum Architecture: String, Codable, Hashable, Sendable { case arm64, x86_64 }
public enum UpdateSource: String, Codable, CaseIterable, Sendable { case appStore, homebrew, sparkle, catalogue, unknown }
public enum ReleaseChannel: String, Codable, CaseIterable, Sendable { case stable, beta }

public struct AppSnapshot: Codable, Hashable, Sendable, Identifiable {
    public let id: AppInstanceID
    public let bundleID: String
    public let name: String
    public let version: AppVersion
    public let architectures: Set<Architecture>
    public let hasReceipt: Bool
    public let isWrapped: Bool
    public let feedURL: URL?
    public let signatureTeam: String?
    public let fingerprint: String
    public init(url: URL, bundleID: String, name: String, version: AppVersion,
                architectures: Set<Architecture> = [], hasReceipt: Bool = false,
                isWrapped: Bool = false, feedURL: URL? = nil, signatureTeam: String? = nil,
                fingerprint: String = "") {
        id = .init(url: url); self.bundleID = bundleID; self.name = name; self.version = version
        self.architectures = architectures; self.hasReceipt = hasReceipt; self.isWrapped = isWrapped
        self.feedURL = feedURL; self.signatureTeam = signatureTeam; self.fingerprint = fingerprint
    }
}

public enum UpdateAction: Codable, Hashable, Sendable {
    case appStore(UInt64), homebrew(String), sparkle(URL), external(URL), none
}

public struct UpdateCandidate: Codable, Hashable, Sendable, Identifiable {
    public let app: AppSnapshot
    public let source: UpdateSource
    public let version: AppVersion
    public let action: UpdateAction
    public let authoritative: Bool
    public let channel: ReleaseChannel
    public let minimumOS: String?
    public let architectures: Set<Architecture>
    public let releaseNotes: String?
    public let releaseNotesURL: URL?
    public let releaseDate: Date?
    public let comparison: VersionOrder
    public var id: String { "\(app.id.path)|\(source.rawValue)|\(version.description)" }
    public init(app: AppSnapshot, source: UpdateSource, version: AppVersion, action: UpdateAction,
                authoritative: Bool, channel: ReleaseChannel = .stable, minimumOS: String? = nil,
                architectures: Set<Architecture> = [], releaseNotes: String? = nil,
                releaseNotesURL: URL? = nil, releaseDate: Date? = nil, comparison: VersionOrder? = nil) {
        self.app = app; self.source = source; self.version = version; self.action = action
        self.authoritative = authoritative; self.channel = channel; self.minimumOS = minimumOS
        self.architectures = architectures; self.releaseNotes = releaseNotes
        self.releaseNotesURL = releaseNotesURL; self.releaseDate = releaseDate
        self.comparison = comparison ?? app.version.compare(to: version, policy: source == .sparkle ? .build : .display)
    }
    public var isMajorUpgrade: Bool {
        if let a = app.version.major, let b = version.major { return b > a }
        return false
    }
}

public enum AppStatus: String, Codable, Sendable {
    case available, current, external, unknown, incompatible, ignored, skipped
}

public struct AppRecord: Hashable, Sendable, Identifiable {
    public let app: AppSnapshot
    public let candidate: UpdateCandidate?
    public let status: AppStatus
    public let reason: String?
    public var id: AppInstanceID { app.id }
    public init(app: AppSnapshot, candidate: UpdateCandidate? = nil, status: AppStatus = .unknown, reason: String? = nil) {
        self.app = app; self.candidate = candidate; self.status = status; self.reason = reason
    }
}

public struct DirectoryPreference: Codable, Hashable, Sendable, Identifiable {
    public let path: String
    public var enabled: Bool
    public var id: String { path }
    public init(path: String, enabled: Bool = true) { self.path = path; self.enabled = enabled }
}

public struct Preferences: Codable, Equatable, Sendable {
    public var directories: [DirectoryPreference]
    public var ignoredBundleIDs: Set<String> = []
    public var skippedVersions: [String: String] = [:]
    public var channels: [String: ReleaseChannel] = [:]
    public var showCurrent = true
    public var showIgnored = false
    public var showUnknown = true
    public var sortBySource = false
    public var fontScale: Double = 1
    public init(directories: [DirectoryPreference] = [
        .init(path: "/Applications"), .init(path: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path)
    ]) { self.directories = directories }
}

public struct CheckContext: Sendable {
    public let apps: [AppSnapshot]
    public let preferences: Preferences
    public init(apps: [AppSnapshot], preferences: Preferences) { self.apps = apps; self.preferences = preferences }
}

public protocol UpdateProvider: Sendable {
    func check(_ app: AppSnapshot, context: CheckContext) async throws -> UpdateCandidate?
}

public enum LatestFailure: Error, LocalizedError, Sendable, Equatable {
    case rejected(String), network(String), process(String), timeout, cancelled
    public var errorDescription: String? {
        switch self {
        case .rejected(let text), .network(let text), .process(let text): text
        case .timeout: "The operation timed out."
        case .cancelled: "The operation was cancelled."
        }
    }
}
