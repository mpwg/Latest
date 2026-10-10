import Foundation

public actor PreferencesStore {
    private let url: URL
    public init(url: URL) { self.url = url }
    public func load(legacy: [String: PreferenceValue] = [:]) throws -> Preferences {
        if FileManager.default.fileExists(atPath: url.path) {
            return try JSONDecoder().decode(Preferences.self, from: Data(contentsOf: url))
        }
        var preferences = Preferences()
        if case .strings(let paths) = legacy["directoryPaths"] {
            for path in paths where path.hasPrefix("/") && !preferences.directories.contains(where: { $0.path == path }) {
                preferences.directories.append(.init(path: path))
            }
        }
        if case .strings(let ids) = legacy["IgnoredAppsKey"] { preferences.ignoredBundleIDs = Set(ids) }
        if case .bool(let value) = legacy["ShowInstalledUpdatesKey"] { preferences.showCurrent = value }
        if case .bool(let value) = legacy["ShowIgnoredUpdatesKey"] { preferences.showIgnored = value }
        if case .bool(let value) = legacy["ShowUnsupportedUpdatesKey"] { preferences.showUnknown = value }
        try save(preferences)
        return preferences
    }
    public func save(_ preferences: Preferences) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode(preferences).write(to: url, options: .atomic)
    }
}

public enum PreferenceValue: Sendable { case strings([String]), bool(Bool) }
