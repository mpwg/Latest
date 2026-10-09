import Foundation
import Darwin
import LatestCore

public struct CommandResult: Sendable {
    public let exitCode: Int32
    public let output: Data
    public var text: String { String(decoding: output, as: UTF8.self) }
}

/// Each invocation owns a process group, nonblocking output pipe and bounded lifetime.
public actor CommandRunner {
    public init() {}

    public func run(executable: URL, arguments: [String], environment: [String: String],
                    timeout: Duration = .seconds(45), maximumBytes: Int = 8_000_000) async throws -> CommandResult {
        guard executable.isFileURL, executable.path.hasPrefix("/"), !arguments.contains(where: { $0.contains("\0") }),
              !environment.contains(where: { $0.key.contains("=") || $0.key.contains("\0") || $0.value.contains("\0") }),
              maximumBytes > 0 else { throw LatestFailure.rejected("Invalid process request.") }
        try Task.checkCancellation()
        var descriptors: [Int32] = [0, 0]
        guard pipe(&descriptors) == 0 else { throw LatestFailure.process("Could not create process output pipe.") }
        let input = descriptors[0], output = descriptors[1]
        defer { close(input); close(output) }
        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        posix_spawn_file_actions_init(&actions); posix_spawnattr_init(&attributes)
        defer { posix_spawn_file_actions_destroy(&actions); posix_spawnattr_destroy(&attributes) }
        posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_adddup2(&actions, output, STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&actions, output, STDERR_FILENO)
        posix_spawn_file_actions_addclose(&actions, input)
        posix_spawn_file_actions_addclose(&actions, output)
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT))
        posix_spawnattr_setpgroup(&attributes, 0)
        let argv = ([executable.path] + arguments).map { strdup($0) } + [nil]
        let envp = environment.sorted { $0.key < $1.key }.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { for pointer in argv { free(pointer) }; for pointer in envp { free(pointer) } }
        var pid: pid_t = 0
        let result = argv.withUnsafeBufferPointer { args in
            envp.withUnsafeBufferPointer { env in
                posix_spawn(&pid, executable.path, &actions, &attributes,
                            UnsafeMutablePointer(mutating: args.baseAddress), UnsafeMutablePointer(mutating: env.baseAddress))
            }
        }
        guard result == 0 else { throw LatestFailure.process("Could not start \(executable.lastPathComponent): \(result).") }
        _ = fcntl(input, F_SETFL, fcntl(input, F_GETFL) | O_NONBLOCK)
        var reaped = false
        defer {
            if !reaped {
                // Cancellation also stops child installers; never leave an orphaned group.
                kill(-pid, SIGKILL)
                var ignored: Int32 = 0
                while waitpid(pid, &ignored, 0) < 0 && errno == EINTR {}
            }
        }
        var data = Data()
        let deadline = ContinuousClock.now.advanced(by: timeout)
        var status: Int32 = 0
        while true {
            try Task.checkCancellation()
            try Self.drain(input, into: &data, limit: maximumBytes)
            let waited = waitpid(pid, &status, WNOHANG)
            if waited == pid {
                reaped = true
                try Self.drain(input, into: &data, limit: maximumBytes)
                let signal = status & 0x7f
                return CommandResult(exitCode: signal == 0 ? (status >> 8) & 0xff : 128 + signal, output: data)
            }
            if waited < 0 && errno != EINTR { throw LatestFailure.process("Lost process completion.") }
            if ContinuousClock.now >= deadline { throw LatestFailure.timeout }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    private static func drain(_ descriptor: Int32, into data: inout Data, limit: Int) throws {
        var buffer = [UInt8](repeating: 0, count: 8192)
        while true {
            let count = buffer.withUnsafeMutableBytes { read(descriptor, $0.baseAddress, $0.count) }
            if count <= 0 { return }
            guard data.count <= limit - count else { throw LatestFailure.process("The process output exceeds the size limit.") }
            data.append(contentsOf: buffer.prefix(count))
        }
    }

    public static func userEnvironment(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [String: String] {
        ["HOME": home.path, "USER": NSUserName(), "LOGNAME": NSUserName(),
         "PATH": "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin",
         "LANG": "en_US.UTF-8", "MAS_NO_AUTO_INDEX": "1", "HOMEBREW_NO_AUTO_UPDATE": "1",
         "HOMEBREW_NO_ANALYTICS": "1", "HOMEBREW_NO_INSTALL_CLEANUP": "1"]
    }
}
