import Foundation
import CryptoKit
import LatestCore

public struct InventoryResult: Sendable {
    public let apps: [AppSnapshot]
    public let warnings: [String]
}

public actor AppInventory {
    public init() {}
    public func scan(_ directories: [DirectoryPreference]) async -> InventoryResult {
        await Task.detached(priority: .utility) { Self.collect(directories) }.value
    }

    public static func collect(_ directories: [DirectoryPreference]) -> InventoryResult {
        var apps: [AppInstanceID: AppSnapshot] = [:]
        var warnings: [String] = []
        for directory in directories where directory.enabled {
            let root = URL(fileURLWithPath: directory.path)
            guard FileManager.default.isReadableFile(atPath: root.path) else {
                warnings.append("Cannot read directory: \(directory.path)"); continue
            }
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
                warnings.append("Cannot enumerate directory: \(directory.path)"); continue
            }
            while let url = enumerator.nextObject() as? URL {
                if Task.isCancelled { return .init(apps: Array(apps.values), warnings: warnings) }
                guard url.pathExtension.lowercased() == "app" else { continue }
                enumerator.skipDescendants()
                if let app = snapshot(at: url) { apps[app.id] = app }
                if apps.count >= 5000 { warnings.append("The inventory limit of 5000 apps was reached."); break }
            }
        }
        return .init(apps: apps.values.sorted { $0.id.path < $1.id.path }, warnings: warnings)
    }

    public static func snapshot(at url: URL) -> AppSnapshot? {
        let canonical = url.standardizedFileURL.resolvingSymlinksInPath()
        let infoURL = canonical.appendingPathComponent("Contents/Info.plist")
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: infoURL.path),
              let size = attributes[.size] as? Int, size <= 1_000_000,
              let data = try? Data(contentsOf: infoURL),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let bundleID = info["CFBundleIdentifier"] as? String, !bundleID.isEmpty else { return nil }
        let receipt = canonical.appendingPathComponent("Contents/_MASReceipt/receipt")
        let receiptValues = try? receipt.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        let hasReceipt = receiptValues?.isRegularFile == true && (receiptValues?.fileSize ?? 0) > 0
        var architectures = Set<Architecture>()
        if let executable = info["CFBundleExecutable"] as? String, executable == URL(fileURLWithPath: executable).lastPathComponent,
           let handle = try? FileHandle(forReadingFrom: canonical.appendingPathComponent("Contents/MacOS").appendingPathComponent(executable)) {
            defer { try? handle.close() }
            if let header = try? handle.read(upToCount: 4096) { architectures = MachO.architectures(header) }
        }
        let feed = (info["SUFeedURL"] as? String).flatMap(URL.init(string:)).flatMap { $0.scheme == "https" && $0.user == nil && $0.password == nil ? $0 : nil }
        let modification = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let fingerprint = SHA256.hash(data: data + Data("\(modification)|\(hasReceipt)".utf8)).map { String(format: "%02x", $0) }.joined()
        return AppSnapshot(url: canonical, bundleID: bundleID, name: info["CFBundleDisplayName"] as? String ?? info["CFBundleName"] as? String ?? canonical.deletingPathExtension().lastPathComponent,
                           version: .init(display: info["CFBundleShortVersionString"] as? String, build: info["CFBundleVersion"] as? String),
                           architectures: architectures, hasReceipt: hasReceipt,
                           isWrapped: FileManager.default.fileExists(atPath: canonical.appendingPathComponent("Wrapper").path),
                           feedURL: feed, fingerprint: fingerprint)
    }
}

public enum MachO {
    public static func architectures(_ data: Data) -> Set<Architecture> {
        guard data.count >= 8 else { return [] }
        func word(_ offset: Int, little: Bool) -> UInt32? {
            guard offset >= 0, offset + 4 <= data.count else { return nil }
            let bytes = Array(data[offset..<offset+4])
            let ordered = little ? bytes.reversed().map { $0 } : bytes
            return ordered.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        }
        func architecture(_ cpu: UInt32?) -> Architecture? {
            switch cpu { case 0x0100000c: .arm64; case 0x01000007: .x86_64; default: nil }
        }
        let magic = word(0, little: false)
        if magic == 0xcffaedfe || magic == 0xcefaedfe { return Set([architecture(word(4, little: true))].compactMap { $0 }) }
        if magic == 0xfeedfacf || magic == 0xfeedface { return Set([architecture(word(4, little: false))].compactMap { $0 }) }
        guard magic == 0xcafebabe || magic == 0xcafebabf || magic == 0xbebafeca || magic == 0xbfbafeca else { return [] }
        let little = magic == 0xbebafeca || magic == 0xbfbafeca
        guard let count = word(4, little: little), count <= 16 else { return [] }
        let stride = magic == 0xcafebabf || magic == 0xbfbafeca ? 32 : 20
        return Set((0..<Int(count)).compactMap { architecture(word(8 + $0 * stride, little: little)) })
    }
}
