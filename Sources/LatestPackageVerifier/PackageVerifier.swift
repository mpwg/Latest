import Foundation
import Darwin
import LatestCore
import LatestProcess

private final class PackageDescription: NSObject, XMLParserDelegate {
    var bundleIDs = Set<String>()
    var locations = Set<String>()
    var containsScripts = false
    let appName: String
    init(appName: String) { self.appName = appName }
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String]) {
        if name == "pkg-info", let location = attributes["install-location"] { locations.insert(location) }
        if name == "scripts" { containsScripts = true }
        if name == "bundle", let path = attributes["path"], URL(fileURLWithPath: path).lastPathComponent == appName,
           let id = attributes["id"] { bundleIDs.insert(id) }
    }
}

@main private struct PackageVerifier {
    static func main() async {
        do {
            let arguments = CommandLine.arguments
            guard getuid() == 0, geteuid() == 0, arguments.count == 5, let id = UInt64(arguments[2]) else {
                throw LatestFailure.rejected("Invalid package verification invocation.")
            }
            let claim = AppStoreClaim(storeID: id, bundleID: arguments[3], path: arguments[4])
            try BrokerPolicy.validate(claim, installed: [claim], outdatedIDs: [id])
            let source = URL(fileURLWithPath: arguments[1])
            let input = open(source.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
            guard input >= 0 else { throw LatestFailure.rejected("Cannot open package safely.") }
            defer { close(input) }
            var info = stat()
            guard fstat(input, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_size > 0, info.st_size <= 8_000_000_000 else {
                throw LatestFailure.rejected("Invalid package file.")
            }
            var template = Array("/private/var/tmp/latest-package.XXXXXX".utf8CString)
            guard let pointer = mkdtemp(&template) else { throw LatestFailure.process("Cannot stage package.") }
            let directory = URL(fileURLWithPath: String(cString: pointer))
            let package = directory.appendingPathComponent("update.pkg")
            var success = false
            defer { if !success { try? FileManager.default.removeItem(at: directory) } }
            let output = open(package.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o400)
            guard output >= 0 else { throw LatestFailure.process("Cannot create staged package.") }
            defer { close(output) }
            var buffer = [UInt8](repeating: 0, count: 65536)
            var remaining = info.st_size
            while remaining > 0 {
                let size = buffer.withUnsafeMutableBytes { read(input, $0.baseAddress, min(Int(remaining), $0.count)) }
                guard size > 0 else { throw LatestFailure.rejected("Package changed while copying.") }
                var offset = 0
                while offset < size {
                    let written = buffer.withUnsafeBytes { write(output, $0.baseAddress?.advanced(by: offset), size - offset) }
                    guard written > 0 else { throw LatestFailure.process("Cannot write staged package.") }
                    offset += written
                }
                remaining -= off_t(size)
            }
            guard fsync(output) == 0 else { throw LatestFailure.process("Cannot persist staged package.") }
            let runner = CommandRunner()
            let environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LANG": "en_US.UTF-8"]
            let signature = try await runner.run(executable: URL(fileURLWithPath: "/usr/sbin/pkgutil"), arguments: ["--check-signature", package.path], environment: environment)
            guard signature.exitCode == 0, signature.text.contains("signed by a certificate trusted by"),
                  signature.text.contains("Apple Root CA"),
                  signature.text.contains("Software Update") || signature.text.contains("Apple Mac OS Application Signing") || signature.text.contains("Apple Mac OS Application Installer") else {
                throw LatestFailure.rejected("The package is not authenticated as an Apple App Store package. Update through the App Store instead.")
            }
            let expanded = directory.appendingPathComponent("metadata")
            let expand = try await runner.run(executable: URL(fileURLWithPath: "/usr/sbin/pkgutil"), arguments: ["--expand", package.path, expanded.path], environment: environment)
            guard expand.exitCode == 0 else { throw LatestFailure.rejected("Cannot inspect package metadata.") }
            let description = PackageDescription(appName: URL(fileURLWithPath: claim.path).lastPathComponent)
            let enumerator = FileManager.default.enumerator(at: expanded, includingPropertiesForKeys: nil)
            while let url = enumerator?.nextObject() as? URL {
                if url.lastPathComponent == "Scripts" { description.containsScripts = true }
                if url.lastPathComponent == "PackageInfo" {
                    guard let data = try? Data(contentsOf: url), data.count < 1_000_000 else { throw LatestFailure.rejected("Invalid package manifest.") }
                    let parser = XMLParser(data: data); parser.shouldResolveExternalEntities = false; parser.delegate = description
                    guard parser.parse() else { throw LatestFailure.rejected("Invalid package manifest XML.") }
                }
            }
            let payload = try await runner.run(executable: URL(fileURLWithPath: "/usr/sbin/pkgutil"), arguments: ["--payload-files", package.path], environment: environment)
            guard payload.exitCode == 0 else { throw LatestFailure.rejected("Cannot enumerate package payload.") }
            try PackagePolicy.validate(bundleIDs: description.bundleIDs, installLocations: description.locations,
                                       payloadPaths: payload.stdoutText.split(whereSeparator: \.isNewline).map(String.init),
                                       containsScripts: description.containsScripts, claim: claim)
            // Existing symlinks must not redirect extraction outside the selected bundle.
            if let existing = FileManager.default.enumerator(at: URL(fileURLWithPath: claim.path), includingPropertiesForKeys: [.isSymbolicLinkKey]) {
                while let url = existing.nextObject() as? URL {
                    let path = url.resolvingSymlinksInPath().path
                    guard path == claim.path || path.hasPrefix(claim.path + "/") else { throw LatestFailure.rejected("The existing app contains an external symlink.") }
                }
            }
            success = true
            print(package.path)
        } catch {
            FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8)); exit(1)
        }
    }
}
