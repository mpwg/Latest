import Foundation
import LatestCore

public actor CatalogueProvider: UpdateProvider {
    private let http: BoundedHTTPClient
    private var entries: [CaskMetadata]?
    public init(http: BoundedHTTPClient) { self.http = http }
    public func check(_ app: AppSnapshot, context: CheckContext) async throws -> UpdateCandidate? {
        guard context.preferences.showCatalogueHints, !app.hasReceipt, app.feedURL == nil else { return nil }
        if entries == nil {
            let response = try await http.fetch(URL(string: "https://formulae.brew.sh/api/cask.json")!, maximumBytes: 32_000_000) { _ = try Metadata.casks($0) }
            entries = try Metadata.casks(response.data)
        }
        let matches = entries?.filter { $0.names.contains(app.id.url.lastPathComponent) && !$0.autoUpdates && $0.version != "latest" } ?? []
        guard matches.count == 1, let entry = matches.first else { return nil }
        return .init(app: app, source: .catalogue, version: .init(display: entry.version), action: .none,
                     authoritative: false, minimumOS: entry.minimumOS)
    }
}
