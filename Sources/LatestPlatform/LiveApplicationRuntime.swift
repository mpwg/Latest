import Foundation
import LatestCore
import LatestApplication

/// The same native adapters can be driven by a GUI, a CLI or headless integration tests.
public struct LiveApplicationRuntime: ApplicationRuntime {
    private let inventory = AppInventory()
    private let brew: HomebrewProvider
    private let appStore: AppStoreProvider
    private let sparkle = SparkleProvider()
    private let http: BoundedHTTPClient
    private let catalogue: CatalogueProvider
    private let broker: BrokerClient
    private let selfUpdates: HostSelfUpdates

    @MainActor public init(cacheDirectory: URL, homebrewExecutable: URL? = nil,
                           masURL: URL? = nil, catalogueURL: URL? = nil) {
        brew = HomebrewProvider(executable: homebrewExecutable)
        http = BoundedHTTPClient(cacheDirectory: cacheDirectory)
        appStore = AppStoreProvider(http: http, masURL: masURL)
        catalogue = CatalogueProvider(http: http, catalogueURL: catalogueURL)
        broker = BrokerClient()
        selfUpdates = HostSelfUpdates()
    }
    public func scan(_ directories: [DirectoryPreference]) async -> ApplicationInventory {
        let result = await inventory.scan(directories)
        return .init(apps: result.apps, warnings: result.warnings)
    }
    public func check(_ app: AppSnapshot, context: CheckContext) async -> AppRecord {
        #if arch(arm64)
        let architecture = Architecture.arm64
        #else
        let architecture = Architecture.x86_64
        #endif
        let providers: [any UpdateProvider] = [appStore, brew, sparkle, catalogue]
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
    public func validate(_ expected: AppSnapshot) async throws -> AppSnapshot {
        try await AppInventory.validateForInstallation(expected)
    }
    public func install(_ candidate: UpdateCandidate, context: CheckContext,
                        event: @escaping @MainActor @Sendable (UpdateEvent) -> Void) async throws {
        switch candidate.action {
        case .homebrew:
            await event(.init(.installing))
            try await brew.upgrade(candidate, context: context)
        case .appStore(let id):
            await appStore.invalidate()
            guard let claim = try await appStore.claim(for: candidate.app), claim.storeID == id else {
                throw LatestFailure.rejected("The App Store installation is ambiguous.")
            }
            await event(.init(.installing))
            try await broker.update(claim)
            await appStore.invalidate()
        case .sparkle:
            try await sparkle.install(candidate, channel: context.preferences.channels[candidate.app.id.path, default: .stable], event: event)
        default: throw LatestFailure.rejected("This update must be performed externally.")
        }
    }
    public func verify(_ candidate: UpdateCandidate, context: CheckContext) async throws {
        guard let installed = AppInventory.snapshot(at: candidate.app.id.url), installed.bundleID == candidate.app.bundleID else {
            throw LatestFailure.process("The installed app could not be verified.")
        }
        if case .homebrew = candidate.action {
            guard let checked = try await brew.check(installed, context: context), checked.comparison == .same else {
                throw LatestFailure.process("Homebrew still reports this app as outdated.")
            }
        } else {
            let order = installed.version.compare(to: candidate.version, policy: candidate.source == .sparkle ? .build : .display)
            guard order == .same || order == .newer else { throw LatestFailure.process("The installed version does not match the expected update.") }
        }
        guard candidate.app.architectures.isEmpty || !installed.architectures.isDisjoint(with: candidate.app.architectures) else {
            throw LatestFailure.process("The installed app architecture changed unexpectedly.")
        }
    }
    public func releaseNotes(_ url: URL) async throws -> String {
        let response = try await http.fetch(url, maximumBytes: 500_000) {
            guard String(data: $0, encoding: .utf8) != nil else { throw LatestFailure.network("Unsupported release notes encoding.") }
        }
        return String(decoding: response.data, as: UTF8.self)
    }
    public func brokerStatus() async -> InstallationHelperStatus {
        await MainActor.run { BrokerClient.availability }
    }
    public func enableBroker() async throws -> InstallationHelperStatus {
        try await MainActor.run { try BrokerClient.register(); return BrokerClient.availability }
    }
    public func configureSelfUpdates() async throws -> Bool { try await selfUpdates.configure() }
    public func checkSelfUpdates() async throws { try await selfUpdates.check() }
}
