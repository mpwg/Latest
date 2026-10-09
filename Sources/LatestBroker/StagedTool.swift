import Foundation
import Darwin
import LatestCore
import LatestContracts
import LatestTrust

struct StagedTool {
    let directory: URL
    let executable: URL

    static func prepare(source: URL, configuration: BrokerConfiguration) throws -> Self {
        guard getuid() == 0 else { throw LatestFailure.rejected("The installation broker must be launched by the system.") }
        let descriptor = open(source.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { throw LatestFailure.rejected("Cannot open the bundled tool safely.") }
        defer { close(descriptor) }
        var status = stat()
        guard fstat(descriptor, &status) == 0, status.st_mode & S_IFMT == S_IFREG,
              status.st_size > 0, status.st_size <= 128_000_000 else { throw LatestFailure.rejected("Invalid bundled tool file.") }
        var template = Array("/private/var/tmp/latest-broker.XXXXXX".utf8CString)
        guard let path = mkdtemp(&template) else { throw LatestFailure.process("Cannot stage the App Store tool.") }
        let directory = URL(fileURLWithPath: String(cString: path))
        let executable = directory.appendingPathComponent("mas")
        var success = false
        defer { if !success { try? FileManager.default.removeItem(at: directory) } }
        let output = open(executable.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o500)
        guard output >= 0 else { throw LatestFailure.process("Cannot create tool staging file.") }
        defer { close(output) }
        var remaining = status.st_size
        var buffer = [UInt8](repeating: 0, count: 65536)
        while remaining > 0 {
            let count = buffer.withUnsafeMutableBytes { read(descriptor, $0.baseAddress, min($0.count, Int(remaining))) }
            guard count > 0 else { throw LatestFailure.rejected("Bundled tool changed while being staged.") }
            var offset = 0
            while offset < count {
                let written = buffer.withUnsafeBytes { write(output, $0.baseAddress?.advanced(by: offset), count - offset) }
                guard written > 0 else { throw LatestFailure.process("Could not stage tool data.") }
                offset += written
            }
            remaining -= off_t(count)
        }
        guard fsync(output) == 0,
              try CodeTrust.sha256(executable) == configuration.masHash else { throw LatestFailure.rejected("Bundled tool digest mismatch.") }
        try CodeTrust.verify(executable, requirement: ForkIdentity.requirement(identifier: ForkIdentity.tool, team: configuration.team))
        success = true
        return .init(directory: directory, executable: executable)
    }
}
