import Foundation
import ServiceManagement
import LatestCore
import LatestContracts
import LatestTrust

private actor ReplyGate {
    private var continuation: CheckedContinuation<Data, Error>?
    private var outcome: Result<Data, Error>?
    func wait(_ continuation: CheckedContinuation<Data, Error>) {
        if let outcome { continuation.resume(with: outcome) }
        else { self.continuation = continuation }
    }
    func finish(_ result: Result<Data, Error>) {
        guard outcome == nil else { return }
        outcome = result
        continuation?.resume(with: result); continuation = nil
    }
}

@MainActor public final class BrokerClient {
    private var connections: [UUID: NSXPCConnection] = [:]
    private func invalidate(_ token: UUID) { connections.removeValue(forKey: token)?.invalidate() }
    public init() {}
    @MainActor public static var status: SMAppService.Status {
        SMAppService.daemon(plistName: ForkIdentity.broker + ".plist").status
    }
    @MainActor public static func register() throws {
        let service = SMAppService.daemon(plistName: ForkIdentity.broker + ".plist")
        if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        else if service.status != .enabled { try service.register() }
    }
    public func update(_ claim: AppStoreClaim, appURL: URL = Bundle.main.bundleURL) async throws {
        let configuration = try BrokerConfiguration.load(appURL: appURL)
        let requirement = try ForkIdentity.requirement(identifier: ForkIdentity.broker, team: configuration.team)
        let token = UUID()
        let connection = NSXPCConnection(machServiceName: ForkIdentity.broker, options: .privileged)
        connections[token] = connection
        connection.setCodeSigningRequirement(requirement)
        connection.remoteObjectInterface = NSXPCInterface(with: LatestBrokerProtocol.self)
        let gate = ReplyGate()
        connection.invalidationHandler = { Task { await gate.finish(.failure(LatestFailure.process("The update helper disconnected."))) } }
        connection.interruptionHandler = { Task { await gate.finish(.failure(LatestFailure.process("The update helper was interrupted."))) } }
        connection.resume()
        let timeout = Task { @MainActor in try await Task.sleep(for: .seconds(1200)); await gate.finish(.failure(LatestFailure.timeout)); self.invalidate(token) }
        defer { timeout.cancel(); invalidate(token) }
        let payload = try JSONEncoder().encode(claim)
        _ = try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                Task { await gate.wait(continuation) }
                guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                    Task { await gate.finish(.failure(LatestFailure.process(error.localizedDescription))) }
                }) as? any LatestBrokerProtocol else {
                    Task { await gate.finish(.failure(LatestFailure.process("The update helper is unavailable."))) }; return
                }
                proxy.update(payload) { data, error in
                    Task {
                        if let error { await gate.finish(.failure(LatestFailure.process(error.localizedDescription))) }
                        else if let data { await gate.finish(.success(data)) }
                        else { await gate.finish(.failure(LatestFailure.process("The update helper returned no result."))) }
                    }
                }
            }
        } onCancel: {
            Task { @MainActor in await gate.finish(.failure(CancellationError())); self.invalidate(token) }
        }
    }
}
