import Foundation
import LatestCore

public struct ApplicationInventory: Sendable {
    public let apps: [AppSnapshot]
    public let warnings: [String]
    public init(apps: [AppSnapshot], warnings: [String] = []) { self.apps = apps; self.warnings = warnings }
}

/// Platform capabilities. The application owns policy, state, jobs and persistence;
/// adapters own discovery, transport, signatures and provider-specific installation.
public protocol ApplicationRuntime: Sendable {
    func scan(_ directories: [DirectoryPreference]) async -> ApplicationInventory
    func check(_ app: AppSnapshot, context: CheckContext) async -> AppRecord
    func validate(_ expected: AppSnapshot) async throws -> AppSnapshot
    func install(_ candidate: UpdateCandidate, context: CheckContext,
                 event: @escaping @MainActor @Sendable (UpdateEvent) -> Void) async throws
    func verify(_ candidate: UpdateCandidate, context: CheckContext) async throws
    func releaseNotes(_ url: URL) async throws -> String
    /// Returns whether explicit system approval is still required.
    func enableBroker() async throws -> Bool
    /// Configure the host's native self-updater, if this runtime supports it.
    func configureSelfUpdates() async throws -> Bool
    func checkSelfUpdates() async throws
}

public extension ApplicationRuntime {
    func configureSelfUpdates() async throws -> Bool { false }
    func checkSelfUpdates() async throws { throw LatestFailure.rejected("Latest self-updates are unavailable in this runtime.") }
}
