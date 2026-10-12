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

/// Reject unavailable test profiles before a frontend creates runtime or persistence.
public enum ApplicationLaunchPolicy {
    public static func validate(arguments: [String], testProfilesAllowed: Bool) throws {
        guard !testProfilesAllowed else { return }
        let testFlags: Set<String> = ["--ui-testing", "--ui-test-directory",
            "--native-install-test-directory", "--native-install-test-catalogue-url",
            "--native-install-test-hold-scans", "--native-migration-test-domain"]
        if let flag = arguments.lazy.compactMap({ $0.split(separator: "=", maxSplits: 1).first.map(String.init) })
            .first(where: { testFlags.contains($0) }) {
            throw LatestFailure.rejected("Test-only launch argument \(flag) is unavailable in this build.")
        }
    }
}
