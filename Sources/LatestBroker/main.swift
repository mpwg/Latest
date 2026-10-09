import Foundation
import Darwin
import MachO
import LatestCore
import LatestContracts
import LatestTrust
import LatestProcess

private func hostApplication() throws -> URL {
    var size: UInt32 = 4096
    var bytes = [CChar](repeating: 0, count: Int(size))
    guard _NSGetExecutablePath(&bytes, &size) == 0 else { throw LatestFailure.rejected("Cannot resolve the broker executable.") }
    let executable = URL(fileURLWithPath: String(decoding: bytes.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self)).resolvingSymlinksInPath()
    let host = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    guard host.pathExtension == "app", executable.lastPathComponent == "LatestBroker" else { throw LatestFailure.rejected("The broker is outside its application bundle.") }
    return host
}

private actor BrokerEngine {
    private let host: URL
    private let configuration: BrokerConfiguration
    private let runner = CommandRunner()
    private var busy = false
    init(host: URL, configuration: BrokerConfiguration) { self.host = host; self.configuration = configuration }

    func update(data: Data, uid: uid_t, gid: gid_t) async throws -> Data {
        guard !busy, uid >= 500, data.count <= 4096 else { throw LatestFailure.rejected("The broker cannot accept this request.") }
        busy = true; defer { busy = false }
        let claim = try JSONDecoder().decode(AppStoreClaim.self, from: data)
        _ = try BrokerPolicy.arguments(for: claim)
        // The signed host seals configuration and tool resources before staging.
        try CodeTrust.verify(host, requirement: ForkIdentity.requirement(identifier: ForkIdentity.application, team: configuration.team))
        let staged = try StagedTool.prepare(source: host.appendingPathComponent("Contents/Resources/mas"), configuration: configuration)
        defer { try? FileManager.default.removeItem(at: staged.directory) }
        guard let user = getpwuid(uid), let home = user.pointee.pw_dir, let name = user.pointee.pw_name else {
            throw LatestFailure.rejected("Cannot resolve the authenticated user.")
        }
        let environment = ["HOME": String(cString: home), "USER": String(cString: name), "LOGNAME": String(cString: name),
                           "SUDO_UID": String(uid), "SUDO_GID": String(gid), "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
                           "LANG": "en_US.UTF-8", "MAS_NO_AUTO_INDEX": "1"]
        let installed = try await runJSON(staged.executable, arguments: ["list", "--json"], environment: environment)
        let outdated = try await runJSON(staged.executable, arguments: ["outdated", "--json", String(claim.storeID)], environment: environment)
        let claims = try Self.installations(installed)
        let ids = try Self.outdatedIDs(outdated)
        try BrokerPolicy.validate(claim, installed: claims, outdatedIDs: ids)
        try Self.verifyReceipt(claim)
        let result = try await runner.run(executable: staged.executable, arguments: BrokerPolicy.arguments(for: claim),
                                          environment: environment, timeout: .seconds(1100))
        guard result.exitCode == 0 else { throw LatestFailure.process(String(result.text.suffix(4000))) }
        try Self.verifyReceipt(claim)
        let remaining = try await runJSON(staged.executable, arguments: ["outdated", "--json", String(claim.storeID)], environment: environment)
        guard try !Self.outdatedIDs(remaining).contains(claim.storeID) else { throw LatestFailure.process("The App Store update did not complete.") }
        return try JSONEncoder().encode(claim)
    }
    private func runJSON(_ tool: URL, arguments: [String], environment: [String: String]) async throws -> Data {
        let result = try await runner.run(executable: tool, arguments: arguments, environment: environment, timeout: .seconds(60))
        guard result.exitCode == 0 else { throw LatestFailure.process("The App Store metadata check failed.") }
        return result.output
    }
    private static func objects(_ data: Data) throws -> [[String: Any]] {
        try String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline).map {
            guard let object = try JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any] else { throw LatestFailure.process("Unexpected App Store metadata.") }
            return object
        }
    }
    private static func installations(_ data: Data) throws -> [AppStoreClaim] {
        try objects(data).map {
            guard let id = ($0["adamID"] as? NSNumber)?.uint64Value, let bundle = $0["bundleID"] as? String,
                  let path = $0["path"] as? String else { throw LatestFailure.process("Invalid installation metadata.") }
            return .init(storeID: id, bundleID: bundle, path: path)
        }
    }
    private static func outdatedIDs(_ data: Data) throws -> Set<UInt64> {
        Set(try objects(data).map {
            guard let id = ($0["adamID"] as? NSNumber)?.uint64Value, $0["newVersion"] is String else { throw LatestFailure.process("Invalid outdated metadata.") }
            return id
        })
    }
    private static func verifyReceipt(_ claim: AppStoreClaim) throws {
        let app = URL(fileURLWithPath: claim.path)
        guard app.resolvingSymlinksInPath().path == claim.path else { throw LatestFailure.rejected("Symlinked App Store targets are not supported.") }
        let receipt = app.appendingPathComponent("Contents/_MASReceipt/receipt")
        guard receipt.resolvingSymlinksInPath().path == receipt.path,
              let attributes = try? FileManager.default.attributesOfItem(atPath: receipt.path),
              attributes[.type] as? FileAttributeType == .typeRegular, (attributes[.size] as? Int ?? 0) > 0,
              let data = try? Data(contentsOf: app.appendingPathComponent("Contents/Info.plist")),
              let dictionary = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              dictionary["CFBundleIdentifier"] as? String == claim.bundleID else {
            throw LatestFailure.rejected("The selected App Store app or receipt changed.")
        }
    }
}

private final class ConnectionService: NSObject, LatestBrokerProtocol {
    let engine: BrokerEngine
    let uid: uid_t
    let gid: gid_t
    init(engine: BrokerEngine, uid: uid_t, gid: gid_t) { self.engine = engine; self.uid = uid; self.gid = gid }
    func update(_ request: Data, reply: @escaping @Sendable (Data?, NSError?) -> Void) {
        let engine = engine, uid = uid, gid = gid
        Task {
            do { reply(try await engine.update(data: request, uid: uid, gid: gid), nil) }
            catch { reply(nil, NSError(domain: "LatestBroker", code: 1, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])) }
        }
    }
}

private final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    let engine: BrokerEngine
    let requirement: String
    init(engine: BrokerEngine, requirement: String) { self.engine = engine; self.requirement = requirement }
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard connection.effectiveUserIdentifier >= 500 else { return false }
        connection.setCodeSigningRequirement(requirement)
        connection.exportedInterface = NSXPCInterface(with: LatestBrokerProtocol.self)
        connection.exportedObject = ConnectionService(engine: engine, uid: connection.effectiveUserIdentifier, gid: connection.effectiveGroupIdentifier)
        connection.resume()
        return true
    }
}

do {
    guard getuid() == 0 else { throw LatestFailure.rejected("Launch the broker through System Settings, not directly.") }
    let host = try hostApplication()
    let configuration = try BrokerConfiguration.load(appURL: host)
    let engine = BrokerEngine(host: host, configuration: configuration)
    let delegate = ListenerDelegate(engine: engine, requirement: try ForkIdentity.requirement(identifier: ForkIdentity.application, team: configuration.team))
    let listener = NSXPCListener(machServiceName: ForkIdentity.broker)
    listener.delegate = delegate; listener.resume()
    withExtendedLifetime(delegate) { RunLoop.current.run() }
} catch {
    FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8)); exit(1)
}
