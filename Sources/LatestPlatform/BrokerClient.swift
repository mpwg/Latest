import Foundation
import ServiceManagement
import LatestCore
import LatestApplication
import LatestContracts
import LatestTrust

@MainActor public final class BrokerClient {
    private var connections: [UUID: NSXPCConnection] = [:]
    var activeConnectionCount: Int { connections.count }
    private func invalidate(_ token: UUID) { connections.removeValue(forKey: token)?.invalidate() }
    private nonisolated static func connectionEvent(_ gate: CompletionGate<Data>, message: String) -> @Sendable () -> Void {
        { Task { await gate.finish(.failure(LatestFailure.process(message))) } }
    }
    private nonisolated static func proxyError(_ gate: CompletionGate<Data>) -> @Sendable (any Error) -> Void {
        { error in
            let message = error.localizedDescription
            Task { await gate.finish(.failure(LatestFailure.process(message))) }
        }
    }
    private nonisolated static func reply(_ gate: CompletionGate<Data>) -> @Sendable (Data?, NSError?) -> Void {
        { data, error in
            let result: Result<Data, LatestFailure>
            if let error { result = .failure(.process(error.localizedDescription)) }
            else if let data { result = .success(data) }
            else { result = .failure(.process("The update helper returned no result.")) }
            Task { await gate.finish(result) }
        }
    }
    public init() {}
    @MainActor public static var status: SMAppService.Status {
        SMAppService.daemon(plistName: ForkIdentity.broker + ".plist").status
    }
    @MainActor public static var availability: InstallationHelperStatus {
        switch status {
        case .notRegistered: .notRegistered
        case .requiresApproval: .requiresApproval
        case .enabled: .enabled
        case .notFound: .unavailable
        @unknown default: .unavailable
        }
    }
    @MainActor public static func register() throws {
        let service = SMAppService.daemon(plistName: ForkIdentity.broker + ".plist")
        if service.status != .requiresApproval && service.status != .enabled { try service.register() }
    }
    public func update(_ claim: AppStoreClaim, appURL: URL = Bundle.main.bundleURL) async throws {
        try BrokerPolicy.validateRequest(claim)
        try Task.checkCancellation()
        let validation = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let configuration = try BrokerConfiguration.load(appURL: appURL)
            try configuration.verifyBundledTools(appURL: appURL)
            try Task.checkCancellation()
            return configuration
        }
        let configuration = try await withTaskCancellationHandler { try await validation.value }
            onCancel: { validation.cancel() }
        let requirement = try ForkIdentity.requirement(identifier: ForkIdentity.broker, team: configuration.team)
        let token = UUID()
        let connection = NSXPCConnection(machServiceName: ForkIdentity.broker, options: .privileged)
        connections[token] = connection
        connection.setCodeSigningRequirement(requirement)
        connection.remoteObjectInterface = NSXPCInterface(with: LatestBrokerProtocol.self)
        let gate = CompletionGate<Data>()
        connection.invalidationHandler = Self.connectionEvent(gate, message: "The update helper disconnected.")
        connection.interruptionHandler = Self.connectionEvent(gate, message: "The update helper was interrupted.")
        connection.resume()
        let timeout = Task { @MainActor in try await Task.sleep(for: .seconds(1200)); await gate.finish(.failure(LatestFailure.timeout)); self.invalidate(token) }
        defer { timeout.cancel(); invalidate(token) }
        let payload = try JSONEncoder().encode(claim)
        _ = try await withTaskCancellationHandler {
            try Task.checkCancellation()
            let dispatch = Task { @MainActor in
                guard let proxy = connection.remoteObjectProxyWithErrorHandler(Self.proxyError(gate)) as? any LatestBrokerProtocol else {
                    Task { await gate.finish(.failure(LatestFailure.process("The update helper is unavailable."))) }; return
                }
                proxy.update(payload, reply: Self.reply(gate))
            }
            defer { dispatch.cancel() }
            return try await gate.wait()
        } onCancel: {
            Task { @MainActor in await gate.finish(.failure(LatestFailure.cancelled)); self.invalidate(token) }
        }
    }
}
