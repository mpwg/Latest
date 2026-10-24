import Foundation
import LatestCore
import LatestProcess

public actor AppStoreProvider: UpdateProvider {
    private let http: BoundedHTTPClient
    private let runner = CommandRunner()
    private let masURL: URL?
    private var installations: [AppStoreClaim] = []
    private var loadedAt = Date.distantPast
    public init(http: BoundedHTTPClient, masURL: URL?) { self.http = http; self.masURL = masURL }
    public func claim(for app: AppSnapshot) async throws -> AppStoreClaim? {
        guard let masURL else { return nil }
        if Date().timeIntervalSince(loadedAt) >= 15 {
            let result = try await runner.run(executable: masURL, arguments: ["list", "--json"], environment: CommandRunner.userEnvironment())
            guard result.exitCode == 0 else { throw LatestFailure.process("Cannot read App Store installations.") }
            installations = try MasMetadata.installed(result.output); loadedAt = Date()
        }
        let matches = installations.filter { $0.bundleID == app.bundleID }
        guard matches.count == 1, let claim = matches.first, claim.path == app.id.path else { return nil }
        return claim
    }
    public func invalidate() { loadedAt = .distantPast }
    public func check(_ app: AppSnapshot, context: CheckContext) async throws -> UpdateCandidate? {
        guard app.hasReceipt || app.isWrapped else { return nil }
        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        components?.queryItems = [URLQueryItem(name: "bundleId", value: app.bundleID),
            URLQueryItem(name: "entity", value: "macSoftware"), URLQueryItem(name: "country", value: Locale.current.region?.identifier ?? "US"),
            URLQueryItem(name: "lang", value: Locale.preferredLanguages.first ?? "en")]
        guard let url = components?.url else { return nil }
        let response = try await http.fetch(url, maximumBytes: 2_000_000) { data in
            _ = try JSONDecoder().decode(Lookup.self, from: data)
        }
        let result = try JSONDecoder().decode(Lookup.self, from: response.data)
        guard let entry = result.results.first(where: { $0.bundleId == app.bundleID }), entry.trackId > 0 else { return nil }
        var ownership: AppStoreClaim?
        if BrokerPolicy.permitsOwnershipLookup(for: app, apps: context.apps, metadataIsFresh: !response.stale) {
            do { ownership = try await claim(for: app) }
            catch {
                if error is CancellationError { throw error }
                try Task.checkCancellation()
                // Failed local ownership cannot authorize installation; preserve the external updater.
            }
        }
        try Task.checkCancellation()
        let action = try BrokerPolicy.updateAction(for: app, apps: context.apps, storeID: entry.trackId,
            metadataIsFresh: !response.stale, claim: ownership)
        return .init(app: app, source: .appStore, version: .init(display: entry.version), action: action,
                     authoritative: !response.stale, minimumOS: entry.minimumOsVersion,
                     releaseNotes: entry.releaseNotes, releaseDate: entry.currentVersionReleaseDate.flatMap { ISO8601DateFormatter().date(from: $0) })
    }
    private struct Lookup: Decodable { let results: [Entry] }
    private struct Entry: Decodable {
        let trackId: UInt64; let bundleId: String; let version: String
        let minimumOsVersion: String?; let releaseNotes: String?; let currentVersionReleaseDate: String?
    }
}
