import Foundation
import LatestCore
import LatestProcess

public actor HomebrewProvider: UpdateProvider {
    private let runner: CommandRunner
    public let executable: URL?
    private var entries: [CaskMetadata] = []
    private var prefix: URL?
    private var loadedAt = Date.distantPast
    public init(runner: CommandRunner = .init(), executable: URL? = nil) {
        self.runner = runner
        self.executable = executable ?? ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first(where: FileManager.default.isExecutableFile).map(URL.init(fileURLWithPath:))
    }
    private func prepare() async throws {
        guard let executable else { return }
        if Date().timeIntervalSince(loadedAt) < 30 { return }
        let environment = CommandRunner.userEnvironment()
        let prefixResult = try await runner.run(executable: executable, arguments: ["--prefix"], environment: environment)
        guard prefixResult.exitCode == 0, prefixResult.text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("/") else { throw LatestFailure.process("Cannot determine the Homebrew prefix.") }
        let result = try await runner.run(executable: executable, arguments: ["info", "--cask", "--json=v2", "--installed"], environment: environment)
        guard result.exitCode == 0 else { throw LatestFailure.process("Cannot read installed Homebrew casks.") }
        entries = try Metadata.casks(result.output)
        prefix = URL(fileURLWithPath: prefixResult.text.trimmingCharacters(in: .whitespacesAndNewlines))
        loadedAt = Date()
    }
    public func check(_ app: AppSnapshot, context: CheckContext) async throws -> UpdateCandidate? {
        guard !app.hasReceipt, executable != nil else { return nil }
        try await prepare()
        guard let prefix else { return nil }
        let owned = entries.filter { entry in
            guard let installed = entry.installed, !installed.isEmpty else { return false }
            return entry.names.contains { name in
                let staged = prefix.appendingPathComponent("Caskroom").appendingPathComponent(entry.token)
                    .appendingPathComponent(installed).appendingPathComponent(name)
                return FileManager.default.fileExists(atPath: staged.path) && AppInstanceID(url: staged) == app.id
            }
        }
        guard owned.count == 1, let cask = owned.first, let executable else { return nil }
        if cask.autoUpdates, app.feedURL != nil { return nil }
        let result = try await runner.run(executable: executable, arguments: ["outdated", "--cask", "--json=v2", cask.token], environment: CommandRunner.userEnvironment())
        guard result.exitCode == 0 else { throw LatestFailure.process("Cannot check the installed cask.") }
        let outdated = try Metadata.outdatedCaskTokens(result.output).contains(cask.token)
        guard cask.version != "latest" else { return nil }
        let version = AppVersion(display: cask.version.split(separator: ",").first.map(String.init))
        return .init(app: app, source: .homebrew, version: version, action: .homebrew(cask.token),
                     authoritative: true, channel: version.isPrerelease ? .beta : .stable, minimumOS: cask.minimumOS,
                     comparison: outdated ? .older : .same)
    }
    public func upgrade(_ candidate: UpdateCandidate, context: CheckContext) async throws {
        guard let executable, case .homebrew(let token) = candidate.action, Metadata.validToken(token) else {
            throw LatestFailure.rejected("Invalid Homebrew update.")
        }
        loadedAt = .distantPast
        guard let fresh = try await check(candidate.app, context: context), fresh.action == candidate.action,
              fresh.comparison == .older else { throw LatestFailure.rejected("Homebrew ownership or update state changed.") }
        let result = try await runner.run(executable: executable, arguments: ["upgrade", "--cask", "--no-ask", token], environment: CommandRunner.userEnvironment(), timeout: .seconds(1200))
        loadedAt = .distantPast
        guard result.exitCode == 0 else { throw LatestFailure.process(String(result.text.suffix(4000))) }
    }
}
