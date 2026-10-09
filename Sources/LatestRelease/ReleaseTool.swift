import Foundation
import CryptoKit
import Darwin
import LatestCore

@main struct ReleaseTool {
    static func main() {
        do { try run() }
        catch { FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8)); exit(1) }
    }
    static func run() throws {
        let arguments = CommandLine.arguments
        guard arguments.count >= 3 else { throw LatestFailure.rejected("Usage: LatestRelease keygen <private-key-file> | public-key <key-file> | sign <key-file-or-dash> <input> | sign-feed <key-file-or-dash> <input> <output>") }
        if arguments[1] == "keygen" {
            let url = URL(fileURLWithPath: arguments[2])
            guard !FileManager.default.fileExists(atPath: url.path) else { throw LatestFailure.rejected("Refusing to replace an existing signing key.") }
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let key = Curve25519.Signing.PrivateKey()
            let descriptor = open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
            guard descriptor >= 0 else { throw LatestFailure.rejected("Cannot create a private signing key safely.") }
            defer { close(descriptor) }
            let data = Data(key.rawRepresentation.base64EncodedString().utf8)
            let written = data.withUnsafeBytes { write(descriptor, $0.baseAddress, $0.count) }
            guard written == data.count, fsync(descriptor) == 0 else { throw LatestFailure.process("Cannot persist the signing key.") }
            print(key.publicKey.rawRepresentation.base64EncodedString()); return
        }
        let encoded = arguments[2] == "-" ? FileHandle.standardInput.readDataToEndOfFile() : try Data(contentsOf: URL(fileURLWithPath: arguments[2]))
        guard let text = String(data: encoded, encoding: .utf8), let seed = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)), seed.count == 32 else { throw LatestFailure.rejected("Invalid Ed25519 signing seed.") }
        if arguments[1] == "public-key" { print(try ReleaseSigning.publicKey(seed: seed)); return }
        guard arguments.count >= 4 else { throw LatestFailure.rejected("Input file missing.") }
        let data = try Data(contentsOf: URL(fileURLWithPath: arguments[3]))
        if arguments[1] == "sign" { print(try ReleaseSigning.signature(data: data, seed: seed)) }
        else if arguments[1] == "sign-feed", arguments.count == 5 { try ReleaseSigning.signedFeed(data, seed: seed).write(to: URL(fileURLWithPath: arguments[4]), options: .atomic) }
        else { throw LatestFailure.rejected("Unknown signing command.") }
    }
}
